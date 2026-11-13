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

  def test_the_game_starts_on_home
    assert_instance_of Cabinet::Home, @cabinet.state
    assert_nil @cabinet.game
  end

  def test_a_press_on_home_starts_nothing
    @cabinet.press(400, 300)

    assert_instance_of Cabinet::Home, @cabinet.state
    assert_empty @heard.grep(Events::GameStarted)
  end

  def test_starting_a_game_from_home_starts_a_fresh_one_in_play
    start!(@cabinet)

    assert_instance_of Cabinet::Playing, @cabinet.state
    assert_predicate @cabinet, :playing?
    assert_equal 0, @cabinet.game.score
    assert_equal 10.0, @cabinet.game.countdown.remaining
    assert_equal 1, @cabinet.game.dots.size
    assert_instance_of Events::GameStarted, @heard.last
  end

  def test_presses_in_play_reach_the_game_and_are_announced
    start!(@cabinet)
    target = @cabinet.game.dots.first

    @cabinet.press(target.x, target.y)

    assert_equal 1, @cabinet.game.score
    assert_instance_of Events::Popped, @heard.last
  end

  # Each event carries the game as it stood when the event was told, so
  # a listener needs nothing but the event.
  def test_every_event_carries_the_game_as_it_stood_when_it_was_told
    start!(@cabinet)
    game = @cabinet.game
    assert_stood game, @heard.last, :field, :dots, :score, :dots_in_a_row
    @cabinet.update(1.25)
    bright = game.dots.first
    @cabinet.press(bright.x, bright.y)
    assert_stood game, @heard.last, :dots, :score, :countdown, :elapsed
    popped = game.dots.first
    @cabinet.press(popped.x, popped.y)
    assert_stood game, @heard.last, :dots, :score, :countdown, :elapsed
    @cabinet.update(20)
    assert_stood game, @heard.last, :field, :dots, :score, :elapsed

    assert_equal [Events::GameStarted, Events::Popped, Events::Penalized, Events::GameEnded], @heard.map(&:class)
    # 10 seconds, +1 for the pop and -2 for the mistake, all played
    assert_equal [1.25, 1.25, 9.0], @heard.drop(1).map(&:elapsed)
  end

  def test_when_time_runs_out_the_game_is_over_and_shows_the_final_score
    play_to_score(1)
    @cabinet.update(20)

    assert_instance_of Cabinet::GameOver, @cabinet.state
    assert_equal 1, @cabinet.state.score
    assert_instance_of Events::GameEnded, @heard.last
  end

  def test_a_penalty_that_empties_the_clock_ends_the_game_at_once
    start!(@cabinet)
    target = @cabinet.game.dots.first
    @cabinet.press(target.x, target.y)
    @cabinet.update(10.5) # 0.5 s left, and the popped dot is still on top where it went
    popped = @cabinet.game.dots.first

    @cabinet.press(popped.x, popped.y)

    assert_instance_of Cabinet::GameOver, @cabinet.state
  end

  def test_game_over_ignores_presses_for_a_moment_then_returns_to_home
    start!(@cabinet)
    @cabinet.update(11)

    @cabinet.press(400, 300)
    assert_instance_of Cabinet::GameOver, @cabinet.state

    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @cabinet.press(400, 300)
    assert_instance_of Cabinet::Home, @cabinet.state
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
    @cabinet.press(0, 0) # to Home
    start!(@cabinet) # and a new game

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

  # A class's first game sets its record, but beat nothing, so it is not
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
    start!(@cabinet)
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
    start!(@cabinet)

    assert_equal 300, @cabinet.game.field.width
  end

  # 1200 by 800 is the reference window, where a fitted dot is the usual
  # 50; 600 by 400 fits a radius of 25, which the rules raise to 30.
  def test_sized_to_the_screen_sets_each_games_radius_when_it_starts_and_keeps_it
    @cabinet.screen = field(600, 400)
    @cabinet.sizing = DotPopper::DotSizing::SIZED_TO_SCREEN
    start!(@cabinet)
    assert_in_delta 30.0, @cabinet.game.field.radius
    assert_equal DotPopper::SizeClass::FITTED, @cabinet.state.size_class

    @cabinet.screen = field(1200, 800)
    @cabinet.sizing = DotPopper::DotSizing::FIXED
    assert_in_delta 30.0, @cabinet.game.field.radius, 0.001, "a game keeps its radius through a resize"
    assert_equal 1200, @cabinet.game.field.width
    assert_equal DotPopper::DotSizing::SIZED_TO_SCREEN, @cabinet.sizing, "only the title changes the choice"
    assert_in_delta 50.0, @cabinet.field.radius, 0.001, "the next game fits the new screen"
  end

  def test_a_subscriber_must_be_a_listener_or_a_block
    assert_raises(ArgumentError) { @cabinet.subscribe }
  end

  def test_each_game_has_a_seed_of_its_own_that_replays_its_dots
    start!(@cabinet)
    first = @heard.last.seed
    seeded = DotPopper::Game.new(field, random: Random.new(first))

    assert_equal seeded.dots.to_a, @cabinet.game.dots.to_a
    finish_and_restart
    refute_equal first, @heard.last.seed
  end

  def test_a_paused_game_is_made_on_home_and_announced_only_when_unpaused
    first = DotPopper::Stack.new(dots: [dot(300, 300, id: 0)])
    start_paused!(@cabinet, first)

    assert_instance_of Cabinet::Paused, @cabinet.state
    assert_predicate @cabinet, :paused?
    assert_equal first, @cabinet.game.dots
    assert_equal [0, 10.0], [@cabinet.game.score, @cabinet.game.countdown.remaining]
    assert_empty @heard.grep(Events::GameStarted)
  end

  def test_a_paused_games_clock_does_not_run_and_no_press_reaches_it
    start_paused!(@cabinet, DotPopper::Stack.new(dots: [dot(300, 300, velocity_x: 50, id: 0)]))
    @cabinet.update(3.0)
    @cabinet.press(300, 300)

    assert_equal [300.0, 10.0, 0.0], [@cabinet.game.dots.first.x, @cabinet.game.countdown.remaining, @cabinet.game.elapsed]
    assert_equal [false], @cabinet.game.dots.map(&:popped?)
    @cabinet.move_paused(1.0)
    assert_in_delta 350.0, @cabinet.game.dots.first.x, 1e-9, "its dots move only as the tutorial moves them"
    assert_in_delta 10.0, @cabinet.game.countdown.remaining
  end

  def test_the_tutorials_presses_reach_a_paused_game_by_the_usual_rules_and_tell_no_one
    start_paused!(@cabinet, DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    popped = @cabinet.press_paused(300, 300)
    bright = @cabinet.game.dots.find(&:bright?)
    clear_around!(live(@cabinet), @cabinet.game.dots.first)
    penalized = @cabinet.press_paused(300, 300)

    assert_instance_of Events::Popped, popped
    assert_equal 1, popped.spawned.id
    assert_equal bright.id, popped.spawned.id
    assert_instance_of Events::Penalized, penalized
    assert_equal [0, 9.0, 0], [@cabinet.game.score, @cabinet.game.countdown.remaining, @cabinet.game.dots_in_a_row]
    assert_empty @heard.grep(Events::Popped)
    assert_empty @heard.grep(Events::Penalized)
  end

  def test_the_tutorial_arranges_a_paused_games_dots
    start_paused!(@cabinet, DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    @cabinet.arrange(@cabinet.game.dots.first.with(velocity_y: -60.0))

    assert_equal(-60.0, @cabinet.game.dots.first.velocity_y)
  end

  def test_unpausing_begins_play_on_the_same_game_as_it_is
    start_paused!(@cabinet, DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    @cabinet.press_paused(300, 300)
    game = @cabinet.game
    @cabinet.unpause

    assert_instance_of Cabinet::Playing, @cabinet.state
    assert_same game, @cabinet.game
    started = @heard.last
    assert_instance_of Events::GameStarted, started
    assert_equal [game.dots, 1], [started.dots, started.score]
    assert_equal [1, 11.0], [game.score, game.countdown.remaining]
    @cabinet.update(0.5)
    assert_in_delta 10.5, game.countdown.remaining, 1e-9, "its clock runs from there"
  end

  def test_a_paused_games_seed_replays_the_dots_it_spawns
    first = DotPopper::Stack.new(dots: [dot(300, 300, id: 0)])
    start_paused!(@cabinet, first)
    @cabinet.press_paused(300, 300)
    @cabinet.unpause
    seeded = DotPopper::Game.new(field, random: Random.new(@heard.last.seed), dots: first)
    seeded.tap_at(300, 300)

    assert_equal seeded.dots.to_a, @cabinet.game.dots.to_a
  end

  def test_a_paused_game_counts_among_the_records_of_the_screen_it_was_made_on
    start_paused!(@cabinet, DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    made_on = @cabinet.size_class
    @cabinet.screen = DotPopper::Field.new(2000, 1500, R)
    @cabinet.unpause

    refute_equal made_on, @cabinet.size_class
    assert_equal made_on, @cabinet.state.size_class
  end

  def test_a_resized_window_keeps_a_paused_games_dots_on_it
    start_paused!(@cabinet, DotPopper::Stack.new(dots: [dot(700, 300, id: 0)]))
    @cabinet.screen = DotPopper::Field.new(400, 850, R)

    assert_equal 400, @cabinet.game.field.width
    assert @cabinet.game.dots.first.x.between?(R, 400 - R)
  end

  def test_only_home_starts_a_game
    start!(@cabinet)
    game = @cabinet.game
    start!(@cabinet)
    @cabinet.update(11)
    start!(@cabinet)

    assert_same game, @cabinet.game
    assert_instance_of Cabinet::GameOver, @cabinet.state
    assert_equal 1, @heard.grep(Events::GameStarted).size
  end

  # A game starts only through the cabinet's Starts, which it hands out
  # once: asked to start one itself, by what holds only the cabinet, it
  # refuses, and starts nothing.
  def test_only_the_cabinets_starts_start_a_game_and_it_hands_them_out_once
    assert_raises(NoMethodError) { @cabinet.start_game(1) }
    assert_raises(NoMethodError) { @cabinet.start_paused(DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]), 1) }
    starts = @cabinet.starts
    assert_raises(Cabinet::StartsTaken) { @cabinet.starts }

    assert_instance_of Cabinet::Home, @cabinet.state
    assert_empty @heard.grep(Events::GameStarted)
    starts.game(1)
    assert_instance_of Cabinet::Playing, @cabinet.state
  end

  def test_only_home_makes_a_paused_game_and_only_a_paused_game_unpauses
    @cabinet.unpause
    assert_instance_of Cabinet::Home, @cabinet.state
    start!(@cabinet)
    game = @cabinet.game
    start_paused!(@cabinet, DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    @cabinet.unpause

    assert_same game, @cabinet.game
    assert_nil @cabinet.press_paused(game.dots.first.x, game.dots.first.y)
    assert_equal 1, @heard.grep(Events::GameStarted).size
  end

  # What changes a game: a press, time, the tutorial's moves, and a resize.
  CHANGES = %i[tap_at update move_dots arrange field=].freeze

  # What the cabinet answers without an argument, but what moves it on
  # (to Home, from a pause, or taking its Starts): every reader there is,
  # or will be.
  def readers = Cabinet.public_instance_methods(false).select { Cabinet.instance_method(it).arity.zero? } - %i[show_home unpause starts]

  # Only the cabinet holds its game. Nothing it answers, in any state,
  # and nothing its state holds, is the game or can change it: what the
  # screens, the renderer, the bot and the tutorial read is the game's
  # read-only Game::View, the same one each frame.
  def test_nothing_the_cabinet_answers_can_change_its_game
    answers = lambda do
      state = @cabinet.state
      [state, *Data.instance_method(:to_h).bind_call(state).values, *readers.map { @cabinet.public_send(it) }]
    end
    seen = [answers.call]
    start_paused!(@cabinet, DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    seen << answers.call
    @cabinet.unpause
    seen << answers.call
    assert_same @cabinet.game, @cabinet.game, "made once, not each time it is asked"
    @cabinet.update(30)
    seen << answers.call

    assert_equal %w[Home Paused Playing GameOver], seen.map { it[0].class.name.split("::").last }
    held = seen.flatten.compact
    view = DotPopper::Game::View
    read = held.grep(view).flat_map { |game| view.public_instance_methods(false).map { game.public_send(it) } }
    held += read
    assert_empty held.grep(DotPopper::Game)
    # What a view answers is a value, frozen all the way down, so nothing
    # reached through it can change the game it reads.
    assert_empty read.reject { Ractor.shareable?(it) }.map(&:class)
    # A state's own #update takes the game as the cabinet hands it over.
    values = held.reject { it.class.name.start_with?("DotPopper::Cabinet::") }
    assert_empty values.select { |answer| CHANGES.any? { answer.respond_to?(it) } }.map(&:class)
    assert_empty DotPopper::Game::View.public_instance_methods & CHANGES
  end

  private

  def finish_and_restart
    @cabinet.update(20)
    @cabinet.update(1)
    @cabinet.press(0, 0)
    start!(@cabinet)
  end

  def play_to_score(points)
    start!(@cabinet)
    points.times do
      bright = @cabinet.game.dots.find(&:bright?)
      clear_around!(live(@cabinet), bright)
      @cabinet.press(bright.x, bright.y)
    end
  end

  def assert_stood(game, event, *values)
    values.each { assert_equal game.public_send(it), event.public_send(it), "#{event.class}##{it}" }
  end
end
