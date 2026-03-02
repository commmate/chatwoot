class BrandColorService::TailwindOverridesCssBuilder
  def initialize(palette)
    @p = palette
    @r = palette[:red]
    @g = palette[:green]
    @b = palette[:blue]
  end

  def build
    [
      woot_shade_overrides,
      brand_background_overrides,
      brand_text_overrides,
      brand_border_overrides,
      brand_fill_stroke_overrides,
      ring_outline_overrides,
      hover_overrides,
      focus_overrides,
      alpha_overrides,
      special_component_overrides,
      avatar_overrides,
      form_overrides
    ].join("\n")
  end

  private

  def woot_shade_overrides
    <<~CSS
      .bg-woot-25 { background-color: #{@p[:woot_25]} !important; }
      .bg-woot-50 { background-color: #{@p[:woot_50]} !important; }
      .bg-woot-500, .bg-woot-600 { background-color: #{@p[:primary]} !important; }
      .bg-woot-500\\/10 { background-color: rgba(#{@r}, #{@g}, #{@b}, 0.1) !important; }
      .bg-woot-500\\/20 { background-color: rgba(#{@r}, #{@g}, #{@b}, 0.2) !important; }
      .text-woot-500, .text-woot-600 { color: #{@p[:primary]} !important; }
      .border-woot-100 { border-color: #{@p[:woot_100]} !important; }
      .border-woot-500, .border-woot-600 { border-color: #{@p[:primary]} !important; }
      .border-woot-700 { border-color: #{@p[:woot_700]} !important; }
      .ring-woot-500, .ring-woot-600 { --tw-ring-color: #{@p[:primary]} !important; }
      .focus-visible\\:outline-woot-500:focus-visible { outline-color: #{@p[:primary]} !important; }
    CSS
  end

  def brand_background_overrides
    <<~CSS
      .bg-n-brand { background-color: #{@p[:primary]} !important; }
      .bg-brand { background-color: #{@p[:primary]} !important; }
      .bg-n-blue-9, .bg-n-blue-10, .bg-n-blue-11, .bg-n-blue-12 { background-color: #{@p[:primary]} !important; }
      .bg-n-blue-text { background-color: #{@p[:primary]} !important; }
      .bg-n-iris-9, .bg-n-iris-10, .bg-n-iris-11 { background-color: #{@p[:primary]} !important; }
      .bg-green-400 { background-color: #{@p[:primary]} !important; }
      .bg-\\[\\#107e44\\] { background-color: #{@p[:primary]} !important; }
    CSS
  end

  def brand_text_overrides
    <<~CSS
      .text-n-brand { color: #{@p[:primary]} !important; }
      .text-brand { color: #{@p[:primary]} !important; }
      .text-n-blue-9, .text-n-blue-10, .text-n-blue-11, .text-n-blue-12 { color: #{@p[:primary]} !important; }
      .text-n-blue-text, .text-blue-text { color: #{@p[:primary]} !important; }
      .text-n-iris-9, .text-n-iris-10, .text-n-iris-11 { color: #{@p[:primary]} !important; }
      .\\!text-n-iris-9 { color: #{@p[:primary]} !important; }
    CSS
  end

  def brand_border_overrides
    <<~CSS
      .border-n-brand { border-color: #{@p[:primary]} !important; }
      .border-brand { border-color: #{@p[:primary]} !important; }
      .border-t-n-brand { border-top-color: #{@p[:primary]} !important; }
      .border-n-blue-9, .border-n-blue-10, .border-n-blue-11 { border-color: #{@p[:primary]} !important; }
      .border-n-blue-border { border-color: rgba(#{@r}, #{@g}, #{@b}, 0.5) !important; }
      .border-n-blue-9\\/30 { border-color: rgba(#{@r}, #{@g}, #{@b}, 0.3) !important; }
      .border-blue-border { border-color: rgba(#{@r}, #{@g}, #{@b}, 0.5) !important; }
    CSS
  end

  def brand_fill_stroke_overrides
    <<~CSS
      .fill-n-blue-9, .fill-n-blue-10, .fill-n-blue-11 { fill: #{@p[:primary]} !important; }
      .stroke-n-blue-text, .stroke-n-blue-9 { stroke: #{@p[:primary]} !important; }
    CSS
  end

  def ring_outline_overrides
    <<~CSS
      .outline-n-blue-border { outline-color: rgba(#{@r}, #{@g}, #{@b}, 0.5) !important; }
      .outline-n-brand { outline-color: #{@p[:primary]} !important; }
    CSS
  end

  def hover_overrides
    <<~CSS
      .hover\\:bg-woot-500:hover, .hover\\:bg-woot-600:hover { background-color: #{@p[:woot_600]} !important; }
      .hover\\:bg-woot-700:hover { background-color: #{@p[:woot_700]} !important; }
      .hover\\:text-woot-500:hover, .hover\\:text-woot-600:hover { color: #{@p[:woot_600]} !important; }
      .hover\\:bg-brand:hover, .hover\\:bg-n-brand:hover { background-color: #{@p[:woot_600]} !important; }
      .hover\\:text-brand:hover, .hover\\:text-n-brand:hover { color: #{@p[:woot_600]} !important; }
      .hover\\:bg-n-blue-9:hover, .hover\\:bg-n-blue-10:hover { background-color: #{@p[:woot_600]} !important; }
      .hover\\:text-n-blue-9:hover, .hover\\:text-n-blue-10:hover { color: #{@p[:woot_600]} !important; }
      .hover\\:border-n-brand:hover { border-color: #{@p[:woot_600]} !important; }
      .group:hover .group-hover\\:text-n-brand { color: #{@p[:primary]} !important; }
      .group:hover .group-hover\\:bg-n-brand { background-color: #{@p[:primary]} !important; }
    CSS
  end

  def focus_overrides
    <<~CSS
      .focus\\:border-woot-500:focus, .focus\\:border-woot-600:focus { border-color: #{@p[:primary]} !important; }
      .focus\\:ring-woot-500:focus, .focus\\:ring-woot-600:focus { --tw-ring-color: #{@p[:primary]} !important; }
      .focus\\:outline-n-brand:focus, .dark .focus\\:outline-n-brand:focus { outline-color: #{@p[:primary]} !important; }
      .focus-visible\\:outline-n-brand:focus-visible { outline-color: #{@p[:primary]} !important; }
      .focus\\:bg-n-brand:focus { background-color: #{@p[:primary]} !important; }
      .focus\\:border-n-brand:focus { border-color: #{@p[:primary]} !important; }
      .active\\:bg-woot-500:active, .active\\:bg-woot-600:active { background-color: #{@p[:woot_700]} !important; }
      .active\\:bg-n-brand:active { background-color: #{@p[:woot_700]} !important; }
    CSS
  end

  def alpha_overrides
    <<~CSS
      .bg-n-brand\\/5 { background-color: rgba(#{@r}, #{@g}, #{@b}, 0.05) !important; }
      .bg-n-brand\\/10 { background-color: rgba(#{@r}, #{@g}, #{@b}, 0.1) !important; }
      .bg-n-brand\\/20 { background-color: rgba(#{@r}, #{@g}, #{@b}, 0.2) !important; }
      .bg-n-brand\\/30 { background-color: rgba(#{@r}, #{@g}, #{@b}, 0.3) !important; }
      .bg-n-blue-9\\/10 { background-color: rgba(#{@r}, #{@g}, #{@b}, 0.1) !important; }
      .bg-n-blue-9\\/20 { background-color: rgba(#{@r}, #{@g}, #{@b}, 0.2) !important; }
      .text-n-brand\\/80 { color: rgba(#{@r}, #{@g}, #{@b}, 0.8) !important; }
    CSS
  end

  def special_component_overrides
    <<~CSS
      .text-link { color: #{@p[:primary]} !important; }
      .text-link:hover { color: #{@p[:woot_600]} !important; }
      .banner.primary { background-color: #{@p[:primary]} !important; }
      .is-active { background-color: #{@p[:primary]} !important; }
      .woot-widget a:hover { color: #{@p[:primary]} !important; }
    CSS
  end

  def avatar_overrides
    <<~CSS
      span[style*="rgb(215, 238, 225)"] { background-color: #{@p[:woot_50]} !important; color: #{@p[:woot_700]} !important; }
      span[style*="rgb(195, 230, 210)"] { background-color: #{@p[:woot_100]} !important; color: #{@p[:woot_800]} !important; }
      span[style*="rgb(204, 243, 234)"] { background-color: #{@p[:woot_50]} !important; color: #{@p[:woot_700]} !important; }
      span[style*="color: rgb(16, 126, 68)"] { color: #{@p[:woot_700]} !important; }
      span[style*="color: rgb(13, 102, 54)"] { color: #{@p[:woot_800]} !important; }
      span[style*="color: rgb(0, 133, 115)"] { color: #{@p[:woot_700]} !important; }
    CSS
  end

  def form_overrides
    <<~CSS
      input:focus, textarea:focus, select:focus {
        outline-color: #{@p[:primary]} !important;
        border-color: #{@p[:primary]} !important;
        box-shadow: 0 0 0 3px rgba(#{@r}, #{@g}, #{@b}, 0.1) !important;
      }
      input[type="checkbox"]:checked, input[type="radio"]:checked {
        background-color: #{@p[:primary]} !important;
        border-color: #{@p[:primary]} !important;
      }
      input[type="checkbox"], input[type="radio"], select, input[type="date"], input[type="time"], input[type="range"] {
        accent-color: #{@p[:primary]} !important;
      }
    CSS
  end
end
