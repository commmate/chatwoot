class BrandColorService::ColorMath
  class << self
    def hex_to_rgb(hex_str)
      [hex_str[0..1], hex_str[2..3], hex_str[4..5]].map { |component| component.to_i(16) }
    end

    def hex_to_hsl(hex_str)
      rgb_to_hsl(*hex_to_rgb(hex_str))
    end

    def rgb_to_hsl(red, green, blue)
      red /= 255.0
      green /= 255.0
      blue /= 255.0
      max = [red, green, blue].max
      min = [red, green, blue].min
      lum = (max + min) / 2.0

      return [0.0, 0.0, lum] if max == min

      delta = max - min
      sat = lum > 0.5 ? delta / (2.0 - max - min) : delta / (max + min)
      hue = compute_hue(red, green, blue, max, delta)

      [(hue / 6.0) * 360, sat, lum]
    end

    def hsl_to_rgb(hue, sat, lum)
      hue /= 360.0
      return Array.new(3, (lum * 255).round) if sat.zero?

      q_val = lum < 0.5 ? lum * (1 + sat) : (lum + sat) - (lum * sat)
      p_val = (2 * lum) - q_val

      [
        (hue_to_channel(p_val, q_val, hue + (1.0 / 3)) * 255).round,
        (hue_to_channel(p_val, q_val, hue) * 255).round,
        (hue_to_channel(p_val, q_val, hue - (1.0 / 3)) * 255).round
      ]
    end

    def hsl_to_hex(hue, sat, lum)
      red, green, blue = hsl_to_rgb(hue, sat, lum)
      format('#%<red>02x%<green>02x%<blue>02x', red: red, green: green, blue: blue)
    end

    def offset_rgb_string(hex_color, offset = 0)
      red, green, blue = hex_to_rgb(hex_color.delete_prefix('#'))
      if offset != 0
        red = (red + offset).clamp(0, 255)
        green = (green + offset).clamp(0, 255)
        blue = (blue + offset).clamp(0, 255)
      end
      "#{red} #{green} #{blue}"
    end

    private

    def compute_hue(red, green, blue, max, delta)
      case max
      when red   then ((green - blue) / delta) + (green < blue ? 6 : 0)
      when green then ((blue - red) / delta) + 2
      when blue  then ((red - green) / delta) + 4
      end
    end

    def hue_to_channel(p_val, q_val, tone)
      tone += 1 if tone.negative?
      tone -= 1 if tone > 1
      return p_val + ((q_val - p_val) * 6 * tone) if tone < (1.0 / 6)
      return q_val if tone < 0.5
      return p_val + ((q_val - p_val) * ((2.0 / 3) - tone) * 6) if tone < (2.0 / 3)

      p_val
    end
  end
end
