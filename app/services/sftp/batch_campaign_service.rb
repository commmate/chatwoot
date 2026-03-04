# frozen_string_literal: true

class Sftp::BatchCampaignService
  include Sftp::BatchNotifier

  def initialize(batch_path:)
    @batch_path = batch_path
  end

  CHECKPOINT_INTERVAL = 25

  def perform
    mtr_files = Dir.glob(File.join(@batch_path, '*.mtr'))
    return notify_invalid_upload(reason: :no_mtr_files) if mtr_files.empty?

    sample = parse_sample(mtr_files.first)
    return unless sample

    return notify_invalid_upload(reason: :missing_required_fields) if sample[:company_name].blank? || sample[:from].blank?

    inbox = resolve_inbox(sample, mtr_files.size)
    return unless inbox

    send_campaign(inbox, mtr_files, sample)
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
    inbox = find_resend_inbox(account, sample[:from], from_domain)

    return notify_no_inbox(account, from_domain, batch_info, reason: :no_matching_inbox) unless inbox
    return notify_no_inbox(account, from_domain, batch_info, reason: :sftp_disabled) unless inbox.channel.provider_config['sftp_campaigns_enabled']

    inbox
  end

  def find_resend_inbox(account, from_email, from_domain)
    return nil if from_domain.blank?

    resend_inboxes = account.inboxes
                            .where(channel_type: 'Channel::Email')
                            .select { |inb| inb.channel.provider == 'resend' }

    # Prefer exact from_email match so multiple Resend inboxes per domain resolve correctly
    resend_inboxes.find { |inb| inb.channel.provider_config['from_email'] == from_email } ||
      resend_inboxes.find { |inb| inb.channel.provider_config['from_email']&.split('@')&.last == from_domain }
  end

  def send_campaign(inbox, mtr_files, sample)
    preview = build_preview(mtr_files)
    campaign = find_or_create_campaign(inbox, mtr_files, sample, preview)
    report = find_or_create_delivery_report(campaign, mtr_files.size)

    already_sent_job_ids = report.message_mappings.where.not(external_job_id: nil).pluck(:external_job_id).to_set
    remaining_files = mtr_files.reject { |f| already_sent_job_ids.include?(job_id_from_mtr(f)) }

    if already_sent_job_ids.any?
      Rails.logger.info("[SFTP] Resuming batch #{sample[:batch_id]}: #{already_sent_job_ids.size} already sent, #{remaining_files.size} remaining")
    end

    client = build_sender(inbox)
    entries = prepare_entries(remaining_files)
    sends_since_checkpoint = 0

    Resend::BatchSenderService.new(client: client).send_all(entries) do |entry, result|
      if result[:ok]
        record_success(campaign, report, entry[:meta][:data], result)
      else
        Rails.logger.error("[SFTP] Failed to send email #{entry[:meta][:mtr_path]}: #{result[:error_message]}")
        report.failed += 1
        report.record_error(code: result[:error_code], message: result[:error_message], details: "MTR: #{entry[:meta][:mtr_path]}")
      end
      sends_since_checkpoint += 1
      if sends_since_checkpoint >= CHECKPOINT_INTERVAL
        report.save!
        sends_since_checkpoint = 0
      end
    end
    report.finalize!
    campaign.completed!
  end

  def prepare_entries(mtr_files)
    mtr_files.map do |mtr_path|
      data = Sftp::MtrParser.new(mtr_path).parse
      payload = build_email_payload(data, mtr_path)
      { payload: payload, meta: { mtr_path: mtr_path, data: data } }
    end
  end

  def find_or_create_campaign(inbox, mtr_files, sample, preview)
    batch_id = sample[:batch_id]
    if batch_id.present?
      existing = inbox.account.campaigns
                      .where(campaign_status: :sending)
                      .find_by("additional_attributes->>'sftp_batch_id' = ?", batch_id)
      return existing if existing
    end

    inbox.account.campaigns.create!(
      inbox: inbox,
      title: "SFTP — #{sample[:company_name]} — #{batch_id&.slice(0, 8)}",
      description: sftp_description(preview, mtr_files.size),
      campaign_type: :one_off,
      campaign_status: :sending,
      message: preview[:html_body].presence || 'SFTP batch campaign',
      audience: [],
      additional_attributes: campaign_attributes(sample, preview, mtr_files.size)
    )
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

  def find_or_create_delivery_report(campaign, total)
    campaign.delivery_report || campaign.create_delivery_report!(
      provider: 'resend', status: 'running', total: total, started_at: Time.current
    )
  end

  def job_id_from_mtr(mtr_path)
    Sftp::MtrParser.new(mtr_path).parse[:job_id]
  rescue StandardError
    nil
  end

  def build_sender(inbox)
    config = inbox.channel.provider_config
    Resend::Client.new(api_key: config['api_key'])
  end

  def build_email_payload(data, mtr_path)
    payload = {
      from: data[:from],
      to: Array(data[:to_email]),
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

  def record_success(campaign, report, data, result)
    contact = find_or_create_contact(campaign.account, data)
    mapping_attrs = {
      campaign_delivery_report: report, contact: contact,
      resend_email_id: result[:email_id], status: 'sent'
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
