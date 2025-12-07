# frozen_string_literal: true

class Api::V1::Accounts::PipelinesController < Api::V1::Accounts::BaseController
  before_action :fetch_pipeline, only: [:show, :update, :destroy, :reorder_stages]
  before_action :check_authorization

  def index
    @pipelines = Current.account.pipelines.ordered
  end

  def show; end

  def create
    @pipeline = Current.account.pipelines.new(pipeline_params)
    
    if @pipeline.save
      render json: @pipeline, status: :created
    else
      render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @pipeline.update(pipeline_params)
      render json: @pipeline
    else
      render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @pipeline.destroy
    head :no_content
  end

  def reorder_stages
    new_stages = params[:stages]
    
    if new_stages.is_a?(Array)
      @pipeline.update(stages: new_stages)
      render json: @pipeline
    else
      render json: { error: 'Invalid stages format' }, status: :unprocessable_entity
    end
  end

  private

  def fetch_pipeline
    @pipeline = Current.account.pipelines.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name, :description, :position, stages: [:name, :order])
  end

  def check_authorization
    authorize(Pipeline)
  end
end

