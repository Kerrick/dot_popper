# frozen_string_literal: true

require "test_helper"
require "dot_popper/use_cases"

# Finishing a game: Stats and achievements are kept for anyone, and what
# Game Over shows and friend groups hear of an achievement is Pro's.
class FinishGameTest < Minitest::Test
  include DotPopperTest
  Memory = DotPopper::ScoreRecord::Memory

  # Friend groups as a local fake: what they were told.
  class Groups
    attr_reader :games, :achievements

    def initialize
      @games = []
      @achievements = []
    end

    def game_finished(score:, counts:) = @games << [score, counts]
    def report_achievements(ids) = @achievements << ids
  end

  def setup
    @stats_book = DotPopper::StatsBook.new(Memory.new, today: -> { Date.new(2026, 11, 13) })
    @achievements = DotPopper::Achievements.new(Memory.new)
    @entitlement = DotPopper::Entitlement.new
    @groups = Groups.new
    @finish = DotPopper::UseCases::FinishGame.new(stats_book: @stats_book, achievements: @achievements, entitlement: @entitlement,
                                                  friend_groups: @groups)
  end

  def test_the_game_goes_into_stats
    @finish.finish(ended, stats: stats(dots_popped: 3))

    assert_equal 1, @stats_book.stats.games
    assert_equal 3, @stats_book.stats.dots_popped
  end

  def test_game_over_names_the_most_impressive_record_the_game_set
    assert_nil @finish.finish(ended, stats: stats(most_dots_in_a_row: 2)).record, "a first game has nothing to beat"

    result = @finish.finish(ended, stats: stats(most_dots_in_a_row: 5))
    assert_equal :most_dots_in_a_row, result.record.kind
    assert_equal 5, result.record.value
  end

  def test_a_free_players_achievements_are_kept_but_not_shown_or_reported
    result = @finish.finish(ended, stats: stats, earned: %i[big_score])

    assert_empty result.achievements
    assert @achievements.earned?(:big_score)
    assert_equal "2026-11-13", @achievements.day(:big_score)
    assert_empty @groups.achievements
  end

  def test_a_pro_player_sees_and_reports_only_those_first_earned_in_this_game
    @finish.finish(ended, stats: stats, earned: %i[big_score])
    pro = DotPopper::UseCases::FinishGame.new(stats_book: @stats_book, achievements: @achievements, entitlement: DotPopper::Entitlement.new(forced: true),
                                              friend_groups: @groups)
    result = pro.finish(ended, stats: stats, earned: %i[big_score blink])

    assert_equal %i[blink], result.achievements
    assert_equal [%i[blink]], @groups.achievements
  end

  # The maintainer: "Somebody's gonna choose a dot size they like and
  # stick with it, usually. Nobody who does that should be excluded from
  # enjoying friend groups." So a game counts whatever its dot size; only
  # the tutorial's never does.
  def test_every_game_but_the_tutorials_counts_in_a_friend_group_whatever_its_dot_size
    @finish.finish(ended(score: 4), stats: stats)
    @finish.finish(ended(score: 5, tutorial: true), stats: stats)
    @finish.finish(ended(score: 6, size_class: DotPopper::SizeClass::SMALL), stats: stats)

    assert_equal [[4, true], [5, false], [6, true]], @groups.games
  end

  # Heard as the rules announce each event, what it finishes with is the
  # game's own: its numbers, and whether the tutorial opened it.
  def test_it_finishes_each_game_from_the_rules_events_alone
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(3), sizing: DotPopper::DotSizing::STANDARD)
    cabinet.subscribe(@finish)
    play = ->(start) { start.call.then { cabinet.update(30) }.then { cabinet.update(DotPopper::Rules::GAME_OVER_GRACE) } }
    play.(-> { start!(cabinet) })
    cabinet.press(0, 0)
    play.(-> { start_paused!(cabinet, DotPopper::Stack.new(dots: [dot(300, 300, id: 0)])).unpause })

    assert_equal 2, @stats_book.stats.games
    assert_equal [true, false], @groups.games.map(&:last), "the tutorial's game never counts"
    assert_equal cabinet.game.score, @finish.stats.score
    assert_equal [], @finish.result.achievements
  end

  # What Game Over shows is told to the finished game's listeners as the
  # game is finished, never left to be read back: each is told once a
  # game is in Stats, with that game's own result and numbers.
  def test_it_tells_its_listeners_each_game_it_finishes_with_that_games_result
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(3))
    told = []
    heard = []
    @finish.subscribe(->(finished) { told << [finished, @stats_book.stats.games] })
    cabinet.subscribe(@finish)
    cabinet.subscribe { heard << it if it.is_a?(DotPopper::Events::GameEnded) }
    2.times do
      start!(cabinet)
      cabinet.update(30)
      cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
      cabinet.press(0, 0)
    end

    assert_equal [1, 2], told.map(&:last), "told after the game is in Stats"
    assert_equal heard, told.map { it.first.ended }, "each game's own, in order"
    told.each do |finished, _|
      assert_equal finished.ended.score, finished.stats.score
      assert_instance_of DotPopper::UseCases::FinishGame::Result, finished.result
    end
  end

  private

  def ended(score: 3, size_class: DotPopper::SizeClass::STANDARD, tutorial: false)
    DotPopper::Events::GameEnded.new(score_record: score, new_score_record: false, seed: 1, size_class:, field:, dots: DotPopper::Stack.new,
                                     score:, elapsed: 10.0, tutorial:)
  end

  def stats(**) = DotPopper::GameStats.start.with(duration: 10.0, **)
end
