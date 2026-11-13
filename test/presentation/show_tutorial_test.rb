# frozen_string_literal: true

require_relative "presentation_helper"

# The Tutorial as the Show plays it: opened by a first Play over a game
# paused before its clock runs, and ended by its last beat or by a skip,
# after which that same game plays on from the state it is in.
class ShowTutorialTest < Minitest::Test
  include PresentationTest

  STEP = 1 / 60.0

  def setup
    @sounds = FakeSounds.new
    @store = DotPopper::ScoreRecord::Memory.new
    @score_record = DotPopper::ScoreRecord.new(DotPopper::ScoreRecord::Memory.new)
    @stats_book = DotPopper::StatsBook.new(DotPopper::ScoreRecord::Memory.new)
    @cabinet = DotPopper::Cabinet.new(field, score_record: @score_record, random: Random.new(2))
    @events = []
    @cabinet.subscribe { @events << it.class }
    @show = show
  end

  def test_a_first_play_opens_the_tutorial_over_a_paused_game
    press_main

    assert @show.tutorial?
    refute @show.home?
    refute @show.playing?
    assert_instance_of DotPopper::Cabinet::Paused, @cabinet.state
    assert_empty @events.grep(->(it) { it == DotPopper::Events::GameStarted })
    assert_equal "seen", @store.read, "it is seen from the moment it opens"
  end

  def test_the_game_plays_on_as_it_is_with_only_the_clock_starting
    play_through(hand_over: false)
    scene = @show.tutorial
    paused = @cabinet.game
    update_for(STEP) while @show.tutorial?

    assert @show.playing?
    game = @cabinet.game
    assert_same paused, game, "the one game, not a copy"
    assert_equal scene.dots.map(&:id), game.dots.map(&:id), "the same dots, in the same order"
    assert_equal [true, true, false], game.dots.map(&:popped?)
    assert_equal 1, game.score, "two dots popped, less what the guide's mistake cost"
    assert_operator game.countdown.remaining, :<=, 10.0
    assert_operator game.countdown.remaining, :>, 9.9, "the clock has only just started"
    assert_equal [1, 10], [@show.hud.score, @show.hud.seconds], "the HUD shows the same numbers"
    assert_equal [1, 1], [game.dots_in_a_row, @show.hud.dots_in_a_row], "and the row goes on as the player left it"
    assert_same scene.animations, @show.animations, "and the dots are drawn as they were"
    assert_equal 0, @stats_book.stats.games
    assert_equal [DotPopper::Events::GameStarted], @events.uniq - [DotPopper::Events::HomeShown]
  end

  def test_the_game_it_goes_on_into_counts_as_any_game_does
    play_through
    update_for(0.1) until @show.game_over?

    assert_equal 1, @stats_book.stats.games
    assert_operator @show.game_stats.dots_popped, :>=, 2, "its two dots popped are the game's"
    assert_equal @cabinet.game.score, @show.game_stats.score
    assert_equal @cabinet.game.score, @score_record.of(@cabinet.size_class)
  end

  def test_its_end_starts_the_game_with_the_clock_lit_and_its_first_second_ticking
    play_through
    lead_in = @show.clock_highlight

    assert lead_in
    assert_operator lead_in.strength(@show.now), :>, 0.9
    @sounds.played.clear
    update_for(1.05)
    assert_includes @sounds.names, :tick, "the clock's first second down ticks"
    update_for(2.0)
    assert_nil @show.clock_highlight
  end

  # Kerrick: "Skip should skip all the tutorial-y bits being added to the
  # current game, and get out of the way so the player can play."
  def test_its_skip_button_takes_the_tutorial_away_and_the_same_game_plays_on
    press_main
    update_for(2.0)
    paused = @cabinet.game
    @show.tutorial.tap(*@show.tutorial.dots.first.then { [it.x, it.y] })
    reach = @show.skip_reach
    @show.tap(reach.center_x, reach.center_y)

    refute @show.tutorial?
    assert @show.playing?
    assert_nil @show.clock_highlight
    assert_same paused, @cabinet.game
    assert_equal [1, 2], [@cabinet.game.score, @cabinet.game.dots.size], "the pop the player made is the game's"
    assert_in_delta 11.0, @cabinet.game.countdown.remaining
    assert_equal [true, false], @cabinet.game.dots.map(&:popped?)
    assert_equal [DotPopper::Events::GameStarted], @events.uniq - [DotPopper::Events::HomeShown], "nothing else starts"
    @show.update(0.0)
    assert_equal [1, 11], [@show.hud.score, @show.hud.seconds], "and the HUD shows the game as it is"
  end

  def test_a_skip_keeps_the_row
    press_main
    update_for(0.1) until @show.tutorial.beat == :aim
    tap_dot(@show.tutorial.dots.find { it.id == Tutorial::BRIGHT })
    update_for(0.05) until @show.tutorial.hud.dots_in_a_row == 1
    @show.back

    assert @show.playing?
    assert_equal [1, 2, 1], [@cabinet.game.score, @cabinet.game.dots.size, @cabinet.game.dots_in_a_row]
    update_for(STEP)
    assert_equal 1, @show.hud.dots_in_a_row
  end

  def test_a_skip_before_any_pop_plays_on_with_the_first_dot
    press_main
    update_for(0.5)
    first = @cabinet.game.dots.first
    @show.back

    assert @show.playing?
    assert_equal [first], @cabinet.game.dots.to_a, "the dot where it was"
    assert_equal [0, 10.0], [@cabinet.game.score, @cabinet.game.countdown.remaining]
  end

  # Skipped after the guide's mistake, the game plays on with what it
  # cost, but that mistake was the guide's, so Stats count none.
  def test_a_skip_after_the_guides_mistake_keeps_its_cost_and_counts_no_mistake
    press_main
    update_for(0.1) until @show.tutorial.beat == :aim
    tap_dot(@show.tutorial.dots.find { it.id == Tutorial::BRIGHT })
    update_for(0.05) until @show.tutorial.flights.any? { it.to.name == :score && it.text.start_with?("−") }
    @show.back

    assert_equal [0, 9.0, 0], [@cabinet.game.score, @cabinet.game.countdown.remaining, @cabinet.game.dots_in_a_row]
    assert_equal [1, 0], [@show.game_stats.dots_popped, @show.game_stats.mistakes]
  end

  # While the tutorial hides what the rules already did, Skip shows it at
  # once: the dot the player popped takes its popped look, and the dot
  # spawned under it is born.
  def test_a_skip_shows_what_the_tutorial_had_yet_to_show
    press_main
    update_for(0.1) until @show.tutorial.beat == :aim
    tap_dot(@show.tutorial.dots.find { it.id == Tutorial::BRIGHT })
    assert_equal 1, @show.tutorial.dots.size
    @show.back

    popped, born = @cabinet.game.dots.map { @show.animations.pose(it, @show.now) }
    assert_in_delta 1.0, popped.bright_look, 1e-9, "the popped dot turns from bright to popped from now"
    assert_operator popped.scale_x * popped.scale_y, :>, 1.2, "with its squash"
    assert_in_delta 0.15, born.scale_x, 1e-9, "and the new one grows in from now"
  end

  # The guide's mistake, whatever the hand: touch, a mouse, and a
  # gamepad's A all reach it the same way, and none is heard.
  def test_no_kind_of_tap_is_heard_while_the_guide_demonstrates
    press_main
    update_for(0.1) until @show.tutorial.beat == :aim
    dot = @show.tutorial.dots.find { it.id == Tutorial::BRIGHT }
    @show.tap(dot.x, dot.y)
    update_for(0.05) until @show.tutorial.beat == :warn
    popped = @show.tutorial.dots.find { it.id == Tutorial::BRIGHT }
    kept = @show.tutorial.hud.then { [it.score, it.seconds] }
    @sounds.played.clear

    %i[tap touch mouse gamepad].each { @show.tap(popped.x, popped.y, by: it) }

    assert_equal kept, @show.tutorial.hud.then { [it.score, it.seconds] }
    assert_equal :warn, @show.tutorial.beat
    assert_empty @sounds.names
    assert @show.back, "the skip still works"
    assert @show.playing?
  end

  # The maintainer's report, the path a real click takes: a press on the
  # bad dot once the guide has shown its cost and the bright dot waits. It
  # is the player's turn, and the tap must still cost nothing.
  def test_a_click_on_the_bad_dot_on_the_players_turn_costs_nothing
    press_main
    update_for(0.1) until @show.tutorial.beat == :aim
    tap_dot(@show.tutorial.dots.find { it.id == Tutorial::BRIGHT })
    update_for(0.05) until @show.tutorial.beat == :aim_next
    popped = @show.tutorial.dots.find { it.id == Tutorial::BRIGHT }
    kept = @show.tutorial.hud.then { [it.score, it.seconds] }
    game = @cabinet.game.then { [it.score, it.countdown.remaining, it.dots_in_a_row] }
    @sounds.played.clear

    %i[mouse tap gamepad].each { @show.tap(popped.x, popped.y, by: it) }

    assert_equal kept, @show.tutorial.hud.then { [it.score, it.seconds] }
    assert_equal game, @cabinet.game.then { [it.score, it.countdown.remaining, it.dots_in_a_row] }, "no press reaches the game"
    assert_equal :aim_next, @show.tutorial.beat
    assert_empty @sounds.names
  end

  def test_escape_or_a_gamepads_b_skips_it
    press_main

    assert @show.back
    assert @show.playing?
  end

  def test_a_gamepads_press_at_its_cursor_pops_the_dot_and_its_start_does_nothing
    press_main
    update_for(2.0)
    dot = @show.tutorial.dots.first
    @show.tap(dot.x, dot.y, by: :gamepad)
    assert_equal :points, @show.tutorial.beat

    @show.primary
    @show.open_stats
    @show.choose_sizing(DotPopper::DotSizing::BIGGER_OR_SMALLER)
    assert @show.tutorial?
    refute @show.stats?
  end

  def test_it_never_opens_again_not_even_after_the_stats_are_cleared
    play_through
    finish_game
    keeper = DotPopper::StatsKeeper.new(score_record: @score_record, stats_book: @stats_book)
    keeper.clear
    @show = show(keeper:)
    press_main

    refute @show.tutorial?
    assert @show.playing?
  end

  def test_a_player_who_has_played_before_goes_straight_to_the_game
    @stats_book.record(DotPopper::GameStats.start.with(dots_popped: 3, duration: 13.0, score: 3), DotPopper::SizeClass::MEDIUM)
    press_main

    refute @show.tutorial?
    assert @show.playing?
  end

  # "How to play" replays it from Home, seen or not, and it hands over
  # into a game as a first Play's does; the seen flag stays seen.
  def test_how_to_play_opens_it_again_and_it_hands_over_into_a_game
    play_through
    finish_game
    assert @show.home?
    reach = @show.reach_of(:how_to_play)
    @show.tap(reach.center_x, reach.center_y)

    assert @show.tutorial?
    assert_instance_of DotPopper::Cabinet::Paused, @cabinet.state
    assert_equal "seen", @store.read
    play_through(opened: true)
    assert @show.playing?
    assert_equal [true, true, false], @cabinet.game.dots.map(&:popped?)
    assert_equal 1, @cabinet.game.score
    assert_operator @cabinet.game.countdown.remaining, :>, 9.8, "from what it left, the clock only now running"
    assert @show.clock_highlight
  end

  def test_how_to_play_does_nothing_off_home
    @show.how_to_play
    @show.back
    assert @show.playing?
    @show.how_to_play
    refute @show.tutorial?
  end

  # H on a keyboard is How to play on Home, and another screen's key
  # elsewhere, if anything.
  def test_h_opens_it_from_home_only
    play_through
    finish_game
    @show.open_stats
    refute @show.type_key(:h), "not Stats' key"
    @show.back
    assert @show.type_key(:h)

    assert @show.tutorial?
  end

  def test_its_dots_follow_a_resized_window
    press_main
    @cabinet.screen = DotPopper::Field.new(400, 850, R)
    @show.resize(layout(400, 850), @cabinet.field)

    dot = @show.tutorial.dots.first
    assert dot.x.between?(R, 400 - R)
    assert_equal R, @show.tutorial.radius
  end

  private

  def show(keeper: DotPopper::StatsKeeper.new(score_record: @score_record, stats_book: @stats_book))
    new_show(cabinet: @cabinet, layout: layout, sounds: @sounds, radius: R, random: Random.new(3), stats_book: @stats_book,
             keeper:, tutorial_flag: TutorialFlag.new(@store))
  end

  def update_for(seconds)
    (seconds / STEP).ceil.times do
      @cabinet.update(STEP)
      @show.update(STEP)
    end
  end

  # Plays the whole tutorial, tapping each bright dot as it is shown.
  def play_through(hand_over: true, opened: false)
    press_main unless opened
    [Tutorial::BRIGHT, Tutorial::NEXT].each do |id|
      update_for(0.1) until %i[aim aim_next].include?(@show.tutorial.beat) && !tapped?(id)
      dot = @show.tutorial.dots.find { it.id == id }
      @show.tap(dot.x, dot.y)
    end
    update_for(STEP) while @show.tutorial? if hand_over
  end

  def tap_dot(dot) = @show.tap(dot.x, dot.y)

  def tapped?(id) = @show.tutorial.dots.find { it.id == id }.popped?

  def finish_game
    update_for(0.1) until @show.game_over?
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
  end
end
