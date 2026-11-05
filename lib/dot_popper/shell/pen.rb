# frozen_string_literal: true

module DotPopper
  module Shell
    # What every painter draws with: the fonts, the shaders, a plain square
    # to draw shaders on, and the screen's device pixels for placing text
    # and the HUD crisply.
    class Pen
      G = ::Lota::Graphics
      SHADERS = %i[dot glow edge backdrop].freeze

      attr_reader :fonts, :look, :pixels

      def initialize(look)
        @look = look
        @fonts = FontBook.new(look::TYPE)
        @square = G::Image.new(::Lota::Image::ImageData.new(2, 2, :rgba8, ("\xFF".b * 16)))
        @shaders = SHADERS.to_h { [it, G::Shader.new("assets/shaders/#{it}.glsl")] }
        configure_dot_shader
        refresh
      end

      def palette = look::PALETTE

      # Reads the screen's size and density again, after a resize.
      def refresh
        @pixels = Presentation::Pixels.new(scale: G.dpi_scale)
        fonts.density = G.dpi_scale
      end

      def color(color, alpha = color.a) = G.color = [color.r, color.g, color.b, alpha]

      # A square of half sides +half_width+ and +half_height+ centred on
      # (+x+, +y+), for a shader to draw in.
      def square(x, y, half_width, half_height) = G.draw(@square, x, y, 0, half_width, half_height, 1, 1)

      def shading(name)
        G.shader = @shaders.fetch(name)
        yield @shaders.fetch(name)
      ensure
        G.shader = nil
      end

      def adding
        G.blend_mode = :add
        yield
      ensure
        G.blend_mode = :alpha
      end

      # +text+ centred on +x+ and +y+, on whole device pixels.
      def text(text, font, x, y, color, alpha = color.a)
        color(color, alpha)
        G.print(text, font, pixels.snap(x - (font.width(text) / 2.0)), pixels.snap(y - (font.height / 2.0)))
      end

      # A shader's uniform, if the shader uses it (a GPU compiler drops one
      # that does not count).
      def send(shader, name, value) = shader.uniform?(name) && shader.send(name, value)

      def rgb(color) = [color.r, color.g, color.b]

      private

      def configure_dot_shader
        shader = @shaders[:dot]
        dot = look::DOT
        { "extent" => dot.extent, "shadow_offset" => dot.shadow_offset, "shadow_alpha" => dot.shadow_alpha,
          "halo_alpha" => dot.halo_alpha }.each { |name, value| send(shader, name, value) }
        %i[fresh_light fresh_body fresh_deep fresh_bounce gloss halo popped_top popped_bottom popped_rim
           popped_crater popped_lip shadow alarm].each { send(shader, it.to_s, rgb(palette.public_send(it))) }
        backdrop = @shaders[:backdrop]
        %i[ink_top ink_bottom ink_glow ink_edge].each { send(backdrop, it.to_s, rgb(palette.public_send(it))) }
      end
    end
  end
end
