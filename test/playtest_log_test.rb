# frozen_string_literal: true

require "test_helper"

class PlaytestLogTest < Minitest::Test
  include DotPopperTest

  def setup
    @store = DotPopper::BestScore::Memory.new
    @game = DotPopper::Game.new(field, random: Random.new(9))
    @game.subscribe(DotPopper::PlaytestLog.new(@store, clock: -> { Time.utc(2026, 11, 5, 9, 30) }))
  end

  def test_each_finished_round_appends_a_line_under_one_header
    play_round(pops: 2)
    play_round(pops: 0)

    lines = @store.read.lines(chomp: true)
    assert_equal "time,seed,score,duration,pops,slips,softened,mean_wait,longest_wait", lines.first
    assert_equal 3, lines.size
    time, seed, score, duration, pops, slips, softened, mean_wait, longest_wait = lines[1].split(",")
    assert_equal "2026-11-05T09:30:00Z", time
    assert_match(/\A\d+\z/, seed)
    assert_equal %w[2 12.00 2 0 0], [score, duration, pops, slips, softened]
    assert_equal %w[0.50 1.00], [mean_wait, longest_wait]
  end

  def test_a_round_still_in_play_is_not_logged
    @game.press(0, 0)

    assert_nil @store.read
  end

  private

  def play_round(pops:)
    @game.press(0, 0)
    pops.times do |i|
      @game.update(1.0) if i.zero?
      fresh = @game.round.dots.find(&:fresh?)
      clear_around!(@game.round, fresh)
      @game.press(fresh.x, fresh.y)
    end
    @game.update(20)
    @game.update(1)
    @game.press(0, 0)
  end
end
