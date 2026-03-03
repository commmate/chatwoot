# frozen_string_literal: true

class V2::Reports::CampaignMessagesBuilder
  DEFAULT_PER_PAGE = 25
  ALLOWED_SORT_COLUMNS = %w[contact_name status created_at opened_at clicked_at replied_at].freeze

  pattr_initialize [:account!, :params!]

  def build
    { data: page_records.map { |m| serialize(m) }, meta: meta }
  end

  private

  def campaign
    @campaign ||= account.campaigns.find(params[:campaign_id])
  end

  def delivery_report
    @delivery_report ||= campaign.delivery_report
  end

  def base_scope
    CampaignMessageMapping
      .where(campaign_delivery_report_id: delivery_report&.id)
      .includes(:contact)
  end

  def filtered_scope
    scope = base_scope
    scope = apply_filter(scope) if params[:filter].present?
    scope
  end

  def apply_filter(scope)
    query = "%#{params[:filter]}%"
    scope.joins(:contact).where('contacts.email ILIKE :q OR contacts.phone_number ILIKE :q OR contacts.name ILIKE :q', q: query)
  end

  def sort_column
    col = params[:sort_by].to_s
    return 'campaign_message_mappings.created_at' unless ALLOWED_SORT_COLUMNS.include?(col)

    col == 'contact_name' ? 'contacts.name' : "campaign_message_mappings.#{col}"
  end

  def sort_direction
    params[:sort_order].to_s.downcase == 'asc' ? :asc : :desc
  end

  def mappings_scope
    @mappings_scope ||= begin
      scope = filtered_scope
      scope = scope.joins(:contact) if sort_column.start_with?('contacts.')
      scope.order(sort_column => sort_direction)
    end
  end

  def page
    [(params[:page] || 1).to_i, 1].max
  end

  def per_page
    [(params[:per_page] || DEFAULT_PER_PAGE).to_i, 100].min
  end

  def total_count
    @total_count ||= mappings_scope.count
  end

  def page_records
    @page_records ||= mappings_scope.offset((page - 1) * per_page).limit(per_page)
  end

  def engagement?
    @engagement ||= CampaignMessageMapping
                    .where(campaign_delivery_report_id: delivery_report&.id)
                    .exists?(['opened_at IS NOT NULL OR clicked_at IS NOT NULL OR status = ?', 'read'])
  end

  def meta
    {
      total: total_count,
      page: page,
      per_page: per_page,
      total_pages: (total_count.to_f / per_page).ceil,
      has_engagement: engagement?
    }
  end

  def serialize(mapping)
    contact = mapping.contact
    {
      id: mapping.id,
      contact_id: contact&.id,
      contact_name: contact&.name,
      contact_identifier: contact&.email.presence || contact&.phone_number,
      status: mapping.status,
      opened_at: mapping.opened_at,
      clicked_at: mapping.clicked_at,
      replied_at: mapping.replied_at,
      error_code: mapping.error_code,
      error_message: mapping.error_message,
      created_at: mapping.created_at
    }
  end
end
