# frozen_string_literal: true

module DotPopper
  module Presentation
    # How tall a line of type is and how wide some words are in it, in
    # graphics units, without drawing them: the size of every font the
    # screens lay out. A face is :bold or :semibold and a size is whole
    # graphics units. Shell::FontMeasure measures with the real fonts;
    # this one guesses from the size, near enough Fredoka's, for tests
    # and for a Show with no window.
    class RoughMeasure
      LINE = 1.23 # a line's height, in its size
      LETTER = { bold: 0.56, semibold: 0.53 }.freeze # a letter's average width, in its size

      def height(_face, size) = size * LINE
      def width(face, size, text) = text.length * size * LETTER.fetch(face)
    end
  end
end
