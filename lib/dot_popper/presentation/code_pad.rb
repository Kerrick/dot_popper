# frozen_string_literal: true

module DotPopper
  module Presentation
    # A key on a CodePad, or any other button a code's screen offers:
    # +name+ is what Show#tap hears and +text+ the key's word.
    class CodeKey < Data.define(:name, :rect, :text); end

    # A telephone's keypad inside +rect+: 1 to 9 in threes, then Erase, 0
    # and +submit+ (the word on the key that sends the code). Every code in
    # the game is tapped on one, so a phone needs no keyboard and nothing
    # is ever typed. Keys stay a thumb's height where +rect+ allows it.
    class CodePad < Data.define(:rect, :gap, :key_height, :erase, :submit)
      DIGITS = %w[1 2 3 4 5 6 7 8 9].freeze
      ROWS = 4
      COLUMNS = 3

      # The height a pad of keys +key_height+ tall takes up.
      def self.height(key_height, gap) = (key_height * ROWS) + (gap * (ROWS - 1))

      def keys
        [*DIGITS.each_with_index.map { |digit, i| key([:code_digit, digit], digit, i % COLUMNS, i / COLUMNS) },
         key(:code_erase, erase, 0, 3), key([:code_digit, "0"], "0", 1, 3), key(:code_submit, submit, 2, 3)]
      end

      private

      def width = (rect.width - (gap * (COLUMNS - 1))) / COLUMNS
      def height = [key_height, (rect.height - (gap * (ROWS - 1))) / ROWS].min

      def key(name, text, column, row)
        CodeKey.new(name:, text:, rect: Rect.new(x: rect.x + ((width + gap) * column), y: rect.y + ((height + gap) * row), width:, height:))
      end
    end

    # The digits of a code so far, as a player reads them: in groups, with
    # a dash for each digit still to come.
    module CodeText
      module_function

      def of(code, length, group: length)
        (code + ("-" * (length - code.size))).chars.each_slice(group).map(&:join).join(" ")
      end
    end
  end
end
