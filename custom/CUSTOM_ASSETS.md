# Custom Assets Feature (n8n-Powered)

## Overview

Custom Assets allows admins to configure external API integrations using n8n workflows. Agents can view asset data (products, invoices, orders, etc.) in the conversation sidebar and share them via WhatsApp.

**Key Innovation**: Uses n8n as the integration layer instead of building custom API clients!

## Architecture

```
┌─────────────┐         ┌──────────┐         ┌─────────────────┐
│  Chatwoot   │ ─POST─> │   n8n    │ ─HTTP─> │  External APIs  │
│  (Sidebar)  │ <─JSON─ │ Workflow │ <─JSON─ │ (Products, etc) │
└─────────────┘         └──────────┘         └─────────────────┘
```

## Benefits

- **No Custom Code**: n8n handles all API calls, auth, pagination, retries
- **Visual Configuration**: Admins build workflows visually in n8n
- **400+ Integrations**: Use n8n's pre-built nodes (Shopify, Stripe, Salesforce, etc.)
- **Flexible**: Chain multiple APIs, add conditional logic, transform data
- **Maintainable**: n8n team maintains the integration layer

## Database Schema

**Table**: `custom_assets`
- `name`: Display name (e.g., "Products", "Invoices")
- `asset_type`: Identifier (e.g., "products", "invoices")
- `n8n_webhook_url`: n8n webhook trigger URL
- `n8n_workflow_id`: Optional workflow ID for linking
- `description`: User-friendly description
- `display_config`: JSONB - which fields to display `{ fields: [{key, label, type}] }`
- `enabled`: Boolean flag
- `account_id`: Account reference

## Setup Guide

### 1. Configure n8n Workflow

1. Open n8n and create a new workflow
2. Add **Webhook** trigger node (POST method)
3. Build your API integration:
   - Add HTTP Request nodes
   - Configure authentication (API Key, OAuth2, Basic, Bearer)
   - Add data transformation/filtering as needed
4. Return JSON: array or `{items: [...]}` or `{data: [...]}`
5. Activate the workflow
6. Copy the webhook URL

**Example Workflow** (Simple Product API):
```
[Webhook] → [HTTP: GET /products?email={{$json.email}}] → [Respond]
```

**Webhook Payload** (sent from Chatwoot):
```json
{
  "contact_id": 123,
  "email": "customer@example.com",
  "phone": "+1234567890",
  "name": "John Doe",
  "custom_attributes": {...},
  "search_query": "laptop",
  "filters": {...},
  "account_id": 1
}
```

### 2. Configure in Chatwoot

1. Navigate to **Settings → Custom Assets** (admin only)
2. Click **Add Custom Asset**
3. Fill in:
   - **Name**: e.g., "Products"
   - **Asset Type**: e.g., "products" (lowercase, no spaces)
   - **Description**: Optional description
   - **n8n Webhook URL**: Paste from n8n
   - **n8n Workflow ID**: Optional (for easy access)
4. Click **Test Connection** to verify
5. Configure **Display Fields**:
   - Add fields from n8n response
   - Set labels and types (text, number, currency, date, link)
6. Save

### 3. Use in Conversations

1. Open a conversation
2. View custom assets in the **Contact Sidebar**
3. Assets are fetched automatically based on contact info
4. Click **Share via WhatsApp** to send asset info to customer

## Backend Structure

**Location**: `custom/` folder (keeps it separate from core Chatwoot)

```
custom/
├── app/
│   ├── models/custom_asset.rb
│   ├── controllers/api/v1/accounts/custom_assets_controller.rb
│   ├── policies/custom_asset_policy.rb
│   ├── services/custom_assets/
│   │   ├── n8n_client_service.rb
│   │   └── message_formatter_service.rb
│   └── javascript/dashboard/
│       ├── api/customAssets.js
│       └── store/modules/customAssets.js
└── db/migrate/TIMESTAMP_create_custom_assets.rb
```

## API Endpoints

