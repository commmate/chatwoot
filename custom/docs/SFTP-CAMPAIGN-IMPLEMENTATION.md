# SFTP Campaign — Implementation Plan & Test Spec

**Reference**: [SFTP-CAMPAIGN-PROPOSAL.md](./SFTP-CAMPAIGN-PROPOSAL.md) (Draft 3.0)  
**Date**: March 2026  

---

## Implementation Tickets

Each ticket is a self-contained unit of work that can be merged independently. Tickets within a phase should be done in order; phases themselves are sequential (each depends on the previous).

---

### Phase 1: Super Admin — Resend Toggle

> Gate Resend inboxes behind a Super Admin toggle, same pattern as Evolution API.

#### Ticket 1.1 — Backend: `RESEND_ENABLED` Installation Config

**Files to create/modify**:
- `config/installation_config.yml` — add `RESEND_ENABLED` entry
- `app/helpers/super_admin/features.yml` — add `resend` feature card
- `app/controllers/super_admin/app_configs_controller.rb` — add `'resend' => %w[RESEND_ENABLED]` mapping

**Acceptance criteria**:
- [ ] `RESEND_ENABLED` appears in Super Admin → Settings → Resend Email
- [ ] Default value is `false`
- [ ] Toggling persists across server restarts
- [ ] `GlobalConfigService.load('RESEND_ENABLED', 'false')` returns the correct value

#### Ticket 1.2 — Frontend: Gate Resend Inbox Creation

**Files to modify**:
- `app/controllers/dashboard_controller.rb` — expose `RESEND_ENABLED`
- `app/views/layouts/vueapp.html.erb` — pass `resendEnabled` to `window.chatwootConfig`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/Email.vue` — hide Resend option when disabled
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/emailChannels/Resend.vue` — redirect if disabled

**Acceptance criteria**:
- [ ] When `RESEND_ENABLED=false`: Resend option does not appear in inbox creation
- [ ] When `RESEND_ENABLED=true`: Resend option appears normally
- [ ] Existing Resend inboxes continue to function regardless of toggle (toggle only gates new creation)

#### Ticket 1.3 — Backend: Guard Resend Inbox Provisioning

**Files to modify**:
- `app/services/resend/inbox_validator.rb` (or equivalent) — check `RESEND_ENABLED` before creating

**Acceptance criteria**:
- [ ] API call to create a Resend inbox returns error when `RESEND_ENABLED=false`
- [ ] API call succeeds when `RESEND_ENABLED=true`

---

### Phase 2: Super Admin — SFTP Campaigns Toggle

> Add SFTP Campaigns as a separate Super Admin feature with configurable watch path.

#### Ticket 2.1 — Backend: SFTP Campaigns Installation Config

**Files to create/modify**:
- `config/installation_config.yml` — add `SFTP_CAMPAIGNS_ENABLED` and `SFTP_CAMPAIGNS_PATH`
- `app/helpers/super_admin/features.yml` — add `sftp_campaigns` feature card
- `app/controllers/super_admin/app_configs_controller.rb` — add `'sftp_campaigns' => %w[SFTP_CAMPAIGNS_ENABLED SFTP_CAMPAIGNS_PATH]`

**Acceptance criteria**:
- [ ] Super Admin → Settings shows "SFTP Campaigns" card
- [ ] Config page at `/super_admin/app_config?config=sftp_campaigns` shows both fields
- [ ] `SFTP_CAMPAIGNS_ENABLED` defaults to `false`
- [ ] `SFTP_CAMPAIGNS_PATH` defaults to `/data/sftp/campaigns`
- [ ] Both values are editable and persist

#### Ticket 2.2 — Frontend: Expose SFTP Campaigns Config

**Files to modify**:
- `app/controllers/dashboard_controller.rb` — expose `SFTP_CAMPAIGNS_ENABLED`
- `app/views/layouts/vueapp.html.erb` — pass `sftpCampaignsEnabled`

**Acceptance criteria**:
- [ ] `window.chatwootConfig.sftpCampaignsEnabled` reflects the Super Admin setting

---

### Phase 3: Per-Inbox SFTP Toggle

> Add an "Allow SFTP Campaigns" checkbox to each Resend inbox settings page.

#### Ticket 3.1 — Frontend: SFTP Toggle in Resend Settings

**Files to modify**:
- `app/javascript/dashboard/routes/dashboard/settings/inbox/resend/ResendSettings.vue`
- `app/javascript/dashboard/i18n/locale/en/settings.json` — add i18n keys
- `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json` — add i18n keys

