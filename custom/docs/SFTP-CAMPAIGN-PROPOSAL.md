# SFTP-Triggered Email Campaign — Technical Proposal

**Project**: CommMate SFTP Email Dispatch  
**Client**: TicoMailWorks (TMW)  
**Version**: Draft 3.0  
**Date**: March 2026  

---

## Executive Summary

TicoMailWorks operates a print/mailing business that processes physical correspondence for clients (hospitals, utilities, government, etc.). Their production system (**OffMail**) already generates structured files containing email metadata and PDF letter attachments. They need a system that:

1. **Receives** batches of email jobs via SFTP (hot-folder pattern)
2. **Dispatches** emails through an ESP (Resend) with PDF attachments
3. **Tracks** delivery status (sent, delivered, bounced, opened)
4. **Provides a client portal** where TMW's end-customers can monitor their email campaigns

CommMate already has a Resend email integration, campaign system, delivery tracking via webhooks, and user/permission management. This proposal outlines how to extend CommMate with an SFTP ingestion layer that plugs into the existing infrastructure, maximizing code reuse and minimizing maintenance burden.

---

## 1. Current State — What CommMate Already Has

| Capability | Status | Key Files |
|-----------|--------|-----------|
| Resend inbox creation & config | Done | `Channel::Email`, `Resend::InboxValidator` |
| Send emails via Resend API | Done | `Resend::Client`, `Resend::OneoffCampaignService` |
| Campaign model & scheduling | Done | `Campaign`, `Campaigns::TriggerOneoffCampaignJob` |
| Per-email delivery tracking | Done | `CampaignMessageMapping` (resend_email_id) |
| Webhook processing (delivered/bounced/opened) | Done | `Resend::DeliveryStatusService` |
| Campaign delivery reports | Done | `CampaignDeliveryReport` |
| User management & permissions | Done | `AccountUser`, granular permissions |
| Client portal (dashboard) | Done | Vue.js dashboard with role-based access |
| System mailer (welcome, reset password) | Done | `ApplicationMailer`, Devise mailers |
| Super Admin feature toggles | Done | `InstallationConfig`, `features.yml`, `app_configs_controller.rb` |

**What's missing**: SFTP file ingestion, `.mtr`/`.pdf` parsing, auto-routing to the correct account/inbox, notification emails for failures.

---

## 2. Input File Format (from OffMail)

Each email job produces a **pair of files** sharing the same UUID:

### 2.1 `.mtr` — MiniTicketX (XML metadata)

```xml
<MiniTicketX>
  <JobID>f5c76b69-0cda-11f1-9835-00155d012944</JobID>
  <MainJobID>f5c76b68-0cda-11f1-9835-00155d012944</MainJobID>
  <JobName>test_OCR.pdf</JobName>
  <JobReference>email test</JobReference>
  <Pages>1</Pages>
  <UserName>arthur.costa</UserName>
  <CompanyName>TicoMailWorks</CompanyName>
  <CompanyID>1</CompanyID>
  <DepartmentName>HQ</DepartmentName>
  <BatchID>741c2d68-e192-42b1-8b0c-fff434c8cd38</BatchID>
  <DeliveryServices CommunicationType="..." CommunicationChannel="...">
    <Email ...>
      <EmailOptions>
        <From>sender@company.ie</From>
        <ToEmail>recipient@example.com</ToEmail>
        <Subject>Subject Line</Subject>
        <Body>BASE64_ENCODED_HTML</Body>
      </EmailOptions>
    </Email>
  </DeliveryServices>
  <MetaDataFields>
    <ExtractField FieldName="email address" ...>Extracted Name</ExtractField>
  </MetaDataFields>
</MiniTicketX>
```

### 2.2 `.pdf` — The letter/document (attached to the email)

### 2.3 `Email.tkt` — Batch manifest (pipe-delimited)

One line per email in the batch. Used for reconciliation, not for sending.

### Key Fields for Auto-Routing and Sending

| Field | Source | Purpose |
|-------|--------|---------|
| `CompanyName` | `.mtr` | **Routes to CommMate Account** (matched by `account.name`) |
| `From` (domain) | `.mtr` → EmailOptions | **Routes to Resend Inbox** (matched by `from_email` domain) |
| `JobID` | `.mtr` | Unique email identifier (external_id) |
| `BatchID` | `.mtr` | Groups emails into a single campaign |
| `ToEmail` | `.mtr` → EmailOptions | Recipient address |
| `Subject` | `.mtr` → EmailOptions | Email subject |
| `Body` | `.mtr` → EmailOptions | HTML body (base64-encoded) |
| `{JobID}.pdf` | `.pdf` file | PDF attachment |

---

## 3. Proposed Architecture

### Core Design: Three-Layer Configuration + Auto-Routing

CommMate does **not** manage the SFTP server. The SFTP server is a separate container (or external service) that the operator deploys independently. CommMate only monitors a local filesystem path where the SFTP server writes files.

Configuration happens at four levels:

| Layer | Who configures | What |
|-------|----------------|------|
| **Super Admin: Resend** | CommMate operator | Enable/disable Resend inboxes globally (like Evolution API) |
| **Super Admin: SFTP Campaigns** | CommMate operator | Enable/disable SFTP campaign ingestion + set the watch path |
| **Per Resend Inbox** | Account administrator | Enable/disable SFTP campaigns for that specific inbox |
| **SFTP Server** | Operator (external) | Separate container — CommMate provides a sample compose file |

