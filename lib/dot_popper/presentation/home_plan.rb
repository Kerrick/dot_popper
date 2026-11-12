# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where Home's parts go, worked out by HomeScreen#plan: the name and its
    # type size, the first launch's +legend+ and its type size (nil after
    # the first game), Play, the daily goal's card, the four large +tiles+
    # by name, the bottom row's +pills+ by name, and +quit_line+, the middle
    # of "Press B again to quit". Parts a screen does not show are nil.
    class HomePlan < Data.define(:name, :name_size, :legend, :legend_size, :play, :goal, :tiles, :pills, :quit_line)
      def play_button = play
    end

    # Today's goal on Home's card, laid out in +rect+: +pad+ in from its
    # edges, "Today's goal" at +label_size+, and the goal's whole sentence
    # in +lines+ at +text_size+, the first line's top at +top+, all left
    # of the +divider+ before the days in a row. Like a large button's
    # words, the sentence's type shrinks until it fits, in at most LINES
    # lines and above the card's bottom, down to SMALLEST; #whole? says
    # whether it fit by then. Home shows the card only where every goal
    # fits (.room?), so the card never cuts a goal short.
    class GoalCard < Data.define(:rect, :pad, :divider, :label_size, :text_size, :top, :lines, :measure)
      LINES = 2
      SMALLEST = 11 # as small as a large button's words go (HomePainter#fit)

      def self.fit(rect, sentence, measure)
        pad = [rect.height * 0.18, 16.0].min
        label_size = [(rect.height * 0.15).round, 12].max
        card = new(rect:, pad:, divider: rect.right - (rect.height * 1.1), label_size:, text_size: [(rect.height * 0.2).round, 14].max,
                   top: rect.y + pad + (measure.height(:semibold, label_size) * 1.25), lines: [], measure:)
        card = card.at(sentence, card.text_size)
        card = card.at(sentence, card.text_size - 1) until card.whole? || card.text_size <= SMALLEST
        card
      end

      # Whether every daily goal, in +words+, fits whole on a card in +rect+.
      def self.room?(rect, words, measure) = DailyGoal::LIST.all? { fit(rect, words.goal_sentence(it), measure).whole? }

      def at(sentence, size) = with(text_size: size, lines: Words.wrap(sentence, room) { measure.width(:bold, size, it) })

      def whole?
        lines.size <= LINES && lines.all? { measure.width(:bold, text_size, it) <= room } &&
          top + (lines.size * measure.height(:bold, text_size)) <= rect.bottom - (pad / 2.0)
      end

      # How wide a line may be, left of the divider.
      def room = divider - rect.x - (2 * pad)
    end

    # The first launch's legend, a reminder of the scoring with no word, in
    # the Tutorial's own signs (Tally): a bright dot, then "+1" and "+1"
    # with a stopwatch; under it a popped dot, then "−2" and "−2" with a
    # stopwatch, the numbers in two columns. On a line +height+ tall, it is
    # +width+ across, and its columns start +points+ and +seconds+ from its
    # left.
    class Legend < Data.define(:height, :points, :seconds, :width)
      DOT = 0.5
      AFTER_DOT = 0.7
      APART = 0.9
      ROW = 2.8
      HEIGHT = 2.4

      def self.rows = [[true, *Tally.pop], [false, *Tally.penalty]]

      def self.measure(height, &measure)
        first = height * DOT * (2 + AFTER_DOT)
        widest = ->(column) { rows.map { it[column].width(height, &measure) }.max }
        second = first + widest[1] + (height * APART)
        new(height:, points: first, seconds: second, width: second + widest[2])
      end

      def radius = height * DOT
    end

    # Home, read top down: the name, Play, today's goal with the days in a
    # row, four large buttons (+tile_names+), then How to play, Settings
    # and, on a computer (+window+), Quit. Before the first game (+played+
    # false) it is the name, the legend, Play and Settings alone, so
    # nothing has to be read to begin. A short landscape window puts the
    # name and Play on the left and the rest on the right.
    class HomeScreen < Data.define(:layout, :type, :words, :measure, :played, :tile_names, :window)
      NAME_WIDTH = 615.0 # how wide the name may be on a large window
      PLAY = [560.0, 104.0].freeze

      def initialize(layout:, type:, words:, measure:, played: false, tile_names: [], window: false) = super

      def plan
        layout.short? ? landscape : upright
      end

      private

      def margin = layout.page_margin
      def safe = layout.safe
      def wide? = safe.width >= 900 && !layout.short?
      def tile_names = played ? super : []
      def pill_names = (played ? %i[how_to_play settings] : %i[settings]) + (window ? %i[quit] : [])

      # Laid out as the mocks draw it, or where that does not fit the
      # window, tighter, and on the smallest windows without the goal's
      # card, which Stats shows too.
      def upright
        plans = [0, 1, 2].lazy.map { upright_at(it) }
        plans.find { fits?(it) } || upright_at(2)
      end

      def fits?(plan)
        parts = [plan.name, plan.legend, plan.play, plan.goal, *plan.tiles.values, *plan.pills.values].compact
        x, y = plan.quit_line
        quit = Rect.new(x: x - 100, y: y - 9, width: 200, height: 18)
        parts.all? { it.y >= safe.y - 1e-6 && it.bottom <= safe.bottom + 1e-6 } &&
          (parts + [quit]).combination(2).none? { |one, other| one.overlaps?(other) } && (plan.goal.nil? || goal_room?(plan.goal))
      end

      # Whether a card in +rect+ shows every daily goal whole.
      def goal_room?(rect) = GoalCard.room?(rect, words, measure)

      # +tight+: 0 as drawn, 1 with less room between the parts, 2 also
      # without the goal's card.
      def upright_at(tight)
        left = safe.x + margin
        full = safe.width - (2 * margin)
        columns = self.columns(full)
        tile_top_gap = tight.positive? ? 8.0 : (wide? ? 17.0 : 12.0)
        tile_height = tight.positive? ? [56.0, layout.button_size].max : (wide? ? 105.0 : 76.0)
        gap = tight.positive? ? 8.0 : (wide? ? 12.0 : 10.0)
        bottom = safe.bottom - margin
        tall = tight.positive? ? [48.0, layout.button_size].max : (wide? ? 60.0 : 56.0)
        pill_y = bottom - tall
        pills = pill_row(layout.center_x, pill_y, tall)
        tile_width = [(full - (gap * (columns - 1))) / columns, wide? ? 255.0 : Float::INFINITY].min
        rows = tile_names.each_slice(columns).to_a
        tiles_height = (rows.size * tile_height) + ([rows.size - 1, 0].max * gap)
        tiles_left = layout.center_x - ((columns * tile_width) + ((columns - 1) * gap)) / 2.0
        tiles_top = pill_y - (tight.positive? ? 12.0 : (wide? ? 63.0 : 14.0)) - tiles_height
        tiles = tile_rects(rows, tiles_left, tiles_top, tile_width, tile_height, gap)
        card_height = tight.positive? ? 72.0 : (wide? ? 101.0 : 87.0)
        card_width = wide? ? [768.0, full].min : full
        card = (Rect.new(x: layout.center_x - (card_width / 2.0), y: tiles_top - tile_top_gap - card_height, width: card_width, height: card_height) if played && tight < 2)
        above = card ? card.y : (played ? tiles_top - tile_top_gap : pill_y - tall)
        top_group(left, full, card, above, tiles, pills, tight:)
      end

      # As many columns as there are large buttons where each has room for
      # its words, and otherwise two.
      def columns(full)
        count = [tile_names.size, 1].max
        return count if wide?

        (full - (10.0 * (count - 1))) / count >= 170.0 ? count : 2
      end

      # The name and Play above the card, or the name, legend and Play on the
      # first launch.
      def top_group(left, full, card, above, tiles, pills, tight: 0)
        play_width = wide? ? [PLAY[0], full].min : full
        play_height = (wide? ? PLAY[1] : 100.0).clamp(0.0, [(above - safe.y - margin) * 0.45, layout.button_size].max)
        play_height = [play_height, [64.0, layout.button_size].max].min if tight.positive?
        size = name_size(wide? ? [NAME_WIDTH, full].min : full)
        name_height = measure.height(:bold, size)
        under = card || played
        gap_after = under ? (tight.positive? ? 28.0 : (wide? ? 56.0 : 105.0)) : 0.0
        play_y = under ? [above - gap_after - play_height, safe.y + margin + name_height + 12].max : centered_play(above, name_height, play_height)
        legend, legend_size = legend_for(play_y, name_height, size) unless under
        name_y = if under then [play_y - (tight.positive? ? (name_height * 0.5) + 10 : (wide? ? 95.0 : 108.0)), safe.y + margin + (name_height / 2.0)].max
                 else legend ? legend.y - (name_height * 0.7) : play_y - (name_height * 0.9)
                 end
        HomePlan.new(name: Rect.new(x: left, y: name_y - (name_height / 2.0), width: full, height: name_height), name_size: size, legend:, legend_size:,
                     play: Rect.new(x: layout.center_x - (play_width / 2.0), y: play_y, width: play_width, height: play_height), goal: card, tiles:,
                     pills:, quit_line: [layout.center_x, (play_y + play_height + (under ? above : (pills.values.first&.y || safe.bottom))) / 2.0])
      end

      def centered_play(above, name_height, play_height)
        legend_size = layout.type_size(type.legend)
        legend_height = measure.height(:bold, legend_size) * Legend::HEIGHT
        total = name_height + 24 + legend_height + 30 + play_height
        top = safe.y + [(above - safe.y - total) * 0.42, margin].max
        top + name_height + 24 + legend_height + 30
      end

      def legend_for(play_y, _name_height, _size)
        size = layout.type_size(type.legend)
        height = measure.height(:bold, size) * Legend::HEIGHT
        width = Legend.measure(measure.height(:bold, size)) { measure.width(:bold, size, it) }.width
        [Rect.new(x: layout.center_x - (width / 2.0), y: play_y - 30 - height, width:, height:), size]
      end

      def landscape
        gap = 22.0
        left_width = [(safe.width - (2 * margin) - gap) / 2.0, 398.0].min
        right_x = safe.x + margin + left_width + gap
        right_width = safe.right - margin - right_x
        room = safe.height - (2 * margin)
        card_height, tile_height, pill_height = shares(room)
        card = Rect.new(x: right_x, y: safe.y + margin, width: right_width, height: card_height)
        card = nil unless played && goal_room?(card)
        # Where the card is left out after a game, the large buttons and the
        # bottom row share its room. A first launch keeps it, as before.
        above = card || !played ? card_height : 0.0
        between = [(room - above - (tile_height * 2) - 10 - pill_height) / 2.0, 6.0].max
        tile_y = safe.y + margin + above + between
        pill_y = tile_y + (tile_height * 2) + 10 + between
        tile_width = (right_width - 10) / 2.0
        tiles = tile_rects(tile_names.each_slice(2).to_a, right_x, tile_y, tile_width, tile_height, 10.0)
        pills = pill_row(right_x + (right_width / 2.0), pill_y, pill_height)
        return first_landscape(left_width, tiles, pills) unless played

        size = name_size(left_width)
        name_height = measure.height(:bold, size)
        play_height = [78.0, layout.button_size, safe.height * 0.22].sort[1]
        play_y = (safe.y + (safe.height / 2.0)) + (name_height * 0.15)
        name = Rect.new(x: safe.x + margin, y: play_y - name_height - 4, width: left_width, height: name_height)
        HomePlan.new(name:, name_size: size, legend: nil, legend_size: nil,
                     play: Rect.new(x: safe.x + margin, y: play_y, width: left_width, height: play_height),
                     goal: card, tiles:, pills:,
                     quit_line: [safe.x + margin + (left_width / 2.0), play_y + play_height + 18.0])
      end

      def first_landscape(left_width, _tiles, pills)
        size = name_size(left_width)
        name_height = measure.height(:bold, size)
        legend_size = layout.type_size(type.legend) - 2
        legend_height = measure.height(:bold, legend_size) * Legend::HEIGHT
        play_height = [78.0, layout.button_size, safe.height * 0.22].sort[1]
        total = name_height + legend_height + play_height + 24
        top = [safe.y + ((safe.height - total) / 2.0), safe.y + margin].max
        width = Legend.measure(measure.height(:bold, legend_size)) { measure.width(:bold, legend_size, it) }.width
        legend = Rect.new(x: safe.x + margin + (left_width / 2.0) - (width / 2.0), y: top + name_height + 8, width:, height: legend_height)
        HomePlan.new(name: Rect.new(x: safe.x + margin, y: top, width: left_width, height: name_height), name_size: size, legend:, legend_size:,
                     play: Rect.new(x: safe.x + margin, y: legend.bottom + 12, width: left_width, height: play_height), goal: nil, tiles: {}, pills:,
                     quit_line: [safe.x + margin + (left_width / 2.0), legend.bottom + play_height + 30.0])
      end

      # Heights for the card, a tile and the pills on a short window.
      def shares(room)
        scale = (room / (87.0 + 76 + 10 + 76 + 56 + 48)).clamp(0.5, 1.0)
        [[87.0 * scale, layout.button_size].max, [76.0 * scale, layout.button_size].max, [56.0 * scale, layout.button_size].max]
      end

      def tile_rects(rows, left, top, width, height, gap)
        rows.each_with_index.flat_map do |row, r|
          row.each_with_index.map { |name, c| [name, Rect.new(x: left + (c * (width + gap)), y: top + (r * (height + gap)), width:, height:)] }
        end.to_h
      end

      # The bottom row, centered on +center+, each as wide as its words.
      def pill_row(center, y, height)
        widths = pill_names.map { pill_width(it, height) }
        gap = 10.0
        most = (2 * (safe.width - margin - (center - safe.x)).clamp(0.0, safe.width)) - gap
        total = widths.sum + ((widths.size - 1) * gap)
        widths = widths.map { it * most / total } if total > most
        total = widths.sum + ((widths.size - 1) * gap)
        x = center - (total / 2.0)
        pill_names.zip(widths).to_h do |name, width|
          rect = Rect.new(x:, y:, width:, height:)
          x += width + gap
          [name, rect]
        end
      end

      def pill_width(name, height)
        size = (height * PillLabel::RATIO).round
        PillLabel.width_with_icon(measure.width(:semibold, size, words.public_send(name)), height)
      end

      # The name's type size, so it fills +width+ and never exceeds what
      # the window's height allows.
      def name_size(width)
        size = layout.type_size(type.game_name)
        size -= 1 while size > 22 && measure.width(:bold, size, words.game_name) > width * 0.96
        grow = width * 0.96
        size += 1 while size < 200 && measure.width(:bold, size + 1, words.game_name) < grow && measure.height(:bold, size + 1) < safe.height * 0.28
        size
      end
    end

    # How big a pill's word is, in the pill's height.
    module PillLabel
      RATIO = 0.32 # the word's size, in the pill's height, as the mocks set it
      GLYPH = 0.45 # how wide an icon beside the word is, in the pill's height
      GAP = 0.22 # the room between the icon and the word, in the pill's height

      # How wide a pill with an icon is for +word_width+ of words, on a pill
      # +height+ tall, with room at either end.
      def self.width_with_icon(word_width, height) = word_width + (height * (GLYPH + GAP + 1.0))
    end
  end
end
