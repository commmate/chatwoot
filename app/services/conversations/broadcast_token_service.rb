# CommMate: Determines which agent pubsub tokens should receive ActionCable
# broadcasts for a given conversation, based on per-user access_permissions.
#
# Mirrors the filtering logic in Conversations::PermissionFilterService so
# WebSocket events match what each agent sees via the HTTP API.
class Conversations::BroadcastTokenService
  pattr_initialize [:account!, :conversation!]

  def permitted_tokens
    admin_tokens = account.administrators.pluck(:pubsub_token)

    inbox_members = conversation.inbox.inbox_members.includes(:user)
    return admin_tokens if inbox_members.empty?

    agent_tokens = inbox_members.filter_map do |im|
      im.user.pubsub_token if permitted?(im.user_id)
    end

    (agent_tokens + admin_tokens).uniq
  end

  private

  def permitted?(user_id)
    au = account_users_by_id[user_id]
    return false if au.nil?
    return true if au.administrator? || full_access?(au)

    assignee?(user_id) || unassigned_access?(au) || participating_access?(au, user_id)
  end

  def full_access?(account_user)
    agent_permissions(account_user).include?('conversation_manage')
  end

  def assignee?(user_id)
    conversation.assignee_id == user_id
  end

  def unassigned_access?(account_user)
    conversation.assignee_id.nil? && agent_permissions(account_user).include?('conversation_unassigned_manage')
  end

  def participating_access?(account_user, user_id)
    participant_ids.include?(user_id) && agent_permissions(account_user).include?('conversation_participating_manage')
  end

  def agent_permissions(account_user)
    account_user.access_permissions || []
  end

  def account_users_by_id
    @account_users_by_id ||= AccountUser.where(account_id: account.id, user_id: member_user_ids).index_by(&:user_id)
  end

  def participant_ids
    @participant_ids ||= conversation.conversation_participants.where(user_id: member_user_ids).pluck(:user_id).to_set
  end

  def member_user_ids
    @member_user_ids ||= conversation.inbox.inbox_members.pluck(:user_id)
  end
end
