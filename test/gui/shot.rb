# frozen_string_literal: true

module DotPopperGui
  # A screenshot of the window, read in graphics units, as the game
  # draws: Lota captures device pixels, which may be two or more to a
  # unit on a high-density display.
  class Shot
    def initialize(image, width, height)
      @image = image
      @scale_x = image.width.to_f / width
      @scale_y = image.height.to_f / height
    end

    # The colour at +x+, +y+, as [red, green, blue] from 0 to 1.
    def color(x, y)
      px = (x * @scale_x).floor.clamp(0, @image.width - 1)
      py = (y * @scale_y).floor.clamp(0, @image.height - 1)
      @image.pixel(px, py).first(3)
    end

    def lightness(x, y) = lightness_of(color(x, y))

    # A fresh dot's body is light and warm, red over blue (Look::PALETTE's
    # fresh colours); the night behind the dots and a popped dot are dark
    # and cool.
    def fresh?(x, y)
      red, green, blue = color(x, y)
      red > 0.75 && green > 0.45 && red - blue > 0.2
    end

    # Whether +x+, +y+ is warm, red over blue, as a fresh dot is even when
    # dimmed.
    def warm?(x, y)
      red, _, blue = color(x, y)
      red - blue > 0.03
    end

    # How many points of +rect+ (a Presentation::Rect), sampled every
    # device pixel or two, are light, as words drawn in cream are.
    def lit_in(rect)
      points(rect).count { lightness(*it) > 0.7 }
    end

    def describe(x, y) = format("rgb %.2f %.2f %.2f", *color(x, y))

    private

    def lightness_of(rgb) = (0.2126 * rgb[0]) + (0.7152 * rgb[1]) + (0.0722 * rgb[2])

    def points(rect)
      step = 1.0
      xs = (rect.x...rect.right).step(step).to_a
      ys = (rect.y...rect.bottom).step(step).to_a
      xs.product(ys)
    end
  end
end