**Acceptance criteria**:
- [ ] Toggle only visible when both `resendEnabled` and `sftpCampaignsEnabled` are `true`
- [ ] Toggling updates `provider_config.sftp_campaigns_enabled`
- [ ] Info box appears when enabled, showing the inbox domain
- [ ] Toggle hidden when either global flag is off

#### Ticket 3.2 — Backend: Allow `sftp_campaigns_enabled` in provider_config

**Files to modify**:
- Inbox update API (strong params) — permit `sftp_campaigns_enabled` in `provider_config`

**Acceptance criteria**:
- [ ] API accepts `sftp_campaigns_enabled` in the `provider_config` payload
- [ ] Value is persisted in `channel_email.provider_config`

---

### Phase 4: Sample SFTP Container Documentation

#### Ticket 4.1 — Create Sample Docker Compose + Docs

**Files to create**:
- `custom/docs/docker-compose.sftp-sample.yaml`

**Acceptance criteria**:
- [ ] Sample compose file is well-commented
- [ ] Key generation instructions are included
- [ ] Volume sharing instructions for CommMate containers are documented

---

### Phase 5: Watcher Job + Processing Pipeline

> Core backend logic: scan, parse, route, send, cleanup.

#### Ticket 5.1 — `Sftp::MtrParser` — XML Parser

**Files to create**:
- `app/services/sftp/mtr_parser.rb`

**Acceptance criteria**:
- [ ] Parses the example `.mtr` file correctly (from `custom/docs/sftp-camping-email-example/`)
- [ ] Extracts all required fields: `job_id`, `batch_id`, `company_name`, `from`, `to_email`, `subject`, `html_body`
- [ ] Decodes base64-encoded `Body` to HTML
- [ ] Returns `nil` for missing optional fields without erroring
- [ ] Raises `Nokogiri::XML::SyntaxError` on invalid XML

#### Ticket 5.2 — `Sftp::WatcherJob` — Cron Scanner

**Files to create**:
- `app/jobs/sftp/watcher_job.rb`
- `config/schedule.yml` — add `sftp_watcher` cron entry

**Acceptance criteria**:
- [ ] Does nothing when `RESEND_ENABLED=false`
- [ ] Does nothing when `SFTP_CAMPAIGNS_ENABLED=false`
- [ ] Does nothing when `SFTP_CAMPAIGNS_PATH` does not exist
- [ ] Enqueues `Sftp::ProcessBatchJob` for each subdirectory
- [ ] Deletes stray files (non-folders) and sends `invalid_upload` notification
- [ ] Skips `.` and `..` entries

#### Ticket 5.3 — `Sftp::ProcessBatchJob` + `Sftp::BatchCampaignService`

**Files to create**:
- `app/jobs/sftp/process_batch_job.rb`
- `app/services/sftp/batch_campaign_service.rb`

**Dependencies**: Ticket 5.1 (MtrParser)

**Acceptance criteria**:
- [ ] **Empty folder**: notifies Super Admins (invalid upload), deletes folder
- [ ] **Malformed XML**: notifies Super Admins (invalid upload), deletes folder
- [ ] **Missing required fields**: notifies Super Admins (invalid upload), deletes folder
- [ ] **No matching account**: notifies Super Admins (no account found), deletes folder
- [ ] **No matching inbox**: notifies Account Admins (no inbox found), deletes folder
- [ ] **Inbox SFTP disabled**: notifies Account Admins (SFTP disabled), deletes folder
- [ ] **Happy path**: creates Campaign, sends emails via Resend, creates CampaignMessageMapping per email, deletes folder
- [ ] Campaign `additional_attributes` contains `sftp_batch_id`, `sftp_company_name`, `sftp_source`
- [ ] PDF attachments are base64-encoded and included in the Resend payload
- [ ] Contacts are find-or-created by email address
- [ ] Individual email send failures are logged but don't stop the batch

#### Ticket 5.4 — Database Migration: `external_job_id`

**Files to create**:
- `db/migrate/XXXXXX_add_external_job_id_to_campaign_message_mappings.rb`

**Acceptance criteria**:
- [ ] Adds `external_job_id` string column to `campaign_message_mappings`
- [ ] Adds index on `external_job_id`
- [ ] Migration is reversible

---

### Phase 6: Notification Emails

#### Ticket 6.1 — `SftpCampaignMailer` + Views