```
┌─────────────────────────────┐
│  TMW Production Server      │
│  (OffMail / PlanetPress)    │
│                             │
│  Generates .mtr + .pdf      │
│  pairs per email job        │
│                             │
│  Batch script uploads       │
│  folder to SFTP             │
└──────────┬──────────────────┘
           │ SFTP upload
           ▼
┌──────────────────────┐    shared volume    ┌──────────────────────────────┐
│  SFTP Server         │    or bind mount    │  CommMate (Rails + Sidekiq)  │
│  (separate container)│                     │                              │
│                      │                     │  Super Admin Console:        │
│  Managed by operator │────────────────────▶│    RESEND_ENABLED ✓           │
│  NOT by CommMate     │  /data/sftp/        │    SFTP_CAMPAIGNS_ENABLED ✓  │
│                      │                     │    SFTP_CAMPAIGNS_PATH       │
│                      │    campaigns/       │                              │
│  Key-based auth      │      batch_A/       │  Sftp::WatcherJob (60s):     │
│  Port, users, etc.   │        *.mtr        │    scan → parse → route      │
│  all operator-managed│        *.pdf        │    → send → delete           │
│                      │      batch_B/       │                              │
└──────────────────────┘        ...          │  Per-inbox toggle:           │
                                             │    sftp_campaigns_enabled ✓  │
                                             └──────────────────────────────┘
```

---

## 4. Auto-Routing Rules

The watcher reads the first `.mtr` file in each batch folder and applies these rules in order:

### Step 1: Find Account by CompanyName

```ruby
account = Account.find_by(name: company_name)
```

| Result | Action |
|--------|--------|
| Account found | Proceed to Step 2 |
| Account NOT found | Delete folder + **email all Super Admins** |

### Step 2: Find Resend Inbox by From Domain

Extract the domain from the `.mtr` `From` field (e.g., `sender@company.ie` → `company.ie`), then find a matching Resend inbox in that account:

```ruby
from_domain = from_email.split('@').last
inbox = account.inboxes.joins(:channel)
               .where(channel_type: 'Channel::Email')
               .where("channel_email.provider = 'resend'")
               .where("channel_email.provider_config->>'from_email' LIKE ?", "%@#{from_domain}")
               .first
```

| Result | Action |
|--------|--------|
| Inbox found + `sftp_campaigns_enabled` | Proceed to send |
| Inbox found + `sftp_campaigns_enabled` is OFF | Delete folder + **email Account Admins** |
| Inbox NOT found (no matching domain) | Delete folder + **email Account Admins** |

### Step 3: Send Campaign

Create campaign, send emails, delete folder. (Detailed in Section 6.)

---

## 5. Notification Emails

Use the existing `ApplicationMailer` infrastructure (same system as password reset and welcome emails) to send failure notifications.

### 5.1 No Account Found → Notify Super Admins

**Trigger**: `CompanyName` from `.mtr` does not match any `Account.name`.

**Recipients**: All users with `type: 'SuperAdmin'`.

**Email content**:
- Subject: `[CommMate] SFTP Campaign failed — unknown company "{CompanyName}"`
- Body: Company name, batch folder name, From address, number of emails in batch, timestamp
- Action hint: "Create an account with this name, or check the CompanyName in the source system."

### 5.2 Invalid Upload (Not a Folder / Bad Format) → Notify Super Admins

**Trigger**: An entry in the SFTP path is not a folder, or a batch folder contains no valid `.mtr` files, or the `.mtr` XML cannot be parsed.

**Recipients**: All users with `type: 'SuperAdmin'`.

**Email content**:
- Subject: `[CommMate] SFTP Campaign failed — invalid upload "{entry_name}"`
- Body: Entry name, reason (not a folder / no .mtr files / XML parse error), timestamp
- Action hint: "Check the upload format. Each campaign must be a folder containing .mtr + .pdf file pairs."

---

### 5.3 No Inbox / SFTP Disabled → Notify Account Admins

**Trigger**: Account found, but either no Resend inbox matches the From domain, or the matching inbox has `sftp_campaigns_enabled: false`.

**Recipients**: All administrators of the matched account.

**Email content**:
- Subject: `[CommMate] SFTP Campaign failed — no inbox for domain "{domain}"`
- Body: Company name, From domain, batch folder name, number of emails, specific reason (no inbox / SFTP disabled)
- Action hint: "Create a Resend inbox for this domain and enable SFTP campaigns, or check the From address."

### 5.4 Mailer Implementation

```ruby
# app/mailers/sftp_campaign_mailer.rb
class SftpCampaignMailer < ApplicationMailer
  def invalid_upload(entry_name:, reason:, recipients:, details: nil)
    @entry_name = entry_name
    @reason = reason
    @details = details
    mail(to: recipients, subject: "[CommMate] SFTP Campaign failed — invalid upload \"#{entry_name}\"")
  end

  def no_account_found(company_name:, batch_info:, recipients:)
    @company_name = company_name
    @batch_info = batch_info
    mail(to: recipients, subject: "[CommMate] SFTP Campaign failed — unknown company \"#{company_name}\"")
  end

  def no_inbox_found(account:, from_domain:, batch_info:, reason:)
    @account = account
    @from_domain = from_domain
    @batch_info = batch_info
    @reason = reason
    admin_emails = account.administrators.pluck(:email)
    mail(to: admin_emails, subject: "[CommMate] SFTP Campaign failed — no inbox for domain \"#{from_domain}\"")
  end
end
```

---

## 6. Implementation Plan

### Phase 1: Super Admin — Resend Inboxes Toggle

**Goal**: Add a global on/off for Resend inboxes in the Super Admin console, following the same pattern as Evolution API. Currently Resend inboxes have no Super Admin gate — this adds one.

#### 6.1 Installation Config YAML — Resend

Add to `config/installation_config.yml`:

