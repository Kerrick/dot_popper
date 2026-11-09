# frozen_string_literal: true

require_relative "presentation_helper"

# The Tutorial as the Show plays it: opened by a first Play over the
# title, before the clock runs, and ended by its last beat, which the
# game goes on from, or by a skip, which starts a game as Play does.
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

  def test_a_first_play_opens_the_tutorial_and_the_game_stays_on_its_title
    press_main

    assert @show.tutorial?
    refute @show.home?
    assert_instance_of DotPopper::Cabinet::Home, @cabinet.state
    assert_empty @events.grep(->(it) { it == DotPopper::Events::GameStarted })
    assert_equal "seen", @store.read, "it is seen from the moment it opens"
  end

  def test_the_game_goes_on_from_its_dots_score_and_time_with_only_the_clock_starting
    play_through(hand_over: false)
    scene = @show.tutorial
    update_for(STEP) while @show.tutorial?

    assert @show.playing?
    game = @cabinet.game
    assert_equal scene.dots.map(&:id), game.dots.map(&:id), "the same dots, in the same order"
    assert_equal [true, true, false], game.dots.map(&:popped?)
    assert_equal 1, game.score, "two pops, less what the guide's wrong tap cost"
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
    assert_operator @show.game_stats.pops, :>=, 2, "its two pops are the game's"
    assert_equal @cabinet.game.score, @show.game_stats.score
    assert_equal @cabinet.game.score, @score_record.of(@cabinet.size_class)
  end

  def test_its_end_starts_the_game_with_the_clock_lit_and_its_first_second_ticking
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

  def test_its_skip_button_starts_a_fresh_game_at_once
    press_main
    update_for(2.0)
    @show.tutorial.tap(*@show.tutorial.dots.first.then { [it.x, it.y] })
    reach = @show.skip_reach
    @show.tap(reach.center_x, reach.center_y)

    refute @show.tutorial?
    assert @show.playing?
    assert_nil @show.lead_in
    assert_equal [0, 1], [@cabinet.game.score, @cabinet.game.dots.size], "nothing of the tutorial's comes with it"
    assert_in_delta DotPopper::Rules::STARTING_SECONDS, @cabinet.game.countdown.remaining
  end

  def test_a_skip_leaves_the_row_behind
    press_main
    update_for(0.1) until @show.tutorial.beat == :aim
    tap_dot(@show.tutorial.dots.find { it.id == Tutorial::BRIGHT })
    update_for(0.05) until @show.tutorial.hud.dots_in_a_row == 1
    @show.back

    assert @show.playing?
    assert_equal [0, 1, 0], [@cabinet.game.score, @cabinet.game.dots.size, @cabinet.game.dots_in_a_row]
    update_for(STEP)
    assert_equal 0, @show.hud.dots_in_a_row
  end

  # The guide's wrong tap, whatever the hand: touch, a mouse, and a
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
    @sounds.played.clear

    %i[mouse tap gamepad].each { @show.tap(popped.x, popped.y, by: it) }

    assert_equal kept, @show.tutorial.hud.then { [it.score, it.seconds] }
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
    @show.choose_sizing(DotPopper::DotSizing::STANDARD)
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
    @stats_book.record(DotPopper::GameStats.start.with(pops: 3, duration: 13.0, score: 3), DotPopper::SizeClass::MEDIUM)
    press_main

    refute @show.tutorial?
    assert @show.playing?
  end

  # "How to play" replays it on any title, seen or not, and it hands over
  # into a game as a first Play's does; the seen flag stays seen.
  def test_how_to_play_opens_it_again_and_it_hands_over_into_a_game
    play_through
    finish_game
    assert @show.home?
    reach = @show.reach_of(:how_to_play)
    @show.tap(reach.center_x, reach.center_y)

    assert @show.tutorial?
    assert_instance_of DotPopper::Cabinet::Home, @cabinet.state
    assert_equal "seen", @store.read
    play_through(opened: true)
    assert @show.playing?
    assert_equal [true, true, false], @cabinet.game.dots.map(&:popped?)
    assert_equal 1, @cabinet.game.score
    assert_operator @cabinet.game.countdown.remaining, :>, 9.8, "from what it left, the clock only now running"
    assert @show.lead_in
  end

  def test_how_to_play_does_nothing_off_the_title
    @show.how_to_play
    @show.back
    assert @show.playing?
    @show.how_to_play
    refute @show.tutorial?
  end

  def test_its_dots_follow_a_resized_window
    press_main
    @show.resize(layout(400, 850), DotPopper::Field.new(400, 850, R))

    dot = @show.tutorial.dots.first
    assert dot.x.between?(R, 400 - R)
    assert_equal R, @show.tutorial.radius
  end

  private

  def show(keeper: DotPopper::StatsKeeper.new(score_record: @score_record, stats_book: @stats_book))
    Show.new(cabinet: @cabinet, layout: layout, sounds: @sounds, radius: R, random: Random.new(3), stats_book: @stats_book,
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
