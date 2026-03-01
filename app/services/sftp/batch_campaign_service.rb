# frozen_string_literal: true

class Sftp::BatchCampaignService
  include Sftp::BatchNotifier

  def initialize(batch_path:)
    @batch_path = batch_path
  end

  def perform
    mtr_files = Dir.glob(File.join(@batch_path, '*.mtr'))
    return notify_invalid_upload(reason: :no_mtr_files) if mtr_files.empty?

    sample = parse_sample(mtr_files.first)
    return unless sample

    return notify_invalid_upload(reason: :missing_required_fields) if sample[:company_name].blank? || sample[:from].blank?

    inbox = resolve_inbox(sample, mtr_files.size)
    return unless inbox

    send_campaign(inbox, mtr_files, sample)
  ensure
    FileUtils.rm_rf(@batch_path)
  end

  private

  def parse_sample(mtr_path)
    Sftp::MtrParser.new(mtr_path).parse
  rescue Nokogiri::XML::SyntaxError, StandardError => e
    notify_invalid_upload(reason: :xml_parse_error, details: e.message)
    nil
  end

  def resolve_inbox(sample, file_count)
    batch_info = build_batch_info(sample, file_count)

    account = Account.find_by(name: sample[:company_name])
    return notify_no_account(sample[:company_name], batch_info) unless account

    from_domain = sample[:from]&.split('@')&.last
    inbox = find_resend_inbox(account, from_domain)

    return notify_no_inbox(account, from_domain, batch_info, reason: :no_matching_inbox) unless inbox
    return notify_no_inbox(account, from_domain, batch_info, reason: :sftp_disabled) unless inbox.channel.provider_config['sftp_campaigns_enabled']

    inbox
  end

  def find_resend_inbox(account, from_domain)
    return nil if from_domain.blank?

    account.inboxes
           .where(channel_type: 'Channel::Email')
           .find do |inb|
             ch = inb.channel
             ch.provider == 'resend' &&
               ch.provider_config['from_email']&.split('@')&.last == from_domain
           end
  end

  def send_campaign(inbox, mtr_files, sample)
    preview = build_preview(mtr_files)
    campaign = create_campaign(inbox, mtr_files, sample, preview)
    report = create_delivery_report(campaign, mtr_files.size)

    sender = build_sender(inbox)
    mtr_files.each { |mtr_path| deliver_email(sender, campaign, report, mtr_path) }
    report.finalize!
  end

  def create_campaign(inbox, mtr_files, sample, preview)
    campaign = inbox.account.campaigns.create!(
      inbox: inbox,
      title: "SFTP — #{sample[:company_name]} — #{sample[:batch_id]&.slice(0, 8)}",
      description: sftp_description(preview, mtr_files.size),
      campaign_type: :one_off,
      campaign_status: :active,
      message: preview[:html_body].presence || 'SFTP batch campaign',
      audience: [],
      additional_attributes: campaign_attributes(sample, preview, mtr_files.size)
    )
    campaign.completed!
    campaign
  end

  def campaign_attributes(sample, preview, email_count)
    {
      'sftp_batch_id' => sample[:batch_id],
      'sftp_company_name' => sample[:company_name],
      'sftp_company_id' => sample[:company_id],
      'sftp_source' => 'offmail',
      'email_count' => email_count,
      'email_subject' => preview[:subject],
      'preview_recipients' => preview[:recipients],
      'recipient_count' => preview[:recipient_count],
      'has_attachments' => preview[:has_attachments],
      'attachment_count' => preview[:attachment_count]
    }
  end

  def create_delivery_report(campaign, total)
    campaign.create_delivery_report!(
      provider: 'resend',
      status: 'running',
      total: total,
      started_at: Time.current
    )
  end

  def build_sender(inbox)
    channel = inbox.channel
    config = channel.provider_config
    from_name = config['from_name'] || inbox.name
    {
      client: Resend::Client.new(api_key: config['api_key']),
      from_address: "#{from_name} <#{config['from_email']}>"
    }
  end

  def deliver_email(sender, campaign, report, mtr_path)
    data = Sftp::MtrParser.new(mtr_path).parse
    payload = build_email_payload(sender[:from_address], data, mtr_path)
    response = sender[:client].send_email(**payload)

    record_success(campaign, report, data, response)
  rescue Resend::Client::ApiError => e
    Rails.logger.error("[SFTP] Failed to send email #{mtr_path}: #{e.message}")
    report.failed += 1
    report.record_error(code: e.error_code, message: e.message, details: "MTR: #{mtr_path}")
  end

  def build_email_payload(from_address, data, mtr_path)
    payload = {
      from: from_address,
      to: data[:to_email],
      subject: data[:subject] || '(No subject)',
      html: data[:html_body].presence || '<p></p>'
    }
    payload[:reply_to] = data[:reply_to] if data[:reply_to].present?
    attach_pdf(payload, mtr_path)
    payload
  end

  def attach_pdf(payload, mtr_path)
    pdf_path = mtr_path.sub('.mtr', '.pdf')
    return unless File.exist?(pdf_path)

    payload[:attachments] = [{
      filename: File.basename(pdf_path),
      content: Base64.strict_encode64(File.binread(pdf_path)),
      content_type: 'application/pdf'
    }]
  end

  def record_success(campaign, report, data, response)
    contact = find_or_create_contact(campaign.account, data)
    mapping_attrs = {
      campaign_delivery_report: report, contact: contact,
      resend_email_id: response['id'], status: 'sent'
    }
    mapping_attrs[:external_job_id] = data[:job_id] if data[:job_id].present? && external_job_id_column?

    CampaignMessageMapping.create!(mapping_attrs)
    report.succeeded += 1
  end

  def external_job_id_column?
    CampaignMessageMapping.column_names.include?('external_job_id')
  end

  def find_or_create_contact(account, data)
    account.contacts.find_or_create_by!(email: data[:to_email]) do |c|
      c.name = (data[:to_email].split('@').first || 'Contact').titleize
    end
  end

  def sftp_description(preview, count)
    parts = ["SFTP batch — #{count} email(s)"]
    parts << "Subject: #{preview[:subject]}" if preview[:subject].present?
    parts << "#{preview[:attachment_count]} PDF attachment(s)" if preview[:has_attachments]
    parts.join(' · ')
  end

  def build_preview(mtr_files)
    first_data = Sftp::MtrParser.new(mtr_files.first).parse
    recipients = mtr_files.filter_map { |f| Sftp::MtrParser.new(f).parse[:to_email] }.uniq
    attachment_count = mtr_files.count { |f| File.exist?(f.sub('.mtr', '.pdf')) }

    {
      subject: first_data[:subject], html_body: first_data[:html_body],
      recipients: recipients, recipient_count: recipients.size,
      has_attachments: attachment_count.positive?, attachment_count: attachment_count
    }
  end

  def build_batch_info(sample, file_count)
    {
      batch_id: sample[:batch_id], company_name: sample[:company_name],
      from_email: sample[:from], email_count: file_count,
      folder_name: File.basename(@batch_path), timestamp: Time.current.iso8601
    }
  end
end