```yaml
# ------- Resend Email Integration Config ------- #
- name: RESEND_ENABLED
  display_title: 'Resend Email Integration Enabled'
  value: false
  description: 'Enable Resend as an email inbox provider'
  locked: false
  type: boolean
# ------- End of Resend Email Integration Config ------- #
```

#### 6.2 Super Admin Feature Definition — Resend

Add to `app/helpers/super_admin/features.yml`:

```yaml
resend:
  name: 'Resend Email'
  description: 'Configuration for Resend email inbox integration'
  enabled: true
  icon: 'icon-mail-line'
  config_key: 'resend'
```

#### 6.3 Super Admin Config Mapping — Resend

Add to `app/controllers/super_admin/app_configs_controller.rb`:

```ruby
'resend' => %w[RESEND_ENABLED],
```

This gives the Super Admin a settings page at `/super_admin/app_config?config=resend` with a single toggle: **Resend Email Integration Enabled**.

#### 6.4 Frontend Config Exposure — Resend

Add to `DashboardController`:

```ruby
RESEND_ENABLED: GlobalConfigService.load('RESEND_ENABLED', 'false'),
```

Add to `vueapp.html.erb`:

```erb
resendEnabled: '<%= @global_config['RESEND_ENABLED'] %>',
```

Use in the inbox creation flow (`Email.vue`, `ChannelList.vue`) to show/hide the Resend option:

```javascript
const isResendEnabled = window.chatwootConfig?.resendEnabled === 'true';
```

#### 6.5 Backend Guard — Resend

In the Resend inbox provisioning/validation flow, check the global toggle:

```ruby
def validate_resend_enabled!
  enabled = InstallationConfig.find_by(name: 'RESEND_ENABLED')&.value
  raise StandardError, 'Resend integration is not enabled' unless enabled == true || enabled == 'true'
end
```

---

### Phase 2: Super Admin — SFTP Campaigns Toggle + Settings

**Goal**: SFTP Campaigns as a separate feature that can be enabled/disabled from the Super Admin console, with the watch path setting. Only relevant when Resend is also enabled.

#### 6.6 Installation Config YAML — SFTP Campaigns

Add to `config/installation_config.yml`:

```yaml
# ------- SFTP Campaigns Config ------- #
- name: SFTP_CAMPAIGNS_ENABLED
  display_title: 'SFTP Campaigns Enabled'
  value: false
  description: 'Enable SFTP-based campaign ingestion for Resend inboxes. Requires Resend to be enabled.'
  locked: false
  type: boolean
- name: SFTP_CAMPAIGNS_PATH
  display_title: 'SFTP Campaigns Watch Path'
  value: '/data/sftp/campaigns'
  description: 'Local filesystem path where the SFTP server writes campaign batch folders. CommMate monitors this path.'
  locked: false
# ------- End of SFTP Campaigns Config ------- #
```

These values can be set in three ways (in order of precedence):
1. Super Admin console UI
2. `config/installation_config.yml` (defaults, applied on deploy)
3. `custom/config/installation_config.yml` (CommMate overrides)

#### 6.7 Super Admin Feature Definition — SFTP Campaigns

Add to `app/helpers/super_admin/features.yml`:

```yaml
sftp_campaigns:
  name: 'SFTP Campaigns'
  description: 'Monitor an SFTP directory for email campaign batches and auto-dispatch via Resend inboxes'
  enabled: true
  icon: 'icon-folder-line'
  config_key: 'sftp_campaigns'
```

#### 6.8 Super Admin Config Mapping — SFTP Campaigns

Add to `app/controllers/super_admin/app_configs_controller.rb`:

```ruby
'sftp_campaigns' => %w[SFTP_CAMPAIGNS_ENABLED SFTP_CAMPAIGNS_PATH],
```

Super Admin settings page at `/super_admin/app_config?config=sftp_campaigns`:
- **SFTP Campaigns Enabled** — on/off toggle
- **SFTP Campaigns Watch Path** — the local filesystem path to monitor

#### 6.9 Frontend Config Exposure — SFTP Campaigns

Add to `DashboardController`:

```ruby
SFTP_CAMPAIGNS_ENABLED: GlobalConfigService.load('SFTP_CAMPAIGNS_ENABLED', 'false'),
```

Add to `vueapp.html.erb`:

```erb
sftpCampaignsEnabled: '<%= @global_config['SFTP_CAMPAIGNS_ENABLED'] %>',
```

---

### Phase 3: Per-Inbox Toggle — "Allow SFTP Campaigns"

**Goal**: Each Resend inbox can individually opt-in to receive SFTP campaigns. This toggle only appears when **both** Resend and SFTP Campaigns are globally enabled.

#### 6.10 Backend — Extend `provider_config`

No migration needed — `provider_config` is already JSONB. Add one new key:

```ruby
# provider_config for a Resend inbox with SFTP campaigns enabled:
{
  "api_key": "re_xxx",
  "from_email": "noreply@company.ie",
  "from_name": "Company Name",
  "sftp_campaigns_enabled": true    # ← new boolean flag
}
```

#### 6.11 Frontend — Toggle in Resend Settings

In `ResendSettings.vue`, add a checkbox that is only visible when both global flags are on:

```javascript
const showSftpToggle = window.chatwootConfig?.resendEnabled === 'true'
  && window.chatwootConfig?.sftpCampaignsEnabled === 'true';
```

- **"Allow SFTP Campaigns"** — toggles `sftp_campaigns_enabled` in `provider_config`
- When enabled, show an info box: "This inbox will automatically process email campaigns uploaded via SFTP when the sender domain matches `{from_email domain}`."

