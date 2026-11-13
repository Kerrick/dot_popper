# frozen_string_literal: true

require "test_helper"

class GamesLogTest < Minitest::Test
  include DotPopperTest

  def setup
    @store = DotPopper::ScoreRecord::Memory.new
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(9))
    @cabinet.subscribe(DotPopper::GamesLog.new(@store, clock: -> { Time.utc(2026, 11, 5, 9, 30) },
                                               today: -> { Date.new(2026, 11, 5) }))
  end

  def test_each_finished_game_appends_a_line_under_one_header
    play_game(dots_popped: 2)
    play_game(dots_popped: 0)

    lines = @store.read.lines(chomp: true)
    assert_equal "time,seed,score,duration,pops,mistakes,softened,mean_time_to_pop,longest_time_to_pop,goal,goal_met", lines.first
    assert_equal 3, lines.size
    time, seed, score, duration, dots_popped, mistakes, softened, mean_time_to_pop, longest_time_to_pop, goal, met = lines[1].split(",")
    assert_equal "2026-11-05T09:30:00Z", time
    assert_match(/\A\d+\z/, seed)
    assert_equal %w[2 12.00 2 0 0], [score, duration, dots_popped, mistakes, softened]
    assert_equal %w[0.50 1.00], [mean_time_to_pop, longest_time_to_pop]
    assert_equal [DotPopper::DailyGoal.for(Date.new(2026, 11, 5)).to_s, "false"], [goal, met]
  end

  def test_a_log_with_other_columns_is_set_aside_and_a_new_one_begins
    old = "time,mode,seed,score\n2026-11-04T20:00:00Z,daily,7,12\n"
    store = DotPopper::ScoreRecord::Memory.new(old)
    archives = {}
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(9))
    cabinet.subscribe(DotPopper::GamesLog.new(store, clock: -> { Time.utc(2026, 11, 5, 9, 30, 15) },
                                              archive: ->(name) { archives[name] = DotPopper::ScoreRecord::Memory.new }))
    @cabinet = cabinet
    play_game(dots_popped: 1)
    play_game(dots_popped: 1)

    assert_equal ["games-20261105-093015.csv"], archives.keys
    assert_equal old, archives.values.first.read
    lines = store.read.lines(chomp: true)
    assert_equal DotPopper::GamesLog::HEADER, lines.first
    assert_equal 3, lines.size, "the new log keeps its own games"
  end

  def test_a_log_under_the_current_header_is_only_added_to
    @store.write("#{DotPopper::GamesLog::HEADER}\nan,earlier,game\n")
    play_game(dots_popped: 0)

    assert_equal "an,earlier,game", @store.read.lines(chomp: true)[1]
    assert_equal 3, @store.read.lines.size
  end

  def test_a_game_still_in_play_is_not_logged
    start!(@cabinet)

    assert_nil @store.read
  end

  private

  def play_game(dots_popped:)
    start!(@cabinet)
    dots_popped.times do |i|
      @cabinet.update(1.0) if i.zero?
      bright = @cabinet.game.dots.find(&:bright?)
      clear_around!(live(@cabinet), bright)
      @cabinet.press(bright.x, bright.y)
    end
    @cabinet.update(20)
    @cabinet.update(1)
    @cabinet.press(0, 0)
  end
end
