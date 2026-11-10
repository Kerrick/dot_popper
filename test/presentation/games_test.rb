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
    def update(_seconds) = nil
  end

  def setup
    @day = Date.new(2026, 11, 8)
    @entitlement = DotPopper::Entitlement.free
    @games = DotPopper::FreeGames.new(Memory.new, today: -> { @day }, entitlement: @entitlement, bank: 0)
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(3))
    @show = Show.new(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, games: @games, entitlement: @entitlement,
                     storefront: Store.new)
  end

  def test_each_started_game_costs_one_play_and_the_title_says_how_many_are_left
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

  def test_back_from_that_offer_returns_to_the_title
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

  def test_tomorrow_the_games_come_back
    3.times { @games.spend! }
    @day += 1

    assert_equal "3 games left", @show.games_line
  end

  def test_the_tutorial_costs_no_play
    show = Show.new(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, games: @games, storefront: Store.new,
                    tutorial_flag: TutorialFlag.new(Memory.new))
    press_main(show)

    assert_predicate show, :tutorial?
    assert_equal 3, @games.left
    show.skip_tutorial

    assert_equal 2, @games.left, "the game it skips into is a play"
  end

  def test_skipping_the_tutorial_with_none_left_opens_the_offer
    3.times { @games.spend! }
    show = Show.new(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, games: @games, storefront: Store.new,
                    tutorial_flag: TutorialFlag.new(Memory.new))
    press_main(show)
    show.skip_tutorial

    assert_predicate show, :offer?
  end

  # Every way into a real game, as a table: each spends exactly one game
  # as the game starts, and with none left opens the offer instead. A
  # new way in belongs here, and must go through Show#with_a_game.
  WAYS_IN = {
    "Play" => ->(test, show) { test.press_main(show) },
    "Enter/Start" => ->(_test, show) { show.primary },
    "Skip from a first Play" => lambda do |test, show|
      test.open_first_play(show)
      show.skip_tutorial
    end,
    "Skip from How to Play" => lambda do |_test, show|
      show.how_to_play
      show.skip_tutorial
    end,
    "A first Play's tutorial, played to its end" => lambda do |test, show|
      test.open_first_play(show)
      test.play_out(show)
    end,
    "How to Play, played to its end" => lambda do |test, show|
      show.how_to_play
      test.play_out(show)
    end
  }.freeze

  WAYS_IN.each do |name, way_in|
    define_method("test_#{name.downcase.gsub(/[^a-z]+/, "_")}_spends_one_game") do
      show = tutorial_show(seen: name.match?(/\APlay\z|Start|How to Play/))
      started = started_games

      way_in.call(self, show)

      assert_predicate show, :playing?, name
      assert_equal 2, @games.left, name
      assert_equal 1, started.size, name
    end

    define_method("test_#{name.downcase.gsub(/[^a-z]+/, "_")}_with_none_left_opens_the_offer") do
      3.times { @games.spend! }
      show = tutorial_show(seen: name.match?(/\APlay\z|Start|How to Play/))
      started = started_games

      way_in.call(self, show)

      refute_predicate show, :playing?, name
      assert_predicate show, :offer?, name
      assert_equal 0, @games.left, name
      assert_empty started, name
    end
  end

  def test_nothing_starts_a_game_except_through_the_one_door
    callers = Dir[File.expand_path("../../lib/dot_popper/{presentation,shell}/**/*.rb", __dir__)].flat_map do |path|
      File.readlines(path).filter_map { |line| [path, line] if line.match?(/cabinet\.resume|cabinet\.start_game/) }
    end

    assert_equal ["show.rb"], callers.map { File.basename(it.first) }
    assert_includes File.read(File.expand_path("../../lib/dot_popper/presentation/show.rb", __dir__)), "with_a_game { go_on_from(scene) }"
  end

  def test_with_none_left_how_to_play_can_still_be_watched
    3.times { @games.spend! }
    show = tutorial_show
    show.how_to_play

    assert_predicate show, :tutorial?
    assert_equal 0, @games.left
  end

  def test_buying_makes_play_unlimited_and_hides_the_count
    3.times { @games.spend! }
    @entitlement.unlock!

    assert_nil @show.games_line
    press_main

    assert_predicate @show, :playing?
  end

  # A Show with its Tutorial still due, or, +seen+, only How to Play's.
  def tutorial_show(seen: false) = Show.new(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, games: @games,
                                                entitlement: @entitlement, storefront: Store.new, tutorial_flag: TutorialFlag.new(Memory.new).tap { it.seen! if seen })

  def started_games = [].tap { |seen| @cabinet.subscribe { |event| seen << event if event.is_a?(DotPopper::Events::GameStarted) } }

  def open_first_play(show)
    press_main(show)
    assert_predicate show, :tutorial?
  end

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
