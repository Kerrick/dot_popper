# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where Game Over's words go, worked out by FinaleScreen#plan: each
    # line's Rect by name (Stacked), the font size each is set in, the
    # stacking rule broken into lines, and the backing behind them all.
    # A line the screen had no room for, or that is not shown, has no
    # Rect; Continue is the Rect named :continue, and "Copy my result" the
    # one named :share.
    class FinalePlan < Data.define(:placed, :sizes, :lesson_lines, :backing)
      def [](name) = placed[name]
      def size(name) = sizes.fetch(name)
      def share_button = placed[:share]
      def continue_button = placed[:continue]
    end

    # Game Over's words for +finale+ (Finale), stacked as one group
    # between the HUD, whose bottom is at +below+, and the safe area's
    # bottom: the stacking rule when it is taught, "Time's up!", "You met
    # today's goal!" when the round did, the score, the best or how far
    # short of it the round fell, the round's facts, a record it set,
    # +hint+, how to play with the pile, when there is one, the Continue
    # button, as big as Layout's primary_size for dots of +radius+, and
    # "Copy my result" under it. Short of room, the type shrinks first;
    # then the hint goes, then the record, the facts, the goal, the best,
    # "Time's up!", "Copy my result", and last the lesson. The score and
    # Continue always stay. The backing (+scrim+, a ScrimLook) is drawn
    # around the words, above the buttons, which need none, so it hides
    # no more of the pile than it must. Sizes are measured with +measure+
    # (RoughMeasure's methods).
    class FinaleScreen < Data.define(:layout, :type, :words, :measure, :scrim, :finale, :below, :hint, :radius)
      # The gaps above each line, in graphics units at full size.
      GAPS = { heading: 26, goal: 12, score: 4, best: 4, summary: 14, record: 8, continue: 22, share: 14,
               hint: 8 }.freeze

      def initialize(layout:, type:, words:, measure:, scrim:, finale:, below:, hint: nil, radius: Rules::RADIUS) = super

      def plan
        placed = Column.new(room:).fit(layout.type_scales) { blocks(sizes(it), it) }
        sizes = sizes(placed.scale)
        FinalePlan.new(placed:, sizes:, lesson_lines: lesson_lines(sizes[:lesson]), backing: backing(placed))
      end

      # From a margin under the HUD to a margin above the safe area's
      # bottom.
      def room
        margin = layout.margin
        safe = layout.safe
        top = below + margin
        Rect.new(x: safe.x + margin, y: top, width: safe.width - (2 * margin), height: safe.bottom - margin - top)
      end

      # The best line's face and size, and what it says.
      def best_line(size)
        if finale.new_best? then [:bold, size, words.new_best]
        else [:semibold, size, words.short_of_best(finale.score, finale.best, first: finale.first)]
        end
      end

      private

      def blocks(sizes, scale)
        [(lesson_block(sizes[:lesson], scale) if finale.lesson),
         line(:heading, :bold, sizes[:heading], words.time_up, scale, drop: 6),
         (line(:goal, :bold, sizes[:goal], words.goal_met, scale, drop: 4, mark: true) if finale.goal_met),
         line(:score, :bold, sizes[:score], finale.score.to_s, scale, depth: 1.06),
         line(:best, *best_line(sizes[:best]), scale, drop: 5),
         line(:summary, :semibold, sizes[:summary], words.summary(finale.stats), scale, drop: 3),
         (line(:record, :semibold, sizes[:summary], words.record(finale.record), scale, drop: 2) if finale.record),
         (line(:hint, :semibold, sizes[:summary], hint, scale, drop: 1) if hint),
         continue(scale),
         share].compact
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

      # "Copy my result", as tall as a button at any type scale.
      def share
        height = layout.button_size
        Block.new(name: :share, height:, width: height * 4.6, gap: gap(:share, 1.0), drop: 7)
      end

      # The stacking rule, its lines 1.05 lines apart.
      def lesson_block(size, scale)
        lines = lesson_lines(size)
        line = measure.height(:bold, size)
        Block.new(name: :lesson, height: (line * 1.05 * (lines.size - 1)) + line, gap: 0.0, drop: 8,
                  width: lines.map { measure.width(:bold, size, it) }.max)
      end

      def gap(name, scale) = GAPS.fetch(name) * layout.ui * scale

      def sizes(scale)
        size = ->(nominal) { layout.type_size(nominal, scale) }
        { lesson: size[type.hint], heading: size[type.heading], goal: size[type.best], score: size[type.final_score],
          best: size[finale.new_best? ? type.new_best : type.best], summary: size[type.summary] }
      end

      # The stacking rule, a sentence a line, each broken evenly if it
      # would not fit across.
      def lesson_lines(size)
        return [] unless finale.lesson

        room = layout.safe.width - (layout.margin * 3)
        finale.lesson.flat_map { |sentence| Words.balance(sentence, room) { measure.width(:bold, size, it) } }
      end

      # Around every line above the buttons, and never past the safe area
      # once padded.
      def backing(placed)
        bounds = placed.with(rects: placed.rects.except(:continue, :share)).bounds
        most = layout.safe.width - (2 * (scrim.pad + scrim.feather) * layout.ui)
        width = [bounds.width, most].min
        bounds.with(x: layout.center_x - (width / 2.0), width:)
      end
    end
  end
end
