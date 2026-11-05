# frozen_string_literal: true

require_relative "presentation_helper"

class ShowTest < Minitest::Test
  include PresentationTest

  def setup
    @sounds = FakeSounds.new
    @game = DotPopper::Game.new(field, random: Random.new(2))
    @show = Show.new(game: @game, layout: layout, sounds: @sounds, radius: R, random: Random.new(3))
  end

  def test_the_mute_button_takes_its_own_tap_on_the_title
    button = @show.layout.mute_button
    @show.tap(button.center_x, button.center_y)

    assert @sounds.muted?
    assert @show.title?
  end

  def test_any_other_tap_reaches_the_game_at_once
    @show.tap(10, 10)

    assert @show.playing?
    assert_equal [:start], @sounds.names
  end

  def test_a_pop_shows_what_it_earned_and_bloops
    start_and_pop

    assert_equal ["+1", "+1s"], @show.effects.floaters.map(&:text)
    assert_equal :pop, @sounds.names.last
    assert_equal [Look::POP_BURST], @show.effects.take_sprays.map(&:look)
    assert_equal 2, @show.effects.rings.size
  end

  def test_a_pop_is_heard_where_it_is
    start_and_pop
    x = @game.round.dots.find(&:popped?).x

    assert_in_delta Look::SOUND.stereo.pan(x, 800), @sounds.pans.last
  end

  def test_the_pop_climbs_with_the_score_up_to_a_cap
    @show.tap(10, 10)
    score!(@game.round, 1000)
    start_and_pop(started: true)

    assert_in_delta Look::SOUND.pop_highest, @sounds.played.last.last
  end

  def test_a_wrong_tap_shows_only_what_was_lost
    start_and_pop
    popped = @game.round.dots.first
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y) # the score falls from 1 to 0: only 1 lost

    assert_equal ["−1", "−2s"], @show.effects.floaters.last(2).map(&:text)
    assert_equal :bonk, @sounds.names.last
    assert_operator @show.effects.flash_alpha, :>, 0
  end

  def test_a_wrong_tap_at_zero_shows_only_the_seconds
    start_and_pop
    score!(@game.round, 0)
    popped = @game.round.dots.first
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y)

    assert_equal "−2s", @show.effects.floaters.last.text
  end

  def test_a_wrong_tap_over_the_fresh_dot_outlines_it
    start_and_pop
    popped = @game.round.dots.first
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, popped)
    put!(fresh.id, popped.x + 30, popped.y)
    @show.tap(popped.x - 20, popped.y)

    assert_equal [fresh.id], @show.effects.reveals.map(&:follow)
    @show.update(Look::REVEAL.duration)
    assert_empty @show.effects.reveals
  end

  def test_the_first_wrong_tap_ever_explains_the_stack_and_later_ones_do_not
    start_and_pop
    popped = @game.round.dots.first
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y)

    assert_equal Look::WORDS.covered, @show.hint.lines
    @show.update(Look::HINT.life)
    assert_nil @show.hint
    @show.tap(popped.x, popped.y)
    assert_nil @show.hint
  end

  def test_a_wrong_tap_with_the_fresh_dot_elsewhere_reveals_nothing
    start_and_pop
    popped = @game.round.dots.first
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y)

    assert_empty @show.effects.reveals
  end

  def test_game_over_counts_up_then_asks_to_continue_once_ready
    start_and_pop
    @game.update(20)
    @show.update(0.1)

    assert @show.finished?
    assert_equal :new_best, @sounds.names.last
    assert_equal 1, @show.finale.stats.pops
    assert_in_delta 0.0, @show.finale.prompt(@show.now)
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.update(0.01)
    @show.update(1.0)
    assert_equal 1, @show.finale.shown_score(@show.now)
    assert_operator @show.finale.prompt(@show.now), :>, 0.9
    assert @show.finale.celebrated
  end

  def test_the_last_seconds_tick
    @show.tap(10, 10)
    105.times do
      @game.update(0.1)
      @show.update(0.1)
    end

    assert_equal 3, @sounds.names.count(:tick)
    assert_equal :game_over, @sounds.names.last
  end

  def test_back_on_the_title_the_effects_are_cleared
    start_and_pop
    @game.update(20)
    @game.update(1)
    @show.tap(10, 10)

    assert @show.title?
    assert_empty @show.effects.floaters
  end

  private

  def put!(id, x, y)
    round = @game.round
    round.instance_variable_set(:@dots, round.dots.map_dots { it.id == id ? it.with(x:, y:) : it })
  end

  def start_and_pop(started: false)
    @show.tap(10, 10) unless started
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, fresh)
    @show.tap(fresh.x, fresh.y)
  end
end
