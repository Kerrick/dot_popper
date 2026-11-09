# frozen_string_literal: true

module DotPopper
  module Shell
    # What every painter draws with: the fonts, the pointing hand's
    # pictures, the shaders, a plain square to draw shaders on, and the
    # screen's device pixels for placing text and the HUD crisply.
    #
    # Every shader is optional. One that will not compile on this GPU, or
    # all of them with DOT_POPPER_NO_SHADERS=1, is left out with a warning,
    # and the painters draw that part with plain shapes instead.
    class Pen
      G = ::Lota::Graphics
      SHADERS = %i[dot edge backdrop blur].freeze

      attr_reader :fonts, :style, :pixels, :hands

      def initialize(style, shaders: true)
        @style = style
        @palette = style::PALETTE
        @fonts = FontBook.new(style::TYPE)
        @hands = HandSprites.new
        @square = G::Image.new(::Lota::Image::ImageData.new(2, 2, :rgba8, ("\xFF".b * 16)))
        @shaders = shaders ? SHADERS.to_h { [it, compile(it)] }.compact : {}
        warn "Dot Popper: drawing without shaders" if @shaders.empty?
        configure
        refresh
      end

      attr_reader :palette

      # Puts on the look whose colors are +palette+ (Presentation::Wardrobe):
      # the shaders are given its colors and the hover's lit colors follow
      # it. Says whether it was a change, so the caller can redraw what it
      # keeps, such as the clear color. A palette already worn changes nothing.
      def wear(palette)
        return false if palette.equal?(@palette)

        @palette = palette
        @lit = nil
        paint_shaders
        true
      end

      # What a button the mouse is over is lit with (Presentation::HoverLook):
      # the night's glow behind it and cream around it, in the worn palette.
      def lit
        @lit ||= style::HOVER.with(fill: palette.ink_glow.with_alpha(style::HOVER.fill.a), edge: palette.cream)
      end

      # +color+ as the worn palette has it: one of the ordinary palette's
      # colors, which Look gives to rings and flashes, becomes the worn
      # palette's color for the same job; any other color stays.
      def themed(color)
        ordinary = style::PALETTE.to_h
        job = ordinary.key(color)
        job ? palette.public_send(job) : color
      end

      # Reads the screen's size and density again, after a resize.
      def refresh
        @pixels = Presentation::Pixels.new(scale: G.dpi_scale)
        fonts.density = G.dpi_scale
        fonts.forget
      end

      def color(color, alpha = color.a) = G.color = [color.r, color.g, color.b, alpha]

      # A square of half sides +half_width+ and +half_height+ centred on
      # (+x+, +y+), for a shader to draw in.
      def square(x, y, half_width, half_height) = G.draw(@square, x, y, 0, half_width, half_height, 1, 1)

      def shader?(name) = @shaders.key?(name)

      # Draws the block with the shader +name+, which it is given. Only
      # call this when shader?(name).
      def shading(name)
        shader = @shaders.fetch(name)
        G.shader = shader
        yield shader
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

      # +text+ as #text draws it, ringed by a soft dark outline, so it reads
      # over a light dot or a dark one. The outline is copies of the text
      # moved by whole device pixels.
      def outlined(text, font, x, y, color, alpha = color.a)
        reach = [(font.height * 0.05 * pixels.scale).round, 1].max / pixels.scale
        [[-reach, 0], [reach, 0], [0, -reach], [0, reach], [0, reach * 2]].each do |dx, dy|
          text(text, font, x + dx, y + dy, palette.shadow, alpha * 0.7)
        end
        text(text, font, x, y, color, alpha)
      end

      # A shader's uniform, if the shader uses it (a GPU compiler drops one
      # that does not count).
      def uniform(shader, name, value) = shader.uniform?(name) && shader.send(name, value)

      def rgb(color) = [color.r, color.g, color.b]

      private

      def compile(name)
        G::Shader.new("assets/shaders/#{name}.glsl")
      rescue StandardError => e
        warn "Dot Popper: drawing #{name} without its shader (#{e.message.lines.first&.strip})"
        nil
      end

      def configure
        if (dot = @shaders[:dot])
          style::DOT.to_h.except(:legend).each { |name, value| uniform(dot, name.to_s, value) }
        end
        paint_shaders
      end

      # Gives the shaders the worn palette's colors.
      def paint_shaders
        if (dot = @shaders[:dot])
          %i[fresh_light fresh_body fresh_deep fresh_bounce fresh_rim gloss halo popped_top popped_bottom popped_rim
             popped_crater popped_lip shadow alarm bonus_light bonus_body bonus_deep bonus_bounce bonus_rim bonus_mark].each { uniform(dot, it.to_s, rgb(palette.public_send(it))) }
        end
        return unless (backdrop = @shaders[:backdrop])

        %i[ink_top ink_bottom ink_glow ink_edge].each { uniform(backdrop, it.to_s, rgb(palette.public_send(it))) }
      end
    end
  end
end
