# frozen_string_literal: true

require_relative "presentation_helper"

class ThemeKeeperTest < Minitest::Test
  include PresentationTest

  Memory = DotPopper::ScoreRecord::Memory
  THEMES = Style::THEMES

  def setup
    @store = Memory.new
    @pro = false
  end

  def theme_keeper(pro: true)
    @pro = true if pro
    ThemeKeeper.new(@store, themes: THEMES, entitlement: DotPopper::Entitlement.new(forced: @pro))
  end

  def test_until_the_server_says_so_there_is_no_trace_of_a_theme
    w = theme_keeper
    assert_equal [THEMES.first], w.choices
    refute_predicate w, :offered?
    assert_nil w.arrival
  end

  def test_unlocks_are_kept_for_good_even_if_the_server_forgets
    w = theme_keeper
    assert w.receive(%w[ghost awake]), "the server sent new themes"
    assert_equal %i[classic ghost awake], w.choices.map(&:key)
    w.receive([])
    assert_equal %i[classic ghost awake], theme_keeper.choices.map(&:key), "still there, after a restart, offline"
  end

  def test_keys_the_game_does_not_know_are_ignored
    theme_keeper.receive(%w[zombie classic])
    assert_equal [THEMES.first], theme_keeper.choices
  end

  def test_each_new_theme_is_told_once_and_a_pro_player_can_use_it
    w = theme_keeper
    w.receive(["ghost"])
    assert_equal :ghost, w.arrival.key
    w.told(w.arrival)
    assert_nil w.arrival, "told, however it was answered"
    w.use(w.choices.last)
    assert_equal :ghost, theme_keeper.in_use.key
  end

  def test_a_free_player_may_know_of_a_theme_but_uses_the_ordinary_one
    w = theme_keeper(pro: false)
    w.receive(["ghost"])
    assert_predicate w, :offered?
    assert_predicate w, :locked?
    assert_equal :ghost, w.arrival.key
    w.use(w.choices.last)
    assert_predicate w.in_use, :ordinary?
  end
end

class ThemeFeedTest < Minitest::Test
  include PresentationTest

  Memory = DotPopper::ScoreRecord::Memory
  Reply = DotPopper::Groups::Reply

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
    @pro = false
    @theme_keeper = ThemeKeeper.new(@store, themes: Style::THEMES, entitlement: DotPopper::Entitlement.new(forced: @pro))
    @feed = ThemeFeed.new(worker: @worker, theme_keeper: @theme_keeper, store: @dated, clock: -> { Time.utc(2026, 11, 8, 12) })
  end

  def test_sends_the_first_play_date_and_keeps_it_for_good
    @feed.ask
    assert_equal "/themes?started_on=2026-11-08", @worker.started.path
    feed = ThemeFeed.new(worker: @worker, theme_keeper: @theme_keeper, store: @dated, clock: -> { Time.utc(2027, 1, 1, 12) })
    feed.ask
    assert_equal "/themes?started_on=2026-11-08", @worker.started.path
  end

  def test_sends_the_utc_date_not_the_local_one
    late_in_los_angeles = Time.new(2026, 11, 8, 20, 0, 0, "-08:00")
    ThemeFeed.new(worker: @worker, theme_keeper: @theme_keeper, store: Memory.new, clock: -> { late_in_los_angeles }).ask
    assert_equal "/themes?started_on=2026-11-09", @worker.started.path
    early_in_auckland = Time.new(2026, 11, 9, 5, 0, 0, "+13:00")
    ThemeFeed.new(worker: @worker, theme_keeper: @theme_keeper, store: Memory.new, clock: -> { early_in_auckland }).ask
    assert_equal "/themes?started_on=2026-11-08", @worker.started.path
  end

  def test_an_empty_answer_shows_no_trace_of_any_theme
    @worker.finished_list = [[nil, Reply.new(status: 200, body: [])]]
    refute @feed.update
    refute_predicate @theme_keeper, :offered?
    assert_nil @theme_keeper.arrival
  end

  def test_an_unlock_arrives_and_unknown_keys_are_ignored
    @worker.finished_list = [[nil, Reply.new(status: 200, body: [{ "key" => "ghost" }, { "key" => "zombie" }])]]
    assert @feed.update
    assert_equal [:ghost], @theme_keeper.choices.drop(1).map(&:key)
  end

  def test_offline_keeps_what_was_saved
    @theme_keeper.receive(["ghost"])
    @worker.finished_list = [[nil, Reply.offline]]
    refute @feed.update
    assert_equal [:ghost], @theme_keeper.choices.drop(1).map(&:key)
  end
end
