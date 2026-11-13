# frozen_string_literal: true

require "test_helper"
require "dot_popper/use_cases"

# Looking at achievements: anyone earns and keeps them, and seeing what
# was earned, when, how many and how far along is Pro's.
class ViewAchievementsTest < Minitest::Test
  include DotPopperTest
  Memory = DotPopper::ScoreRecord::Memory

  def setup
    @achievements = DotPopper::Achievements.new(Memory.new)
    @achievements.award(%i[blink], day: "2026-11-01")
    @stats_book = DotPopper::StatsBook.new(Memory.new, today: -> { Date.new(2026, 11, 13) })
    @stats_book.record(DotPopper::GameStats.start.with(duration: 31.6, most_dots_in_a_row: 12), DotPopper::SizeClass::SMALL)
    @score_record = DotPopper::ScoreRecord.new(Memory.new)
    @score_record.record(40, DotPopper::SizeClass::SMALL)
  end

  def view(pro:) = DotPopper::UseCases::ViewAchievements.new(achievements: @achievements, entitlement: DotPopper::Entitlement.new(forced: pro),
                                                             stats_book: @stats_book, score_record: @score_record)

  def test_pro_sees_what_was_earned_when_and_how_many
    pro = view(pro: true)

    refute_predicate pro, :locked?
    assert pro.earned?(:blink)
    refute pro.earned?(:steady)
    assert_equal "2026-11-01", pro.day(:blink)
    assert_equal 1, pro.count
    assert_equal :earned, pro.status(:blink)
    assert_equal :not_earned, pro.status(:steady)
  end

  def test_pro_sees_how_far_along_the_measured_ones_are_until_earned
    pro = view(pro: true)

    assert_equal [12, DotPopper::Achievement::STEADY], pro.progress(:steady)
    assert_equal [40, DotPopper::Achievement::BIG_SCORE], pro.progress(:big_score)
    assert_equal [32, DotPopper::Achievement::LONG_HAUL.to_i], pro.progress(:long_haul)
    assert_nil pro.progress(:blink), "earned, and not measured"
  end

  def test_a_free_player_sees_none_of_it_though_it_is_kept
    free = view(pro: false)

    assert_predicate free, :locked?
    refute free.earned?(:blink)
    assert_nil free.day(:blink)
    assert_nil free.count
    assert_nil free.progress(:steady)
    assert_equal :offer, free.status(:blink), "the dialog offers Pro instead"
    assert @achievements.earned?(:blink)
  end
end
