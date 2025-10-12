# frozen_string_literal: true

json.id @pipeline.id
json.name @pipeline.name
json.description @pipeline.description
json.stages @pipeline.stages
json.position @pipeline.position
json.custom_attribute_definition_id @pipeline.custom_attribute_definition_id
json.custom_field_key @pipeline.custom_field_key
json.conversations_count @pipeline.conversations_count
json.created_at @pipeline.created_at
json.updated_at @pipeline.updated_at

