# frozen_string_literal: true

require_relative "presentation_helper"

# The title's and Game Over's words never collide, whatever lines a
# game leaves them to show and however small the window: each is
# stacked in the room it has, shrinking its type and then leaving out
# the least needed lines. And on every screen, a press reaches one
# button at most, and a press on a button as drawn reaches it.
class ScreenPlansTest < Minitest::Test
  include PresentationTest

  SIZES = [[400, 850], [1200, 800], [800, 500], [640, 400], [400, 320], [844, 390], [1024, 768], [1920, 1080],
           [2560, 1440], [3840, 2160], [412, 832], [832, 412], [375, 812], [812, 375], [850, 400]].freeze
  WORDS = Style::WORDS
  GOAL = WORDS.goal(DotPopper::DailyGoal.for(Date.new(2026, 11, 1)))

  # A desktop's window may be any size from SMALLEST_WINDOW up, so these
  # step across the whole range, and past it to big screens.
  DESKTOP_WIDTHS = [400, 480, 640, 800, 1000, 1200, 1920, 3840].freeze
  DESKTOP_HEIGHTS = [320, 340, 360, 400, 500, 640, 800, 1080, 2160].freeze

  # On the maintainer's Android phone in portrait, "Done today:" and its
  # goal ran off both sides: a met goal was never broken into lines.
  def assert_goal_fits(plan, done, screen_layout, name)
    return unless plan[:goal]

    measure = RoughMeasure.new
    size = plan.size(:goal)
    plan.goal_lines.each_with_index do |line, i|
      check = done && i.zero? ? measure.height(:semibold, size) * 0.75 : 0.0
      assert_operator measure.width(:semibold, size, line) + check, :<=, screen_layout.safe.width, "#{name}: #{line}"
    end
  end

  CHIPS = [GameOverChip.new(name: :over_goal, text: WORDS.goal_met, glyph: :check, opens: false),
           GameOverChip.new(name: :over_achievement, text: "New achievement: Back from the brink", glyph: :achievement, opens: true),
           GameOverChip.new(name: :over_group, text: "You took the Adventurous Albatrosses title!", glyph: :crown, opens: true)].freeze

  # Game Over at every size, with every line a game can give it: nothing
  # overlaps, everything is inside the safe area, Play again, Home and
  # Share my score always show, and nothing hides the lower half of the
  # pile's bottom row.
  def test_game_overs_lines_never_overlap_each_other
    SIZES.each do |width, height|
      screen_layout = layout(width, height)
      radius = DotPopper::DotSize.fitted(width, height).radius
      [true, false].repeated_permutation(2).to_a.product([[], CHIPS.first(1), CHIPS]) do |(new_score_record, record), chips|
        plan = GameOverScreen.new(layout: screen_layout, type: Style::TYPE, words: WORDS, measure: RoughMeasure.new,
                                  scrim: Style::GAME_OVER_BACKING, game_over: game_over(new_score_record:, record:),
                                  below: screen_layout.safe.y, radius:, chips:, play_note: "22 games left").plan
        name = "#{width}x#{height} new record #{new_score_record}, record #{record}, #{chips.size} chips"

        assert plan.placed.fits?, name
        %i[score play_again].each { assert plan[it], "#{name}: #{it} always shows" }
        assert plan.home_button && plan.share_button, "#{name}: Home and Share my score always show"
        rects = plan.placed.rects.except(:buttons).values + [plan.home_button, plan.share_button]
        assert_apart rects, name
        rects.each { assert_inside it, screen_layout.safe, name }
        assert_operator plan.home_button.right, :<=, plan.share_button.x, "#{name}: Home, then Share my score"
        assert_operator [plan.play_button, plan.home_button].map(&:bottom).max, :<=, height - radius + 1e-6, "#{name}: the pile's floor shows"
      end
    end
  end

  # The share preview, at every size, with the longest results a game
  # can give, and in each input's words: its blocks are apart and inside
  # the card, the card is inside the safe area, every line of the result
  # fits across its bubble, and Close and Copy are side by side, a
  # fingertip tall at least.
  def test_the_share_preview_never_overlaps_or_runs_off_screen
    stats = DotPopper::GameStats.start.with(pops: 128, mistakes: 11, duration: 141.0)
    record = DotPopper::Stats::Record.new(kind: :longest_time_to_pop, value: 12.3)
    screen = format(WORDS.screen_size.fetch(:played), 38, 21)
    SIZES.each do |width, height|
      screen_layout = layout(width, height)
      [InputKind::MOUSE, InputKind::GAMEPAD].product([nil, record], [nil, screen]) do |input, held, played|
        words = WORDS.for(input)
        text = words.share_text(128, stats, score_record: 128, new_score_record: true, record: held, screen: played)
        plan = ShareScreen.new(layout: screen_layout, type: Style::TYPE, words:, measure: RoughMeasure.new,
                               style: Style::SHARE_PREVIEW, lines: text.split("\n")).plan
        name = "#{width}x#{height} #{input.name}, record #{!held.nil?}, screen #{!played.nil?}"

        assert plan.placed.fits?, name
        %i[message note buttons].each { assert plan[it], "#{name}: #{it} always shows" }
        rects = plan.placed.rects.except(:buttons).values + [plan.close, plan.copy]
        assert_apart rects, name
        rects.each { assert_within it, plan.card, name }
        assert_within plan.card, screen_layout.safe, name
        assert_operator plan.close.right, :<=, plan.copy.x, "#{name}: Close is left of Copy"
        [plan.close, plan.copy].each { assert_operator it.height, :>=, 44.0, name }
        assert_lines_fit(plan, name)
      end
    end
  end

  def assert_lines_fit(plan, name)
    measure = RoughMeasure.new
    size = plan.size(:message)
    height = measure.height(:semibold, size)
    room = plan[:message].width - (2 * plan.side)
    wides = plan.lines.map do |line|
      ShareGlyphs.width(line, height) { measure.width(:semibold, size, it) }.tap do |wide|
        assert_operator wide, :<=, room + 1e-6, "#{name}: #{line}"
      end
    end
    # The widest line has the same padding at its right as at its left,
    # unless the buttons below are what the bubble is as wide as.
    spare = room - wides.max
    buttons = plan.copy.right - plan.close.x
    assert_operator [spare.abs, plan[:message].width - buttons].min, :<=, 1e-6, "#{name}: even side padding"
  end

  # The title's legend says the scoring with no word, in the Tutorial's
  # numbers and stopwatch, in two columns that line up.
  def test_the_legend_shows_what_each_dot_does_in_the_tutorials_signs
    rows = Legend.rows.map { |fresh, points, seconds| [fresh, points.text, points.stopwatch, seconds.text, seconds.stopwatch] }
    assert_equal [[true, "+1", false, "+1", true], [false, "−2", false, "−2", true]], rows

    legend = Legend.measure(30.0) { it.size * 15.0 }
    assert_in_delta 30.0 * 0.5 * 2.7, legend.points, 1e-9, "the numbers start past the dot"
    assert_in_delta legend.points + 30.0 + (30.0 * Legend::APART), legend.seconds, 1e-9
    assert_in_delta legend.seconds + 30.0 + (Tally.icon(30.0) * (1 + Tally::GAP)), legend.width, 1e-9,
                    "the second column ends with its stopwatch"
  end

  def test_short_of_room_game_over_lets_the_record_go_first_and_keeps_the_score
    plan = GameOverScreen.new(layout: layout(400, 520), type: Style::TYPE, words: WORDS, measure: RoughMeasure.new,
                              scrim: Style::GAME_OVER_BACKING, game_over: game_over(record: true), below: 0, chips: CHIPS).plan
    order = [:record, :summary, [:chip, 2], [:chip, 1], [:chip, 0], :score_record, :heading]
    dropped = order.reject { plan[it] }

    refute_empty dropped
    assert_equal order.first(dropped.size), dropped
    assert plan[:score]
    assert plan[:play_again]
  end

  # The facts stand in one row where it fits, and one under another
  # where it does not, every one inside the room.
  def test_game_overs_facts_stack_where_a_row_does_not_fit
    huge = game_over.with(stats: DotPopper::GameStats.start.with(pops: 123_456_789, mistakes: 123_456_789, duration: 123_456_789.0))
    wide = GameOverScreen.new(layout: layout(1200, 800), type: Style::TYPE, words: WORDS, measure: RoughMeasure.new,
                              scrim: Style::GAME_OVER_BACKING, game_over:, below: 0).plan
    narrow = GameOverScreen.new(layout: layout(320, 800), type: Style::TYPE, words: WORDS, measure: RoughMeasure.new,
                                scrim: Style::GAME_OVER_BACKING, game_over: huge, below: 0).plan

    assert wide[:summary]
    refute narrow[:summary]
    rows = (0..2).map { narrow[[:fact, it]] }
    assert rows.all?, "each fact on a line of its own"
    assert_operator rows[0].bottom, :<=, rows[1].y
  end

  def test_a_roomy_game_over_shows_every_line_at_full_size
    plan = GameOverScreen.new(layout: layout(1200, 800), type: Style::TYPE, words: WORDS, measure: RoughMeasure.new,
                              scrim: Style::GAME_OVER_BACKING, game_over: game_over, below: 0, chips: CHIPS).plan

    assert_equal [:heading, :score, :score_record, :summary, [:chip, 0], [:chip, 1], [:chip, 2], :play_again, :buttons], plan.placed.rects.keys
    assert_operator plan.backing.bottom, :<=, plan.play_button.y, "Play again stands on the pile, not the backing"
    assert_in_delta 1.0, plan.placed.scale
  end

  DESKTOPS = DESKTOP_WIDTHS.product(DESKTOP_HEIGHTS)

  # The tutorial's Skip stands in the safe area's bottom right corner,
  # where its dots and the HUD never go, a fingertip tall at least.
  def test_skip_stands_in_the_bottom_right_corner
    (SIZES + DESKTOPS).each do |width, height|
      screen_layout = layout(width, height)
      skip = screen_layout.skip_button
      name = "#{width}x#{height}"
      assert_inside skip, screen_layout.safe, name
      assert_operator skip.right, :>, screen_layout.center_x + (screen_layout.safe.width * 0.25), name
      assert_operator skip.bottom, :>, screen_layout.safe.bottom - screen_layout.page_margin - 1, name
      assert_operator skip.height, :>=, 44.0, name
    end
  end

  # The offer of Pro, led by each thing a Free player can tap, at every
  # size: its parts are apart and inside the safe area, clear of Back, and
  # Buy and Restore Purchases always show.
  def test_the_offer_fits_every_screen_whatever_it_leads_with
    (SIZES + DESKTOPS).each do |width, height|
      screen_layout = layout(width, height)
      [[:games, "No games left today."], [:themes, nil], [:achievements, nil], [:groups, nil]].each do |focus, note|
        art = { themes: 100.0, achievements: 110.0 }.fetch(focus, 56.0)
        plan = OfferScreen.new(layout: screen_layout, type: Style::TYPE, words: WORDS, measure: RoughMeasure.new, offering: true, note:, focus:,
                               art:).plan
        name = "#{width}x#{height} #{focus}"
        %i[focus buy restore].each { assert plan[it], "#{name}: #{it} shows" }
        rects = plan.placed.rects.values
        assert_apart rects + [screen_layout.back_button], name
        rects.each { assert_inside it, screen_layout.safe, name }
      end
    end
  end

  # Every screen, at every size, on a phone and on a desktop: a press
  # reaches one button at most, the middle of each button reaches it,
  # no two buttons are drawn over each other, and each is drawn inside
  # the safe area.
  def test_on_every_screen_a_press_reaches_one_button_and_the_middle_of_each_reaches_it
    desktop = DESKTOPS.map { [*it, FakeWindow.new] }
    (SIZES.map { [*it, NoWindowControl.new] } + desktop).each do |width, height, window|
      each_screen(width, height, window:) do |where, show|
        name = "#{width}x#{height} #{where}#{" on a desktop" if window.offered?}"
        controls = show.controls

        refute_empty controls, name
        controls.combination(2) do |one, other|
          refute one.reach.overlaps?(other.reach), "#{name}: #{one.name} and #{other.name} share a reach"
        end
        controls.each do |control|
          frame = control.frame
          assert_equal control.name, show.control_at(frame.center_x, frame.center_y)&.name, "#{name}: #{control.name}"
          assert_inside frame, show.layout.safe, "#{name}: #{control.name}"
        end
        assert_apart controls.map(&:frame), name
      end
    end
  end

  # Home's parts, first launch or after a game, with three large buttons
  # or four, on a phone or with Quit on a desktop, never overlap and stay
  # inside the safe area.
  def test_homes_parts_never_overlap_or_leave_the_safe_area
    (SIZES + DESKTOPS).each do |width, height|
      screen_layout = layout(width, height)
      [true, false].product([3, 4], [true, false]) do |played, tiles, window|
        plan = HomeScreen.new(layout: screen_layout, type: Style::TYPE, words: WORDS, measure: RoughMeasure.new, played:,
                              tile_names: %i[stats achievements themes groups].first(tiles), window:).plan
        name = "#{width}x#{height} played #{played}, #{tiles} tiles, window #{window}"
        parts = [plan.name, plan.legend, plan.play, plan.goal, *plan.tiles.values, *plan.pills.values].compact
        assert_apart parts, name
        parts.each { assert_inside it, screen_layout.safe, name }
        x, y = plan.quit_line
        quit = Rect.new(x: x - 100, y: y - 9, width: 200, height: 18) # "Press B again to quit"
        parts.each { refute quit.overlaps?(it), "#{name}: the question to quit is clear of #{it.to_h}" }
      end
    end
  end

  # On an upright phone the card showed "Pop a bright dot that has been
  # on screen for at least 3", its last word cut: the goal's sentence
  # was wrapped and only its first two lines drawn. Every goal, on every
  # card Home lays out, shows its whole sentence in at most two lines,
  # each across the room left of the divider, and all above the card's
  # bottom edge and its padding. Only the smallest windows leave the card
  # out, as they always have; phones and roomy windows keep it.
  def test_homes_goal_card_shows_every_goal_whole
    measure = RoughMeasure.new
    kept = [[400, 850], [412, 832], [375, 812], [844, 390], [850, 400], [1200, 800], [1920, 1080]]
    (SIZES + DESKTOPS).each do |width, height|
      screen_layout = layout(width, height)
      [3, 4].product([true, false]) do |tiles, window|
        rect = HomeScreen.new(layout: screen_layout, type: Style::TYPE, words: WORDS, measure:, played: true,
                              tile_names: %i[stats achievements themes groups].first(tiles), window:).plan.goal
        assert rect, "#{width}x#{height}, #{tiles} tiles, window #{window}: the card is shown" if kept.include?([width, height])
        next unless rect

        DotPopper::DailyGoal::LIST.each do |goal|
          sentence = WORDS.goal_sentence(goal)
          card = GoalCard.fit(rect, sentence, measure)
          name = "#{width}x#{height}, #{tiles} tiles, window #{window}, #{goal}"
          assert_equal sentence, card.lines.join(" "), name
          assert_operator card.lines.size, :<=, 2, name
          card.lines.each { assert_operator measure.width(:bold, card.text_size, it), :<=, card.divider - rect.x - (2 * card.pad) + 1e-6, "#{name}: #{it}" }
          bottom = card.top + (card.lines.size * measure.height(:bold, card.text_size))
          assert_operator bottom, :<=, rect.bottom - (card.pad / 2.0) + 1e-6, name
        end
      end
    end
  end

  # The Credits screen: at 400x850, 850x400, 1200x800 and every other
  # size, the heading, the window of text and Back are apart and inside
  # the safe area, every line fits across the window, and scrolled to
  # the end the last line is in it.
  def test_the_credits_screen_never_overlaps_or_runs_off_screen
    SIZES.each do |width, height|
      screen_layout = layout(width, height)
      show = credits_show(screen_layout)
      show.open_credits
      page = show.credits_layout
      window = page.window
      name = "#{width}x#{height}"
      title = show.words.button(:credits_title)
      size, middle = show.heading_place(title)
      wide = RoughMeasure.new.width(:bold, size, title)
      heading = Rect.new(x: middle - (wide / 2.0), y: page.heading_y - (size / 2.0), width: wide, height: size)

      assert_inside window, screen_layout.safe, name
      assert_apart [heading, window, screen_layout.back_button], name
      assert_operator window.x, :>=, screen_layout.safe.x, name
      assert_operator window.right, :<=, screen_layout.safe.right, name
      assert_operator window.height, :>, page.line * 2, "#{name}: room to read"
      measure = RoughMeasure.new
      show.credits_lines.rows.each do |row|
        face = { heading: :bold, legal: :mono }.fetch(row.kind, :semibold)
        size = row.kind == :heading ? CreditsLines.heading_size(page.text_size) : page.text_size
        assert_operator measure.width(face, size, row.text), :<=, window.width + 1e-6, "#{name}: #{row.text}"
      end
      show.scroll_key(:end)
      assert_in_delta show.credits_lines.height - window.height, show.credits.offset, 1e-6, name
    end
  end

  private

  def credits_show(screen_layout)
    long = ["License text with a longer word, #{"x" * 90}, and a ruled line", "-" * 70, "", "  1. an indented item"]
    notices = Notices.new(iosevka: Array.new(40) { long.join("\n") }.join("\n\n"), ofl: "Fredoka text", lota: "Lota text",
                          fledge: ["Fledge text"])
    cabinet = DotPopper::Cabinet.new(field(screen_layout.width, screen_layout.height), random: Random.new(2))
    show = Show.new(cabinet:, layout: screen_layout, sounds: FakeSounds.new, radius: R, notices:, measure: RoughMeasure.new)
    show.primary
    cabinet.update(30)
    show.update(1.0)
    cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    show.back
    show.open_settings
    show
  end

  # A Show on each screen in turn, with every button it can offer, and
  # with +window+'s on Home: the first Home, Game Over, the share
  # preview, Home after a game, Stats, and Undo there once the stats are
  # cleared, Achievements and an achievement's dialog, Themes, Settings
  # at its top and scrolled to its end, Credits, and Privacy.
  def each_screen(width, height, window: NoWindowControl.new)
    cabinet = DotPopper::Cabinet.new(field(width, height), random: Random.new(2))
    show = Show.new(cabinet:, layout: layout(width, height), sounds: FakeSounds.new, radius: R, window:)
    yield "the first Home", show
    show.primary
    cabinet.update(30)
    show.update(1.0)
    yield "Game Over", show
    show.share
    yield "the share preview", show
    show.close_share
    cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    show.back
    yield "Home after a game", show
    show.open_stats
    yield "the Stats screen", show
    show.tap(*middle(show.clear_reach))
    show.update(Style::RECORDS_CLEAR.hold)
    yield "the Stats screen with Undo", show
    show.back
    show.open_achievements
    yield "Achievements", show
    show.open_achievement(DotPopper::Achievement::IDS.first)
    yield "an achievement's dialog", show
    show.back
    show.back
    show.open_themes
    yield "Themes", show
    show.input = InputKind::GAMEPAD
    yield "Themes with a controller", show
    show.input = InputKind::MOUSE
    show.back
    show.open_settings
    yield "Settings", show
    show.scroll_key(:end)
    yield "Settings scrolled to its end", show
    show.open_credits
    yield "the Credits screen", show
    show.back
    show.open_privacy
    yield "Privacy", show
  end

  def middle(rect) = [rect.center_x, rect.center_y]

  def game_over(goal_met: false, new_score_record: false, record: false)
    GameOver.new(style: Style::GAME_OVER, score: 128, score_record: new_score_record ? 128 : 140, new_score_record:, at: 0.0, goal_met:,
               record: (DotPopper::Stats::Record.new(kind: :most_dots_in_a_row, value: 31) if record))
  end

  def assert_apart(rects, name)
    rects.combination(2) do |one, other|
      slack = 1e-6
      apart = one.right <= other.x + slack || other.right <= one.x + slack || one.bottom <= other.y + slack ||
              other.bottom <= one.y + slack
      assert apart, "#{name}: #{one.to_h} overlaps #{other.to_h}"
    end
  end

  # +rect+ wholly inside +outer+, across as well as down.
  def assert_within(rect, outer, name)
    slack = 1e-6
    inside = rect.x >= outer.x - slack && rect.right <= outer.right + slack && rect.y >= outer.y - slack &&
             rect.bottom <= outer.bottom + slack
    assert inside, "#{name}: #{rect.to_h} is not inside #{outer.to_h}"
  end

  def assert_inside(rect, safe, name)
    assert_operator rect.y, :>=, safe.y, name
    assert_operator rect.bottom, :<=, safe.bottom, name
  end
end