**Files to create**:
- `app/mailers/sftp_campaign_mailer.rb`
- `app/views/sftp_campaign_mailer/invalid_upload.html.erb`
- `app/views/sftp_campaign_mailer/no_account_found.html.erb`
- `app/views/sftp_campaign_mailer/no_inbox_found.html.erb`

**Acceptance criteria**:
- [ ] `invalid_upload` email renders with entry name, reason, details, timestamp
- [ ] `no_account_found` email renders with company name, batch info, action hint
- [ ] `no_inbox_found` email renders with account name, domain, reason, action hint
- [ ] All emails use `ApplicationMailer` settings (from address, SMTP config)
- [ ] All emails are enqueued via `deliver_later` (async)

---

## Test Plan

### Unit Tests (RSpec)

#### `spec/services/sftp/mtr_parser_spec.rb`

```ruby
RSpec.describe Sftp::MtrParser do
  let(:fixture_path) { Rails.root.join('spec/fixtures/sftp') }

  describe '#parse' do
    context 'with a valid .mtr file' do
      let(:parser) { described_class.new(fixture_path.join('valid.mtr')) }
      let(:result) { parser.parse }

      it 'extracts job_id' do
        expect(result[:job_id]).to eq('f5c76b69-0cda-11f1-9835-00155d012944')
      end

      it 'extracts batch_id' do
        expect(result[:batch_id]).to eq('741c2d68-e192-42b1-8b0c-fff434c8cd38')
      end

      it 'extracts company_name' do
        expect(result[:company_name]).to eq('TicoMailWorks')
      end

      it 'extracts from email' do
        expect(result[:from]).to eq('sender@company.ie')
      end

      it 'extracts to_email' do
        expect(result[:to_email]).to eq('recipient@example.com')
      end

      it 'extracts subject' do
        expect(result[:subject]).to eq('Subject Line')
      end

      it 'decodes base64 body to HTML' do
        expect(result[:html_body]).to include('<html')
      end
    end

    context 'with invalid XML' do
      let(:parser) { described_class.new(fixture_path.join('invalid.mtr')) }

      it 'raises Nokogiri::XML::SyntaxError' do
        expect { parser.parse }.to raise_error(Nokogiri::XML::SyntaxError)
      end
    end

    context 'with missing optional fields' do
      let(:parser) { described_class.new(fixture_path.join('minimal.mtr')) }

      it 'returns nil for missing fields without error' do
        result = parser.parse
        expect(result[:cc_email]).to be_nil
        expect(result[:reply_to]).to be_nil
      end
    end
  end
end
```

#### `spec/jobs/sftp/watcher_job_spec.rb`

```ruby
RSpec.describe Sftp::WatcherJob do
  let(:campaigns_path) { Dir.mktmpdir('sftp_campaigns') }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('SFTP_CAMPAIGNS_PATH', anything).and_return(campaigns_path)
  end

  after { FileUtils.rm_rf(campaigns_path) }

  context 'when RESEND_ENABLED is false' do
    before do
      allow(GlobalConfigService).to receive(:load).with('RESEND_ENABLED', 'false').and_return('false')
    end

    it 'does not scan the directory' do
      FileUtils.mkdir_p("#{campaigns_path}/batch_1")
      expect(Sftp::ProcessBatchJob).not_to receive(:perform_later)
      described_class.perform_now
    end
  end

  context 'when SFTP_CAMPAIGNS_ENABLED is false' do
    before do
      allow(GlobalConfigService).to receive(:load).with('RESEND_ENABLED', 'false').and_return('true')
      allow(GlobalConfigService).to receive(:load).with('SFTP_CAMPAIGNS_ENABLED', 'false').and_return('false')
    end

    it 'does not scan the directory' do
      FileUtils.mkdir_p("#{campaigns_path}/batch_1")
      expect(Sftp::ProcessBatchJob).not_to receive(:perform_later)
      described_class.perform_now
    end
  end

  context 'when both features are enabled' do
    before do
      allow(GlobalConfigService).to receive(:load).with('RESEND_ENABLED', 'false').and_return('true')
      allow(GlobalConfigService).to receive(:load).with('SFTP_CAMPAIGNS_ENABLED', 'false').and_return('true')
    end

    it 'enqueues ProcessBatchJob for each subdirectory' do
      FileUtils.mkdir_p("#{campaigns_path}/batch_1")
      FileUtils.mkdir_p("#{campaigns_path}/batch_2")

      expect(Sftp::ProcessBatchJob).to receive(:perform_later).with(batch_path: "#{campaigns_path}/batch_1")
      expect(Sftp::ProcessBatchJob).to receive(:perform_later).with(batch_path: "#{campaigns_path}/batch_2")
      described_class.perform_now
    end

    it 'deletes stray files and notifies super admins' do
      File.write("#{campaigns_path}/stray_file.txt", 'garbage')
      create(:super_admin)

      expect(Sftp::ProcessBatchJob).not_to receive(:perform_later)
      expect { described_class.perform_now }.to have_enqueued_mail(SftpCampaignMailer, :invalid_upload)
      expect(File.exist?("#{campaigns_path}/stray_file.txt")).to be false
    end

    it 'does nothing when the path does not exist' do
      FileUtils.rm_rf(campaigns_path)
      expect(Sftp::ProcessBatchJob).not_to receive(:perform_later)
      described_class.perform_now
    end
  end
end
```

