class BrandColorService::RootCssBuilder
  def initialize(palette, dark_rgb)
    @pal = palette
    @dark_rgb = dark_rgb
  end

  def build
    <<~CSS
      :root {
      #{color_variables}
      #{brand_variables}
      #{blue_ramp_variables}
      #{blue_shade_variables}
      #{iris_and_text_variables}
        accent-color: #{@pal[:primary]};
      }
    CSS
  end

  private

  def color_variables
    <<~CSS.chomp
      --color-primary: #{@pal[:primary]};
      --color-primary-dark: #{@pal[:primary_dark]};
      --color-primary-light: #{@pal[:primary_light]};
      --color-secondary: #{@pal[:secondary]};
      --color-secondary-dark: #{@pal[:secondary_dark]};
      --color-secondary-light: #{@pal[:secondary_light]};
      --color-tertiary: #{@pal[:tertiary]};
      --color-tertiary-dark: #{@pal[:tertiary_dark]};
      --color-tertiary-light: #{@pal[:tertiary_light]};
      --color-quaternary: #{@pal[:quaternary]};
      --color-quaternary-dark: #{@pal[:quaternary_dark]};
      --color-quaternary-light: #{@pal[:quaternary_light]};
    CSS
  end

  def brand_variables
    <<~CSS.chomp
      --brand-primary: var(--color-primary);
      --brand-secondary: var(--color-secondary);
    CSS
  end

  def blue_ramp_variables
    ramp = @pal[:ramp]
    (0..7).map { |idx| "    --blue-#{idx + 1}: #{ramp[idx]};" }.join("\n")
  end

  def blue_shade_variables
    dark_str = "#{@dark_rgb[0]} #{@dark_rgb[1]} #{@dark_rgb[2]}"
    dark_m20 = BrandColorService::ColorMath.offset_rgb_string(@pal[:primary_dark], -20)
    dark_m40 = BrandColorService::ColorMath.offset_rgb_string(@pal[:primary_dark], -40)
    rgb = primary_rgb_str

    <<~CSS.chomp
      --blue-9: #{rgb};
      --blue-10: #{dark_str};
      --blue-11: #{dark_m20};
      --blue-12: #{dark_m40};
    CSS
  end

  def iris_and_text_variables
    dark_str = "#{@dark_rgb[0]} #{@dark_rgb[1]} #{@dark_rgb[2]}"
    dark_m20 = BrandColorService::ColorMath.offset_rgb_string(@pal[:primary_dark], -20)
    rgb = primary_rgb_str

    <<~CSS.chomp
      --iris-9: #{rgb};
      --iris-10: #{dark_str};
      --iris-11: #{dark_m20};
      --text-blue: #{rgb};
      --border-blue: #{@pal[:red]}, #{@pal[:green]}, #{@pal[:blue]}, 0.5;
      --solid-blue: #{@pal[:ramp][3]};
    CSS
  end

  def primary_rgb_str
    "#{@pal[:red]} #{@pal[:green]} #{@pal[:blue]}"
  end
end
