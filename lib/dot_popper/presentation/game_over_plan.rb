# frozen_string_literal: true

module DotPopper
  module Presentation
    # One of Game Over's short lines in a pill of its own: today's goal
    # met, a new achievement, or a friend group's title. +name+ is the
    # control it is when +opens+ (:over_achievement or :over_group), and
    # +glyph+ the mark before its words (:check, :achievement, :crown).
    class GameOverChip < Data.define(:name, :text, :glyph, :opens); end

    # Where Game Over's parts go, worked out by GameOverScreen#plan: each
    # block's Rect by name (Stacked), the font size each is set in, the
    # backing behind the result, and Play again, Home and Share my score.
    # A line the screen had no room for, or that is not shown, has no
    # Rect.
    class GameOverPlan < Data.define(:placed, :sizes, :backing, :home, :share)
      def [](name) = placed[name]
      def size(name) = sizes.fetch(name)
      def play_button = placed[:play_again]
      def home_button = home
      def share_button = share
    end

    # Game Over, read top down: "Time's up!", the score, a new record or
    # how far short of it the game fell, the game's facts (Words.facts),
    # in a row or, short of room across, one under another, a record it
    # set, then its +chips+ (GameOverChip), each a line of its own, then
    # Play again, as big as Layout's primary_size for dots of +radius+, with
    # +play_note+ under its word, and Home beside Share my score. Short of
    # room, the type shrinks first; then the record goes, the facts, the
    # chips, the best and "Time's up!". The score and the buttons always
    # stay. A short window held sideways puts the result on the left and
    # the rest on the right. Nothing goes lower than the middle of the
    # pile's bottom row, a radius above the window's floor, so the pile
    # still shows. Sizes are measured with +measure+ (RoughMeasure's
    # methods).
    class GameOverScreen < Data.define(:layout, :type, :words, :measure, :scrim, :game_over, :below, :radius, :chips,
                                       :play_word, :play_note)
      # The gaps above each line, in graphics units at full size.
      GAPS = { heading: 26, score: 4, score_record: 4, summary: 14, fact: 4, record: 8, chip: 10, play_again: 34, buttons: 14 }.freeze
      # A fact's sign and the room after it, and the room between facts, in
      # the height of their type (Words.facts).
      FACT_SIGN = 1.0
      FACT_GAP = 0.3
      FACTS_APART = 1.1
      FACTS_LARGER = 3 # the facts' type over the summary's, as the mocks set their numbers
      # A chip's height and its words' size, in units at full size.
      CHIP = 38.0
      CHIP_TEXT = 15
      # Share my score's glyph and the room around its words, in the
      # button's height (Shell::ShareButton).
      SHARE_GLYPH = 0.45
      SHARE_SIDES = 1.1

      def initialize(layout:, type:, words:, measure:, scrim:, game_over:, below:, radius: Rules::RADIUS, chips: [], play_word: "Play again",
                     play_note: nil)
        super
      end

      def plan
        layout.short? ? sideways : upright
      end

      # From under the HUD to a margin above the safe area's bottom, or to
      # the middle of the pile's bottom row, if that is higher.
      def room
        margin = layout.margin
        safe = layout.safe
        top = below + margin
        bottom = [safe.bottom - margin, layout.height - radius].min
        Rect.new(x: safe.x + margin, y: top, width: safe.width - (2 * margin), height: bottom - top)
      end

      # The best line's face and size, and what it says.
      def score_record_line(size)
        if game_over.new_score_record? then [:bold, size, words.new_score_record]
        else [:semibold, size, words.short_of_score_record(game_over.score, game_over.score_record, first: game_over.first)]
        end
      end

      # How wide one fact is, its sign and its number, in type +size+.
      def fact_width(text, size) = (measure.height(:bold, size) * (FACT_SIGN + FACT_GAP)) + measure.width(:bold, size, text)

      # How wide the facts are in one row, in type +size+.
      def facts_width(size)
        facts = Words.facts(game_over.stats)
        facts.sum { fact_width(it.last, size) } + (measure.height(:bold, size) * FACTS_APART * (facts.size - 1))
      end

      # The size a chip's words are set in, at type +scale+.
      def chip_size(scale = 1.0) = [(CHIP_TEXT * scale).round, 12].max

      # How wide a chip is for its words: room for its mark, its words,
      # and its arrow when it opens something.
      def chip_width(chip, scale = 1.0)
        height = chip_height(scale)
        measure.width(:semibold, chip_size(scale), chip.text) + (height * (chip.opens ? 1.9 : 1.4))
      end

      def chip_height(scale = 1.0) = [CHIP * scale, 30.0].max

      # The size Share my score's words are set in, on a button +height+ tall.
      def self.share_size(height) = (height * PillLabel::RATIO).round

      private

      def upright
        placed = Column.new(room:).fit(layout.type_scales) { result(sizes(it), it) + rest(it) }
        finish(placed)
      end

      # The result on the left, the rest on the right, each a column of
      # its own, with a shared type scale.
      def sideways
        whole = room
        gap = layout.margin
        split = lambda do |scale|
          widest = result(sizes(scale), scale).map(&:width).max
          left = whole.with(width: widest.clamp(whole.width * 0.38, whole.width * 0.5))
          [left, whole.with(x: left.right + gap, width: whole.right - left.right - gap)]
        end
        scale = layout.type_scales.find do |each|
          left, right = split.(each)
          blocks = result(sizes(each), each)
          Column.new(room: left).fits?(blocks) && blocks.all? { |block| block.width <= left.width } && Column.new(room: right).fits?(rest(each, right.width))
        end
        scale ||= layout.type_scales.last
        left, right = split.(scale)
        one = Column.new(room: left).fit([scale]) { result(sizes(it), it) }
        two = Column.new(room: right).fit([scale]) { rest(it, right.width) }
        finish(Stacked.new(scale:, rects: one.rects.merge(two.rects), fits: one.fits? && two.fits?))
      end

      def finish(placed)
        sizes = sizes(placed.scale)
        home, share = buttons(placed[:buttons])
        GameOverPlan.new(placed:, sizes: sizes.merge(chip: chip_size(placed.scale)), backing: backing(placed), home:, share:)
      end

      # "Time's up!", the score, and the best line.
      def result(sizes, scale)
        [line(:heading, :bold, sizes[:heading], words.time_up, scale, drop: 6),
         line(:score, :bold, sizes[:score], game_over.score.to_s, scale, depth: 1.06),
         line(:score_record, *score_record_line(sizes[:score_record]), scale, drop: 5)]
      end

      # The facts, a record, the chips, Play again, and Home with Share my
      # score.
      def rest(scale, across = room.width)
        sizes = sizes(scale)
        [*facts(sizes[:facts], scale, across),
         (line(:record, :semibold, sizes[:summary], words.record(game_over.record), scale, drop: 2) if game_over.record),
         *chips.each_with_index.map { |chip, i| chip_block(chip, i, scale, across) },
         play_again(scale, across),
         buttons_block(scale, across)].compact.reject { it.width > across + 1e-6 } # a line too wide for the room is left out
      end

      # The facts in one row, :summary; or where the row is too wide for
      # the room, one under another, [:fact, 0] and on.
      def facts(size, scale, across)
        height = measure.height(:bold, size)
        row = facts_width(size)
        return [Block.new(name: :summary, height:, width: row, gap: gap(:summary, scale), drop: 3)] if row <= across

        Words.facts(game_over.stats).each_with_index.map do |(_, text), i|
          Block.new(name: [:fact, i], height:, width: fact_width(text, size), gap: gap(i.zero? ? :summary : :fact, scale), drop: 3)
        end
      end

      def chip_block(chip, index, scale, across)
        Block.new(name: [:chip, index], height: chip_height(scale), width: [chip_width(chip, scale), across].min, gap: gap(:chip, scale),
                  drop: 4 - (index * 0.1))
      end

      # A line of +text+, and for the candy's extruded copy under it,
      # +depth+ of its height.
      def line(name, face, size, text, scale, drop: nil, depth: 1.0)
        Block.new(name:, height: measure.height(face, size) * depth, gap: gap(name, scale), width: measure.width(face, size, text), drop:)
      end

      # Play again, as big as a main button is, whatever the type's scale.
      # Play again, as tall as Home's Play at full size, and never less
      # than a main button is (Layout#primary_size).
      def play_again(scale, across)
        width, least = layout.primary_size(radius)
        height = [least, (layout.phone? ? 100.0 : 104.0) * scale].max
        Block.new(name: :play_again, height:, width: [[width, 560.0].max, across].min, gap: gap(:play_again, scale))
      end

      # Home and Share my score side by side, each as wide as its words.
      def buttons_block(scale, across)
        widths = button_widths
        Block.new(name: :buttons, height: layout.control_height, width: [widths.sum + gap_between, across].min, gap: gap(:buttons, scale))
      end

      def gap_between = 10.0

      def button_widths
        height = layout.control_height
        size = (height * PillLabel::RATIO).round
        [words.button(:home), words.share].map { PillLabel.width_with_icon(measure.width(:semibold, size, it), height) }
      end

      # Home's and Share my score's Rects in the row +row+ gives them.
      def buttons(row)
        return [nil, nil] unless row

        widths = button_widths
        scale = [(row.width - gap_between) / widths.sum, 1.0].min
        home = row.with(width: widths[0] * scale)
        [home, row.with(x: home.right + gap_between, width: widths[1] * scale)]
      end

      def gap(name, scale) = GAPS.fetch(name) * layout.ui * scale

      def sizes(scale)
        size = ->(nominal) { layout.type_size(nominal, scale) }
        { heading: size[type.heading], score: size[type.final_score],
          score_record: size[game_over.new_score_record? ? type.new_score_record : type.score_record], summary: size[type.summary],
          facts: size[type.summary + FACTS_LARGER] }
      end

      # Around the result and its lines, short of Play again, and never
      # past the safe area once padded.
      def backing(placed)
        kept = placed.rects.except(:play_again, :buttons)
        bounds = placed.with(rects: kept).bounds or return
        edge = (scrim.pad + scrim.feather) * layout.ui
        bounds.cut(left: layout.safe.x + edge, right: layout.safe.right - edge)
      end
    end
  end
end
