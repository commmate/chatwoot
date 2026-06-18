class CustomAttributeDefinitionPolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    @account_user.administrator? || has_custom_attributes_manage_permission?
  end

  def update?
    @account_user.administrator? || has_custom_attributes_manage_permission?
  end

  def destroy?
    @account_user.administrator? || has_custom_attributes_manage_permission?
  end

  private

  def has_custom_attributes_manage_permission?
    @account_user.permissions.include?('settings_custom_attributes_manage')
  end
end
