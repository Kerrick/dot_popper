# frozen_string_literal: true

require "test_helper"

class GameTest < Minitest::Test
  include DotPopperTest
  Game = DotPopper::Game
  Events = DotPopper::Events

  def setup
    @store = DotPopper::BestScore::Memory.new
    @game = Game.new(field, best: DotPopper::BestScore.new(@store), random: Random.new(9))
    @heard = []
    @game.subscribe { @heard << it }
  end

  def test_the_game_starts_on_the_title
    assert_instance_of Game::Title, @game.state
    assert_nil @game.round
  end

  def test_a_press_on_the_title_starts_a_fresh_round_without_tapping_anything
    @game.press(400, 300)

    assert_instance_of Game::Playing, @game.state
    assert_equal 0, @game.round.score
    assert_equal 10.0, @game.round.countdown.remaining
    assert_equal 1, @game.round.dots.size
    assert_instance_of Events::RoundStarted, @heard.last
  end

  def test_presses_in_play_reach_the_round_and_are_announced
    @game.press(0, 0)
    target = @game.round.dots.first

    @game.press(target.x, target.y)

    assert_equal 1, @game.round.score
    assert_instance_of Events::Popped, @heard.last
  end

  def test_when_time_runs_out_the_game_is_over_and_shows_the_final_score
    play_to_score(1)
    @game.update(20)

    assert_instance_of Game::GameOver, @game.state
    assert_equal 1, @game.state.score
    assert_instance_of Events::RoundEnded, @heard.last
  end

  def test_a_penalty_that_empties_the_clock_ends_the_game_at_once
    @game.press(0, 0)
    target = @game.round.dots.first
    @game.press(target.x, target.y)
    @game.update(10.5) # 0.5 s left, and the popped dot is still on top where it went
    popped = @game.round.dots.first

    @game.press(popped.x, popped.y)

    assert_instance_of Game::GameOver, @game.state
  end

  def test_game_over_ignores_presses_for_a_moment_then_returns_to_the_title
    @game.press(0, 0)
    @game.update(11)

    @game.press(400, 300)
    assert_instance_of Game::GameOver, @game.state

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @game.press(400, 300)
    assert_instance_of Game::Title, @game.state
  end

  def test_presses_outside_play_do_not_change_the_finished_round
    play_to_score(1)
    @game.update(11)
    round = @game.round

    @game.update(5)
    @game.press(400, 300)
    @game.press(400, 300)

    assert_equal 1, round.score
    assert_equal 0.0, round.countdown.remaining
  end

  def test_a_new_round_starts_fresh
    play_to_score(2)
    @game.update(20)
    @game.update(1)
    @game.press(0, 0) # to the title
    @game.press(0, 0) # and a new round

    assert_equal 0, @game.round.score
    assert_equal 1, @game.round.dots.size
    assert_equal 10.0, @game.round.countdown.remaining
  end

  # 800 by 600 is 16 by 12 radii, a phone-sized field, and 1200 by 800 a
  # tablet-sized one.
  def test_a_round_counts_among_the_bests_of_the_screen_it_started_on
    assert_equal DotPopper::SizeClass::SMALL, @game.size_class
    play_to_score(2)
    @game.screen = field(1200, 800)
    @game.update(20)

    assert_equal DotPopper::SizeClass::SMALL, @heard.last.size_class
    assert_equal 2, @game.best.of(DotPopper::SizeClass::SMALL)
    assert_equal 0, @game.best.of(DotPopper::SizeClass::MEDIUM)
    assert_equal DotPopper::SizeClass::MEDIUM, @game.size_class, "the next round counts with the new size"
  end

  def test_the_best_score_is_kept_and_a_new_best_is_announced
    play_to_score(2)
    @game.update(20)

    assert_equal 2, @game.best.of(DotPopper::SizeClass::SMALL)
    assert_equal "small=2\n", @store.read
    assert @heard.last.new_best

    @game.update(1)
    @game.press(0, 0)
    @game.press(0, 0)
    @game.update(20)
    refute @heard.last.new_best
    assert_equal 2, @heard.last.best
  end

  def test_a_new_round_uses_the_field_as_it_is_when_the_round_starts
    @game.screen = field(300, 200)
    @game.press(0, 0)

    assert_equal 300, @game.round.field.width
  end

  # 1200 by 800 is the reference window, where a fitted dot is the usual
  # 50; 600 by 400 fits a radius of 25, which the rules raise to 30.
  def test_sized_to_the_screen_sets_each_rounds_radius_when_it_starts_and_keeps_it
    @game.screen = field(600, 400)
    @game.sizing = DotPopper::DotSizing::SIZED_TO_SCREEN
    @game.press(0, 0)
    assert_in_delta 30.0, @game.round.field.radius
    assert_equal DotPopper::SizeClass::FITTED, @game.state.size_class

    @game.screen = field(1200, 800)
    @game.sizing = DotPopper::DotSizing::STANDARD
    assert_in_delta 30.0, @game.round.field.radius, 0.001, "a round keeps its radius through a resize"
    assert_equal 1200, @game.round.field.width
    assert_equal DotPopper::DotSizing::SIZED_TO_SCREEN, @game.sizing, "only the title changes the choice"
    assert_in_delta 50.0, @game.field.radius, 0.001, "the next round fits the new screen"
  end

  def test_a_subscriber_must_be_a_listener_or_a_block
    assert_raises(ArgumentError) { @game.subscribe }
  end

  def test_each_round_has_a_seed_of_its_own_that_replays_its_dots
    @game.press(0, 0)
    first = @heard.last.seed
    seeded = DotPopper::Round.new(field, random: Random.new(first))

    assert_equal seeded.dots.to_a, @game.round.dots.to_a
    finish_and_restart
    refute_equal first, @heard.last.seed
  end

  private

  def finish_and_restart
    @game.update(20)
    @game.update(1)
    @game.press(0, 0)
    @game.press(0, 0)
  end

  def play_to_score(points)
    @game.press(0, 0)
    points.times do
      fresh = @game.round.dots.find(&:fresh?)
      clear_around!(@game.round, fresh)
      @game.press(fresh.x, fresh.y)
    end
  end
end
