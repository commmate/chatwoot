# frozen_string_literal: true

# This initializer enforces Evolution integration safety without modifying upstream models.
#
# Evolution (in its Chatwoot integration) locates the inbox by `nameInbox` within an account.
# If there are multiple inboxes with the same name in the same account, Evolution may bind
# to the wrong inbox (it selects the first match), breaking message routing.
#
# We enforce: For Evolution-backed inboxes, `name` must be unique within the account.

Rails.application.config.after_initialize do
  Inbox.class_eval do
    validate :evolution_inbox_name_unique_within_account

    private

    def evolution_inbox_name_unique_within_account
      return if account_id.blank? || name.blank?
      return unless channel_type == 'Channel::Api'
      return unless channel.respond_to?(:additional_attributes)
      return if channel.additional_attributes&.dig('evolution_instance_name').blank?

      normalized = name.to_s.strip
      return if normalized.blank?

      conflict = Inbox.where(account_id: account_id)
                      .where('lower(name) = ?', normalized.downcase)
                      .where.not(id: id)
                      .exists?
      return unless conflict

      errors.add(:name, 'must be unique within the account for Evolution inboxes')
    end
  end
end