#### `spec/services/sftp/batch_campaign_service_spec.rb`

```ruby
RSpec.describe Sftp::BatchCampaignService do
  let(:batch_path) { Dir.mktmpdir('sftp_batch') }
  let(:service) { described_class.new(batch_path: batch_path) }

  let!(:account) { create(:account, name: 'TicoMailWorks') }
  let!(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:channel) do
    create(:channel_email, provider: 'resend', provider_config: {
      'api_key' => 're_test',
      'from_email' => 'noreply@company.ie',
      'from_name' => 'Company',
      'sftp_campaigns_enabled' => true
    })
  end

  after { FileUtils.rm_rf(batch_path) }

  def write_mtr(path, company: 'TicoMailWorks', from: 'noreply@company.ie', to: 'user@test.com')
    File.write(path, <<~XML)
      <MiniTicketX>
        <JobID>#{SecureRandom.uuid}</JobID>
        <BatchID>#{SecureRandom.uuid}</BatchID>
        <CompanyName>#{company}</CompanyName>
        <CompanyID>1</CompanyID>
        <DeliveryServices>
          <Email><EmailOptions>
            <From>#{from}</From>
            <ToEmail>#{to}</ToEmail>
            <Subject>Test</Subject>
            <Body>#{Base64.strict_encode64('<html><body>Hello</body></html>')}</Body>
          </EmailOptions></Email>
        </DeliveryServices>
      </MiniTicketX>
    XML
  end

  context 'with an empty folder (no .mtr files)' do
    before { create(:super_admin) }

    it 'notifies super admins and deletes the folder' do
      expect { service.perform }.to have_enqueued_mail(SftpCampaignMailer, :invalid_upload)
      expect(Dir.exist?(batch_path)).to be false
    end
  end

  context 'with malformed XML' do
    before do
      File.write("#{batch_path}/bad.mtr", '<broken xml')
      create(:super_admin)
    end

    it 'notifies super admins and deletes the folder' do
      expect { service.perform }.to have_enqueued_mail(SftpCampaignMailer, :invalid_upload)
      expect(Dir.exist?(batch_path)).to be false
    end
  end

  context 'with missing required fields (no CompanyName)' do
    before do
      write_mtr("#{batch_path}/test.mtr", company: '')
      create(:super_admin)
    end

    it 'notifies super admins and deletes the folder' do
      expect { service.perform }.to have_enqueued_mail(SftpCampaignMailer, :invalid_upload)
      expect(Dir.exist?(batch_path)).to be false
    end
  end

  context 'when no account matches CompanyName' do
    before do
      write_mtr("#{batch_path}/test.mtr", company: 'NonExistentCo')
      create(:super_admin)
    end

    it 'notifies super admins and deletes the folder' do
      expect { service.perform }.to have_enqueued_mail(SftpCampaignMailer, :no_account_found)
      expect(Dir.exist?(batch_path)).to be false
    end
  end

  context 'when account exists but no Resend inbox matches the domain' do
    before do
      write_mtr("#{batch_path}/test.mtr", from: 'noreply@otherdomain.com')
      create(:administrator, account: account)
    end

    it 'notifies account admins and deletes the folder' do
      expect { service.perform }.to have_enqueued_mail(SftpCampaignMailer, :no_inbox_found)
      expect(Dir.exist?(batch_path)).to be false
    end
  end

  context 'when inbox exists but sftp_campaigns_enabled is false' do
    before do
      channel.update!(provider_config: channel.provider_config.merge('sftp_campaigns_enabled' => false))
      write_mtr("#{batch_path}/test.mtr")
      create(:administrator, account: account)
    end

    it 'notifies account admins and deletes the folder' do
      expect { service.perform }.to have_enqueued_mail(SftpCampaignMailer, :no_inbox_found)
      expect(Dir.exist?(batch_path)).to be false
    end
  end

  context 'happy path — valid batch with matching account and inbox' do
    let(:resend_response) { { 'id' => 'resend_email_123' } }

    before do
      write_mtr("#{batch_path}/email1.mtr", to: 'alice@test.com')
      write_mtr("#{batch_path}/email2.mtr", to: 'bob@test.com')
      File.write("#{batch_path}/email1.pdf", '%PDF-fake')
      File.write("#{batch_path}/email2.pdf", '%PDF-fake')

      allow_any_instance_of(Resend::Client).to receive(:send_email).and_return(resend_response)
    end

    it 'creates a campaign' do
      expect { service.perform }.to change(Campaign, :count).by(1)

      campaign = Campaign.last
      expect(campaign.title).to start_with('SFTP — TicoMailWorks')
      expect(campaign.campaign_type).to eq('one_off')
      expect(campaign.additional_attributes['sftp_source']).to eq('offmail')
      expect(campaign.additional_attributes['email_count']).to eq(2)
    end

    it 'creates CampaignMessageMapping for each email' do
      expect { service.perform }.to change(CampaignMessageMapping, :count).by(2)

      mappings = CampaignMessageMapping.last(2)
      expect(mappings.map(&:resend_email_id)).to all(eq('resend_email_123'))
    end

    it 'creates or finds contacts' do
      expect { service.perform }.to change(Contact, :count).by(2)
    end

    it 'sends emails via Resend client' do
      expect_any_instance_of(Resend::Client).to receive(:send_email).twice
      service.perform
    end

    it 'includes PDF attachment in payload' do
      expect_any_instance_of(Resend::Client).to receive(:send_email).twice do |payload|
        expect(payload[:attachments]).to be_present
        expect(payload[:attachments].first[:content_type]).to eq('application/pdf')
      end
      service.perform
    end

    it 'deletes the batch folder after processing' do
      service.perform
      expect(Dir.exist?(batch_path)).to be false
    end

    it 'marks campaign as completed' do
      service.perform
      expect(Campaign.last.campaign_status).to eq('completed')
    end
  end

  context 'when one email in the batch fails to send' do
    before do
      write_mtr("#{batch_path}/email1.mtr", to: 'alice@test.com')
      write_mtr("#{batch_path}/email2.mtr", to: 'bob@test.com')

      call_count = 0
      allow_any_instance_of(Resend::Client).to receive(:send_email) do
        call_count += 1
        raise Resend::Client::ApiError, 'rate limit' if call_count == 1

        { 'id' => 'resend_email_456' }
      end
    end

    it 'continues processing the remaining emails' do
      service.perform
      expect(CampaignMessageMapping.count).to eq(1)
    end

    it 'still creates the campaign and deletes the folder' do
      service.perform
      expect(Campaign.count).to eq(1)
      expect(Dir.exist?(batch_path)).to be false
    end
  end
end
```

