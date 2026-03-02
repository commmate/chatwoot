class BrandColorService::DarkModeCssBuilder
  def initialize(palette)
    @pal = palette
  end

  def build
    prim_rgb = rgb_str(@pal[:primary_light])
    sec_rgb = rgb_str(@pal[:secondary_light])
    tert_rgb = rgb_str(@pal[:tertiary_light])
    solid = dark_solid_rgb(@pal[:tertiary])

    <<~CSS
      .dark {
        --color-primary: #{@pal[:primary_light]};
        --color-secondary: #{@pal[:secondary_light]};
        --color-tertiary: #{@pal[:tertiary_light]};
        --blue-9: #{prim_rgb};
        --blue-10: #{sec_rgb};
        --blue-11: #{tert_rgb};
        --text-blue: #{tert_rgb};
        --solid-blue: #{solid};
        accent-color: #{@pal[:tertiary]};
      }
    CSS
  end

  private

  def rgb_str(hex_color)
    red, green, blue = BrandColorService::ColorMath.hex_to_rgb(hex_color.delete_prefix('#'))
    "#{red} #{green} #{blue}"
  end

  def dark_solid_rgb(hex_color)
    red, green, blue = BrandColorService::ColorMath.hex_to_rgb(hex_color.delete_prefix('#'))
    "#{red / 4} #{green / 4} #{blue / 4}"
  end
end