---

### Phase 4 (unchanged): SFTP Server (Operator-Managed, Sample Provided)

**Goal**: CommMate does NOT include or manage the SFTP server. The operator deploys it separately. We provide a sample Docker Compose file as a reference.

CommMate's only requirement: the SFTP server (or any file source) writes batch folders to the path configured in `SFTP_CAMPAIGNS_PATH`. This could be:
- A Docker shared volume
- A bind mount
- An NFS mount
- Any local filesystem path

#### 6.12 Sample SFTP Container

Provided as `custom/docs/docker-compose.sftp-sample.yaml` (reference only, not part of CommMate):

```yaml
# Sample SFTP sidecar — deploy alongside CommMate
# The operator manages this container independently.
#
# Secured with SSH key auth (password disabled).
# The campaigns/ directory maps to the same volume
# that CommMate's rails/sidekiq containers read.

services:
  sftp:
    image: atmoz/sftp:alpine
    container_name: commmate-sftp
    restart: unless-stopped
    volumes:
      - sftp_data:/home/sftp_user/campaigns
      - ./sftp_keys/tmw_sftp_key.pub:/home/sftp_user/.ssh/keys/tmw_sftp_key.pub:ro
    ports:
      - "127.0.0.1:2222:22"
    command: "sftp_user::1001:1001:campaigns"   # empty password = key auth only
    networks:
      - commmate_default   # same network as CommMate

volumes:
  sftp_data:
    external: true   # shared with CommMate's rails/sidekiq containers

# --- Key Management ---
# ssh-keygen -t ed25519 -f sftp_keys/tmw_sftp_key -C "tmw-sftp" -N ""
# Multiple clients: mount additional .pub files into /home/sftp_user/.ssh/keys/
# Rotate: replace .pub file, restart container — old key immediately revoked
```

The operator then adds the shared volume to CommMate's `docker-compose.commmate.yaml`:

```yaml
# In rails and sidekiq services:
volumes:
  - sftp_data:/data/sftp/campaigns
```

And sets `SFTP_CAMPAIGNS_PATH=/data/sftp/campaigns` in the Super Admin console (or leaves the default).

---

### Phase 5: Watcher + Auto-Routing + Send

#### 6.13 `Sftp::WatcherJob` — Cron Scanner

Runs every 60 seconds. Reads the watch path from `InstallationConfig`. Only runs when the feature is globally enabled.

```ruby
# app/jobs/sftp/watcher_job.rb
module Sftp
class WatcherJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    return unless feature_enabled?('RESEND_ENABLED')
    return unless feature_enabled?('SFTP_CAMPAIGNS_ENABLED')

    campaigns_path = GlobalConfigService.load('SFTP_CAMPAIGNS_PATH', '/data/sftp/campaigns')
    return unless Dir.exist?(campaigns_path)

    Dir.children(campaigns_path).each do |entry|
      full_path = File.join(campaigns_path, entry)

      unless File.directory?(full_path)
        notify_invalid_upload(entry, reason: :not_a_folder)
        FileUtils.rm_f(full_path)
        next
      end

      Sftp::ProcessBatchJob.perform_later(batch_path: full_path)
    end
  end

  private

  def feature_enabled?(key)
    value = GlobalConfigService.load(key, 'false')
    value == true || value == 'true'
  end

  def notify_invalid_upload(entry_name, reason:)
    super_admin_emails = SuperAdmin.pluck(:email)
    return if super_admin_emails.empty?

    SftpCampaignMailer.invalid_upload(
      entry_name: entry_name,
      reason: reason,
      recipients: super_admin_emails
    ).deliver_later
  end
end
end
```

#### 6.14 `Sftp::ProcessBatchJob` — Route + Send + Cleanup

```ruby
# app/jobs/sftp/process_batch_job.rb
module Sftp
class ProcessBatchJob < ApplicationJob
  queue_as :default

  def perform(batch_path:)
    Sftp::BatchCampaignService.new(batch_path: batch_path).perform
  end
end
end
```

#### 6.15 `Sftp::BatchCampaignService` — Core Logic

