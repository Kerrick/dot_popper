# frozen_string_literal: true

require_relative "presentation_helper"

# The Tutorial as the Show plays it: opened by a first Play over the
# title, outside the rules, and ended by its last beat or a skip with the
# real round, as a Play would start it.
class ShowTutorialTest < Minitest::Test
  include PresentationTest

  STEP = 1 / 60.0

  def setup
    @sounds = FakeSounds.new
    @store = DotPopper::BestScore::Memory.new
    @best = DotPopper::BestScore.new(DotPopper::BestScore::Memory.new)
    @lifetime = DotPopper::Lifetime.new(DotPopper::BestScore::Memory.new)
    @game = DotPopper::Game.new(field, best: @best, random: Random.new(2))
    @events = []
    @game.subscribe { @events << it.class }
    @show = show
  end

  def test_a_first_play_opens_the_tutorial_and_the_game_stays_on_its_title
    press_main

    assert @show.tutorial?
    refute @show.title?
    assert_instance_of DotPopper::Game::Title, @game.state
    assert_empty @events.grep(->(it) { it == DotPopper::Events::RoundStarted })
    assert_equal "seen", @store.read, "it is seen from the moment it opens"
  end

  def test_nothing_in_it_reaches_the_rules_or_the_records
    play_through

    assert @show.playing?
    assert_equal 0, @game.round.score
    assert_in_delta DotPopper::Rules::STARTING_SECONDS, @game.round.countdown.remaining, 0.05
    assert_equal 0, @lifetime.stats.rounds
    assert_equal [DotPopper::Events::RoundStarted], @events.uniq - [DotPopper::Events::TitleShown]
  end

  def test_its_end_starts_the_round_with_the_clock_lit_and_its_first_second_ticking
    play_through
    lead_in = @show.lead_in

    assert lead_in
    assert_operator lead_in.strength(@show.now), :>, 0.9
    @sounds.played.clear
    update_for(1.05)
    assert_includes @sounds.names, :tick, "the clock's first second down ticks"
    update_for(2.0)
    assert_nil @show.lead_in
  end

  def test_its_skip_button_starts_the_round_at_once
    press_main
    reach = @show.skip_reach
    @show.tap(reach.center_x, reach.center_y)

    refute @show.tutorial?
    assert @show.playing?
    assert_nil @show.lead_in
  end

  def test_escape_or_a_gamepads_b_skips_it
    press_main

    assert @show.back
    assert @show.playing?
  end

  def test_the_skip_button_is_drawn_where_it_is_reached_in_a_corner_clear_of_the_hud
    press_main
    control = @show.controls.first

    assert_equal [:skip], @show.controls.map(&:name)
    assert_equal control.frame, control.reach
    assert_operator control.frame.width, :>=, 44
    assert_operator control.frame.x, :>, @show.layout.center_x + 150
  end

  def test_a_gamepads_press_at_its_cursor_pops_the_dot_and_its_start_does_nothing
    press_main
    update_for(2.0)
    dot = @show.tutorial.dots.first
    @show.tap(dot.x, dot.y, by: :gamepad)
    assert_equal :points, @show.tutorial.beat

    @show.primary
    @show.open_records
    @show.choose_sizing(DotPopper::DotSizing::STANDARD)
    assert @show.tutorial?
    refute @show.records?
  end

  def test_it_never_opens_again_not_even_after_the_records_are_cleared
    play_through
    finish_round
    keeper = DotPopper::RecordKeeper.new(best: @best, lifetime: @lifetime)
    keeper.clear
    @show = show(keeper:)
    press_main

    refute @show.tutorial?
    assert @show.playing?
  end

  def test_a_player_who_has_played_before_goes_straight_to_the_round
    @lifetime.record(DotPopper::RoundStats.start.with(pops: 3, duration: 13.0, score: 3), DotPopper::SizeClass::MEDIUM)
    press_main

    refute @show.tutorial?
    assert @show.playing?
  end

  def test_its_dots_follow_a_resized_window
    press_main
    @show.resize(layout(400, 850), DotPopper::Field.new(400, 850, R))

    dot = @show.tutorial.dots.first
    assert dot.x.between?(R, 400 - R)
    assert_equal R, @show.tutorial.radius
  end

  private

  def show(keeper: DotPopper::RecordKeeper.new(best: @best, lifetime: @lifetime))
    Show.new(game: @game, layout: layout, sounds: @sounds, radius: R, random: Random.new(3), lifetime: @lifetime,
             keeper:, tutorial_flag: TutorialFlag.new(@store))
  end

  def update_for(seconds)
    (seconds / STEP).ceil.times do
      @game.update(STEP)
      @show.update(STEP)
    end
  end

  # Plays the whole tutorial, tapping each bright dot as it is shown.
  def play_through
    press_main
    [Tutorial::BRIGHT, Tutorial::NEXT].each do |id|
      update_for(0.1) until %i[aim aim_next].include?(@show.tutorial.beat) && !tapped?(id)
      dot = @show.tutorial.dots.find { it.id == id }
      @show.tap(dot.x, dot.y)
    end
    update_for(0.1) while @show.tutorial?
  end

  def tapped?(id) = @show.tutorial.dots.find { it.id == id }.popped?

  def finish_round
    update_for(0.1) until @show.finished?
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
  end
end
