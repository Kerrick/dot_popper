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
    assert_includes @show.offer_plan.note_lines.join(" "), "3 games a day"
    assert_includes @show.controls.map(&:name), :restore
  end

  def test_back_from_that_offer_returns_to_the_title
    3.times { @games.spend! }
    press_main
    @show.back

    assert_predicate @show, :title?
    refute_predicate @show, :offer?
    refute_predicate @show, :stats?
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

  def test_buying_makes_play_unlimited_and_hides_the_count
    3.times { @games.spend! }
    @entitlement.unlock!

    assert_nil @show.games_line
    press_main

    assert_predicate @show, :playing?
  end

  def test_a_title_with_no_counting_says_nothing_of_games
    show = Show.new(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R)

    assert_nil show.games_line
    assert_nil show.title_plan[:games]
  end

  def test_the_games_line_and_the_offer_fit_on_the_screens_a_player_has
    [[1200, 800], [400, 850], [850, 400]].each do |width, height|
      layout = layout(width, height)
      show = Show.new(cabinet: DotPopper::Cabinet.new(field, random: Random.new(3)), layout:, sounds: FakeSounds.new, radius: R,
                      games: @games, storefront: Store.new)
      plan = show.title_plan

      assert plan.placed.fits?, "the title fits #{width}x#{height}"
      assert plan[:games], "the games show at #{width}x#{height}"
      assert_operator plan[:games].y, :>=, plan.play_button.bottom
    end
  end

  def test_no_word_of_the_games_calls_them_a_trial_or_a_demo
    words = [Style::WORDS.games_left(0), Style::WORDS.games_left(5), Style::WORDS.offer_note(0, 3), Style::WORDS.offer_note(4, 3),
             *Style::WORDS.offer_items].join(" ")

    refute_match(/trial|demo/i, words)
  end
end
