class BrandColorService::TailwindOverridesCssBuilder
  def initialize(palette)
    @primary = palette[:primary]
    @secondary = palette[:secondary]
    @red = palette[:red]
    @green = palette[:green]
    @blue = palette[:blue]
  end

  def build
    [
      background_overrides,
      text_overrides,
      border_overrides,
      ring_overrides,
      hover_overrides,
      focus_overrides,
      alpha_overrides,
      form_overrides
    ].join("\n")
  end

  private

  def background_overrides
    <<~CSS
      .bg-woot-500, .bg-woot-600 { background-color: #{@primary} !important; }
      .bg-n-blue-9, .bg-n-blue-10, .bg-n-blue-11 { background-color: #{@primary} !important; }
      .bg-brand, .bg-n-brand { background-color: #{@primary} !important; }
    CSS
  end

  def text_overrides
    <<~CSS
      .text-woot-500, .text-woot-600 { color: #{@primary} !important; }
      .text-n-blue-9, .text-n-blue-10, .text-n-blue-11 { color: #{@primary} !important; }
      .text-blue-text, .text-n-blue-text { color: #{@primary} !important; }
      .text-brand, .text-n-brand { color: #{@primary} !important; }
    CSS
  end

  def border_overrides
    <<~CSS
      .border-woot-500, .border-woot-600 { border-color: #{@primary} !important; }
      .border-n-blue-9, .border-n-blue-10, .border-n-blue-11 { border-color: #{@primary} !important; }
      .border-blue-border { border-color: rgba(#{@red}, #{@green}, #{@blue}, 0.5) !important; }
      .border-brand, .border-n-brand { border-color: #{@primary} !important; }
    CSS
  end

  def ring_overrides
    <<~CSS
      .ring-woot-500, .ring-woot-600 { --tw-ring-color: #{@primary} !important; }
    CSS
  end

  def hover_overrides
    <<~CSS
      .hover\\:bg-woot-500:hover, .hover\\:bg-woot-600:hover { background-color: #{@secondary} !important; }
      .hover\\:text-woot-500:hover, .hover\\:text-woot-600:hover { color: #{@secondary} !important; }
      .hover\\:bg-brand:hover, .hover\\:bg-n-brand:hover { background-color: #{@secondary} !important; }
      .hover\\:text-brand:hover, .hover\\:text-n-brand:hover { color: #{@secondary} !important; }
    CSS
  end

  def focus_overrides
    <<~CSS
      .focus\\:border-woot-500:focus, .focus\\:border-woot-600:focus { border-color: #{@primary} !important; }
      .focus\\:ring-woot-500:focus, .focus\\:ring-woot-600:focus { --tw-ring-color: #{@primary} !important; }
      .focus\\:outline-n-brand:focus, .dark .focus\\:outline-n-brand:focus { outline-color: #{@primary} !important; }
      .outline-n-blue-border { outline-color: rgba(#{@red}, #{@green}, #{@blue}, 0.5) !important; }
    CSS
  end

  def alpha_overrides
    <<~CSS
      .bg-n-brand\\/10 { background-color: rgba(#{@red}, #{@green}, #{@blue}, 0.1) !important; }
      .bg-n-brand\\/20 { background-color: rgba(#{@red}, #{@green}, #{@blue}, 0.2) !important; }
    CSS
  end

  def form_overrides
    <<~CSS
      input:focus, textarea:focus, select:focus {
        outline-color: #{@primary} !important;
        border-color: #{@primary} !important;
        box-shadow: 0 0 0 3px rgba(#{@red}, #{@green}, #{@blue}, 0.1) !important;
      }
      input[type="checkbox"]:checked, input[type="radio"]:checked {
        background-color: #{@primary} !important;
        border-color: #{@primary} !important;
      }
      input[type="checkbox"], input[type="radio"], select, input[type="date"], input[type="time"], input[type="range"] {
        accent-color: #{@primary} !important;
      }
    CSS
  end
end
