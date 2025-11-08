# Testing Custom Assets Feature

## Quick Start

### 1. Start the Stack (Chatwoot + n8n + Postgres + Redis)

```bash
cd /Users/schimuneck/projects/commmmate/chatwoot

# Start everything with podman
podman-compose -f docker-compose.commmate.yaml -f docker-compose.custom-assets.yaml up -d

# Wait for services to be ready (about 30 seconds)
podman-compose -f docker-compose.commmate.yaml ps
```

### 2. Run Database Migration

```bash
# Run migration to create custom_assets table
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:migrate

# Verify migration
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:migrate:status | grep custom_assets
```

### 3. Create Test n8n Workflow

1. Open n8n: http://localhost:5678
2. Create a new workflow
3. Add **Webhook** node:
   - Method: POST
   - Path: /chatwoot-products (or any unique path)
4. Add **Code** node (or HTTP Request for real API):
```javascript
// Sample products data
const contact = $input.first().json;

const products = [
  {
    id: '1',
    name: 'Laptop Pro 15"',
    price: 1299.00,
    status: 'In Stock',
    sku: 'LAP-PRO-15',
    category: 'Electronics',
    link: 'https://example.com/products/1'
  },
  {
    id: '2',
    name: 'Wireless Mouse',
    price: 29.99,
    status: 'In Stock',
    sku: 'MSE-WLS-01',
    category: 'Accessories',
    link: 'https://example.com/products/2'
  },
  {
    id: '3',
    name: 'USB-C Cable',
    price: 15.50,
    status: 'Low Stock',
    sku: 'CBL-USC-20',
    category: 'Accessories',
    link: 'https://example.com/products/3'
  }
];

// Filter by search if provided
const searchQuery = contact.search_query?.toLowerCase();
const filteredProducts = searchQuery 
  ? products.filter(p => 
      p.name.toLowerCase().includes(searchQuery) ||
      p.sku.toLowerCase().includes(searchQuery)
    )
  : products;

return { items: filteredProducts };
```
5. Add **Respond to Webhook** node
6. **Activate** the workflow
7. Copy the **Production Webhook URL** (e.g., `http://localhost:5678/webhook/abc123`)

### 4. Configure Custom Asset in Chatwoot

1. Open Chatwoot: http://localhost:3000
2. Login as admin (create account if needed)
3. Go to **Settings → Custom Assets**
4. Click **Add Custom Asset**
5. Fill in:
   - **Name**: Products
   - **Asset Type**: products
   - **Description**: E-commerce products from our store
   - **n8n Webhook URL**: `http://n8n:5678/webhook/abc123` (use internal Docker network)
   - **n8n Workflow ID**: (optional, copy from n8n URL)
6. Click **Test Connection** - should show ✅
7. Add **Display Fields**:
   - Field: `name`, Label: `Product Name`, Type: `text`
   - Field: `price`, Label: `Price`, Type: `currency`
   - Field: `status`, Label: `Status`, Type: `text`
   - Field: `sku`, Label: `SKU`, Type: `text`
   - Field: `link`, Label: `Product Link`, Type: `link`
8. Click **Create**

### 5. Test in Conversation

1. Go to **Conversations**
2. Open any conversation (or create a test one)
3. Look at the **Contact Sidebar** (right side)
4. You should see **"Custom Assets"** accordion
5. Expand it to see **"Products"** section
6. Products should load automatically
7. Click **"Share via WhatsApp"** on any product
8. The formatted product info should be **copied to clipboard**
9. **Paste** it into the message box
10. Send the message!

## Expected Result

The shared message should look like:
```
*Products*

Product Name: Laptop Pro 15"
Price: USD 1299.00
Status: In Stock
SKU: LAP-PRO-15
Product Link: https://example.com/products/1
```

## Troubleshooting

### Assets not appearing in sidebar:
```bash
# Check n8n logs
podman logs commmate-n8n

# Check Rails logs
podman-compose -f docker-compose.commmate.yaml logs rails

# Check if custom assets loaded
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails console
> CustomAsset.count
> CustomAsset.first
```

### Migration didn't run:
```bash
# Check migration status
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:migrate:status

# Re-run if needed
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:migrate
```

### n8n webhook not working:
- Verify n8n is running: `podman ps | grep n8n`
- Access n8n UI: http://localhost:5678
- Check workflow is **activated** (toggle in top right)
- Test webhook URL directly with curl:
```bash
curl -X POST http://localhost:5678/webhook/abc123 \
  -H "Content-Type: application/json" \
  -d '{"test": true, "contact_id": 0}'
```

### Frontend not loading:
- Clear browser cache
- Check browser console for errors
- Verify Vuex store is loaded:
```javascript
// In browser console
$store.state.customAssets
```

## Clean Up

```bash
# Stop all services
podman-compose -f docker-compose.commmate.yaml -f docker-compose.custom-assets.yaml down

# Remove volumes (if needed)
podman volume rm chatwoot_n8n-data
```

## Next Steps

Once basic testing works:
1. Test with real external APIs (Shopify, Stripe, custom CRM)
2. Test pagination scenarios
3. Test error handling (invalid webhook URL, timeout)
4. Test with multiple asset types
5. Test search functionality
6. Test with different display field types


