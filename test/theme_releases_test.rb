# frozen_string_literal: true

require "test_helper"

# Asking the server which themes are released: the date sent, kept for
# good, and what its answer opens.
class ThemeReleasesTest < Minitest::Test
  Memory = DotPopper::ScoreRecord::Memory
  Reply = DotPopper::Network::Reply

  class FakeWorker
    attr_accessor :finished_list
    attr_reader :started

    def initialize = (@finished_list = [])
    def start(job, _token) = @started = job
    def finished = @finished_list.tap { @finished_list = [] }
  end

  def setup
    @store = Memory.new
    @dated = Memory.new
    @worker = FakeWorker.new
    @themes = DotPopper::Themes.new(@store)
    @feed = DotPopper::ThemeReleases.new(worker: @worker, themes: @themes, store: @dated, clock: -> { Time.utc(2026, 11, 8, 12) })
  end

  def test_sends_the_first_play_date_and_keeps_it_for_good
    @feed.ask
    assert_equal "/themes?started_on=2026-11-08", @worker.started.path
    feed = DotPopper::ThemeReleases.new(worker: @worker, themes: @themes, store: @dated, clock: -> { Time.utc(2027, 1, 1, 12) })
    feed.ask
    assert_equal "/themes?started_on=2026-11-08", @worker.started.path
  end

  def test_sends_the_utc_date_not_the_local_one
    late_in_los_angeles = Time.new(2026, 11, 8, 20, 0, 0, "-08:00")
    DotPopper::ThemeReleases.new(worker: @worker, themes: @themes, store: Memory.new, clock: -> { late_in_los_angeles }).ask
    assert_equal "/themes?started_on=2026-11-09", @worker.started.path
    early_in_auckland = Time.new(2026, 11, 9, 5, 0, 0, "+13:00")
    DotPopper::ThemeReleases.new(worker: @worker, themes: @themes, store: Memory.new, clock: -> { early_in_auckland }).ask
    assert_equal "/themes?started_on=2026-11-08", @worker.started.path
  end

  def test_an_empty_answer_shows_no_trace_of_any_theme
    @worker.finished_list = [[nil, Reply.new(status: 200, body: [])]]
    refute @feed.update
    refute_predicate @themes, :offered?
    assert_nil @themes.new_theme
  end

  def test_an_unlock_arrives_and_unknown_keys_are_ignored
    @worker.finished_list = [[nil, Reply.new(status: 200, body: [{ "key" => "ghost" }, { "key" => "zombie" }])]]
    assert @feed.update
    assert_equal [:ghost], @themes.choices.drop(1)
  end

  def test_offline_keeps_what_was_saved
    @themes.release(["ghost"])
    @worker.finished_list = [[nil, Reply.offline]]
    refute @feed.update
    assert_equal [:ghost], @themes.choices.drop(1)
  end
end
