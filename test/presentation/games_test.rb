# frozen_string_literal: true

require_relative "presentation_helper"

# The free games as the Show spends and shows them: Play spends one, the
# Tutorial none, and with none left Play leads to the offer.
class GamesTest < Minitest::Test
  include PresentationTest

  Memory = DotPopper::ScoreRecord::Memory

  class Store
    def offered? = true
    def status = :ready
    def price = "$1.99"
    def connect = nil
    def buy = nil
    def restore = nil
    def keys? = false
    def sold? = true
    def paste = nil
    def update(_seconds) = nil
  end

  def setup
    @day = Date.new(2026, 11, 8)
    @entitlement = DotPopper::Entitlement.test
    @games = DotPopper::FreeGames.new(Memory.new, today: -> { @day }, entitlement: @entitlement, bank: 0)
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(3))
    @show = Show.new(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, games: @games, entitlement: @entitlement,
                     storefront: Store.new)
  end

  def test_each_started_game_costs_one_play_and_home_says_how_many_are_left
    assert_equal "3 games left", @show.games_line
    press_main

    assert_predicate @show, :playing?
    assert_equal 2, @games.left
  end

  def test_with_none_left_play_opens_the_offer_which_lists_unlimited_play_first
    3.times { @games.spend! }
    assert_equal "No games left today", @show.games_line
    press_main

    refute_predicate @show, :playing?
    assert_predicate @show, :offer?
    assert_equal "Unlimited games", Style::WORDS.offer_items.first
    assert_equal ["No games left today."], @show.offer_plan.note_lines, "the offer says why, and counts nothing"
    assert_equal "Unlimited games", @show.offer_screen.focus_word
    assert_includes @show.controls.map(&:name), :restore
  end

  def test_back_from_that_offer_returns_to_home
    3.times { @games.spend! }
    press_main
    @show.back

    assert_predicate @show, :home?
    refute_predicate @show, :offer?
    refute_predicate @show, :stats?
  end

  # Game Over's Get Pro opens the offer over Game Over, as every Pro
  # feature's offer opens over the screen it was tapped on, and Back
  # returns to Game Over as it was.
  def test_get_pro_at_game_over_opens_the_offer_over_it_and_back_returns_there
    2.times { @games.spend! }
    press_main
    @cabinet.update(20)
    @show.update(0.016)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.update(0.016)

    assert_predicate @show, :game_over?
    assert_equal "Get Pro", @show.game_over_screen.play_word
    @show.primary

    assert_predicate @show, :offer?
    assert_predicate @show, :game_over?, "over Game Over, not Home"
    assert_equal ["No games left today."], @show.offer_plan.note_lines
    assert_equal %i[buy restore back].sort, @show.controls.map(&:name).sort, "only the offer's buttons take a press"
    refute @show.waits_for_release?(5.0, 5.0), "no press under the offer drags the pile"
    @show.share

    refute_predicate @show, :sharing?, "Y is not Share my score under the offer"
    @show.back

    refute_predicate @show, :offer?
    assert_predicate @show, :game_over?
  end

  # Buy says "(Y)" with a controller wherever the offer is open, and Y
  # buys there. Shell::App once sent Y over Game Over to Share my score,
  # which does nothing under the offer, before asking the screen on top.
  def test_over_game_over_a_controllers_y_buys_as_its_words_say
    store = Buying.new
    @show = Show.new(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, games: @games, entitlement: @entitlement,
                     storefront: store, input: InputKind::GAMEPAD)
    2.times { @games.spend! }
    press_main
    @cabinet.update(20)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @show.update(0.016)
    @show.primary

    assert_predicate @show, :offer?
    assert_equal "Buy for $1.99 (Y)", @show.buy_label
    @show.pad(:y)

    assert_equal 1, store.bought
    refute_predicate @show, :sharing?
  end

  # A store that counts the times Buy was pressed.
  class Buying < Store
    attr_reader :bought

    def buy = @bought = bought.to_i + 1
  end

  def test_tomorrow_the_games_come_back
    3.times { @games.spend! }
    @day += 1

    assert_equal "3 games left", @show.games_line
  end

  # The tutorial plays over a game, which is spent as it begins, when the
  # tutorial opens; its end and Skip start nothing, so spend nothing.
  def test_the_tutorials_game_is_spent_as_it_opens_and_skip_spends_no_more
    show = tutorial_show
    press_main(show)

    assert_predicate show, :tutorial?
    assert_equal 2, @games.left
    show.skip_tutorial

    assert_predicate show, :playing?
    assert_equal 2, @games.left, "the game it skips into is the one already spent"
  end

  # Every way into a game, as a table: each spends exactly one game as
  # the game begins, and with none left opens the offer instead. A new
  # way in belongs here, and must go through UseCases::StartGame.
  WAYS_IN = {
    "Play" => ->(test, show) { test.press_main(show) },
    "Enter/Start" => ->(_test, show) { show.primary },
    "A first Play" => ->(test, show) { test.press_main(show) },
    "How to Play" => ->(_test, show) { show.how_to_play }
  }.freeze

  # The ways a game the tutorial plays over goes on into play.
  PLAYING_ON = {
    "skipped" => ->(_test, show) { show.skip_tutorial },
    "played to its end" => ->(test, show) { test.play_out(show) }
  }.freeze

  def self.test_name(*words) = "test_#{words.join(" ").downcase.gsub(/[^a-z]+/, "_")}"

  WAYS_IN.each do |name, way_in|
    seen = name.match?(/\APlay\z|Start|How to Play/)
    tutorial = name.match?(/first|How to/)

    define_method(test_name(name, "spends one game")) do
      show = tutorial_show(seen:)
      way_in.call(self, show)

      assert_equal tutorial, show.tutorial?, name
      assert_predicate show, :playing?, name unless tutorial
      assert_equal 2, @games.left, name
    end

    define_method(test_name(name, "with none left opens the offer")) do
      3.times { @games.spend! }
      show = tutorial_show(seen:)
      started = started_games

      way_in.call(self, show)

      refute_predicate show, :playing?, name
      refute_predicate show, :tutorial?, name
      assert_predicate show, :offer?, name
      assert_equal 0, @games.left, name
      assert_empty started, name
    end

    next unless tutorial

    PLAYING_ON.each do |how, play_on|
      define_method(test_name(name, "and its game", how, "spend one game in all")) do
        show = tutorial_show(seen:)
        started = started_games
        way_in.call(self, show)
        play_on.call(self, show)

        assert_predicate show, :playing?, name
        assert_equal 2, @games.left, name
        assert_equal 1, started.size, name
      end
    end
  end

  # Play and the Tutorial's opening, both Home's, are the Show's only
  # ways into a game, and both go through the one door
  # (UseCases::StartGame, whose own test checks that nothing else starts
  # one). The Show makes the door, and the screens are given it.
  def test_the_show_starts_a_game_only_through_the_one_door
    folder = File.expand_path("../../lib/dot_popper/presentation", __dir__)
    code = ->(path) { File.readlines(path).map(&:strip).reject { it.start_with?("#") } }
    show = code.("#{folder}/show.rb")
    screens = Dir["#{folder}/screens/*.rb"].to_h { [File.basename(it), code.(it)] }

    assert_equal 1, show.grep(/StartGame\.new/).size
    assert_empty show.grep(/start_game\.call/)
    assert_equal({ "home.rb" => 2 }, screens.transform_values { it.grep(/@start_game\.call/).size }.reject { |_, n| n.zero? })
    assert_equal 1, show.grep(/Tutorial\.new/).size
  end

  def test_with_none_left_how_to_play_opens_the_offer_as_play_does
    3.times { @games.spend! }
    show = tutorial_show(seen: true)
    show.how_to_play

    refute_predicate show, :tutorial?
    assert_predicate show, :offer?
  end

  def test_with_none_left_a_first_play_leaves_the_tutorial_due
    3.times { @games.spend! }
    flag = TutorialFlag.new(Memory.new)
    show = Show.new(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, games: @games,
                    entitlement: @entitlement, storefront: Store.new, tutorial_flag: flag)
    press_main(show)

    refute_predicate show, :tutorial?
    assert flag.due?(played: false), "it opens once there is a game to play"
  end

  def test_buying_makes_play_unlimited_and_hides_the_count
    3.times { @games.spend! }
    @entitlement.prove(DotPopper::Receipt.issue)

    assert_nil @show.games_line
    press_main

    assert_predicate @show, :playing?
  end

  # A Show with its Tutorial still due, or, +seen+, only How to Play's.
  def tutorial_show(seen: false) = Show.new(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, games: @games,
                                                entitlement: @entitlement, storefront: Store.new, tutorial_flag: TutorialFlag.new(Memory.new).tap { it.seen! if seen })

  def started_games = [].tap { |seen| @cabinet.subscribe { |event| seen << event if event.is_a?(DotPopper::Events::GameStarted) } }

  # The Tutorial played out as a player would, tapping each dot on its turn.
  def play_out(show)
    while show.tutorial?
      scene = show.tutorial
      id = Tutorial::TURNS[scene.beat]
      dot = id && scene.dots.find { it.id == id && !it.popped? }
      show.tap(dot.x, dot.y) if dot
      @cabinet.update(1 / 60.0)
      show.update(1 / 60.0)
    end
  end

  def test_no_word_of_the_games_calls_them_a_trial_or_a_demo
    words = [Style::WORDS.games_left(0), Style::WORDS.games_left(5), Style::WORDS.offer_note(0, 3), Style::WORDS.offer_note(4, 3),
             *Style::WORDS.offer_items].join(" ")

    refute_match(/trial|demo/i, words)
  end
end
