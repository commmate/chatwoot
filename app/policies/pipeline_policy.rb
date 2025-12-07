# frozen_string_literal: true

class PipelinePolicy < ApplicationPolicy
  def index?
    can_manage? || can_create?
  end

  def show?
    can_manage? || can_create?
  end

  def create?
    can_create?
  end

  def update?
    can_manage?
  end

  def destroy?
    can_create?  # Who creates can delete
  end

  def reorder_stages?
    can_manage?
  end

  private

  def can_create?
    return true if @account_user.administrator?
    return false unless @account_user.custom_role

    @account_user.custom_role.permissions.include?('pipeline_create')
  end

  def can_manage?
    return true if @account_user.administrator?
    return false unless @account_user.custom_role

    @account_user.custom_role.permissions.include?('pipeline_manage')
  end
end