#### `spec/mailers/sftp_campaign_mailer_spec.rb`

```ruby
RSpec.describe SftpCampaignMailer do
  describe '#invalid_upload' do
    let(:mail) do
      described_class.invalid_upload(
        entry_name: 'random_file.zip',
        reason: :not_a_folder,
        recipients: ['admin@example.com']
      )
    end

    it 'renders the subject' do
      expect(mail.subject).to include('invalid upload')
      expect(mail.subject).to include('random_file.zip')
    end

    it 'sends to the provided recipients' do
      expect(mail.to).to eq(['admin@example.com'])
    end

    it 'includes the entry name in the body' do
      expect(mail.body.encoded).to include('random_file.zip')
    end
  end

  describe '#no_account_found' do
    let(:mail) do
      described_class.no_account_found(
        company_name: 'Hospital XYZ',
        batch_info: { folder_name: 'batch_1', email_count: 47, timestamp: Time.current.iso8601 },
        recipients: ['superadmin@example.com']
      )
    end

    it 'renders the subject with company name' do
      expect(mail.subject).to include('Hospital XYZ')
    end

    it 'includes batch info in body' do
      expect(mail.body.encoded).to include('47')
    end
  end

  describe '#no_inbox_found' do
    let(:account) { create(:account, name: 'Hospital XYZ') }
    let!(:admin) { create(:administrator, account: account) }

    let(:mail) do
      described_class.no_inbox_found(
        account: account,
        from_domain: 'hospitalxyz.ie',
        batch_info: { folder_name: 'batch_1', email_count: 47, timestamp: Time.current.iso8601 },
        reason: :no_matching_inbox
      )
    end

    it 'renders the subject with domain' do
      expect(mail.subject).to include('hospitalxyz.ie')
    end

    it 'sends to account administrators' do
      expect(mail.to).to include(admin.email)
    end
  end
end
```

