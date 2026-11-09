# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where Game Over's words go, worked out by FinaleScreen#plan: each
    # line's Rect by name (Stacked), the font size each is set in, and the
    # backing behind them all.
    # A line the screen had no room for, or that is not shown, has no
    # Rect; Continue is the Rect named :continue, and "Share my score" the
    # one named :share.
    class FinalePlan < Data.define(:placed, :sizes, :backing)
      def [](name) = placed[name]
      def size(name) = sizes.fetch(name)
      def share_button = placed[:share]
      def continue_button = placed[:continue]
    end

    # Game Over's words for +finale+ (Finale), stacked as one group
    # between the HUD, whose bottom is at +below+, and the safe area's
    # bottom, or higher, so the pile's dots lying on the window's floor
    # show at least their lower half under Continue: "Time's up!", "You met
    # today's goal!" when the round did, the score, the best or how far
    # short of it the round fell, the round's facts, a record it set,
    # "Share my score", closing the score's group, and the Continue
    # button, as big as Layout's primary_size for dots of +radius+. Short
    # of room, the type shrinks first; then the record goes, the facts, the
    # goal, the best, "Time's up!", and last "Share my score".
    # The score and Continue always stay. The backing (+scrim+, a
    # ScrimLook) is drawn around everything above Continue, so "Share my
    # score" reads as part of the score, and Continue, which needs none,
    # stands apart on the pile; it hides no more of the pile than it must.
    # Sizes are measured with +measure+ (RoughMeasure's methods).
    class FinaleScreen < Data.define(:layout, :type, :words, :measure, :scrim, :finale, :below, :radius, :group_line)
      # The gaps above each line, in graphics units at full size.
      GAPS = { heading: 26, goal: 12, score: 4, best: 4, group: 8, summary: 14, record: 8, achievement: 8, share: 16, continue: 22 }.freeze
      # "Share my score"'s share glyph and the room around its words, in
      # the button's height.
      SHARE_GLYPH = 0.62
      SHARE_SIDES = 1.1

      def initialize(layout:, type:, words:, measure:, scrim:, finale:, below:, radius: Rules::RADIUS, group_line: nil) = super

      def plan
        placed = Column.new(room:).fit(layout.type_scales) { blocks(sizes(it), it) }
        sizes = sizes(placed.scale)
        FinalePlan.new(placed:, sizes:, backing: backing(placed))
      end

      # From a margin under the HUD to a margin above the safe area's
      # bottom, or to the middle of the pile's bottom row, a radius above
      # the window's floor, if that is higher. Continue, the lowest block,
      # is filled, and on a short window it would otherwise hide whatever
      # lies on the floor under the middle of the screen.
      def room
        margin = layout.margin
        safe = layout.safe
        top = below + margin
        bottom = [safe.bottom - margin, layout.height - radius].min
        Rect.new(x: safe.x + margin, y: top, width: safe.width - (2 * margin), height: bottom - top)
      end

      # The best line's face and size, and what it says.
      def best_line(size)
        if finale.new_best? then [:bold, size, words.new_best]
        else [:semibold, size, words.short_of_best(finale.score, finale.best, first: finale.first)]
        end
      end

      private

      def blocks(sizes, scale)
        [line(:heading, :bold, sizes[:heading], words.time_up, scale, drop: 6),
         (line(:goal, :bold, sizes[:goal], words.goal_met, scale, drop: 4, mark: true) if finale.goal_met),
         line(:score, :bold, sizes[:score], finale.score.to_s, scale, depth: 1.06),
         line(:best, *best_line(sizes[:best]), scale, drop: 5),
         (line(:group, :semibold, sizes[:summary], group_line, scale, drop: 3.5) if group_line),
         line(:summary, :semibold, sizes[:summary], words.summary(finale.stats), scale, drop: 3),
         (line(:record, :semibold, sizes[:summary], words.record(finale.record), scale, drop: 2) if finale.record),
         (line(:achievement, :semibold, sizes[:summary], AchievementWords.earned(finale.achievements), scale, drop: 2.5) if finale.achievements.any?),
         share(scale),
         continue(scale)].compact
      end

      # A line of +text+, with room for a check mark before it if +mark+,
      # and for the candy's extruded copy under it as +depth+ of its height.
      def line(name, face, size, text, scale, drop: nil, mark: false, depth: 1.0)
        height = measure.height(face, size)
        width = measure.width(face, size, text) + (mark ? height * 0.75 : 0.0)
        Block.new(name:, height: height * depth, gap: gap(name, scale), width:, drop:)
      end

      # Continue, as big as a main button is, whatever the type's scale.
      def continue(scale)
        width, height = layout.primary_size(radius)
        Block.new(name: :continue, height:, width:, gap: gap(:continue, scale))
      end

      # "Share my score" and its glyph, as tall as a button at any type
      # scale, and as wide as its words need.
      def share(scale)
        height = layout.button_size
        Block.new(name: :share, height:, width: share_width(height), gap: gap(:share, scale), drop: 7)
      end

      def share_width(height)
        words_width = measure.width(:semibold, FinaleScreen.share_size(height), words.share)
        [words_width + (height * (SHARE_GLYPH + SHARE_SIDES)), height * 4.2].max
      end

      # The size "Share my score"'s words are set in, on a button +height+
      # tall.
      def self.share_size(height) = (height * 0.4).round

      def gap(name, scale) = GAPS.fetch(name) * layout.ui * scale

      def sizes(scale)
        size = ->(nominal) { layout.type_size(nominal, scale) }
        { heading: size[type.heading], goal: size[type.best], score: size[type.final_score],
          best: size[finale.new_best? ? type.new_best : type.best], summary: size[type.summary] }
      end

      # Around every line above Continue, and never past the safe area
      # once padded.
      def backing(placed)
        bounds = placed.with(rects: placed.rects.except(:continue)).bounds
        most = layout.safe.width - (2 * (scrim.pad + scrim.feather) * layout.ui)
        width = [bounds.width, most].min
        bounds.with(x: layout.center_x - (width / 2.0), width:)
      end
    end
  end
end
