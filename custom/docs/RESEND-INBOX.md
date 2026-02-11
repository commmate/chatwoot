# Resend Email Inbox Integration

**Purpose:** Enable email campaigns via Resend API with delivery tracking and webhook integration  
**Version:** 1.0  
**Last Updated:** January 25, 2026

---

## Overview

The Resend Inbox integration allows CommMate to send email campaigns through the Resend API. This provides:

- One-off email campaign sending via Resend API
- Delivery status tracking via webhooks
- HTML email support with Liquid template variables
- Flexible reply-to email configuration (IMAP, Resend, or custom)
- Detailed delivery reports with error tracking

---

## Architecture

### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `Channel::Email` | `app/models/channel/email.rb` | Email channel model with Resend provider support |
| `Resend::Client` | `app/services/resend/client.rb` | API client for Resend HTTP calls |
| `Resend::OneoffCampaignService` | `app/services/resend/oneoff_campaign_service.rb` | Campaign sending orchestration |
| `Resend::IncomingWebhookService` | `app/services/resend/incoming_webhook_service.rb` | Webhook event processing |
| `ResendSettings.vue` | `app/javascript/.../resend/ResendSettings.vue` | Inbox settings UI |
| `EmailCampaignDialog.vue` | `app/javascript/.../EmailCampaign/EmailCampaignDialog.vue` | Campaign creation UI |
| `EmailCampaignDetailsDialog.vue` | `app/javascript/.../EmailCampaign/EmailCampaignDetailsDialog.vue` | Campaign details & delivery report |

### Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│ Campaign Dialog │────▶│ OneoffCampaign   │────▶│ Resend API  │
│ (Vue.js)        │     │ Service (Rails)  │     │             │
└─────────────────┘     └──────────────────┘     └─────────────┘
                                                        │
                                                        ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────┐
│ Delivery Report │◀────│ Webhook Service  │◀────│ Resend      │
│ (Vue.js)        │     │ (Rails)          │     │ Webhooks    │
└─────────────────┘     └──────────────────┘     └─────────────┘
```

---

## Inbox Configuration

### Creating a Resend Inbox

1. Navigate to **Settings → Inboxes → Add Inbox**
2. Select **Email** channel type
3. Choose **Resend** as the provider
4. Fill in the required fields:

| Field | Required | Description |
|-------|----------|-------------|
| Inbox Name | Yes | Display name for the inbox |
| From Email | Yes | Verified Resend sender email (e.g., `hello@yourdomain.com`) |
| From Name | No | Sender display name (e.g., `Your Company`) |
| API Key | Yes | Resend API key (starts with `re_`) |

### Provider Config Structure

The `provider_config` JSONB column stores:

```json
{
  "api_key": "re_xxxxx...",
  "from_email": "hello@yourdomain.com",
  "from_name": "Your Company",
  "webhook_signing_secret": "whsec_xxxxx..."
}
```

### Inbox Settings

The Resend inbox settings tab (`/settings/inboxes/:id/resend`) provides:

1. **Sender Settings** (top section)
   - From Email (editable)
   - From Name (optional, editable)
   - Single "Update Sender Settings" button

2. **API Key**
   - Current key displayed with copy button
   - Input field to update the key

3. **Webhook URL**
   - Auto-generated callback URL for Resend webhooks
   - Copy button for easy configuration

4. **Webhook Signing Secret**
   - Current secret displayed with copy button
   - Input field to update the secret

---

## Email Campaigns

### Creating a Campaign

The `EmailCampaignDialog` component provides a form with:

1. **Campaign Details Section**
   - Campaign Title (internal reference)
   - Email Subject (what recipients see)
   - Select Inbox (Resend inbox selector)
   - Reply-To Email options

2. **Email Content Section**
   - HTML content textarea with Liquid variable support
   - Live preview panel

3. **Audience & Schedule Section**
   - Label-based audience selection
   - Scheduled time picker

### Reply-To Options

The dialog offers three reply-to configurations:

| Option | Description | When to Use |
|--------|-------------|-------------|
| **IMAP Email** | Uses inbox's IMAP login email | Best for 2-way communication; shows "Recommended" badge |
| **Resend Email** | Uses the Resend sender email | Default when IMAP not configured |
| **Custom Email** | Any email address | For specific reply routing |

**Logic:**
- If IMAP is enabled → IMAP option shown with "Recommended" badge, selected by default
- If IMAP not enabled → Resend option selected by default with "Default" badge
- Custom option always available

### Liquid Template Variables

Supported variables in email content:

| Variable | Description |
|----------|-------------|
| `{{contact.name}}` | Contact's full name |
| `{{contact.email}}` | Contact's email address |
| `{{contact.phone_number}}` | Contact's phone number |
| `{{inbox.name}}` | Inbox display name |

---

## Campaign Sending Service

### OneoffCampaignService

Located at `app/services/resend/oneoff_campaign_service.rb`

**Responsibilities:**
- Retrieve contacts based on campaign audience labels
- Build personalized email content per contact
- Send emails via Resend API
- Track delivery status per contact
- Handle errors gracefully

**Key Methods:**

```ruby
# Main entry point
def perform
  return if contacts.empty?
  
  contacts.each do |contact|
    send_to_contact(contact)
  end
  
  update_campaign_status