```ruby
# app/services/sftp/batch_campaign_service.rb
module Sftp
class BatchCampaignService
  def initialize(batch_path:)
    @batch_path = batch_path
  end

  def perform
    mtr_files = Dir.glob(File.join(@batch_path, '*.mtr'))

    if mtr_files.empty?
      notify_invalid_upload(reason: :no_mtr_files)
      return cleanup!
    end

    sample = begin
      Sftp::MtrParser.new(mtr_files.first).parse
    rescue Nokogiri::XML::SyntaxError, StandardError => e
      notify_invalid_upload(reason: :xml_parse_error, details: e.message)
      return cleanup!
    end

    if sample[:company_name].blank? || sample[:from].blank?
      notify_invalid_upload(reason: :missing_required_fields)
      return cleanup!
    end

    batch_info = build_batch_info(sample, mtr_files.size)

    # Step 1: Find account by CompanyName
    account = Account.find_by(name: sample[:company_name])
    unless account
      notify_no_account(sample[:company_name], batch_info)
      return cleanup!
    end

    # Step 2: Find Resend inbox by From domain
    from_domain = sample[:from]&.split('@')&.last
    inbox = find_resend_inbox(account, from_domain)

    unless inbox
      notify_no_inbox(account, from_domain, batch_info, reason: :no_matching_inbox)
      return cleanup!
    end

    # Step 3: Check per-inbox sftp_campaigns_enabled
    unless inbox.channel.provider_config['sftp_campaigns_enabled']
      notify_no_inbox(account, from_domain, batch_info, reason: :sftp_disabled)
      return cleanup!
    end

    # Step 4: Create campaign and send
    send_campaign(account, inbox, mtr_files, sample)
    cleanup!
  end

  private

  def find_resend_inbox(account, from_domain)
    return nil if from_domain.blank?

    account.inboxes
           .where(channel_type: 'Channel::Email')
           .find do |inbox|
             channel = inbox.channel
             channel.provider == 'resend' &&
               channel.provider_config['from_email']&.split('@')&.last == from_domain
           end
  end

  def send_campaign(account, inbox, mtr_files, sample)
    channel = inbox.channel
    client = Resend::Client.new(api_key: channel.provider_config['api_key'])

    campaign = account.campaigns.create!(
      inbox: inbox,
      title: "SFTP — #{sample[:company_name]} — #{sample[:batch_id]&.slice(0, 8)}",
      description: "Auto-generated from SFTP. #{mtr_files.size} emails.",
      campaign_type: :one_off,
      campaign_status: :active,
      message: 'SFTP batch campaign',
      audience: [],
      additional_attributes: {
        'sftp_batch_id' => sample[:batch_id],
        'sftp_company_name' => sample[:company_name],
        'sftp_company_id' => sample[:company_id],
        'sftp_source' => 'offmail',
        'email_count' => mtr_files.size
      }
    )

    campaign.completed!

    report = campaign.create_delivery_report!(
      provider: 'resend',
      status: 'running',
      total: mtr_files.size,
      started_at: Time.current
    )

    mtr_files.each do |mtr_path|
      send_single_email(client, channel, campaign, report, mtr_path)
    end

    report.finalize!
  end

  def send_single_email(client, channel, campaign, report, mtr_path)
    data = Sftp::MtrParser.new(mtr_path).parse
    pdf_path = mtr_path.sub('.mtr', '.pdf')

    from_address = "#{channel.provider_config['from_name']} <#{channel.provider_config['from_email']}>"
    payload = {
      from: from_address,
      to: data[:to_email],
      subject: data[:subject] || '(No subject)',
      html: data[:html_body].presence || '<p></p>'
    }
    payload[:reply_to] = data[:reply_to] if data[:reply_to].present?

    if File.exist?(pdf_path)
      payload[:attachments] = [{
        filename: File.basename(pdf_path),
        content: Base64.strict_encode64(File.binread(pdf_path)),
        content_type: 'application/pdf'
      }]
    end

    response = client.send_email(**payload)

    contact = find_or_create_contact(campaign.account, data)
    CampaignMessageMapping.create!(
      campaign_delivery_report: report,
      contact: contact,
      resend_email_id: response['id'],
      status: :sent,
      external_job_id: data[:job_id]
    )
    report.succeeded += 1
  rescue Resend::Client::ApiError => e
    Rails.logger.error("[SFTP] Failed to send email #{mtr_path}: #{e.message}")
    report.failed += 1
    report.record_error(code: e.error_code, message: e.message, details: "MTR: #{mtr_path}")
  end

  def find_or_create_contact(account, data)
    account.contacts.find_or_create_by!(email: data[:to_email]) do |c|
      c.name = data[:to_email].split('@').first.titleize
    end
  end

  def notify_invalid_upload(reason:, details: nil)
    super_admin_emails = SuperAdmin.pluck(:email)
    return if super_admin_emails.empty?

    SftpCampaignMailer.invalid_upload(
      entry_name: File.basename(@batch_path),
      reason: reason,
      details: details,
      recipients: super_admin_emails
    ).deliver_later
  end

  def notify_no_account(company_name, batch_info)
    super_admin_emails = SuperAdmin.pluck(:email)
    return if super_admin_emails.empty?

    SftpCampaignMailer.no_account_found(
      company_name: company_name,
      batch_info: batch_info,
      recipients: super_admin_emails
    ).deliver_later
  end

  def notify_no_inbox(account, from_domain, batch_info, reason:)
    SftpCampaignMailer.no_inbox_found(
      account: account,
      from_domain: from_domain,
      batch_info: batch_info,
      reason: reason
    ).deliver_later
  end

  def build_batch_info(sample, file_count)
    {
      batch_id: sample[:batch_id],
      company_name: sample[:company_name],
      from_email: sample[:from],
      email_count: file_count,
      folder_name: File.basename(@batch_path),
      timestamp: Time.current.iso8601
    }
  end

  def cleanup!
    FileUtils.rm_rf(@batch_path) if Dir.exist?(@batch_path)
  end
end
end
```

#### 6.16 `Sftp::MtrParser` — XML Parser

```ruby
# app/services/sftp/mtr_parser.rb
module Sftp
class MtrParser
  def initialize(path)
    @path = path
  end

  def parse
    doc = Nokogiri::XML(File.read(@path))

    email_opts = doc.at_xpath('//EmailOptions')
    body_b64 = email_opts&.at_xpath('Body')&.text
    html_body = body_b64.present? ? Base64.decode64(body_b64) : ''

    {
      job_id: doc.at_xpath('//JobID')&.text,
      main_job_id: doc.at_xpath('//MainJobID')&.text,
      batch_id: doc.at_xpath('//BatchID')&.text,
      job_name: doc.at_xpath('//JobName')&.text,
      job_reference: doc.at_xpath('//JobReference')&.text,
      pages: doc.at_xpath('//Pages')&.text&.to_i,
      user_name: doc.at_xpath('//UserName')&.text,
      company_name: doc.at_xpath('//CompanyName')&.text,
      company_id: doc.at_xpath('//CompanyID')&.text,
      department_name: doc.at_xpath('//DepartmentName')&.text,
      from: email_opts&.at_xpath('From')&.text,
      to_email: email_opts&.at_xpath('ToEmail')&.text,
      cc_email: email_opts&.at_xpath('CCEmail')&.text,
      reply_to: email_opts&.at_xpath('ReplyTo')&.text,
      subject: email_opts&.at_xpath('Subject')&.text,
      html_body: html_body,
      priority: email_opts&.at_xpath('Priority')&.text,
      send_date: email_opts&.at_xpath('SendDate')&.text
    }
  end
end
end
```