---

### Integration Tests (RSpec)

#### `spec/integration/sftp/end_to_end_spec.rb`

```ruby
RSpec.describe 'SFTP Campaign End-to-End', type: :integration do
  let(:campaigns_path) { Dir.mktmpdir('sftp_e2e') }
  let!(:super_admin) { create(:super_admin) }

  let!(:account) { create(:account, name: 'TicoMailWorks') }
  let!(:admin) { create(:administrator, account: account) }
  let(:channel) do
    create(:channel_email, provider: 'resend', provider_config: {
      'api_key' => 're_test',
      'from_email' => 'noreply@company.ie',
      'from_name' => 'TicoMailWorks',
      'sftp_campaigns_enabled' => true
    })
  end
  let!(:inbox) { create(:inbox, account: account, channel: channel) }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('RESEND_ENABLED', 'false').and_return('true')
    allow(GlobalConfigService).to receive(:load).with('SFTP_CAMPAIGNS_ENABLED', 'false').and_return('true')
    allow(GlobalConfigService).to receive(:load).with('SFTP_CAMPAIGNS_PATH', anything).and_return(campaigns_path)
    allow_any_instance_of(Resend::Client).to receive(:send_email).and_return({ 'id' => 'resend_123' })
  end

  after { FileUtils.rm_rf(campaigns_path) }

  def create_batch(folder_name, count: 3, company: 'TicoMailWorks', from: 'noreply@company.ie')
    batch_dir = File.join(campaigns_path, folder_name)
    FileUtils.mkdir_p(batch_dir)
    batch_id = SecureRandom.uuid

    count.times do |i|
      job_id = SecureRandom.uuid
      File.write("#{batch_dir}/#{job_id}.mtr", <<~XML)
        <MiniTicketX>
          <JobID>#{job_id}</JobID>
          <BatchID>#{batch_id}</BatchID>
          <CompanyName>#{company}</CompanyName>
          <CompanyID>1</CompanyID>
          <DeliveryServices>
            <Email><EmailOptions>
              <From>#{from}</From>
              <ToEmail>user#{i}@test.com</ToEmail>
              <Subject>Test Email #{i}</Subject>
              <Body>#{Base64.strict_encode64("<html><body>Hello #{i}</body></html>")}</Body>
            </EmailOptions></Email>
          </DeliveryServices>
        </MiniTicketX>
      XML
      File.write("#{batch_dir}/#{job_id}.pdf", '%PDF-fake-content')
    end
    batch_dir
  end

  it 'processes a valid batch end-to-end: watcher → job → service → campaign' do
    create_batch('batch_hospital_a', count: 5)

    # WatcherJob enqueues ProcessBatchJob
    Sftp::WatcherJob.perform_now

    # ProcessBatchJob runs inline
    perform_enqueued_jobs

    expect(Campaign.count).to eq(1)
    expect(CampaignMessageMapping.count).to eq(5)
    expect(Contact.count).to eq(5)
    expect(Dir.exist?(File.join(campaigns_path, 'batch_hospital_a'))).to be false
  end

  it 'handles multiple batches in one scan' do
    create_batch('batch_1', count: 2)
    create_batch('batch_2', count: 3)

    Sftp::WatcherJob.perform_now
    perform_enqueued_jobs

    expect(Campaign.count).to eq(2)
    expect(CampaignMessageMapping.count).to eq(5)
  end

  it 'handles a mix of valid and invalid entries' do
    create_batch('valid_batch', count: 2)
    File.write("#{campaigns_path}/stray_file.txt", 'garbage')

    Sftp::WatcherJob.perform_now
    perform_enqueued_jobs

    expect(Campaign.count).to eq(1)
    expect(File.exist?("#{campaigns_path}/stray_file.txt")).to be false
  end

  it 'routes batch to correct account based on CompanyName' do
    other_account = create(:account, name: 'OtherCompany')
    other_channel = create(:channel_email, provider: 'resend', provider_config: {
      'api_key' => 're_other', 'from_email' => 'info@other.com',
      'from_name' => 'Other', 'sftp_campaigns_enabled' => true
    })
    create(:inbox, account: other_account, channel: other_channel)

    create_batch('batch_tmw', company: 'TicoMailWorks', from: 'noreply@company.ie', count: 1)
    create_batch('batch_other', company: 'OtherCompany', from: 'info@other.com', count: 1)

    Sftp::WatcherJob.perform_now
    perform_enqueued_jobs

    expect(Campaign.count).to eq(2)
    expect(account.campaigns.count).to eq(1)
    expect(other_account.campaigns.count).to eq(1)
  end

  it 'sends notification when company not found and deletes folder' do
    create_batch('batch_unknown', company: 'NonExistentCo', count: 1)

    Sftp::WatcherJob.perform_now
    perform_enqueued_jobs

    expect(Campaign.count).to eq(0)
    expect(Dir.exist?(File.join(campaigns_path, 'batch_unknown'))).to be false
    expect(ActionMailer::Base.deliveries.map(&:subject)).to include(
      a_string_including('NonExistentCo')
    )
  end
end
```