end

# Email address formatting
def from_address
  # Uses from_name if set, falls back to inbox name
  # Format: "Display Name <email@domain.com>"
end

def reply_to_address
  # Based on campaign's reply_to_email setting
  # Includes from_name if available
end
```

### From Address Logic

```ruby
def from_address
  from_name = channel.provider_config['from_name'] || inbox.name
  from_email = channel.provider_config['from_email'] || channel.email
  "#{from_name} <#{from_email}>"
end
```

### Reply-To Address Logic

```ruby
def reply_to_address
  reply_email = campaign.additional_attributes&.dig('reply_to_email')
  reply_email = channel.email if reply_email.blank?
  
  from_name = channel.provider_config['from_name']
  from_name.present? ? "#{from_name} <#{reply_email}>" : reply_email
end
```

---

## Webhook Integration

### Webhook URL

Each Resend inbox has an auto-generated webhook URL:

```
https://yourdomain.com/webhooks/resend/:inbox_id
```

### Supported Events

| Event | Description | Action |
|-------|-------------|--------|
| `email.sent` | Email accepted by Resend | Update status to "sent" |
| `email.delivered` | Email delivered to recipient | Update status to "delivered" |
| `email.bounced` | Email bounced | Mark as failed with bounce reason |
| `email.complained` | Recipient marked as spam | Mark as failed |
| `email.opened` | Email was opened | Track open event |
| `email.clicked` | Link was clicked | Track click event |

### Webhook Signature Verification

Webhooks are verified using the signing secret:

```ruby
def verify_signature(payload, signature)
  expected = OpenSSL::HMAC.hexdigest('SHA256', signing_secret, payload)
  ActiveSupport::SecurityUtils.secure_compare(expected, signature)
end
```

---

## Delivery Reports

### EmailCampaignDetailsDialog

The campaign details dialog shows:

1. **Campaign Info**
   - Title, subject, inbox, scheduled time
   - Audience labels

2. **Delivery Summary**
   - Total sent count
   - Delivered count
   - Failed count
   - Processing count

3. **Error Details** (if failures)
   - List of failed contacts
   - Error messages per contact

4. **Email Preview**
   - Rendered HTML in sandboxed iframe

### Status Tracking

Campaign statuses:

| Status | Description |
|--------|-------------|
| `scheduled` | Campaign is scheduled for future |
| `processing` | Campaign is currently sending |
| `completed` | All emails sent successfully |
| `completed_with_errors` | Some emails failed |
| `failed` | Campaign failed entirely |

---

## Error Handling

### Common Errors

| Error | Cause | Resolution |
|-------|-------|------------|
| `ConfigurationError: Resend API key is not configured` | Missing or invalid API key | Update API key in inbox settings |
| `Invalid 'reply_to' field` | Malformed reply-to email | Check from_name for special characters |
| `Resend::RateLimitError` | API rate limit exceeded | Wait and retry; consider batching |
| `Resend::ValidationError` | Invalid email parameters | Check email addresses and content |

### Error Tracking

Errors are stored in `campaign_message_mappings`:

```ruby
mapping.update(
  status: 'failed',
  error_message: error.message,
  processed_at: Time.current
)
```

---

## API Client

### Resend::Client

Located at `app/services/resend/client.rb`

**Configuration:**
```ruby
def initialize(api_key:)
  @api_key = api_key
  validate_configuration!
end
```

**Validation:**
```ruby
def validate_configuration!
  raise ConfigurationError, 'Resend API key is not configured' if @api_key.blank?
end
```

**Sending Emails:**
```ruby
def send_email(to:, from:, subject:, html:, reply_to: nil)
  post('/emails', {
    to: to,
    from: from,
    subject: subject,
    html: html,
    reply_to: reply_to
  })
