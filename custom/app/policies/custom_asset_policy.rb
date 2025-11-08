# frozen_string_literal: true

# Policy for CustomAsset - admin-only access for configuration
class CustomAssetPolicy < ApplicationPolicy
  def index?
    true # All users can view assets
  end

  def show?
    true # All users can view individual assets
  end

  def create?
    @user.administrator?
  end

  def update?
    @user.administrator?
  end

  def destroy?
    @user.administrator?
  end

  def test_connection?
    @user.administrator?
  end

  def fetch_assets?
    true # All users can fetch assets for contacts
  end
end