---

## 7. Delivery Tracking (Fully Reused — Zero New Code)

The existing infrastructure handles everything:

1. `Resend::Client.send_email(**payload)` takes keyword arguments (`from:`, `to:`, `subject:`, `html:`, `attachments:`, etc.) and returns `{ "id": "resend_email_id" }`.
2. `CampaignMessageMapping` belongs to `campaign_delivery_report`, not `campaign` directly. Create a report via `campaign.create_delivery_report!(...)`, then create mappings with `campaign_delivery_report: report`. Use `report.finalize!` when done.
3. We store `resend_email_id` (and optionally `external_job_id`) on each mapping.
4. Resend fires webhooks → `Webhooks::ResendController` → `Webhooks::ResendEventsJob`
5. `Resend::DeliveryStatusService` updates `CampaignMessageMapping` status

Delivery statuses automatically tracked: **sent → delivered / bounced / failed / opened / clicked**

---

## 8. File Lifecycle

```
1. UPLOAD              TMW uploads folder to /data/sftp/campaigns/
                         campaigns/
                           batch_20260301_hospital_A/
                             abc123.mtr
                             abc123.pdf
                             def456.mtr
                             def456.pdf
                             Email.tkt

2. WATCHER DETECTS     Sftp::WatcherJob (every 60s)
                       → Enqueues Sftp::ProcessBatchJob for each folder

3. AUTO-ROUTE          Read first .mtr:
                         CompanyName="Hospital A" → Account.find_by(name:)
                         From="noreply@hospitala.ie" → domain "hospitala.ie"
                         → Find Resend inbox with matching from_email domain
                         → Check sftp_campaigns_enabled flag

4a. SUCCESS            Create Campaign, send all emails via Resend
                       → Delete batch folder from SFTP

4b. FAILURE            No account / no inbox / SFTP disabled
                       → Send notification email to admins
                       → Delete batch folder from SFTP
```

**No archival on CommMate side** — TMW maintains their own backup of all files. CommMate is a passthrough: receive, send, delete.

---

## 9. Database Changes

### 9.1 Extend `CampaignMessageMapping` (optional)

Add a field to cross-reference with OffMail's original job ID:

```ruby
# db/migrate/xxx_add_external_job_id_to_campaign_message_mappings.rb
add_column :campaign_message_mappings, :external_job_id, :string
add_index :campaign_message_mappings, :external_job_id
```

### 9.2 No New Models Required

| Data | Model | Field |
|------|-------|-------|
| Batch → Campaign | `Campaign` | `additional_attributes.sftp_batch_id` |
| Email → Mapping | `CampaignMessageMapping` | `resend_email_id`, `external_job_id` |
| Recipient | `Contact` | `email` (find_or_create) |
| SFTP toggle | `Channel::Email` | `provider_config.sftp_campaigns_enabled` |

---

## 10. New Files Summary

| File | Type | Purpose |
|------|------|---------|
| `config/installation_config.yml` (entries) | Config | `RESEND_ENABLED`, `SFTP_CAMPAIGNS_ENABLED`, `SFTP_CAMPAIGNS_PATH` |
| `app/helpers/super_admin/features.yml` (entries) | Config | Super Admin feature cards for Resend + SFTP Campaigns |
| `app/controllers/super_admin/app_configs_controller.rb` (entries) | Config | Map `resend` + `sftp_campaigns` → config keys |
| `app/jobs/sftp/watcher_job.rb` | Job | Cron: scan SFTP directory every 60s |
| `app/jobs/sftp/process_batch_job.rb` | Job | Async: process one batch folder |
| `app/services/sftp/batch_campaign_service.rb` | Service | Core: route → send → cleanup |
| `app/services/sftp/mtr_parser.rb` | Service | Parse `.mtr` XML files |
| `app/mailers/sftp_campaign_mailer.rb` | Mailer | Failure notification emails |
| `app/views/sftp_campaign_mailer/` | Views | Email templates (3 templates) |
| `custom/docs/docker-compose.sftp-sample.yaml` | Docs | Sample SFTP container for operators |
| Migration | DB | `external_job_id` on `campaign_message_mappings` |

**Modified (small changes)**:
- `app/controllers/dashboard_controller.rb` — expose `RESEND_ENABLED` + `SFTP_CAMPAIGNS_ENABLED`
- `app/views/layouts/vueapp.html.erb` — pass `resendEnabled` + `sftpCampaignsEnabled` to frontend
- `Email.vue` / `ChannelList.vue` — gate Resend inbox creation behind `resendEnabled`
- `ResendSettings.vue` — conditional SFTP campaigns toggle

**Reused (no changes needed)**:
- `Resend::Client` — API calls
- `Resend::DeliveryStatusService` — webhook processing
- `CampaignMessageMapping` — per-email delivery tracking
- `Campaign` model — campaign creation
- `Webhooks::ResendController` — webhook ingestion
- `ApplicationMailer` — base mailer configuration
- `InstallationConfig` / `GlobalConfigService` — existing config infrastructure
- Dashboard campaign views — status display

---

## 11. Routing Decision Flowchart

