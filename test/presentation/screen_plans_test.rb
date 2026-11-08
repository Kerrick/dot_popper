# frozen_string_literal: true

require_relative "presentation_helper"

# The title's and Game Over's words never collide, whatever lines a
# round leaves them to show and however small the window: each is
# stacked in the room it has, shrinking its type and then leaving out
# the least needed lines. And on every screen, a press reaches one
# button at most, and a press on a button as drawn reaches it.
class ScreenPlansTest < Minitest::Test
  include PresentationTest

  SIZES = [[400, 850], [1200, 800], [800, 500], [640, 400], [400, 320], [844, 390], [1024, 768], [1920, 1080],
           [2560, 1440], [3840, 2160], [412, 832], [832, 412], [375, 812], [812, 375], [850, 400]].freeze
  WORDS = Look::WORDS
  GOAL = WORDS.goal(DotPopper::DailyGoal.for(Date.new(2026, 11, 1)))

  def test_the_titles_lines_never_overlap_each_other_or_the_bottom_row
    SIZES.each do |width, height|
      screen_layout = layout(width, height)
      radii = [R, DotPopper::DotSize.fitted(width, height).radius]
      [0, 75].product([nil, :open, :done], [0, 5], [true, false], radii) do |best, goal, streak, sizing, radius|
        screen = TitleScreen.new(layout: screen_layout, type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                                 best:, goal: { open: GOAL, done: WORDS.goal_done_line(DotPopper::DailyGoal.for(Date.new(2026, 11, 1))) }[goal], done: goal == :done,
                                 streak:, records: !goal.nil?, sizing: sizing && !goal.nil?, radius:)
        plan = screen.plan
        name = "#{width}x#{height} best #{best}, goal #{goal.inspect}, streak #{streak}, sizing #{sizing}, R #{radius}"

        assert plan.placed.fits?, name
        %i[title legend play].each { assert plan[it], "#{name}: #{it} always shows" }
        # A dot across, with the dots fitted to any screen a phone has,
        # and with standard ones wherever there is room for it.
        if height >= 375 && (radius < R || height >= 500)
          assert_operator plan.play_button.height, :>=, 2 * radius, "#{name}: Play is at least a dot across"
        end
        assert_apart plan.placed.rects.values + screen.bottom_row, name
        plan.placed.rects.each_value { assert_inside it, screen_layout.safe, name }
        screen.bottom_row.each { assert_within it, screen_layout.safe, name }
        assert_operator plan.backing.bottom, :<=, screen.bottom_row.map(&:y).min, name
        assert_goal_fits(plan, goal == :done, screen_layout, name)
        others = plan.placed.rects.except(plan.quit_over).values + screen.bottom_row
        others.each { assert_apart [plan.quit_line, it], "#{name}: quit" }
        assert_inside plan.quit_line, screen_layout.safe, "#{name}: quit"
      end
    end
  end

  # A desktop's window may be any size from SMALLEST_WINDOW up, so these
  # step across the whole range, and past it to big screens.
  DESKTOP_WIDTHS = [400, 480, 640, 800, 1000, 1200, 1920, 3840].freeze
  DESKTOP_HEIGHTS = [320, 340, 360, 400, 500, 640, 800, 1080, 2160].freeze

  # On a desktop, "Full screen" and Quit join the title at every window
  # size: labelled in a row of their own above the bottom row's right
  # end, or, only where the smallest windows leave no room for that
  # row, their icons in the top right corner. Wherever they are, the
  # title's lines still fit, apart from them and from every other button,
  # and they stay put whatever the title shows, the dot-size choice
  # included, so they never move as a round is played.
  def test_on_a_desktop_full_screen_and_quit_fit_the_title_at_every_window_size
    DESKTOP_WIDTHS.product(DESKTOP_HEIGHTS) do |width, height|
      screen_layout = layout(width, height)
      radius = DotPopper::DotSize.fitted(width, height).radius
      places = [[0, nil, false], [75, :open, false], [75, :done, true], [0, :open, true]].map do |best, goal, sizing|
        screen = TitleScreen.new(layout: screen_layout, type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                                 best:, goal: { open: GOAL, done: WORDS.goal_done_line(DotPopper::DailyGoal.for(Date.new(2026, 11, 1))) }[goal],
                                 done: goal == :done, streak: 5, records: !goal.nil?, sizing:, radius:, window: true)
        plan = screen.plan
        buttons = plan.window_buttons
        name = "#{width}x#{height} best #{best}, goal #{goal.inspect}, sizing #{sizing}"

        assert plan.placed.fits?, name
        %i[title legend play].each { assert plan[it], "#{name}: #{it} always shows" }
        buttons.rects.each do |button|
          assert_operator button.height, :>=, 44.0, name
          assert_within button, screen_layout.safe, name
        end
        screen.bottom_row(buttons).each { assert_within it, screen_layout.safe, name }
        assert_operator buttons.fullscreen.right, :<, buttons.quit.x, "#{name}: Quit is to the right"
        bottom_row = screen.bottom_row(buttons)
        assert_apart plan.placed.rects.values + (bottom_row | buttons.rects), name
        others = plan.placed.rects.except(plan.quit_over).values + bottom_row + buttons.rects
        others.each { assert_apart [plan.quit_line, it], "#{name}: quit" }
        buttons
      end
      assert_equal 1, places.uniq.size, "#{width}x#{height}: they stay put"
    end
  end

  # They are labelled wherever the bottom row has room for their words,
  # their icons in the row where it has room for those, their icons a row
  # above it on a narrow window, and only on the smallest, their icons in
  # the top right corner.
  def test_the_window_buttons_are_labelled_wherever_the_row_has_room
    place = lambda do |width, height|
      buttons = TitleScreen.new(layout: layout(width, height), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                                window: true, radius: DotPopper::DotSize.fitted(width, height).radius).plan.window_buttons
      [buttons.place, buttons.labelled]
    end

    [[1200, 800], [800, 500], [1920, 1080], [2560, 1440]].each { assert_equal [:row, true], place[*it], it.join("x") }
    assert_equal [:row, false], place[640, 400]
    assert_equal [:above, false], place[400, 850]
    assert_equal [:corner, false], place[400, 320]
    wide = TitleScreen.new(layout: layout(1200, 800), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                           window: true).plan
    assert_equal wide.mute_button.y, wide.window_buttons.quit.y, "in the bottom row"
    assert_operator wide.how_to_play_button.right, :<, wide.window_buttons.fullscreen.x, "after How to play"
    assert_operator wide.window_buttons.quit.right, :<, wide.mute_button.x, "before the mute button"
  end

  # The title reads top down: the name, the legend and Play, which say
  # what the game is and how to start it, and under Play, further off,
  # the player's own best, goal and streak, closer to each other than to
  # Play.
  def test_play_follows_the_legend_and_the_players_own_lines_stand_apart_under_it
    plan = TitleScreen.new(layout: layout(1200, 800), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                           best: 75, goal: GOAL, streak: 5, records: true, window: true).plan

    assert_equal %i[title legend play best goal streak], plan.placed.rects.keys
    under_play = plan[:best].y - plan.play_button.bottom
    assert_operator under_play, :>, plan.play_button.y - plan[:legend].bottom, "the player's own lines stand apart"
    assert_operator under_play, :>, plan[:goal].y - plan[:best].bottom, "and together"
    assert_operator plan.backing.bottom, :>=, plan[:streak].bottom, "the backing reaches every line"
  end

  # Phones and tablets show no window buttons, and their titles are laid
  # out as before.
  def test_without_a_window_to_switch_the_title_has_no_window_buttons
    SIZES.each do |width, height|
      screen = TitleScreen.new(layout: layout(width, height), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                               records: true, sizing: true)
      plan = screen.plan

      assert_nil plan.window_buttons
      assert_equal layout(width, height).sizing_control, plan.sizing_control, "#{width}x#{height}"
    end
  end

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

  def test_game_overs_lines_never_overlap_each_other_or_the_hud
    SIZES.each do |width, height|
      screen_layout = layout(width, height)
      radius = DotPopper::DotSize.fitted(width, height).radius
      [true, false].repeated_permutation(3) do |goal_met, new_best, record|
        below = screen_layout.top + 60
        plan = FinaleScreen.new(layout: screen_layout, type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                                scrim: Look::FINALE_BACKING, finale: finale(goal_met:, new_best:, record:),
                                below:, radius:).plan
        name = "#{width}x#{height} goal #{goal_met}, new best #{new_best}, record #{record}"

        assert plan.placed.fits?, name
        %i[score continue].each { assert plan[it], "#{name}: #{it} always shows" }
        assert_apart plan.placed.rects.values, name
        plan.placed.rects.each_value do |rect|
          assert_operator rect.y, :>=, below, name
          assert_inside rect, screen_layout.safe, name
        end
        assert_operator plan.backing.width, :<=, screen_layout.safe.width, name
        # The filled Continue leaves the lower half of the pile's bottom
        # row clear: on a short window it once hid the bright dot there.
        assert_operator plan.continue_button.bottom, :<=, height - radius, "#{name}: Continue clears the pile's floor"
      end
    end
  end

  # The share preview, at every size, with the longest results a round
  # can give, and in each input's words: its blocks are apart and inside
  # the card, the card is inside the safe area, every line of the result
  # fits across its bubble, and Close and Copy are side by side, a
  # fingertip tall at least.
  def test_the_share_preview_never_overlaps_or_runs_off_screen
    stats = DotPopper::RoundStats.start.with(pops: 128, slips: 11, duration: 141.0)
    record = DotPopper::LifetimeStats::Record.new(kind: :longest_wait, value: 12.3)
    screen = format(WORDS.screen_size.fetch(:played), 38, 21)
    SIZES.each do |width, height|
      screen_layout = layout(width, height)
      [InputKind::MOUSE, InputKind::GAMEPAD].product([nil, record], [nil, screen]) do |input, held, played|
        words = WORDS.for(input)
        text = words.share_text(128, stats, best: 128, new_best: true, record: held, screen: played)
        plan = ShareScreen.new(layout: screen_layout, type: Look::TYPE, words:, measure: RoughMeasure.new,
                               look: Look::SHARE_PREVIEW, lines: text.split("\n")).plan
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

  def test_short_of_room_the_title_lets_the_streak_go_before_the_goal_and_the_best
    plan = TitleScreen.new(layout: layout(400, 320), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                           best: 75, goal: GOAL, streak: 5, records: true, sizing: true).plan
    dropped = %i[streak goal best].reject { plan[it] }

    refute_empty dropped
    assert_equal %i[streak goal best].first(dropped.size), dropped
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
    plan = FinaleScreen.new(layout: layout(640, 330), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                            scrim: Look::FINALE_BACKING, finale: finale(goal_met: true, record: true), below: 70).plan
    order = %i[record summary goal best heading share]
    dropped = order.reject { plan[it] }

    refute_empty dropped
    assert_equal order.first(dropped.size), dropped
    assert plan[:score]
    assert plan[:continue]
  end

  def test_a_roomy_game_over_shows_every_line_at_full_size
    plan = FinaleScreen.new(layout: layout(1200, 800), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                            scrim: Look::FINALE_BACKING, finale: finale(goal_met: true), below: 80).plan

    assert_equal %i[heading goal score best summary share continue], plan.placed.rects.keys
    assert_operator plan.backing.bottom, :<=, plan.continue_button.y, "Continue stands on the pile, not the backing"
    assert_operator plan.backing.bottom, :>=, plan.share_button.bottom, "Share my score is backed with the score"
    assert_in_delta 1.0, plan.placed.scale
  end

  # The Android playtest: on an upright phone, a tap on the lower half of
  # the dot size's Standard also reached "Your records" below it. Now no
  # point is in two buttons' reaches on any screen, and a tap at the
  # middle of each button as drawn reaches that button. On a desktop's
  # window, of any size it can be, the same holds with "Full screen" and
  # Quit on the title.
  def test_on_every_screen_a_press_reaches_one_button_and_the_middle_of_each_reaches_it
    desktop = DESKTOP_WIDTHS.product(DESKTOP_HEIGHTS).map { [*it, FakeWindow.new] }
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
          assert_operator control.reach.height, :>=, [frame.height, 44.0].max - 1e-6, "#{name}: #{control.name}"
        end
        assert_apart controls.map(&:frame), name
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
      heading = Rect.new(x: window.x, y: page.heading_y - (page.heading_size / 2.0), width: window.width, height: page.heading_size)

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
      show.credits_key(:end)
      assert_in_delta show.credits_lines.height - window.height, show.credits.offset, 1e-6, name
    end
  end

  private

  def credits_show(screen_layout)
    long = ["License text with a longer word, #{"x" * 90}, and a ruled line", "-" * 70, "", "  1. an indented item"]
    notices = Notices.new(iosevka: Array.new(40) { long.join("\n") }.join("\n\n"), ofl: "Fredoka text", lota: "Lota text",
                          fledge: ["Fledge text"])
    game = DotPopper::Game.new(field(screen_layout.width, screen_layout.height), random: Random.new(2))
    show = Show.new(game:, layout: screen_layout, sounds: FakeSounds.new, radius: R, notices:, measure: RoughMeasure.new)
    show.primary
    game.update(30)
    show.update(1.0)
    game.update(DotPopper::Rules::GAME_OVER_GRACE)
    show.primary
    show.open_records
    show
  end

  # A Show on each screen in turn, with every button it can offer, and
  # with +window+'s on the title: the
  # first title, Game Over, the title after a round with the dot-size
  # choice where it shows, the Records screen, and Undo there once the
  # records are cleared.
  def each_screen(width, height, window: NoWindowControl.new)
    game = DotPopper::Game.new(field(width, height), random: Random.new(2))
    show = Show.new(game:, layout: layout(width, height), sounds: FakeSounds.new, radius: R, window:)
    yield "the first title", show
    show.primary
    game.update(30)
    show.update(1.0)
    yield "Game Over", show
    show.share
    yield "the share preview", show
    show.close_share
    game.update(DotPopper::Rules::GAME_OVER_GRACE)
    show.primary
    yield "the title after a round", show
    show.open_records
    yield "the Records screen", show
    show.tap(*middle(show.clear_reach))
    show.update(Look::RECORDS_CLEAR.hold)
    yield "the Records screen with Undo", show
    show.open_credits
    yield "the Credits screen", show
  end

  def middle(rect) = [rect.center_x, rect.center_y]

  def finale(goal_met: false, new_best: false, record: false)
    Finale.new(look: Look::FINALE, score: 128, best: new_best ? 128 : 140, new_best:, at: 0.0, goal_met:,
               record: (DotPopper::LifetimeStats::Record.new(kind: :longest_run, value: 31) if record))
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
