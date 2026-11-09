# frozen_string_literal: true

require "test_helper"

class AchievementsTest < Minitest::Test
  Memory = DotPopper::ScoreRecord::Memory

  def test_a_new_device_has_earned_nothing
    achievements = DotPopper::Achievements.new(Memory.new)

    assert_empty achievements.earned
    assert_equal 0, achievements.count
    refute achievements.earned?(:sharpshooter)
  end

  def test_awarding_returns_only_what_is_new_and_saves_it
    store = Memory.new
    achievements = DotPopper::Achievements.new(store)

    assert_equal %i[sharpshooter steady], achievements.award(%i[steady sharpshooter], day: "2026-11-08")
    assert_equal [], achievements.award(%i[steady], day: "2026-11-09")
    assert_equal %i[blink], achievements.award(%i[steady blink], day: "2026-11-09")
    assert_equal "2026-11-08", achievements.day(:steady), "the first day is kept"
    assert_equal "sharpshooter=2026-11-08\nblink=2026-11-09\nsteady=2026-11-08\n", store.read
  end

  def test_what_was_saved_is_read_back
    saved = DotPopper::Achievements.new(Memory.new("blink=2026-11-01\nsteady=2026-11-02\n"))

    assert_equal %i[blink steady], saved.earned
    assert_equal 2, saved.count
    assert_equal "2026-11-02", saved.day(:steady)
  end

  def test_damaged_text_and_unknown_achievements_are_left_out
    achievements = DotPopper::Achievements.new(Memory.new("blink=2026-11-01\nfuture_achievement=2027-01-01\n\ngarbage\n=x\n"))

    assert_equal %i[blink], achievements.earned
  end

  def test_clearing_forgets_everything_and_restoring_brings_it_back
    store = Memory.new
    achievements = DotPopper::Achievements.new(store)
    achievements.award(%i[blink], day: "2026-11-08")
    text = achievements.saved

    achievements.clear
    assert_empty achievements.earned
    assert_equal "", store.read

    achievements.restore(text)
    assert_equal %i[blink], achievements.earned
    assert_equal text, store.read
  end

  def test_restoring_nothing_leaves_nothing
    achievements = DotPopper::Achievements.new(Memory.new("blink=2026-11-01\n"))
    achievements.restore(nil)

    assert_empty achievements.earned
  end
end
