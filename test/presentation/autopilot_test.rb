# frozen_string_literal: true

require_relative "presentation_helper"

class AutopilotTest < Minitest::Test
  include PresentationTest

  def test_it_plays_a_round_and_comes_back_to_the_title
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
    rounds = 0
    cabinet.subscribe { rounds += 1 if it.is_a?(DotPopper::Events::RoundStarted) }
    12_000.times do
      x, y = pilot.update(1 / 60.0, cabinet, show)
      show.tap(x, y) if x
      cabinet.update(1 / 60.0)
      show.update(1 / 60.0)
      copies << clipboard.text if cabinet.state.is_a?(DotPopper::Cabinet::Title) && copies.size < rounds
      break if rounds >= 3
    end

    assert_equal 3, rounds
    assert_nil copies[0]
    assert_match(/\ADot Popper: \d+ points?/, copies[1])
  end

  def test_on_its_second_title_it_looks_at_the_records_and_goes_back
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(4))
    show = Show.new(cabinet:, layout: layout, sounds: FakeSounds.new, radius: R)
    pilot = Autopilot.new(Look::AUTOPILOT, random: Random.new(5))
    opened = false
    rounds = 0
    cabinet.subscribe { rounds += 1 if it.is_a?(DotPopper::Events::RoundStarted) }
    12_000.times do
      x, y = pilot.update(1 / 60.0, cabinet, show)
      show.tap(x, y) if x
      opened ||= show.records?
      cabinet.update(1 / 60.0)
      show.update(1 / 60.0)
      break if rounds >= 2
    end

    assert opened
    refute show.records?
    assert_equal 2, rounds
  end

  # 800 by 600 fits smaller dots, so once a round has finished the title
  # offers the choice, and the pilot switches it once.
  def test_it_switches_the_dot_size_once_the_title_offers_it
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(4))
    show = Show.new(cabinet:, layout: layout, sounds: FakeSounds.new, radius: R)
    pilot = Autopilot.new(Look::AUTOPILOT, random: Random.new(5))
    rounds = 0
    cabinet.subscribe { rounds += 1 if it.is_a?(DotPopper::Events::RoundStarted) }
    12_000.times do
      x, y = pilot.update(1 / 60.0, cabinet, show)
      show.tap(x, y) if x
      cabinet.update(1 / 60.0)
      show.update(1 / 60.0)
      break if rounds >= 3
    end

    assert cabinet.sizing.sized_to_screen?
    assert_equal 3, rounds
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
