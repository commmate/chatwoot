module BrandColorHelper
  def brand_color_style_tag(hex_color)
    return '' if hex_color.blank?

    service = BrandColorService.new(hex_color)
    return '' unless service.valid?

    tag.style(service.generate_css.html_safe, id: 'brand-color-override') # rubocop:disable Rails/OutputSafety
  end
end