```
GET    /api/v1/accounts/:account_id/custom_assets
POST   /api/v1/accounts/:account_id/custom_assets
GET    /api/v1/accounts/:account_id/custom_assets/:id
PUT    /api/v1/accounts/:account_id/custom_assets/:id
DELETE /api/v1/accounts/:account_id/custom_assets/:id
GET    /api/v1/accounts/:account_id/custom_assets/:id/fetch_assets?contact_id=123
POST   /api/v1/accounts/:account_id/custom_assets/test_connection
```

## n8n Workflow Examples

### Example 1: Simple Product Lookup
```
[Webhook] → [HTTP Request (GET)] → [Respond]
  URL: https://api.example.com/products?email={{$json.email}}
  Auth: API Key in headers
```

### Example 2: OAuth + Pagination
```
[Webhook] → [Get OAuth Token] → [HTTP Loop] → [Aggregate Results] → [Respond]
```

### Example 3: Multiple Data Sources
```
[Webhook] → [Split]
  ├─> [Get Orders from API 1] → [Transform]
  ├─> [Get Invoices from API 2] → [Transform]
  └─> [Merge] → [Respond]
```

### Example 4: Conditional Logic
```
[Webhook] → [IF: email exists]
  ├─ True: [Fetch Customer Data] → [Respond]
  └─ False: [Return Empty] → [Respond]
```

## Message Formatting

When agents share assets via WhatsApp, the data is formatted as text:

```
*Products*

Name: Laptop Pro 15"
Price: USD 1,299.00
Status: In Stock
SKU: LAP-PRO-15
```

**OpenAI Integration** (optional):
If OpenAI integration is enabled, messages can be formatted naturally using LLM.

## Environment Variables

Add to `.env`:
```bash
N8N_URL=http://localhost:5678  # or your n8n instance URL
```

## Development

### Run Migrations
```bash
# In Docker/Podman
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:migrate

# Or locally
bundle exec rails db:migrate
```

### Testing Locally

1. **Start n8n**:
   ```bash
   docker run -it --rm \
     --name n8n \
     -p 5678:5678 \
     -v ~/.n8n:/home/node/.n8n \
     n8nio/n8n
   ```

2. **Start Chatwoot**:
   ```bash
   podman-compose -f docker-compose.commmate.yaml up
   ```

3. **Create Test Workflow** in n8n:
   - Add Webhook trigger
   - Add HTTP Request or use mock data
   - Return sample JSON

4. **Configure in Chatwoot**:
   - Login as admin
   - Go to Settings → Custom Assets
   - Add new asset with n8n webhook URL

5. **Test in Conversation**:
   - Open any conversation
   - Check sidebar for custom assets
   - Click share to test formatting

## Security

- **Admin-only configuration**: Only administrators can create/edit assets
- **HTTPS required**: Webhook URLs should use HTTPS in production
- **Timeout**: 30-second timeout for n8n requests
- **Error handling**: Failed requests don't crash the app
- **No credential storage**: All credentials stored in n8n, not Chatwoot

## Troubleshooting

**Assets not appearing in sidebar:**
- Check that asset is enabled
- Verify n8n workflow is activated
- Check n8n logs for errors
- Ensure webhook URL is correct

**Test connection fails:**
- Verify n8n is running and accessible
- Check firewall/network settings
- Ensure webhook accepts POST requests
- Check n8n workflow is activated

**Empty results:**
- Check n8n workflow response format
- Verify contact has required data (email/phone)
- Check n8n logs for API errors
- Test n8n workflow directly

## Future Enhancements

- [ ] Webhook authentication (shared secret)
- [ ] Response caching
- [ ] Real-time updates via WebSocket
- [ ] Asset search/filtering in UI
- [ ] Bulk actions
- [ ] Asset templates library
- [ ] n8n workflow import/export
- [ ] Analytics and usage tracking

## Support

For issues or questions:
1. Check n8n logs first
2. Check Chatwoot logs: `podman-compose logs rails`
3. Verify workflow execution in n8n
4. Test API directly with curl/Postman