---

### Manual Test Checklist

Run these after deploying to the Docker environment with the SFTP sidecar.

#### Super Admin Configuration

| # | Test | Expected Result | Pass |
|---|------|----------------|------|
| 1 | Log in as Super Admin → Settings | "Resend Email" and "SFTP Campaigns" cards visible | |
| 2 | Open Resend Email config → toggle ON → save | `RESEND_ENABLED` persists as `true` | |
| 3 | Open SFTP Campaigns config → toggle ON → set path → save | Both values persist | |
| 4 | Toggle Resend OFF → check inbox creation | Resend option not available in new inbox wizard | |
| 5 | Toggle Resend ON, SFTP OFF → check Resend inbox settings | SFTP toggle not visible in Resend inbox settings | |

#### Per-Inbox Toggle

| # | Test | Expected Result | Pass |
|---|------|----------------|------|
| 6 | Both global toggles ON → open Resend inbox settings | "Allow SFTP Campaigns" checkbox visible | |
| 7 | Enable SFTP on inbox → save → reload | Checkbox remains checked, info box shows domain | |
| 8 | Disable SFTP on inbox → save | Checkbox unchecked, info box hidden | |

#### SFTP Upload & Processing

| # | Test | Expected Result | Pass |
|---|------|----------------|------|
| 9 | Upload valid batch folder via SFTP | Folder appears in campaigns path | |
| 10 | Wait 60s (or trigger WatcherJob manually) | Campaign created, folder deleted | |
| 11 | Check Campaigns page | New campaign with "SFTP —" prefix visible | |
| 12 | Check campaign details | Correct email count, status = completed | |
| 13 | Check CampaignMessageMappings | One per .mtr file, resend_email_id populated | |

#### Error Scenarios

| # | Test | Expected Result | Pass |
|---|------|----------------|------|
| 14 | Upload a single file (not a folder) | File deleted, Super Admin email received | |
| 15 | Upload folder with no .mtr files | Folder deleted, Super Admin email received | |
| 16 | Upload folder with malformed .mtr XML | Folder deleted, Super Admin email received | |
| 17 | Upload valid batch with unknown CompanyName | Folder deleted, Super Admin email received | |
| 18 | Upload valid batch, matching account but no inbox for domain | Folder deleted, Account Admin email received | |
| 19 | Upload valid batch, inbox exists but SFTP disabled | Folder deleted, Account Admin email received | |
| 20 | Upload batch with one bad email + one good email | Campaign created, 1 mapping, folder deleted | |

#### Delivery Tracking

| # | Test | Expected Result | Pass |
|---|------|----------------|------|
| 21 | After campaign send, simulate Resend webhook (delivered) | CampaignMessageMapping status → delivered | |
| 22 | Simulate bounce webhook | CampaignMessageMapping status → bounced | |
| 23 | Check campaign delivery report | Correct sent/delivered/bounced counts | |

#### Feature Toggle Interactions

| # | Test | Expected Result | Pass |
|---|------|----------------|------|
| 24 | Disable RESEND_ENABLED while batch exists in SFTP | WatcherJob skips — folder untouched | |
| 25 | Disable SFTP_CAMPAIGNS_ENABLED while batch exists | WatcherJob skips — folder untouched | |
| 26 | Re-enable both → wait for cron | Batch processed normally | |
| 27 | Disable per-inbox toggle, upload matching batch | Folder deleted, Account Admin notified | |

---

## Test Fixtures

Create the following fixtures in `spec/fixtures/sftp/`:

