# frozen_string_literal: true

module DotPopper
  module Shell
    # The soft light that fresh dots and droplets cast on the night
    # around them. What glows is drawn into a canvas at the screen's full
    # resolution, then blurred each way with the blur shader into two
    # smaller canvases, which is cheap and costs nothing in sharpness,
    # since a blur is soft anyway. The result is added to the screen
    # before the dots are drawn, straight to the screen and never scaled,
    # so the light falls on the night and never on a dot. No text is ever
    # drawn into it.
    #
    # It is optional: without the blur shader (DOT_POPPER_NO_SHADERS=1
    # included), or a canvas, or with no strength in the look, #glow
    # draws nothing and the game looks as it did without it.
    class Bloom
      G = ::Lota::Graphics

      def initialize(pen, style)
        @pen = pen
        @style = style
        @kernel = style.kernel
        refresh
      end

      def on? = !@source.nil?

      # Makes the canvases again, for the screen's size and density now.
      def refresh
        @source = @across = @down = nil
        return unless @style.strength.positive? && @pen.shader?(:blur)

        width, height = G.dimensions
        density = G.dpi_scale
        @source = G::Canvas.new(width, height, dpiscale: density)
        blurred_width, = @style.blurred_size(*G.pixel_dimensions)
        smaller = blurred_width.to_f / width
        @across = G::Canvas.new(width, height, dpiscale: smaller)
        @down = G::Canvas.new(width, height, dpiscale: smaller)
      rescue StandardError => e
        warn "Dot Popper: drawing without the glow (#{e.message})"
        @source = @across = @down = nil
      end

      # Draws the block, what glows, into the glow, and adds the glow over
      # the screen, +fade+ of the way to full strength.
      def glow(fade = 1.0, &)
        return unless on?

        G.push(:all) do
          G.origin
          into(@source, &)
          @style.passes.times do |pass|
            blur(pass.zero? ? @source : @down, @across, [1.0 / @across.pixel_width, 0.0])
            blur(@across, @down, [0.0, 1.0 / @down.pixel_height])
          end
          G.canvas = nil
          G.shader = nil
          G.blend_mode = %i[add premultiplied]
          G.color = [@style.strength * fade] * 4
          G.draw(@down, 0, 0)
        end
      end

      private

      def into(canvas)
        G.canvas = canvas
        G.clear(0, 0, 0, 0)
        yield
      end

      def blur(from, to, step)
        into(to) do
          @pen.shading(:blur) do |shader|
            @pen.uniform(shader, "texel_step", step)
            shader.send("offsets", *@kernel.offsets) if shader.uniform?("offsets")
            shader.send("weights", *@kernel.weights) if shader.uniform?("weights")
            G.blend_mode = %i[replace premultiplied]
            G.color = [1, 1, 1, 1]
            G.draw(from, 0, 0)
          end
        end
      end
    end
  end
end
