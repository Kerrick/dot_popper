# frozen_string_literal: true

require_relative "presentation_helper"

class ShowTest < Minitest::Test
  include PresentationTest

  def setup
    @sounds = FakeSounds.new
    @game = DotPopper::Game.new(field, random: Random.new(2))
    @clipboard = MemoryClipboard.new
    @show = Show.new(game: @game, layout: layout, sounds: @sounds, radius: R, random: Random.new(3),
                     clipboard: @clipboard)
  end

  def test_a_tap_on_a_title_dot_pops_it_and_still_starts_the_round
    fresh = @show.attract.dots.find { it.fresh? && @show.attract.dots.top_at(it.x, it.y) == it }
    @show.tap(fresh.x, fresh.y)

    assert @show.playing?
    assert_equal 0, @game.round.score
    assert_equal %i[start pop], @sounds.names
    assert_equal 1, @show.effects.rings.size
  end

  def test_on_game_over_copy_my_result_copies_it_and_does_not_continue
    start_and_pop
    @game.update(20)
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.update(0.1)
    @show.tap(*middle(@show.share_reach))

    assert @show.finished?
    assert_equal "Dot Popper: 1 point, a new best!\n🟡 1 pop · ⚫ 0 wrong taps · ⏱ 11 seconds", @clipboard.text
    assert @show.finale.copied?(@show.now)
  end

  def test_each_finished_round_is_added_to_the_lifetime_stats
    start_and_pop
    @game.update(20)

    assert_equal 1, @show.lifetime.stats.rounds
    assert_equal 1, @show.lifetime.stats.pops
    assert_equal [1], @show.lifetime.stats.recent
  end

  def test_game_over_names_the_best_record_the_round_set
    start_and_pop
    @game.update(20)
    assert_nil @show.finale.record, "a first round has nothing to beat"

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @game.press(10, 10)
    @game.press(10, 10)
    2.times { start_and_pop(started: true) }
    @game.update(30)

    assert_equal :longest_run, @show.finale.record.kind
    assert_equal 2, @show.finale.record.value
  end

  def test_a_tap_elsewhere_on_game_over_continues_once_the_grace_is_over
    @show.tap(10, 10)
    @game.update(20)
    @show.update(0.1)
    @show.tap(10, 10)
    assert @show.finished?, "the grace still holds"

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.tap(10, 10)
    assert @show.title?
    assert_nil @clipboard.text
  end

  def test_the_share_buttons_place_on_the_title_is_an_ordinary_tap
    @show.tap(*middle(@show.share_reach))

    assert @show.playing?
    assert_nil @clipboard.text
  end

  def test_the_mute_button_takes_its_own_tap_on_the_title
    button = @show.layout.mute_button
    @show.tap(button.center_x, button.center_y)

    assert @sounds.muted?
    assert @show.title?
  end

  def test_your_records_is_offered_only_once_a_round_has_finished
    refute @show.records_offered?
    @show.tap(*middle(@show.records_reach))
    assert @show.playing?, "before then, its corner is an ordinary tap"

    finish_round
    assert @show.records_offered?
  end

  def test_your_records_opens_over_the_title_and_any_tap_goes_back
    finish_round
    @show.tap(*middle(@show.records_reach))
    assert @show.records?
    assert @show.title?
    assert_equal 1, @show.records.totals.rows.first.value.to_i

    fresh = @show.attract.dots.find(&:fresh?)
    @show.tap(fresh.x, fresh.y)
    refute @show.records?
    assert @show.title?, "the tap that goes back never starts a round"
  end

  def test_start_and_back_leave_the_records_screen_and_only_it
    finish_round
    @show.open_records
    @show.start
    refute @show.records?
    assert @show.title?

    @show.open_records
    assert @show.back
    refute @show.back, "with no Records screen, back has nothing to do"
    assert @show.title?
  end

  def test_the_records_screen_opens_only_from_the_title
    finish_round(back_to_title: false)
    @show.open_records

    refute @show.records?
  end

  def test_a_gamepads_start_begins_the_usual_round_without_popping_a_title_dot
    @show.start

    assert @show.playing?
    assert_equal [:start], @sounds.names
  end

  def test_start_does_nothing_in_a_round
    @show.start
    score = @game.round.score
    clock = @game.round.countdown
    @show.start

    assert @show.playing?
    assert_equal [score, clock], [@game.round.score, @game.round.countdown]
  end

  def test_start_continues_from_game_over_after_the_grace
    @show.start
    @game.update(20)
    @show.start
    assert @show.finished?, "the grace still holds"

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.start
    assert @show.title?
  end

  def test_a_gamepads_y_copies_the_result_on_game_over_and_nothing_else
    @show.share
    assert @show.title?, "Y does nothing on the title"

    @show.start
    @show.share
    assert @show.playing?, "Y does nothing in a round"
    assert_nil @clipboard.text

    @game.update(20)
    @show.update(0.1)
    @show.share
    assert @show.finished?
    assert_match(/\ADot Popper: 0 points\n/, @clipboard.text)
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

  def test_a_pop_buzzes_briefly_and_a_wrong_tap_longer
    haptics = FakeHaptics.new
    @show = Show.new(game: @game, layout: layout, sounds: @sounds, radius: R, random: Random.new(3), haptics:)
    start_and_pop
    popped = @game.round.dots.find(&:popped?)
    clear_around!(@game.round, popped)
    @show.tap(popped.x, popped.y)

    assert_equal [Look::HAPTICS.pop, Look::HAPTICS.penalty], haptics.buzzes
    assert_operator Look::HAPTICS.penalty, :>, Look::HAPTICS.pop
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

  def middle(rect) = [rect.center_x, rect.center_y]

  def put!(id, x, y)
    round = @game.round
    round.instance_variable_set(:@dots, round.dots.map_dots { it.id == id ? it.with(x:, y:) : it })
  end

  def finish_round(back_to_title: true)
    start_and_pop
    @game.update(20)
    return unless back_to_title

    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.tap(10, 10)
  end

  def start_and_pop(started: false)
    @show.tap(10, 10) unless started
    fresh = @game.round.dots.find(&:fresh?)
    clear_around!(@game.round, fresh)
    @show.tap(fresh.x, fresh.y)
  end
end
