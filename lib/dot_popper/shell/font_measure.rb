# frozen_string_literal: true

module DotPopper
  module Shell
    # How tall a line is and how wide some words are in the game's own
    # fonts (FontBook), so the screens are laid out by the type they are
    # drawn in. Presentation::RoughMeasure has the same methods.
    class FontMeasure < Data.define(:fonts)
      def height(face, size) = fonts.public_send(face, size).height
      def width(face, size, text) = fonts.public_send(face, size).width(text)
    end
  end
end
