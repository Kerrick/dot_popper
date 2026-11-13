# frozen_string_literal: true

require_relative "presentation_helper"

# What arrives when the game asks again (DotPopper::Refresh) takes the
# road it takes at launch: a new theme's card on Home, and a title
# change's announcement. Nothing is handed to the network during a game.
class AskingAgainTest < Minitest::Test
  include PresentationTest

  Reply = DotPopper::Network::Reply
  Refresh = DotPopper::Refresh

  # A worker answered by hand: what was started, and the replies given.
  class HandWorker
    attr_reader :started

    def initialize = (@started = []) && (@answers = [])
    def start(job, token) = @started << [job, token]
    def finished = @answers.shift(@answers.size)
    def answer(reply) = @answers << [@started.shift.first, reply]
  end

  def group(top:, champion:)
    { "id" => 1, "join_code" => "2345678", "you" => 2, "champion_number" => champion, "top_score" => top,
      "reign_started_at" => "2026-11-01", "members" => [1, 2].map { { "number" => it, "top_score" => it } } }
  end

  def setup
    @now = 0.0
    @themes_worker = HandWorker.new
    @groups_worker = HandWorker.new
    store = DotPopper::ScoreRecord::Memory.new
    store.write("t\n")
    @session = DotPopper::Groups::Session.new(store:, worker: @groups_worker)
    @theme_keeper = ThemeKeeper.new(DotPopper::ScoreRecord::Memory.new, themes: Style::THEMES)
    @feed = DotPopper::Presentation::ThemeFeed.new(worker: @themes_worker, theme_keeper: @theme_keeper, store: DotPopper::ScoreRecord::Memory.new)
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2))
    @show = new_show(cabinet: @cabinet, layout:, sounds: FakeSounds.new, radius: R, entitlement: DotPopper::Entitlement.new(forced: true),
                     theme_keeper: @theme_keeper, groups: @session)
    @feed.ask
    @refresh = Refresh.new([-> { @feed.ask }, -> { @session.refresh }], cabinet: @cabinet, clock: -> { @now })
    @cabinet.subscribe(@refresh)
    launch
  end

  # The launch's asks are answered: no theme, and a group whose title the
  # player holds.
  def launch
    tick
    @themes_worker.answer(Reply.new(status: 200, body: []))
    @groups_worker.answer(Reply.new(status: 200, body: [group(top: 18, champion: 2)]))
    tick
    @groups_worker.answer(Reply.new(status: 200, body: [])) until @groups_worker.started.empty?
    tick
    @session.next_announcement while @session.next_announcement
    @themes_worker.started.clear
  end

  def tick(seconds = 0.016)
    @cabinet.update(seconds)
    @show.update(seconds)
    @feed.update
  end

  def play_until_game_over
    @cabinet.start_game
    tick(DotPopper::Rules::STARTING_SECONDS + 1) until @show.game_over?
    tick(DotPopper::Rules::GAME_OVER_GRACE)
  end

  def go_home = @cabinet.press(0, 0)

  def test_a_theme_released_meanwhile_is_told_on_home_after_a_game
    @now += Refresh::FLOOR
    play_until_game_over

    assert_empty @themes_worker.started, "nothing asked during the game or at Game Over"
    go_home
    tick

    assert_equal ["/themes"], @themes_worker.started.map { it.first.path[/\A[^?]*/] }
    assert_nil @show.arrival
    @themes_worker.answer(Reply.new(status: 200, body: [{ "key" => "ghost" }]))
    tick

    assert_equal :ghost, @show.arrival.key
  end

  def test_coming_back_during_a_game_hands_nothing_to_the_network_until_after_it
    @cabinet.start_game
    @now += Refresh::FLOOR
    @refresh.came_back
    tick

    assert_empty @themes_worker.started
    assert_empty @groups_worker.started
  end

  def test_a_title_change_meanwhile_is_announced_after_coming_back
    @now += Refresh::FLOOR
    @refresh.came_back
    tick

    assert_equal ["/groups"], @groups_worker.started.map { it.first.path }
    @groups_worker.answer(Reply.new(status: 200, body: [group(top: 40, champion: 1)]))
    tick
    @groups_worker.answer(Reply.new(status: 200, body: [{ "id" => 9, "champion_number" => 1, "previous_champion_number" => 2, "score" => 40 }]))
    tick

    assert_match(/took your title/, @show.group_panel.banner.text)
  end
end
