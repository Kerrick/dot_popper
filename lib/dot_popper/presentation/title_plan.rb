# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where the title's words go, worked out by TitleScreen#plan: each
    # line's Rect by name (Stacked), the Play button's as :play, the font
    # size each is set in, today's goal broken into lines, the faint
    # backing behind them, the bottom row's buttons, which the words keep
    # above, the window buttons on a desktop (WindowButtons, or nil), and
    # where "Press B again to quit" goes while it shows (+quit_line+), with
    # the name of the line it stands in for there, if any (+quit_over+). A
    # line the screen had no room for, or that is not shown, has no Rect.
    class TitlePlan < Data.define(:placed, :sizes, :goal_lines, :backing, :records_button, :sizing_control,
                                  :mute_button, :how_to_play_button, :window_buttons, :quit_line, :quit_over)
      def [](name) = placed[name]
      def size(name) = sizes.fetch(name)
      def play_button = placed[:play]
    end

    # The title's legend, a reminder of the scoring with no word, in the
    # Tutorial's own signs (Tally): a bright dot, then "+1" and "+1" with a
    # stopwatch; under it a popped dot, then "−2" and "−2" with a
    # stopwatch, the numbers in two columns. On a line +height+ tall, it
    # is +width+ across, and its columns start +points+ and +seconds+
    # from its left. Its dots' radius is DOT of the line's height, with
    # AFTER_DOT of that radius after them; its columns are APART lines'
    # heights apart, its rows ROW radii apart, and the whole HEIGHT lines
    # tall.
    class Legend < Data.define(:height, :points, :seconds, :width)
      DOT = 0.5
      AFTER_DOT = 0.7
      APART = 0.9
      ROW = 2.8
      HEIGHT = 2.4

      # Each row, top first: whether its dot is fresh, then what its tap
      # does to the score and to the clock.
      def self.rows = [[true, *Tally.pop], [false, *Tally.penalty]]

      # The legend on a line +height+ tall, its numbers as wide as the
      # block measures them.
      def self.measure(height, &measure)
        first = height * DOT * (2 + AFTER_DOT)
        widest = ->(column) { rows.map { it[column].width(height, &measure) }.max }
        second = first + widest[1] + (height * APART)
        new(height:, points: first, seconds: second, width: second + widest[2])
      end

      def radius = height * DOT
    end

    # The title screen, short of its dots: its name, the legend, the best
    # score (+best+, shown from 1), today's goal (+goal+, its sentence or
    # "Today's goal is done." once +done+), the days in a row it has been
    # met (+streak+, from 2), and the Play button, as big as Layout's
    # primary_size for dots of +radius+ (or, on a window too small for
    # that, as small as a button), stacked as one group in the
    # middle of the screen; and the bottom row, "Your records" once
    # +records+ is offered, the dot-size choice where +sizing+ is, "How to
    # play", and the mute button. The bottom row is laid out first, and
    # the words fit in what is left above it: their type shrinks first,
    # then the streak goes, then the goal, then the best, and last the
    # name shrinks on.
    # The legend and Play always stay, since they are how to play.
    # On a desktop (+window+), "Full screen" and Quit take a row of their
    # own above the bottom row's right end (#window_buttons).
    # Sizes are measured with +measure+ (RoughMeasure's methods).
    class TitleScreen < Data.define(:layout, :type, :words, :measure, :best, :goal, :done, :streak, :records,
                                    :sizing, :radius, :window)
      # The gaps above each line, in graphics units at full size.
      GAPS = { legend: 34, best: 24, best_room: 24, goal: 18, streak: 10, play: 28 }.freeze
      # How far the name shrinks on, once everything else has made room.
      NAME_SHRINKS = [1.0, 0.82, 0.66, 0.5, 0.4].freeze

      def initialize(layout:, type:, words:, measure:, best: 0, goal: nil, done: false, streak: 0, records: false,
                     sizing: false, radius: Rules::RADIUS, window: false)
        super
      end

      def plan
        buttons = window_buttons
        placed, sizes = stack(buttons)
        TitlePlan.new(placed:, sizes:, goal_lines: goal_lines(sizes[:goal]), backing: backing(placed, sizes),
                      records_button: layout.records_button, sizing_control: sizing_control(buttons),
                      mute_button: layout.mute_button, how_to_play_button: layout.how_to_play_button,
                      window_buttons: buttons, **quit_line(placed, sizes, buttons))
      end

      # The middle of the screen, from the safe area's top margin down to
      # a margin above the bottom row.
      def room(buttons = window_buttons)
        margin = layout.margin
        top = layout.top
        Rect.new(x: layout.safe.x + margin, y: top, width: layout.safe.width - (2 * margin),
                 height: bottom_row(buttons).map(&:y).min - margin - top)
      end

      # The bottom row's parts that show: the window buttons' row above
      # its right end, and the dot-size choice's label and segments too,
      # which take a row above the buttons where they do not fit between
      # them, as "How to play" does.
      def bottom_row(buttons = window_buttons)
        parts = [layout.mute_button, layout.how_to_play_button, *row_of(buttons)]
        parts << layout.records_button if records
        parts.push(sizing_control(buttons).label, sizing_control(buttons).frame) if sizing
        parts
      end

      # Where "Full screen" and Quit go on a desktop's title (Layout's
      # WindowButtons), or nil where the title has none. They are in their
      # row, labelled, wherever the name, the legend and Play fit above it
      # with the dot-size choice shown too, so that they stay put once it
      # shows; only on a window too short for that, as the smallest, are
      # they their icons alone, in the top right corner beside the name,
      # which keeps clear of them.
      def window_buttons
        return unless window

        row = layout.window_buttons
        fits = with(sizing: true, best: 0, goal: nil, streak: 0).stack(row).first.fits?
        fits ? row : layout.window_icons
      end

      protected

      # The words stacked in the room above the bottom row, as the window
      # buttons +buttons+ leave it: where they went, and the type's sizes.
      def stack(buttons)
        column = Column.new(room: room(buttons))
        placed = sizes = nil
        play_heights.each do |play|
          NAME_SHRINKS.each do |shrink|
            placed = column.fit(layout.type_scales) { blocks(sizes(it, shrink, buttons), it, play) }
            sizes = sizes(placed.scale, shrink, buttons)
            break if placed.fits?
          end
          break if placed.fits?
        end
        [placed, sizes]
      end

      private

      # The window buttons standing in the bottom row's rows, where they
      # are labelled; none where they are icons in the corner.
      def row_of(buttons) = buttons&.labelled ? buttons.rects : []

      def sizing_control(buttons) = layout.sizing_control(above: row_of(buttons))

      # Whether the window buttons are their icons in the top right corner.
      def cornered?(buttons) = buttons && !buttons.labelled

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
         Block.new(name: :legend, height: measure.height(:bold, legend) * Legend::HEIGHT, gap: gap(:legend, scale),
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

      def sizes(scale, shrink, buttons)
        { title: title_size((layout.type_size(type.title, scale) * shrink).round, buttons),
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

      # The name's +size+, shrunk if it would not fit across, or, with the
      # window buttons' icons in the corner beside it, between them and as
      # far from the other side, a margin clear of them.
      def title_size(size, buttons)
        room = across
        room = [room, 2 * (buttons.fullscreen.x - layout.margin - layout.center_x)].min if cornered?(buttons)
        width = measure.width(:bold, size, words.title)
        width > room ? (size * room / width).floor : size
      end

      # How wide the legend is (Legend), its numbers set in bold +size+.
      def legend_width(size) = Legend.measure(measure.height(:bold, size)) { measure.width(:bold, size, it) }.width

      # The legend's +size+, shrunk by whole sizes until its longer line
      # fits across.
      def legend_size(size)
        room = layout.safe.width - (layout.margin * 2)
        size -= 1 while size > layout.look.least && legend_width(size) > room
        size
      end

      # "Press B again to quit", in the goal's type: a gap under Play, or
      # a gap above the name. It shows only for a moment, so it takes no
      # room from the others; where neither has room for it, it stands in
      # for a line that is already there: today's goal, the best, or, on
      # the smallest windows, the legend. Above the name is the window
      # buttons' corner, where they are icons there.
      def quit_line(placed, sizes, buttons)
        size = sizes[:goal]
        height = measure.height(:semibold, size)
        width = measure.width(:semibold, size, words.quit_again)
        gap = gap(:goal, placed.scale)
        line = ->(y) { Rect.new(x: layout.center_x - (width / 2.0), y:, width:, height:) }
        below = placed[:play].bottom + gap
        above = placed[:title].y - gap - height
        return { quit_line: line[below], quit_over: nil } if below + height + gap <= bottom_row(buttons).map(&:y).min
        return { quit_line: line[above], quit_over: nil } if above >= layout.safe.y && !cornered?(buttons)

        over = %i[goal best legend].find { placed.key?(it) }
        { quit_line: line[placed[over].center_y - (height / 2.0)], quit_over: over }
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
