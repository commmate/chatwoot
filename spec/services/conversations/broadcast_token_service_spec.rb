require 'rails_helper'

RSpec.describe Conversations::BroadcastTokenService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }

  let(:manage_agent) { create(:user, account: account, role: :agent) }
  let(:participating_agent) { create(:user, account: account, role: :agent) }
  let(:unassigned_agent) { create(:user, account: account, role: :agent) }
  let(:plain_agent) { create(:user, account: account, role: :agent) }
  let(:non_inbox_agent) { create(:user, account: account, role: :agent) }

  before do
    create(:inbox_member, user: manage_agent, inbox: inbox)
    create(:inbox_member, user: participating_agent, inbox: inbox)
    create(:inbox_member, user: unassigned_agent, inbox: inbox)
    create(:inbox_member, user: plain_agent, inbox: inbox)

    set_permissions(manage_agent, %w[conversation_manage])
    set_permissions(participating_agent, %w[conversation_participating_manage])
    set_permissions(unassigned_agent, %w[conversation_unassigned_manage])
    set_permissions(non_inbox_agent, %w[conversation_manage])
  end

  def set_permissions(user, perms)
    AccountUser.find_by(user: user, account: account).update!(access_permissions: perms)
  end

  def tokens_for(conversation)
    described_class.new(account: account, conversation: conversation).permitted_tokens
  end

  describe '#permitted_tokens' do
    context 'when conversation is assigned to an agent' do
      let(:other_agent) { create(:user, account: account, role: :agent) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }

      before { create(:inbox_member, user: other_agent, inbox: inbox) }

      it 'includes administrator tokens' do
        expect(tokens_for(conversation)).to include(admin.pubsub_token)
      end

      it 'includes conversation_manage agent tokens' do
        expect(tokens_for(conversation)).to include(manage_agent.pubsub_token)
      end

      it 'includes the assignee token regardless of permissions' do
        expect(tokens_for(conversation)).to include(other_agent.pubsub_token)
      end

      it 'excludes conversation_unassigned_manage agent when conversation is assigned' do
        expect(tokens_for(conversation)).not_to include(unassigned_agent.pubsub_token)
      end

      it 'excludes conversation_participating_manage agent when not a participant' do
        expect(tokens_for(conversation)).not_to include(participating_agent.pubsub_token)
      end

      it 'includes conversation_participating_manage agent when they are a participant' do
        create(:conversation_participant, conversation: conversation, user: participating_agent, account: account)

        expect(tokens_for(conversation)).to include(participating_agent.pubsub_token)
      end

      it 'excludes agent with no conversation permissions' do
        expect(tokens_for(conversation)).not_to include(plain_agent.pubsub_token)
      end

      it 'excludes non-inbox-member even with conversation_manage permission' do
        expect(tokens_for(conversation)).not_to include(non_inbox_agent.pubsub_token)
      end
    end

    context 'when conversation is unassigned' do
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil) }

      it 'includes administrator tokens' do
        expect(tokens_for(conversation)).to include(admin.pubsub_token)
      end

      it 'includes conversation_manage agent tokens' do
        expect(tokens_for(conversation)).to include(manage_agent.pubsub_token)
      end

      it 'includes conversation_unassigned_manage agent tokens' do
        expect(tokens_for(conversation)).to include(unassigned_agent.pubsub_token)
      end

      it 'excludes conversation_participating_manage agent when not a participant' do
        expect(tokens_for(conversation)).not_to include(participating_agent.pubsub_token)
      end

      it 'excludes agent with no conversation permissions' do
        expect(tokens_for(conversation)).not_to include(plain_agent.pubsub_token)
      end
    end

    context 'when the assignee has no conversation permissions' do
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: plain_agent) }

      it 'still includes the assignee token' do
        expect(tokens_for(conversation)).to include(plain_agent.pubsub_token)
      end
    end

    context 'when inbox has no members' do
      let(:empty_inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: empty_inbox) }

      it 'returns only administrator tokens' do
        result = tokens_for(conversation)
        expect(result).to eq([admin.pubsub_token])
      end
    end

    it 'returns unique tokens when admin is also an inbox member' do
      create(:inbox_member, user: admin, inbox: inbox)
      conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)

      result = tokens_for(conversation)
      expect(result.count(admin.pubsub_token)).to eq(1)
    end
  end
end
