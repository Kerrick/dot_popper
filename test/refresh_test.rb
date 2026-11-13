# frozen_string_literal: true

require "test_helper"
require "dot_popper/presentation"

class RefreshTest < Minitest::Test
  include DotPopperTest
  Refresh = DotPopper::Refresh
  Cabinet = DotPopper::Cabinet

  def setup
    @now = 1_000.0
    @asked = []
    @cabinet = Cabinet.new(field, random: Random.new(3))
    @refresh = Refresh.new([-> { @asked << :themes }, -> { @asked << :groups }], cabinet: @cabinet, clock: -> { @now })
    @cabinet.subscribe(@refresh)
  end

  def later(seconds = Refresh::FLOOR) = @now += seconds

  def test_nothing_is_asked_again_until_the_game_comes_back_or_home_is_shown
    later(3_600)

    assert_empty @asked
  end

  def test_coming_back_asks_for_themes_and_friend_groups_again
    later
    @refresh.came_back

    assert_equal %i[themes groups], @asked
  end

  def test_home_after_a_game_asks_again
    later
    play_a_game

    assert_equal %i[themes groups], @asked
  end

  def test_launch_counts_as_the_last_ask
    later(Refresh::FLOOR - 1)
    @refresh.came_back

    assert_empty @asked
  end

  def test_no_more_often_than_the_floor
    later
    @refresh.came_back
    later(Refresh::FLOOR - 1)
    @refresh.came_back
    play_a_game

    assert_equal %i[themes groups], @asked
    later(1)
    @refresh.came_back

    assert_equal %i[themes groups themes groups], @asked
  end

  def test_nothing_is_asked_during_a_game
    @cabinet.start_game
    later
    @refresh.came_back

    assert_empty @asked
  end

  def test_nothing_is_asked_while_the_tutorial_plays_over_a_game
    @cabinet.start_paused(DotPopper::Stack.new)
    later
    @refresh.came_back

    assert_empty @asked
  end

  def test_coming_back_during_a_game_waits_for_home
    @cabinet.start_game
    later
    @refresh.came_back
    finish_and_go_home

    assert_equal %i[themes groups], @asked
  end

  def test_a_clock_set_back_asks_rather_than_waiting
    @now -= 86_400
    @refresh.came_back

    assert_equal %i[themes groups], @asked
  end

  def test_the_requests_say_when_they_happen_again
    minutes = "#{Integer(Refresh::FLOOR / 60)} minutes"

    [DotPopper::Presentation::ThemeFeed::REQUESTS.fetch(:themes), DotPopper::Groups::REQUESTS.fetch(:groups)].each do |request|
      assert_includes request.happens, minutes, request.kind
      assert_includes request.happens, "returns to the game", request.kind
    end
  end

  private

  def play_a_game
    @cabinet.start_game
    finish_and_go_home
  end

  def finish_and_go_home
    @cabinet.update(DotPopper::Rules::STARTING_SECONDS + 1) until @cabinet.state.is_a?(Cabinet::GameOver)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    @cabinet.press(0, 0)
  end
end
