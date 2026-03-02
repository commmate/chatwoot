class BrandColorService
  attr_reader :hex

  def initialize(hex_color)
    @hex = hex_color.to_s.strip.delete_prefix('#')
  end

  def valid?
    hex.match?(/\A[0-9a-fA-F]{6}\z/)
  end

  def generate_css
    palette = build_palette
    [
      RootCssBuilder.new(palette, ColorMath.hex_to_rgb(palette[:primary_dark].delete_prefix('#'))).build,
      DarkModeCssBuilder.new(palette).build,
      TailwindOverridesCssBuilder.new(palette).build
    ].join("\n")
  end

  private

  def build_palette
    hue, sat, lum = ColorMath.hex_to_hsl(hex)
    red, green, blue = ColorMath.hex_to_rgb(hex)

    base_colors(hue, sat, lum).merge(
      ramp: build_blue_ramp(hue, sat, lum),
      red: red, green: green, blue: blue
    )
  end

  def base_colors(hue, sat, lum)
    {
      primary: "##{hex}",
      **primary_shades(hue, sat, lum),
      **secondary_shades(hue, sat, lum),
      **tertiary_shades(hue, sat, lum),
      **quaternary_shades(hue, sat, lum)
    }
  end

  def primary_shades(hue, sat, lum)
    {
      primary_dark: ColorMath.hsl_to_hex(hue, sat, (lum - 0.08).clamp(0.05, 0.95)),
      primary_light: ColorMath.hsl_to_hex(hue, sat, (lum + 0.08).clamp(0.05, 0.95))
    }
  end

  def secondary_shades(hue, sat, lum)
    shifted = (hue + 10) % 360
    {
      secondary: ColorMath.hsl_to_hex(shifted, sat, (lum + 0.05).clamp(0.05, 0.90)),
      secondary_dark: ColorMath.hsl_to_hex(shifted, sat, lum),
      secondary_light: ColorMath.hsl_to_hex(shifted, sat, (lum + 0.12).clamp(0.05, 0.90))
    }
  end

  def tertiary_shades(hue, sat, lum)
    shifted = (hue + 25) % 360
    desat = (sat - 0.05).clamp(0.1, 1.0)
    {
      tertiary: ColorMath.hsl_to_hex(shifted, desat, (lum + 0.18).clamp(0.05, 0.90)),
      tertiary_dark: ColorMath.hsl_to_hex(shifted, desat, (lum + 0.10).clamp(0.05, 0.85)),
      tertiary_light: ColorMath.hsl_to_hex(shifted, desat, (lum + 0.25).clamp(0.05, 0.90))
    }
  end

  def quaternary_shades(hue, sat, lum)
    shifted = (hue + 40) % 360
    desat = (sat - 0.10).clamp(0.1, 1.0)
    {
      quaternary: ColorMath.hsl_to_hex(shifted, desat, (lum + 0.30).clamp(0.05, 0.90)),
      quaternary_dark: ColorMath.hsl_to_hex(shifted, desat, (lum + 0.22).clamp(0.05, 0.85)),
      quaternary_light: ColorMath.hsl_to_hex(shifted, desat, (lum + 0.38).clamp(0.05, 0.92))
    }
  end

  def build_blue_ramp(hue, sat, lum)
    [0.97, 0.94, 0.90, 0.84, 0.76, 0.66, 0.55, lum + 0.15].map do |target|
      rgb = ColorMath.hsl_to_rgb(hue, (sat * 0.3).clamp(0.05, 1.0), target.clamp(0.05, 0.97))
      "#{rgb[0]} #{rgb[1]} #{rgb[2]}"
    end
  end
end
