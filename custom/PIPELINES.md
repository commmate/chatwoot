# Pipeline Management Feature

## Overview

Pipelines allow you to create custom workflow stages for conversations, similar to sales pipelines or support workflows. Each pipeline automatically creates a custom conversation field for tracking stage progression.

## Features

- Create multiple pipelines per account
- Define custom stages for each pipeline
- Drag-and-drop stage reordering
- Kanban-style board view per pipeline
- Filter conversations by team, inbox, agent, label
- Add conversations to any stage
- Bidirectional sync with custom conversation fields
- Conversations can be in multiple pipelines simultaneously

## Architecture

### Database

**Table**: `pipelines`
- `name`: Pipeline name
- `description`: Optional description
- `stages`: JSONB array of stage objects `[{name: "Lead", order: 0}, ...]`
- `account_id`: Account reference
- `custom_attribute_definition_id`: Link to auto-created custom field
- `position`: Display order

### Backend

**Model**: `custom/app/models/pipeline.rb`
- Automatically creates CustomAttributeDefinition on create
- Syncs stages to custom field values
- Cleans up custom field on delete

**Controller**: `custom/app/controllers/api/v1/accounts/pipelines_controller.rb`
- CRUD operations
- Stage reordering endpoint

**Policy**: `custom/app/policies/pipeline_policy.rb`
- Administrator-only access

### Frontend

**Settings Pages**:
- List: `/settings/pipelines`
- Create: `/settings/pipelines/new`
- Edit: `/settings/pipelines/:id/edit`

**Pipeline Boards**:
- Board view: `/pipelines/:pipelineId`

## Usage

### Create a Pipeline

1. Navigate to Settings → Pipelines
2. Click "Add Pipeline"
3. Enter name and description
4. Add stages (e.g., "Lead", "Qualified", "Proposal", "Closed")
5. Drag to reorder stages
6. Save

A custom conversation field is automatically created: `pipeline_{name}_stage`

### Use the Pipeline

1. Click "Pipelines" in sidebar
2. Select your pipeline
3. View kanban board with columns per stage
4. Click "+" to add conversations to a stage
5. Drag conversations between stages
6. Use filters to narrow down conversations

### Custom Field Integration

The pipeline stages are synced to a custom conversation field (type: list).

**Bidirectional**:
- Edit pipeline stages → custom field values update
- Edit custom field values → pipeline stages update

**Multiple Pipelines**:
- Each pipeline creates its own field
- Conversations can be in multiple pipelines
- Each has independent stages

## API Endpoints

```
GET    /api/v1/accounts/:account_id/pipelines
POST   /api/v1/accounts/:account_id/pipelines
GET    /api/v1/accounts/:account_id/pipelines/:id
PUT    /api/v1/accounts/:account_id/pipelines/:id
DELETE /api/v1/accounts/:account_id/pipelines/:id
POST   /api/v1/accounts/:account_id/pipelines/:id/reorder_stages
```

## Deployment

The pipelines table will be created automatically when you run:

```bash
# In Docker
podman-compose -f docker-compose.commmate.yaml exec rails bundle exec rails db:migrate

# Or locally
bundle exec rails db:migrate
```

## Core File Changes

Minimal changes to core files:
1. `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` - Add custom routes
2. `app/javascript/dashboard/routes/dashboard/settings/settings.routes.js` - Add pipeline settings
3. `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` - Add Pipelines menu
4. `app/javascript/dashboard/i18n/locale/en/index.js` - Add translations

All other code lives in `custom/` directory.

## Future Enhancements

- Pipeline templates (sales, support, etc.)
- Stage automation triggers
- Pipeline analytics
- Conversion rates between stages
- Time in stage tracking
- Pipeline cloning

