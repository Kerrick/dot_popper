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

  def test_with_the_show_it_copies_every_other_result
    game = DotPopper::Game.new(field, random: Random.new(4))
    clipboard = MemoryClipboard.new
    show = Show.new(game:, layout: layout, sounds: FakeSounds.new, radius: R, clipboard:)
    pilot = Autopilot.new(Look::AUTOPILOT, random: Random.new(5))
    copies = []
    rounds = 0
    game.subscribe { rounds += 1 if it.is_a?(DotPopper::Events::RoundStarted) }
    12_000.times do
      x, y = pilot.update(1 / 60.0, game, show)
      show.tap(x, y) if x
      game.update(1 / 60.0)
      show.update(1 / 60.0)
      copies << clipboard.text if game.state.is_a?(DotPopper::Game::Title) && copies.size < rounds
      break if rounds >= 3
    end

    assert_equal 3, rounds
    assert_nil copies[0]
    assert_match(/\ADot Popper: \d+ points?/, copies[1])
  end

  def test_on_its_second_title_it_looks_at_the_records_and_goes_back
    game = DotPopper::Game.new(field, random: Random.new(4))
    show = Show.new(game:, layout: layout, sounds: FakeSounds.new, radius: R)
    pilot = Autopilot.new(Look::AUTOPILOT, random: Random.new(5))
    opened = false
    rounds = 0
    game.subscribe { rounds += 1 if it.is_a?(DotPopper::Events::RoundStarted) }
    12_000.times do
      x, y = pilot.update(1 / 60.0, game, show)
      show.tap(x, y) if x
      opened ||= show.records?
      game.update(1 / 60.0)
      show.update(1 / 60.0)
      break if rounds >= 2
    end

    assert opened
    refute show.records?
    assert_equal 2, rounds
  end

  def test_it_taps_only_a_fresh_dot_it_can_see
    covered = dot(400, 300)
    round = round_with(dot(400, 300, popped: true), covered)
    pilot = Autopilot.new(Look::AUTOPILOT.with(mistakes: 0.0))

    assert_nil pilot.send(:exposed_fresh, round)
  end

  def test_its_mistake_is_impatience_with_the_covered_fresh_dot
    cover = dot(400, 300, popped: true)
    round = round_with(cover, dot(900, 900, popped: true), dot(430, 300))
    pilot = Autopilot.new(Look::AUTOPILOT.with(mistakes: 1.0))

    assert_equal cover, round.dots.top_at(*pilot.send(:mistake, round))
  end
end
