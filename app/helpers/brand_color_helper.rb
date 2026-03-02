module BrandColorHelper
  def brand_color_style_tag(hex_color)
    return '' if hex_color.blank?

    service = BrandColorService.new(hex_color)
    return '' unless service.valid?

    "<style id=\"brand-color-override\">#{service.generate_css}</style>".html_safe # rubocop:disable Rails/OutputSafety
  end
end
