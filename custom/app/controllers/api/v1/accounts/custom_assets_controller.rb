# frozen_string_literal: true

class Api::V1::Accounts::CustomAssetsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_custom_asset, only: [:show, :update, :destroy, :fetch_assets]

  def index
    @custom_assets = Current.account.custom_assets.enabled
    render json: @custom_assets
  end

  def show
    render json: @custom_asset
  end

  def create
    @custom_asset = Current.account.custom_assets.build(custom_asset_params)

    if @custom_asset.save
      render json: @custom_asset, status: :created
    else
      render json: { errors: @custom_asset.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @custom_asset.update(custom_asset_params)
      render json: @custom_asset
    else
      render json: { errors: @custom_asset.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @custom_asset.destroy!
    head :ok
  end

  def fetch_assets
    contact = Current.account.contacts.find(params[:contact_id])

    assets = CustomAssets::N8nClientService.new(@custom_asset).fetch_list(
      contact,
      search: params[:search],
      filters: params[:filters]
    )

    render json: { assets: assets, total: assets.length }
  end

  def test_connection
    response = HTTParty.post(
      params[:n8n_webhook_url],
      body: { test: true, contact_id: 0 }.to_json,
      headers: { 'Content-Type' => 'application/json' },
      timeout: 10
    )

    if response.success?
      render json: { success: true, status: response.code, message: 'Connection successful!' }
    else
      render json: { success: false, status: response.code, error: 'Connection failed' }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def set_custom_asset
    @custom_asset = Current.account.custom_assets.find(params[:id])
  end

  def custom_asset_params
    params.require(:custom_asset).permit(
      :name, :asset_type, :n8n_webhook_url, :n8n_workflow_id,
      :description, :enabled,
      display_config: { fields: [:key, :label, :type, :format] }
    )
  end

  def check_authorization
    authorize(CustomAsset) unless action_name == 'fetch_assets'
  end
end