| File | Description |
|------|-------------|
| `valid.mtr` | Copy of `custom/docs/sftp-camping-email-example/f5c76b69-...mtr` |
| `valid.pdf` | Copy of the matching `.pdf` |
| `invalid.mtr` | Truncated/malformed XML (`<broken xml`) |
| `minimal.mtr` | Valid XML with only required fields (no CC, ReplyTo, etc.) |
| `missing_company.mtr` | Valid XML but `<CompanyName>` is empty |
| `missing_from.mtr` | Valid XML but `<From>` is empty |

---

## Local run with Podman + browser test

Use this to run CommMate with Postgres, Redis, Evolution API, and the SFTP sidecar, then verify Resend/SFTP settings in the UI.

### 1. Start the stack

From the repo root:

```bash
# SFTP key (one-time; used by atmoz/sftp for key-based auth)
mkdir -p custom/docs/sftp_keys
ssh-keygen -t ed25519 -f custom/docs/sftp_keys/tmw_sftp_key -C "tmw-sftp" -N ""

# Start all services including SFTP (profile sftp)
podman compose -f docker-compose.commmate.yaml --profile sftp up -d
```

Ensure `commmate.env` exists and has at least `SECRET_KEY_BASE`, `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `EVOLUTION_API_KEY` (see `commmate.env.example`).

### 2. Wait for app to be ready

- Rails: wait until `commmate-rails` is healthy (Rails runs DB prepare then Puma; Evolution starts only after Rails is healthy).
- Open **http://localhost:3000** and log in (e.g. admin@commmate.com / CommMate123! if using default seeds).

### 3. Browser checks — Super Admin

1. Go to **Super Admin** (avatar → Super Admin or `/super_admin`).
2. **Settings** → confirm **Resend Email** and **SFTP Campaigns** cards are present.
3. **Resend Email**: `RESEND_ENABLED` toggle; set to **true** and save.
4. **SFTP Campaigns**: `SFTP_CAMPAIGNS_ENABLED` toggle and `SFTP_CAMPAIGNS_PATH` (default `/data/sftp/campaigns`); set enabled to **true**, keep or set path, save.

### 4. Browser checks — Inbox (Resend + SFTP toggle)

1. Create or open an **Account** → **Settings** → **Inboxes**.
2. **Add Inbox** → **Email** → **Resend** should be listed (only if `RESEND_ENABLED` is true).
3. Create a Resend inbox (API key, from email, etc.). Open the inbox **Settings**.
4. With both Resend and SFTP Campaigns enabled in Super Admin, the **SFTP Campaigns** section should appear: checkbox to allow campaigns from SFTP for this inbox. Toggle and save; confirm it persists after refresh.

### 5. SFTP container

- SFTP service is on profile `sftp`; with `--profile sftp` it listens on **127.0.0.1:2222** (key-based auth).
- Connect with: `sftp -i custom/docs/sftp_keys/tmw_sftp_key -P 2222 sftp_user@127.0.0.1`
- Upload a campaign folder under `campaigns/` (structure per SFTP-CAMPAIGN-PROPOSAL.md). The watcher (Sidekiq cron) scans `/data/sftp/campaigns` inside rails/sidekiq (same volume as SFTP `campaigns`).

### 6. Stop

```bash
podman compose -f docker-compose.commmate.yaml --profile sftp down
```

---

## Execution Order

```
Week 1:
  Mon   Ticket 1.1 (Resend backend config)
  Mon   Ticket 1.2 (Resend frontend gate)
  Tue   Ticket 1.3 (Resend backend guard)
  Tue   Ticket 2.1 (SFTP Campaigns config)
  Wed   Ticket 2.2 (SFTP frontend exposure)
  Wed   Ticket 3.1 (Per-inbox toggle frontend)
  Thu   Ticket 3.2 (Per-inbox toggle backend)
  Thu   Ticket 4.1 (Sample SFTP container docs)
  Fri   Ticket 5.1 (MtrParser + unit tests)

Week 2:
  Mon   Ticket 5.2 (WatcherJob + unit tests)
  Tue-Wed   Ticket 5.3 (ProcessBatchJob + BatchCampaignService + tests)
  Thu   Ticket 5.4 (DB migration)
  Thu   Ticket 6.1 (SftpCampaignMailer + views)
  Fri   Integration tests + fixture setup

Week 3:
  Mon-Tue   Manual testing with Docker + SFTP sidecar
  Wed   Bug fixes from manual testing
  Thu   Final review + merge
```
