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
        assert_operator plan.backing.bottom, :<=, screen.bottom_row.map(&:y).min, name
      end
    end
  end

  def test_game_overs_lines_never_overlap_each_other_or_the_hud
    SIZES.each do |width, height|
      screen_layout = layout(width, height)
      radius = DotPopper::DotSize.fitted(width, height).radius
      [true, false].repeated_permutation(5) do |lesson, goal_met, new_best, record, hint|
        below = screen_layout.top + 60
        plan = FinaleScreen.new(layout: screen_layout, type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                                scrim: Look::FINALE_BACKING, finale: finale(lesson:, goal_met:, new_best:, record:),
                                below:, hint: (Look::TILT.drag_hint if hint), radius:).plan
        name = "#{width}x#{height} lesson #{lesson}, goal #{goal_met}, new best #{new_best}, record #{record}, " \
               "hint #{hint}"

        assert plan.placed.fits?, name
        %i[score continue].each { assert plan[it], "#{name}: #{it} always shows" }
        assert_apart plan.placed.rects.values, name
        plan.placed.rects.each_value do |rect|
          assert_operator rect.y, :>=, below, name
          assert_inside rect, screen_layout.safe, name
        end
        assert_operator plan.backing.width, :<=, screen_layout.safe.width, name
      end
    end
  end

  def test_short_of_room_the_title_lets_the_streak_go_before_the_goal_and_the_best
    plan = TitleScreen.new(layout: layout(400, 320), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                           best: 75, goal: GOAL, streak: 5, records: true, sizing: true).plan
    dropped = %i[streak goal best].reject { plan[it] }

    refute_empty dropped
    assert_equal %i[streak goal best].first(dropped.size), dropped
  end

  def test_short_of_room_game_over_lets_the_hint_go_first_and_keeps_the_score
    plan = FinaleScreen.new(layout: layout(640, 400), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                            scrim: Look::FINALE_BACKING, finale: finale(lesson: true, goal_met: true, record: true),
                            below: 70, hint: Look::TILT.drag_hint).plan

    refute plan[:hint]
    assert plan[:score]
    assert plan[:continue]
  end

  def test_a_roomy_game_over_shows_every_line_at_full_size
    plan = FinaleScreen.new(layout: layout(1200, 800), type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                            scrim: Look::FINALE_BACKING, finale: finale(goal_met: true), below: 80).plan

    assert_equal %i[heading goal score best summary continue share], plan.placed.rects.keys
    assert_operator plan.backing.bottom, :<=, plan.continue_button.y, "the buttons stand on the pile, not the backing"
    assert_in_delta 1.0, plan.placed.scale
  end

  # The Android playtest: on an upright phone, a tap on the lower half of
  # the dot size's Standard also reached "Your records" below it. Now no
  # point is in two buttons' reaches on any screen, and a tap at the
  # middle of each button as drawn reaches that button.
  def test_on_every_screen_a_press_reaches_one_button_and_the_middle_of_each_reaches_it
    SIZES.each do |width, height|
      each_screen(width, height) do |where, show|
        name = "#{width}x#{height} #{where}"
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

  private

  # A Show on each screen in turn, with every button it can offer: the
  # first title, Game Over, the title after a round with the dot-size
  # choice where it shows, the Records screen, and Undo there once the
  # records are cleared.
  def each_screen(width, height)
    game = DotPopper::Game.new(field(width, height), random: Random.new(2))
    show = Show.new(game:, layout: layout(width, height), sounds: FakeSounds.new, radius: R)
    yield "the first title", show
    show.primary
    game.update(30)
    show.update(1.0)
    yield "Game Over", show
    game.update(DotPopper::Rules::GAME_OVER_GRACE)
    show.primary
    yield "the title after a round", show
    show.open_records
    yield "the Records screen", show
    show.tap(*middle(show.clear_reach))
    show.update(Look::RECORDS_CLEAR.hold)
    yield "the Records screen with Undo", show
  end

  def middle(rect) = [rect.center_x, rect.center_y]

  def finale(lesson: false, goal_met: false, new_best: false, record: false)
    Finale.new(look: Look::FINALE, score: 128, best: new_best ? 128 : 140, new_best:, at: 0.0, goal_met:,
               lesson: (WORDS.covered if lesson),
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

  def assert_inside(rect, safe, name)
    assert_operator rect.y, :>=, safe.y, name
    assert_operator rect.bottom, :<=, safe.bottom, name
  end
end
