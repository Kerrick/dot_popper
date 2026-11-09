# frozen_string_literal: true

require_relative "presentation_helper"

class AutopilotTest < Minitest::Test
  include PresentationTest

  def test_it_games_a_game_and_comes_back_to_the_title
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(4))
    pilot = Autopilot.new(Look::AUTOPILOT, random: Random.new(5))
    seen = []
    events = []
    cabinet.subscribe { events << it.class }
    3000.times do
      x, y = pilot.update(1 / 60.0, cabinet)
      cabinet.press(x, y) if x
      cabinet.update(1 / 60.0)
      seen << cabinet.state.class
      break if seen.include?(DotPopper::Cabinet::GameOver) && cabinet.state.is_a?(DotPopper::Cabinet::Title)
    end

    assert_includes seen, DotPopper::Cabinet::GameOver
    assert_instance_of DotPopper::Cabinet::Title, cabinet.state
    assert_includes events, DotPopper::Events::Popped
  end

  def test_with_the_show_it_copies_every_other_result
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(4))
    clipboard = MemoryClipboard.new
    show = Show.new(cabinet:, layout: layout, sounds: FakeSounds.new, radius: R, clipboard:)
    pilot = Autopilot.new(Look::AUTOPILOT, random: Random.new(5))
    copies = []
    games = 0
    cabinet.subscribe { games += 1 if it.is_a?(DotPopper::Events::GameStarted) }
    12_000.times do
      x, y = pilot.update(1 / 60.0, cabinet, show)
      show.tap(x, y) if x
      cabinet.update(1 / 60.0)
      show.update(1 / 60.0)
      copies << clipboard.text if cabinet.state.is_a?(DotPopper::Cabinet::Title) && copies.size < games
      break if games >= 3
    end

    assert_equal 3, games
    assert_nil copies[0]
    assert_match(/\ADot Popper: \d+ points?/, copies[1])
  end

  def test_on_its_second_title_it_looks_at_the_records_and_goes_back
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(4))
    show = Show.new(cabinet:, layout: layout, sounds: FakeSounds.new, radius: R)
    pilot = Autopilot.new(Look::AUTOPILOT, random: Random.new(5))
    opened = false
    games = 0
    cabinet.subscribe { games += 1 if it.is_a?(DotPopper::Events::GameStarted) }
    12_000.times do
      x, y = pilot.update(1 / 60.0, cabinet, show)
      show.tap(x, y) if x
      opened ||= show.records?
      cabinet.update(1 / 60.0)
      show.update(1 / 60.0)
      break if games >= 2
    end

    assert opened
    refute show.records?
    assert_equal 2, games
  end

  # 800 by 600 fits smaller dots, so once a game has finished the title
  # offers the choice, and the pilot switches it once.
  def test_it_switches_the_dot_size_once_the_title_offers_it
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(4))
    show = Show.new(cabinet:, layout: layout, sounds: FakeSounds.new, radius: R)
    pilot = Autopilot.new(Look::AUTOPILOT, random: Random.new(5))
    games = 0
    cabinet.subscribe { games += 1 if it.is_a?(DotPopper::Events::GameStarted) }
    12_000.times do
      x, y = pilot.update(1 / 60.0, cabinet, show)
      show.tap(x, y) if x
      cabinet.update(1 / 60.0)
      show.update(1 / 60.0)
      break if games >= 3
    end

    assert cabinet.sizing.sized_to_screen?
    assert_equal 3, games
  end

  def test_it_taps_only_a_fresh_dot_it_can_see
    covered = dot(400, 300)
    game = game_with(dot(400, 300, popped: true), covered)
    pilot = Autopilot.new(Look::AUTOPILOT.with(mistakes: 0.0))

    assert_nil pilot.send(:exposed_fresh, game)
  end

  def test_its_mistake_is_impatience_with_the_covered_fresh_dot
    cover = dot(400, 300, popped: true)
    game = game_with(cover, dot(900, 900, popped: true), dot(430, 300))
    pilot = Autopilot.new(Look::AUTOPILOT.with(mistakes: 1.0))

    assert_equal cover, game.dots.top_at(*pilot.send(:mistake, game))
  end
end
