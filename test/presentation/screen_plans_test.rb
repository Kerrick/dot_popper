# frozen_string_literal: true

require_relative "presentation_helper"

# The title's and Game Over's words never collide, whatever lines a
# round leaves them to show and however small the window: each is
# stacked in the room it has, shrinking its type and then leaving out
# the least needed lines.
class ScreenPlansTest < Minitest::Test
  include PresentationTest

  SIZES = [[400, 850], [1200, 800], [800, 500], [640, 400], [400, 320], [844, 390], [1024, 768], [1920, 1080],
           [2560, 1440], [3840, 2160]].freeze
  WORDS = Look::WORDS
  GOAL = WORDS.goal(DotPopper::DailyGoal.for(Date.new(2026, 11, 1)))

  def test_the_titles_lines_never_overlap_each_other_or_the_bottom_row
    SIZES.each do |width, height|
      screen_layout = layout(width, height)
      [0, 75].product([nil, :open, :done], [0, 5], [true, false]) do |best, goal, streak, sizing|
        screen = TitleScreen.new(layout: screen_layout, type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                                 best:, goal: { open: GOAL, done: WORDS.goal_done_line(DotPopper::DailyGoal.for(Date.new(2026, 11, 1))) }[goal], done: goal == :done,
                                 streak:, records: !goal.nil?, sizing: sizing && !goal.nil?)
        plan = screen.plan
        name = "#{width}x#{height} best #{best}, goal #{goal.inspect}, streak #{streak}, sizing #{sizing}"

        assert plan.placed.fits?, name
        %i[title legend prompt].each { assert plan[it], "#{name}: #{it} always shows" }
        assert_apart plan.placed.rects.values + screen.bottom_row, name
        plan.placed.rects.each_value { assert_inside it, screen_layout.safe, name }
        assert_operator plan.backing.bottom, :<=, screen.bottom_row.map(&:y).min, name
      end
    end
  end

  def test_game_overs_lines_never_overlap_each_other_or_the_hud
    SIZES.each do |width, height|
      screen_layout = layout(width, height)
      [true, false].repeated_permutation(5) do |lesson, goal_met, new_best, record, hint|
        below = screen_layout.top + 60
        plan = FinaleScreen.new(layout: screen_layout, type: Look::TYPE, words: WORDS, measure: RoughMeasure.new,
                                scrim: Look::FINALE_BACKING, finale: finale(lesson:, goal_met:, new_best:, record:),
                                below:, hint: (Look::TILT.drag_hint if hint)).plan
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

    assert_equal %i[heading goal score best summary share continue], plan.placed.rects.keys
    assert_in_delta 1.0, plan.placed.scale
  end

  private

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
