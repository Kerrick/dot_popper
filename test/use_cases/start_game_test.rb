# frozen_string_literal: true

require "test_helper"

# Starting a game, the one way into one: it spends exactly one free game
# on each game it starts, and starts none without one (ADR-0012).
class StartGameTest < Minitest::Test
  include DotPopperTest
  Cabinet = DotPopper::Cabinet

  def setup
    @day = Date.new(2026, 11, 8)
    @games = DotPopper::FreeGames.new(DotPopper::ScoreRecord::Memory.new, today: -> { @day }, entitlement: DotPopper::Entitlement.free,
                                                                         bank: 0, daily: 2)
    @cabinet = Cabinet.new(field, random: Random.new(3))
    @started = []
    @cabinet.subscribe { @started << it if it.is_a?(DotPopper::Events::GameStarted) }
    @start = DotPopper::UseCases::StartGame.new(cabinet: @cabinet, free_games: @games)
  end

  def test_it_starts_a_game_in_play_and_spends_one
    refute_predicate @start, :none_left?
    assert_equal :started, @start.call

    assert_predicate @cabinet, :playing?
    assert_equal 1, @games.left
    assert_equal 1, @started.size
  end

  def test_with_an_opening_it_starts_the_game_paused_with_those_dots_and_spends_one_then
    opening = DotPopper::Stack.new(dots: [dot(300, 300, id: 0)])

    assert_equal :started, @start.call(opening)
    assert_predicate @cabinet, :paused?
    assert_equal [0], @cabinet.game.dots.map(&:id)
    assert_equal 1, @games.left, "spent as it opens"
    assert_empty @started, "announced only as play begins"

    @cabinet.unpause
    assert_equal 1, @games.left, "play beginning spends no more"
  end

  def test_with_none_left_nothing_starts
    2.times { @start.call.then { finish_game } }

    assert_predicate @start, :none_left?
    assert_equal :none_left, @start.call
    assert_equal :none_left, @start.call(DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    assert_instance_of Cabinet::Home, @cabinet.state
    assert_equal 2, @started.size
  end

  def test_away_from_home_it_starts_nothing_and_spends_nothing
    @start.call

    assert_equal :not_home, @start.call
    assert_equal 1, @games.left
  end

  def test_a_game_unmetered_costs_nothing
    games = DotPopper::FreeGames.unlimited
    start = DotPopper::UseCases::StartGame.new(cabinet: @cabinet, free_games: games)

    assert_equal :started, start.call
    assert_predicate @cabinet, :playing?
  end

  # Nothing but this use case starts a game: no screen, no shell, no
  # script, and no file outside lib/ that the phones load.
  def test_nothing_else_starts_a_game
    root = File.expand_path("../..", __dir__)
    files = Dir["#{root}/{lib,script}/**/*.rb"] + Dir["#{root}/bin/*"] + ["#{root}/main.rb", "#{root}/conf.rb", "#{root}/android/android_kit"]
    callers = files.select { File.file?(it) }.flat_map do |path|
      File.readlines(path).filter_map { |line| path.delete_prefix("#{root}/") if line.match?(/\.start_(game|paused)\b/) && !line.strip.start_with?("#") }
    end

    assert_equal ["lib/dot_popper/use_cases/start_game.rb"], callers.uniq
  end

  private

  def finish_game
    @cabinet.update(20)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @cabinet.press(0, 0)
  end
end
