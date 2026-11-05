# frozen_string_literal: true

require "test_helper"

class RecordKeeperTest < Minitest::Test
  Memory = DotPopper::BestScore::Memory
  MEDIUM = DotPopper::SizeClass::MEDIUM
  BEST = "medium=24\nsmall=6\n"
  LIFETIME = "rounds=3\npops=40\nrecent=12,24,4\ngoal_streak=2\nlongest_goal_streak=5\ngoal_met_on=2026-11-05\n" \
             "medium.rounds=3\nmedium.longest_run=11\n"

  # A save folder of stores in memory, as the game's is of files.
  class FakeFolder
    attr_reader :stores

    def initialize(files = {}) = @stores = files.transform_values { Memory.new(it) }
    def call(name) = @stores[name] ||= Memory.new
    def names = @stores.reject { |_, store| store.read.nil? }.keys.sort
    def [](name) = @stores[name]&.read
  end

  def setup
    @today = Date.new(2026, 11, 5)
    @folder = FakeFolder.new("best_score.txt" => BEST, "lifetime.txt" => LIFETIME, "rounds.csv" => "time,seed\n1,2\n",
                             "sound.txt" => "muted", "dot_size.txt" => "fitted", "taught.txt" => "2",
                             "tilt_hint.txt" => "touch=1")
    @time = Time.new(2026, 11, 5, 9, 30, 0, "-06:00")
    keep
  end

  def test_clearing_forgets_every_record_as_on_a_new_device
    @keeper.clear

    assert @best.first?(MEDIUM)
    assert_equal 0, @best.of(MEDIUM)
    stats = @lifetime.stats
    assert_equal [0, 0, [], 0, 0], [stats.rounds, stats.pops, stats.recent, stats.streak.longest, @lifetime.streak]
    refute @lifetime.goal_done?
    refute_predicate stats.bests_in(MEDIUM).longest_run, :positive?

    keep
    assert @best.first?(MEDIUM), "the store is cleared too, not only what is in memory"
    assert_equal 0, @lifetime.stats.rounds
  end

  def test_clearing_keeps_the_playtest_log_settings_and_lessons
    before = %w[rounds.csv sound.txt dot_size.txt taught.txt tilt_hint.txt].to_h { [it, @folder[it]] }
    @keeper.clear
    @keeper.restore(@keeper.clear)

    assert_equal before, before.keys.to_h { [it, @folder[it]] }
  end

  def test_the_records_are_copied_exactly_to_backups_named_for_when
    @keeper.clear

    assert_equal BEST, @folder["best_score-20261105-093000.txt"]
    assert_equal LIFETIME, @folder["lifetime-20261105-093000.txt"]
    assert_equal "cleared=2026-11-05T09:30:00-06:00\nbest_score.txt=best_score-20261105-093000.txt\n" \
                 "lifetime.txt=lifetime-20261105-093000.txt\n", @folder["cleared.txt"]
  end

  def test_undo_restores_the_records_exactly_and_keeps_the_backup
    cleared = @keeper.clear
    @keeper.restore(cleared)

    assert_equal [BEST, LIFETIME], [@folder["best_score.txt"], @folder["lifetime.txt"]]
    assert_equal 24, @best.of(MEDIUM)
    assert_equal [3, 2, true], [@lifetime.stats.rounds, @lifetime.streak, @lifetime.goal_done?]
    assert_equal LIFETIME, @folder["lifetime-20261105-093000.txt"]
  end

  def test_only_the_latest_backup_is_kept
    @keeper.clear
    @lifetime.record(DotPopper::RoundStats.start.with(score: 2, duration: 11.0), MEDIUM)
    @time += 60
    @keeper.clear

    backups = @folder.names.grep(/-2026/)
    assert_equal %w[best_score-20261105-093100.txt lifetime-20261105-093100.txt], backups
    assert_match(/\Arounds=1$/, @folder["lifetime-20261105-093100.txt"])
  end

  def test_the_note_never_removes_a_file_that_is_not_a_backup
    @folder.call("cleared.txt").write("cleared=x\nbest_score.txt=rounds.csv\nlifetime.txt=../lifetime.txt\n")
    @keeper.clear

    assert_equal "time,seed\n1,2\n", @folder["rounds.csv"]
  end

  def test_a_store_never_written_is_restored_empty
    @folder = FakeFolder.new("lifetime.txt" => LIFETIME)
    keep
    @keeper.restore(@keeper.clear)

    assert_equal 3, @lifetime.stats.rounds
    assert_equal 0, @best.of(MEDIUM)
    refute @folder.names.include?("best_score-20261105-093000.txt")
  end

  def test_it_remembers_that_records_were_cleared
    refute @keeper.cleared?
    @keeper.clear
    assert @keeper.cleared?

    keep
    assert @keeper.cleared?, "after the game starts again too"
  end

  private

  def keep
    @best = DotPopper::BestScore.new(@folder.call("best_score.txt"))
    @lifetime = DotPopper::Lifetime.new(@folder.call("lifetime.txt"), today: -> { @today })
    @keeper = DotPopper::RecordKeeper.new(best: @best, lifetime: @lifetime, folder: @folder, clock: -> { @time })
  end
end
