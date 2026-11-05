# frozen_string_literal: true

require_relative "presentation_helper"

class AutopilotTest < Minitest::Test
  include PresentationTest

  def test_it_plays_a_round_and_comes_back_to_the_title
    game = DotPopper::Game.new(field, random: Random.new(4))
    pilot = Autopilot.new(Look::AUTOPILOT, random: Random.new(5))
    seen = []
    events = []
    game.subscribe { events << it.class }
    3000.times do
      x, y = pilot.update(1 / 60.0, game)
      game.press(x, y) if x
      game.update(1 / 60.0)
      seen << game.state.class
      break if seen.include?(DotPopper::Game::GameOver) && game.state.is_a?(DotPopper::Game::Title)
    end

    assert_includes seen, DotPopper::Game::GameOver
    assert_instance_of DotPopper::Game::Title, game.state
    assert_includes events, DotPopper::Events::Popped
  end

  def test_it_taps_only_a_fresh_dot_it_can_see
    covered = dot(400, 300)
    round = round_with(dot(400, 300, popped: true), covered)
    pilot = Autopilot.new(Look::AUTOPILOT.with(mistakes: 0.0))

    assert_nil pilot.send(:exposed_fresh, round)
  end
end
