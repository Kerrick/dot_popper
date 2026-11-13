# frozen_string_literal: true

require "test_helper"

# The words the save files hold for the two dot sizes, pinned byte for
# byte. Builds in players' hands wrote them, so every newer build reads
# them as they were meant and writes the same bytes back, whatever the
# code and the screens call the sizes. dot_size.txt says "fitted" for
# the size worked out from the screen (the default) and "standard" for
# the size that is the same on every screen ("same" before that);
# score_record.txt and stats.txt name the size classes "fitted",
# "small", "medium" and "large". games.csv names no size. The tests
# reach the sizes only through what the files say, so they read the same
# before and after a rename.
class SavedDotSizeWordsTest < Minitest::Test
  DotSizing = DotPopper::DotSizing
  ScoreRecord = DotPopper::ScoreRecord
  Stats = DotPopper::Stats
  SizeClass = DotPopper::SizeClass

  PHONE = DotPopper::Field.new(390, 844, 50)

  def test_dot_size_txt_reads_each_word_a_build_wrote
    assert_equal 50, DotSizing.parse("standard").fit(PHONE).radius, "\"standard\" is the size that is the same on every screen"
    assert_equal 50, DotSizing.parse("same").fit(PHONE).radius, "\"same\" is what that size was saved as before"
    assert_operator DotSizing.parse("fitted").fit(PHONE).radius, :<, 50, "\"fitted\" is the size worked out from the screen"
    assert_equal DotSizing.parse("fitted"), DotSizing::DEFAULT
    assert_equal DotSizing::DEFAULT, DotSizing.parse(nil)
    assert_equal DotSizing::DEFAULT, DotSizing.parse("huge")
  end

  def test_dot_size_txt_writes_the_same_bytes
    assert_equal %w[fitted standard standard fitted], %W[fitted standard same #{}].map { DotSizing.parse(it).to_text }
    assert_equal "standard", DotSizing.parse("fitted").toggled.to_text
    assert_equal "fitted", DotSizing.parse("standard").toggled.to_text
  end

  def test_a_game_counts_in_the_class_its_size_saves_as
    assert_equal "fitted", DotSizing.parse("fitted").size_class(PHONE).name
    assert_equal "small", DotSizing.parse("standard").size_class(PHONE).name
    assert_equal %w[small medium large fitted], SizeClass::ALL.map(&:name)
  end

  def test_score_record_txt_reads_and_writes_the_same_bytes
    text = "fitted=12\nsmall=5\nmedium=24\nlarge=40\n"
    store = ScoreRecord::Memory.new(text)
    score_record = ScoreRecord.new(store)

    assert_equal 12, score_record.of(DotSizing.parse("fitted").size_class(PHONE))
    assert_equal 5, score_record.of(DotSizing.parse("standard").size_class(PHONE))
    score_record.record(13, DotSizing.parse("fitted").size_class(PHONE))

    assert_equal "fitted=13\nsmall=5\nmedium=24\nlarge=40\n", store.read
  end

  def test_stats_txt_reads_and_writes_the_same_bytes
    text = "games=4\npops=90\nmistakes=3\nseconds=200.5\ndays=2\nlast_day=2026-11-12\nrecent=10,20,30,40\n" \
           "recent_classes=?,medium,fitted,small\ngoal_streak=1\nlongest_goal_streak=2\ngoal_met_on=2026-11-12\n" \
           "small.games=1\nsmall.longest_game=31.0\nsmall.most_dots_in_a_row=8\nsmall.shortest_time_to_pop=0.4\n" \
           "small.longest_time_to_pop=6.5\nfitted.games=2\nfitted.longest_game=44.25\nfitted.most_dots_in_a_row=12\n" \
           "fitted.shortest_time_to_pop=0.3\nfitted.longest_time_to_pop=7.0\n"
    stats = Stats.parse(text)

    assert_equal 2, stats.records_in(DotSizing.parse("fitted").size_class(PHONE)).games
    assert_equal 1, stats.records_in(DotSizing.parse("standard").size_class(PHONE)).games
    assert_equal [nil, "medium", "fitted", "small"], stats.recent_classes.map { it&.name }
    assert_equal text, stats.to_text
  end
end