end
```

---

## Frontend Components

### ResendSettings.vue

**Location:** `app/javascript/dashboard/routes/dashboard/settings/inbox/resend/ResendSettings.vue`

**Sections:**
1. Sender Settings (From Email + From Name)
2. API Key display and update
3. Webhook URL with copy
4. Signing Secret display and update

**Methods:**
- `updateSenderSettings()` - Updates from_email and from_name
- `updateApiKey()` - Updates API key
- `updateSigningSecret()` - Updates webhook signing secret
- `copyToClipboard()` - Copies value to clipboard

### EmailCampaignDialog.vue

**Location:** `app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/EmailCampaign/EmailCampaignDialog.vue`

**Features:**
- Form validation with Vuelidate
- Live HTML preview
- Smart reply-to option selection based on inbox capabilities
- Audience selection via labels

### EmailCampaignDetailsDialog.vue

**Location:** `app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/EmailCampaign/EmailCampaignDetailsDialog.vue`

**Features:**
- Campaign metadata display
- Delivery statistics
- Error report with contact details
- HTML email preview in sandboxed iframe

---

## i18n Keys

### Backend (`en.yml`)

```yaml
resend:
  errors:
    api_key_not_configured: "Resend API key is not configured"
    invalid_reply_to: "Invalid reply-to email format"
```

### Frontend (`campaign.json`)

```json
{
  "CAMPAIGN": {
    "EMAIL": {
      "CREATE": {
        "FORM": {
          "REPLY_TO": {
            "TITLE": "Reply-To Email",
            "DESCRIPTION": "Choose where replies to this campaign will be sent.",
            "IMAP_OPTION": "Use IMAP inbox email",
            "RESEND_OPTION": "Use Resend sender email",
            "CUSTOM_OPTION": "Use a custom email",
            "RECOMMENDED": "Recommended",
            "DEFAULT": "Default"
          }
        }
      }
    }
  }
}
```

### Frontend (`inboxMgmt.json`)

```json
{
  "INBOX_MGMT": {
    "RESEND_SETTINGS": {
      "SENDER_TITLE": "Sender Settings",
      "SENDER_SUBTITLE": "Configure the sender email and display name for emails sent from this inbox.",
      "FROM_EMAIL_LABEL": "From Email",
      "FROM_NAME_LABEL": "From Name (Optional)",
      "UPDATE_SENDER": "Update Sender Settings",
      "SENDER_SAVED": "Sender settings saved successfully"
    }
  }
}
```

---

## Database Schema

### channel_email table

Relevant columns for Resend:

| Column | Type | Description |
|--------|------|-------------|
| `email` | string | Primary email address |
| `provider` | string | `'resend'` for Resend inboxes |
| `provider_config` | jsonb | Stores API key, from_name, etc. |
| `verified_for_sending` | boolean | Email verification status |

### campaign_message_mappings table

Tracks individual email delivery:

| Column | Type | Description |
|--------|------|-------------|
| `campaign_id` | integer | Parent campaign |
| `contact_id` | integer | Target contact |
| `status` | string | `pending`, `sent`, `delivered`, `failed` |
| `error_message` | text | Error details if failed |
| `resend_email_id` | string | Resend's email ID for tracking |
| `processed_at` | datetime | When email was processed |

---

## Security Considerations

1. **API Key Storage**
   - Stored in `provider_config` JSONB column
   - Only returned to administrators via API
   - Never exposed to non-admin users

2. **Webhook Verification**
   - All webhooks verified using signing secret
   - Prevents unauthorized status updates

3. **Email Content**
   - HTML rendered in sandboxed iframe
   - Prevents XSS in preview

4. **Reply-To Validation**
   - Email format validated before sending
   - From Name sanitized to prevent injection

---

## Troubleshooting

### Campaign Not Sending

1. Check inbox has valid API key in settings
2. Verify scheduled time is in the future (or immediate)
3. Confirm audience labels have contacts with emails
4. Check Rails logs for detailed error messages

### Webhook Not Updating Status

1. Verify webhook URL is configured in Resend dashboard
2. Check signing secret matches between Resend and CommMate
3. Ensure webhook endpoint is publicly accessible
4. Check Rails logs for webhook processing errors

### Reply-To Errors

1. Ensure from_name doesn't contain special characters like `<`, `>`
2. Verify email format is valid
3. Check that channel.email is set correctly

---

## Future Enhancements

- [ ] Batch sending for large campaigns (>1000 contacts)
- [ ] A/B testing support
- [ ] Email template library
- [ ] Attachment support
- [ ] Scheduled recurring campaigns
- [ ] Open/click tracking analytics dashboard