```
┌─────────────────────────────┐
│  Sftp::WatcherJob (cron)    │
│  Runs every 60 seconds      │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐     NO
│  RESEND_ENABLED?            │──────────▶  (skip — Resend is off)
│  (Super Admin toggle)       │
└──────────┬──────────────────┘
           │ YES
           ▼
┌─────────────────────────────┐     NO
│  SFTP_CAMPAIGNS_ENABLED?    │──────────▶  (skip — SFTP campaigns off)
│  (Super Admin toggle)       │
└──────────┬──────────────────┘
           │ YES
           ▼
┌─────────────────────────────┐     NO
│  SFTP_CAMPAIGNS_PATH exists?│──────────▶  (skip — path not mounted)
└──────────┬──────────────────┘
           │ YES
           ▼
┌─────────────────────────────┐
│  For each entry in path:    │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐     NO    ┌──────────────────────────┐
│  Is it a folder?            │──────────▶│ Email Super Admins:      │
│                             │           │ "Invalid upload: X"      │
│                             │           │ Delete file              │
└──────────┬──────────────────┘           └──────────────────────────┘
           │ YES
           ▼
┌─────────────────────────────┐     NO    ┌──────────────────────────┐
│  Contains .mtr files?       │──────────▶│ Email Super Admins:      │
│                             │           │ "No .mtr files in: X"    │
│                             │           │ Delete folder            │
└──────────┬──────────────────┘           └──────────────────────────┘
           │ YES
           ▼
┌─────────────────────────────┐     NO    ┌──────────────────────────┐
│  Parse first .mtr           │──────────▶│ Email Super Admins:      │
│  Valid XML with required    │           │ "Bad format in: X"       │
│  fields (CompanyName, From)?│           │ Delete folder            │
└──────────┬──────────────────┘           └──────────────────────────┘
           │ YES
           ▼
┌─────────────────────────────┐     NO    ┌──────────────────────────┐
│  Account.find_by            │──────────▶│ Email Super Admins:      │
│  (name: CompanyName)        │           │ "Unknown company: X"     │
│  Found?                     │           │ Delete folder            │
└──────────┬──────────────────┘           └──────────────────────────┘
           │ YES
           ▼
┌─────────────────────────────┐     NO    ┌──────────────────────────┐
│  Find Resend inbox in       │──────────▶│ Email Account Admins:    │
│  account where from_email   │           │ "No inbox for domain: X" │
│  domain matches From domain │           │ Delete folder            │
│  Found?                     │           └──────────────────────────┘
└──────────┬──────────────────┘
           │ YES
           ▼
┌─────────────────────────────┐     NO    ┌──────────────────────────┐
│  inbox.channel              │──────────▶│ Email Account Admins:    │
│  .sftp_campaigns_enabled?   │           │ "SFTP campaigns disabled │
│  (per-inbox toggle)         │           │  for inbox: X"           │
└──────────┬──────────────────┘           │ Delete folder            │
           │ YES                          └──────────────────────────┘
           ▼
┌─────────────────────────────┐
│  Create Campaign            │
│  Send all emails via Resend │
│  Delete folder              │
└─────────────────────────────┘
```

---

## 12. Security Considerations

| Risk | Mitigation |
|------|-----------|
| Unauthorized SFTP access | SFTP server is operator-managed; sample uses SSH key auth (password disabled) |
| Feature accidentally enabled | Two-layer toggle: Super Admin global + per-inbox — both must be ON |
| Unknown company uploads | Files are deleted; super admins notified — no emails sent to recipients |
| SFTP disabled on inbox | Files are deleted; account admins notified — no emails sent to recipients |
| Malicious XML | Nokogiri in strict mode; only parse known XPaths |
| Large PDF files | Resend enforces 40MB limit per email; skip oversized attachments |
| Race conditions | `ProcessBatchJob` uses folder as lock — if folder exists, it's being processed |
| Config path traversal | Validate `SFTP_CAMPAIGNS_PATH` is an absolute path within allowed directories |

---

## 13. Advantages of This Approach

### Configuration hierarchy (like Evolution API)

| Aspect | Benefit |
|--------|---------|
| Super Admin toggle | Operator can enable/disable globally without touching code |
| `installation_config.yml` | Settings applied on deploy — works for automated/CI setups |
| `custom/config/installation_config.yml` | CommMate-specific defaults survive upstream merges |
| Per-inbox toggle | Account admins control which inboxes accept SFTP campaigns |
| Separate SFTP server | CommMate doesn't manage SFTP infrastructure — operator's responsibility |

### Why follow the Evolution API pattern?

- Proven pattern already used in production for Evolution API
- Super Admins already know how to use this UI
- Consistent with how all other CommMate integrations are managed
- No new config infrastructure needed — just new entries in existing YAML/controller

### Why use existing mailers for notifications?

- `ApplicationMailer` is already configured with SMTP/delivery settings
- Same pipeline as password reset, welcome emails — proven and reliable
- No new infrastructure needed
- Follows Rails conventions (mailer + views + `deliver_later`)

---

## 14. Estimated Effort

| Phase | Scope | Estimate |
|-------|-------|----------|
| Phase 1: Resend Super Admin toggle | `RESEND_ENABLED` config + features.yml + frontend gate | 1 day |
| Phase 2: SFTP Campaigns Super Admin toggle | `SFTP_CAMPAIGNS_ENABLED` + `SFTP_CAMPAIGNS_PATH` config | 0.5 day |
| Phase 3: Per-inbox SFTP toggle | `provider_config` flag + `ResendSettings.vue` conditional toggle | 0.5 day |
| Phase 4: Sample SFTP container | `docker-compose.sftp-sample.yaml` + documentation | 0.5 day |
| Phase 5: Watcher + routing + send | WatcherJob + BatchCampaignService + MtrParser | 3-4 days |
| Phase 6: Notification emails | SftpCampaignMailer + 2 templates | 1 day |
| Phase 7: Client portal permissions | Scope campaigns by company (future) | 2 days |
| Testing & integration | End-to-end with TMW test files | 2-3 days |
| **Total** | | **11-14 days** |

