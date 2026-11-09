# frozen_string_literal: true

require "test_helper"

class CabinetTest < Minitest::Test
  include DotPopperTest
  Cabinet = DotPopper::Cabinet
  Events = DotPopper::Events

  def setup
    @store = DotPopper::ScoreRecord::Memory.new
    @cabinet = Cabinet.new(field, score_record: DotPopper::ScoreRecord.new(@store), random: Random.new(9))
    @heard = []
    @cabinet.subscribe { @heard << it }
  end

  def test_the_game_starts_on_the_title
    assert_instance_of Cabinet::Title, @cabinet.state
    assert_nil @cabinet.game
  end

  def test_a_press_on_the_title_starts_a_fresh_game_without_tapping_anything
    @cabinet.press(400, 300)

    assert_instance_of Cabinet::Playing, @cabinet.state
    assert_equal 0, @cabinet.game.score
    assert_equal 10.0, @cabinet.game.countdown.remaining
    assert_equal 1, @cabinet.game.dots.size
    assert_instance_of Events::GameStarted, @heard.last
  end

  def test_presses_in_play_reach_the_game_and_are_announced
    @cabinet.press(0, 0)
    target = @cabinet.game.dots.first

    @cabinet.press(target.x, target.y)

    assert_equal 1, @cabinet.game.score
    assert_instance_of Events::Popped, @heard.last
  end

  def test_when_time_runs_out_the_game_is_over_and_shows_the_final_score
    play_to_score(1)
    @cabinet.update(20)

    assert_instance_of Cabinet::GameOver, @cabinet.state
    assert_equal 1, @cabinet.state.score
    assert_instance_of Events::GameEnded, @heard.last
  end

  def test_a_penalty_that_empties_the_clock_ends_the_game_at_once
    @cabinet.press(0, 0)
    target = @cabinet.game.dots.first
    @cabinet.press(target.x, target.y)
    @cabinet.update(10.5) # 0.5 s left, and the popped dot is still on top where it went
    popped = @cabinet.game.dots.first

    @cabinet.press(popped.x, popped.y)

    assert_instance_of Cabinet::GameOver, @cabinet.state
  end

  def test_game_over_ignores_presses_for_a_moment_then_returns_to_the_title
    @cabinet.press(0, 0)
    @cabinet.update(11)

    @cabinet.press(400, 300)
    assert_instance_of Cabinet::GameOver, @cabinet.state

    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @cabinet.press(400, 300)
    assert_instance_of Cabinet::Title, @cabinet.state
  end

  def test_presses_outside_play_do_not_change_the_finished_game
    play_to_score(1)
    @cabinet.update(11)
    game = @cabinet.game

    @cabinet.update(5)
    @cabinet.press(400, 300)
    @cabinet.press(400, 300)

    assert_equal 1, game.score
    assert_equal 0.0, game.countdown.remaining
  end

  def test_a_new_game_starts_fresh
    play_to_score(2)
    @cabinet.update(20)
    @cabinet.update(1)
    @cabinet.press(0, 0) # to the title
    @cabinet.press(0, 0) # and a new game

    assert_equal 0, @cabinet.game.score
    assert_equal 1, @cabinet.game.dots.size
    assert_equal 10.0, @cabinet.game.countdown.remaining
  end

  # 800 by 600 is 16 by 12 radii, a phone-sized field, and 1200 by 800 a
  # tablet-sized one.
  def test_a_game_counts_among_the_records_of_the_screen_it_started_on
    assert_equal DotPopper::SizeClass::SMALL, @cabinet.size_class
    play_to_score(2)
    @cabinet.screen = field(1200, 800)
    @cabinet.update(20)

    assert_equal DotPopper::SizeClass::SMALL, @heard.last.size_class
    assert_equal 2, @cabinet.score_record.of(DotPopper::SizeClass::SMALL)
    assert_equal 0, @cabinet.score_record.of(DotPopper::SizeClass::MEDIUM)
    assert_equal DotPopper::SizeClass::MEDIUM, @cabinet.size_class, "the next game counts with the new size"
  end

  # A class's first game sets its best, but beat nothing, so it is not
  # announced as a new one.
  def test_the_score_record_is_kept_and_only_a_beaten_one_is_a_new_score_record
    play_to_score(2)
    @cabinet.update(20)

    assert_equal 2, @cabinet.score_record.of(DotPopper::SizeClass::SMALL)
    assert_equal "small=2\n", @store.read
    assert @heard.last.first
    refute @heard.last.new_score_record

    @cabinet.update(1)
    @cabinet.press(0, 0)
    @cabinet.press(0, 0)
    @cabinet.update(20)
    refute @heard.last.first
    refute @heard.last.new_score_record
    assert_equal 2, @heard.last.score_record

    @cabinet.update(1)
    @cabinet.press(0, 0)
    play_to_score(3)
    @cabinet.update(20)
    assert @heard.last.new_score_record
    assert_equal 3, @heard.last.score_record
  end

  def test_a_new_game_uses_the_field_as_it_is_when_the_game_starts
    @cabinet.screen = field(300, 200)
    @cabinet.press(0, 0)

    assert_equal 300, @cabinet.game.field.width
  end

  # 1200 by 800 is the reference window, where a fitted dot is the usual
  # 50; 600 by 400 fits a radius of 25, which the rules raise to 30.
  def test_sized_to_the_screen_sets_each_games_radius_when_it_starts_and_keeps_it
    @cabinet.screen = field(600, 400)
    @cabinet.sizing = DotPopper::DotSizing::SIZED_TO_SCREEN
    @cabinet.press(0, 0)
    assert_in_delta 30.0, @cabinet.game.field.radius
    assert_equal DotPopper::SizeClass::FITTED, @cabinet.state.size_class

    @cabinet.screen = field(1200, 800)
    @cabinet.sizing = DotPopper::DotSizing::STANDARD
    assert_in_delta 30.0, @cabinet.game.field.radius, 0.001, "a game keeps its radius through a resize"
    assert_equal 1200, @cabinet.game.field.width
    assert_equal DotPopper::DotSizing::SIZED_TO_SCREEN, @cabinet.sizing, "only the title changes the choice"
    assert_in_delta 50.0, @cabinet.field.radius, 0.001, "the next game fits the new screen"
  end

  def test_a_subscriber_must_be_a_listener_or_a_block
    assert_raises(ArgumentError) { @cabinet.subscribe }
  end

  def test_each_game_has_a_seed_of_its_own_that_replays_its_dots
    @cabinet.press(0, 0)
    first = @heard.last.seed
    seeded = DotPopper::Game.new(field, random: Random.new(first))

    assert_equal seeded.dots.to_a, @cabinet.game.dots.to_a
    finish_and_restart
    refute_equal first, @heard.last.seed
  end

  private

  def finish_and_restart
    @cabinet.update(20)
    @cabinet.update(1)
    @cabinet.press(0, 0)
    @cabinet.press(0, 0)
  end

  def play_to_score(points)
    @cabinet.press(0, 0)
    points.times do
      fresh = @cabinet.game.dots.find(&:fresh?)
      clear_around!(@cabinet.game, fresh)
      @cabinet.press(fresh.x, fresh.y)
    end
  end
  def test_the_title_resumes_a_game_from_where_the_tutorial_left_it
    dots = DotPopper::Stack.new(dots: [dot(300, 300, popped: true, id: 0), dot(500, 300, id: 1)])
    @cabinet.resume(field: field, dots:, score: 1, seconds: 11.0)

    assert_instance_of Cabinet::Playing, @cabinet.state
    assert_equal [1, 11.0], [@cabinet.game.score, @cabinet.game.countdown.remaining]
    assert_equal dots, @cabinet.game.dots
    started = @heard.last
    assert_instance_of Events::GameStarted, started
    assert_same @cabinet.game, started.game

    @cabinet.update(20)
    assert_instance_of Cabinet::GameOver, @cabinet.state
    assert_equal 1, @cabinet.state.score
    assert_equal 1, @cabinet.score_record.of(@cabinet.size_class), "it counts toward the records as any game does"
  end

  def test_only_the_title_resumes_a_game
    @cabinet.press(0, 0)
    game = @cabinet.game
    @cabinet.resume(field: field, dots: DotPopper::Stack.new(dots: [dot(500, 300)]), score: 5, seconds: 11.0)

    assert_same game, @cabinet.game
  end
end
