# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where the title's words go, worked out by TitleScreen#plan: each
    # line's Rect by name (Stacked), the Play button's as :play, the font
    # size each is set in, today's goal broken into lines, the faint
    # backing behind them, and the bottom row's buttons, which the words
    # keep above. A line the screen had no room for, or that is not
    # shown, has no Rect.
    class TitlePlan < Data.define(:placed, :sizes, :goal_lines, :backing, :records_button, :sizing_control,
                                  :mute_button)
      def [](name) = placed[name]
      def size(name) = sizes.fetch(name)
      def play_button = placed[:play]
    end

    # The title screen, short of its dots: its name, the legend, the best
    # score (+best+, shown from 1), today's goal (+goal+, its sentence or
    # "Today's goal is done." once +done+), the days in a row it has been
    # met (+streak+, from 2), and the Play button, as big as Layout's
    # primary_size for dots of +radius+ (or, on a window too small for
    # that, as small as a button), stacked as one group in the
    # middle of the screen; and the bottom row, "Your records" once
    # +records+ is offered, the dot-size choice where +sizing+ is, and the
    # mute button. The bottom row is laid out first, and the words fit in
    # what is left above it: their type shrinks first, then the streak
    # goes, then the goal, then the best, and last the name shrinks on.
    # The legend and Play always stay, since they are how to play.
    # Sizes are measured with +measure+ (RoughMeasure's methods).
    class TitleScreen < Data.define(:layout, :type, :words, :measure, :best, :goal, :done, :streak, :records,
                                    :sizing, :radius)
      # The gaps above each line, in graphics units at full size.
      GAPS = { legend: 34, best: 24, best_room: 24, goal: 18, streak: 10, play: 28 }.freeze
      # How far the name shrinks on, once everything else has made room.
      NAME_SHRINKS = [1.0, 0.82, 0.66, 0.5, 0.4].freeze

      def initialize(layout:, type:, words:, measure:, best: 0, goal: nil, done: false, streak: 0, records: false,
                     sizing: false, radius: Rules::RADIUS)
        super
      end

      def plan
        column = Column.new(room:)
        placed = sizes = nil
        play_heights.each do |play|
          NAME_SHRINKS.each do |shrink|
            placed = column.fit(layout.type_scales) { blocks(sizes(it, shrink), it, play) }
            sizes = sizes(placed.scale, shrink)
            break if placed.fits?
          end
          break if placed.fits?
        end
        TitlePlan.new(placed:, sizes:, goal_lines: goal_lines(sizes[:goal]), backing: backing(placed, sizes),
                      records_button: layout.records_button, sizing_control: layout.sizing_control,
                      mute_button: layout.mute_button)
      end

      # The middle of the screen, from the safe area's top margin down to
      # a margin above the bottom row.
      def room
        margin = layout.margin
        top = layout.top
        Rect.new(x: layout.safe.x + margin, y: top, width: layout.safe.width - (2 * margin),
                 height: bottom_row.map(&:y).min - margin - top)
      end

      # The bottom row's parts that show: the dot-size choice's label and
      # segments too, which take a row above the buttons where they do not
      # fit between them.
      def bottom_row
        parts = [layout.mute_button]
        parts << layout.records_button if records
        parts.push(layout.sizing_control.label, layout.sizing_control.frame) if sizing
        parts
      end

      private

      # How tall Play may be, from the first choice down: a dot across, or,
      # on a window too small for that, as tall as a button.
      def play_heights
        _, height = layout.primary_size(radius)
        [height, (height + layout.button_size) / 2.0, layout.button_size].uniq
      end

      def blocks(sizes, scale, play_height)
        title, legend, line = sizes.values_at(:title, :legend, :best)
        goal = goal_lines(sizes[:goal]) if self.goal
        [Block.new(name: :title, height: measure.height(:bold, title) * 1.06, width: measure.width(:bold, title, words.title)),
         Block.new(name: :legend, height: measure.height(:semibold, legend) * 2.4, gap: gap(:legend, scale),
                   width: legend_width(legend)),
         best_block(line, scale),
         (goal_block(goal, sizes[:goal], scale) if goal),
         (block(:streak, :semibold, sizes[:goal], words.streak(streak), scale, drop: 1) if goal && streak >= 2),
         play(scale, play_height)].compact
      end

      # "Your best: 25", or none yet. While the Dot size choice shows, each
      # size has bests of its own, so a size with none yet keeps the
      # line's room empty: switching sizes then never moves Play.
      def best_block(size, scale)
        return block(:best, :semibold, size, words.best_line(best), scale, drop: 3) if best.positive?

        block(:best_room, :semibold, size, "", scale, drop: 3) if sizing
      end

      # Play, as wide as a main button is, whatever the type's scale.
      def play(scale, height)
        width, = layout.primary_size(radius)
        Block.new(name: :play, height:, width:, gap: gap(:play, scale))
      end

      def block(name, face, size, text, scale, drop: nil)
        Block.new(name:, height: measure.height(face, size), gap: gap(name, scale), width: measure.width(face, size, text),
                  drop:)
      end

      # The goal's lines, 1.2 lines apart, and with the check mark when it
      # is done.
      def goal_block(lines, size, scale)
        line = measure.height(:semibold, size)
        check = done ? line * 0.75 : 0.0
        Block.new(name: :goal, height: (line * 1.2 * (lines.size - 1)) + line, gap: gap(:goal, scale), drop: 2,
                  width: lines.map { measure.width(:semibold, size, it) }.max + check)
      end

      def gap(name, scale) = GAPS.fetch(name) * layout.ui * scale

      def sizes(scale, shrink)
        { title: title_size((layout.type_size(type.title, scale) * shrink).round),
          legend: legend_size(layout.type_size(type.legend, scale)),
          best: layout.type_size(type.best, scale), goal: layout.type_size(type.summary * 1.1, scale) }
      end

      # Today's goal broken into lines that fit across. Once it is done, a
      # check stands before its first line (Shell::Check, half a line's
      # height and a quarter more of gap), so the lines leave it room.
      def goal_lines(size)
        return [] unless goal

        room = done ? across - (measure.height(:semibold, size) * 0.75) : across
        Words.balance(goal, room) { measure.width(:semibold, size, it) }
      end

      # How wide a line of the middle may be.
      def across = layout.safe.width - (layout.margin * 4)

      # The name's +size+, shrunk if it would not fit across.
      def title_size(size)
        width = measure.width(:bold, size, words.title)
        width > across ? (size * across / width).floor : size
      end

      def legend_lines = [words.legend_fresh, words.legend_popped]

      # How wide the legend is: a dot, a gap, and its longer line.
      def legend_width(size)
        radius = measure.height(:semibold, size) * 0.5
        legend_lines.map { (radius * 2.7) + measure.width(:semibold, size, it) }.max
      end

      # The legend's +size+, shrunk by whole sizes until its longer line
      # fits across.
      def legend_size(size)
        room = layout.safe.width - (layout.margin * 2)
        size -= 1 while size > layout.look.least && legend_width(size) > room
        size
      end

      # From near the name's top to the bottom of the line above Play, as
      # wide as the name or the legend, whichever is wider, so the button
      # stands on the night.
      def backing(placed, sizes)
        name = placed[:title]
        width = [name.width, legend_width(sizes[:legend])].max
        top = name.y + (name.height * 0.1)
        above = placed.rects.except(:play).values.map(&:bottom).max
        Rect.new(x: layout.center_x - (width / 2.0), y: top, width:, height: above - top)
      end
    end
  end
end