---

## 15. Future Considerations

### PlanetPress Integration (Stream 2)

PlanetPress can output files in the same `.mtr` + `.pdf` format. If it does, the same SFTP watcher handles it transparently — no code changes needed.

### Scale

- For <10,000 emails/day: single cron + Sidekiq worker is sufficient
- For higher volume: use `Resend::Client#send_batch` (existing method) for batch API calls

### SFTP Reply / Status Callback

The `.mtr` file contains `<SFTPReply>` configuration. Post-send, CommMate could write a status file back to TMW's SFTP server. This is a future enhancement.

### Client Portal Scoping

For strict multi-tenant isolation where each TMW client sees only their own campaigns, scope the campaign API by `additional_attributes->>'sftp_company_name'` matched to the logged-in user's account name. This leverages the existing permission system.

---

## Appendix A: Example `.mtr` File Reference

See `custom/docs/sftp-camping-email-example/f5c76b69-0cda-11f1-9835-00155d012944.mtr`

Key XML paths:

| XPath | Description |
|-------|-------------|
| `//JobID` | Unique email identifier |
| `//BatchID` | Groups emails into a campaign |
| `//CompanyName` | **Routes to Account** |
| `//EmailOptions/From` | **Routes to Inbox** (by domain) |
| `//EmailOptions/ToEmail` | Recipient email |
| `//EmailOptions/Subject` | Email subject line |
| `//EmailOptions/Body` | HTML body (base64-encoded) |

## Appendix B: Sample SFTP Container (Operator Reference)

This is **not** part of CommMate. The operator deploys and manages the SFTP server independently. This sample is provided as `custom/docs/docker-compose.sftp-sample.yaml`.

```yaml
services:
  sftp:
    image: atmoz/sftp:alpine
    container_name: commmate-sftp
    restart: unless-stopped
    volumes:
      - sftp_data:/home/sftp_user/campaigns
      - ./sftp_keys/tmw_sftp_key.pub:/home/sftp_user/.ssh/keys/tmw_sftp_key.pub:ro
    ports:
      - "127.0.0.1:2222:22"
    command: "sftp_user::1001:1001:campaigns"   # empty password = key auth only
    networks:
      - commmate_default

volumes:
  sftp_data:
    external: true
```

### CommMate Side (add to docker-compose.commmate.yaml)

```yaml
# In rails and sidekiq services, mount the shared volume:
volumes:
  - sftp_data:/data/sftp/campaigns

# Then in Super Admin console, set:
#   SFTP_CAMPAIGNS_ENABLED = true
#   SFTP_CAMPAIGNS_PATH = /data/sftp/campaigns
```

### Key Management

```bash
mkdir -p sftp_keys
ssh-keygen -t ed25519 -f sftp_keys/tmw_sftp_key -C "tmw-sftp" -N ""

# Multiple clients: mount additional .pub files
# Rotate: replace .pub, restart SFTP container — old key immediately revoked
```

## Appendix C: Notification Email Examples

### Super Admin notification (invalid upload)

```
Subject: [CommMate] SFTP Campaign failed — invalid upload "random_file.zip"

An invalid entry was found in the SFTP campaigns directory and has been removed.

Entry Name:  random_file.zip
Timestamp:   2026-03-01T09:01:23Z

Reason: Entry is not a folder. Each campaign must be uploaded as a folder
containing .mtr and .pdf file pairs.

Action: Check the upload process on the source system. Expected format:
  campaigns/
    batch_folder_name/
      {uuid}.mtr
      {uuid}.pdf
      Email.tkt (optional)
```

### Super Admin notification (bad format / parse error)

```
Subject: [CommMate] SFTP Campaign failed — invalid upload "batch_20260301_0900"

A campaign batch folder was found but could not be processed. It has been removed.

Folder Name: batch_20260301_0900
Timestamp:   2026-03-01T09:01:23Z

Reason: XML parse error in .mtr file — "Premature end of data in tag
MiniTicketX line 1"

Action: Verify the .mtr files are valid XML with required fields
(CompanyName, EmailOptions/From).
```

### Super Admin notification (no account found)

```
Subject: [CommMate] SFTP Campaign failed — unknown company "Hospital XYZ"

An SFTP campaign batch was uploaded but could not be processed.

Company Name: Hospital XYZ
From Address: noreply@hospitalxyz.ie
Batch Folder: batch_20260301_0900
Email Count:  47
Timestamp:    2026-03-01T09:01:23Z

Reason: No account found with the name "Hospital XYZ".

Action: Create a CommMate account with this name, or verify the
CompanyName field in the source system (OffMail).
```

### Account Admin notification (no inbox / SFTP disabled)

```
Subject: [CommMate] SFTP Campaign failed — no inbox for domain "hospitalxyz.ie"

An SFTP campaign batch was uploaded for your account but could not be processed.

Account:      Hospital XYZ
From Domain:  hospitalxyz.ie
Batch Folder: batch_20260301_0900
Email Count:  47
Timestamp:    2026-03-01T09:01:23Z

Reason: No Resend inbox with SFTP campaigns enabled matches the
domain "hospitalxyz.ie".

Action: Create a Resend inbox with a from-email on this domain
and enable "Allow SFTP Campaigns" in the inbox settings.
```
