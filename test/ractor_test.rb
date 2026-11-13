# frozen_string_literal: true

require "test_helper"

# The rules' values are deeply frozen, so any Ractor may read them
# without a copy, and a whole game can be played in a Ractor of its own,
# as script/simulate.rb does.
class RactorTest < Minitest::Test
  include DotPopperTest

  def test_the_rules_values_can_be_shared_between_ractors
    stack = DotPopper::Stack.new(dots: [dot(100, 100), dot(200, 200, popped: true)])
    stands = { dots: stack, score: 1, countdown: DotPopper::Countdown.new(remaining: 3), elapsed: 1.0 }
    values = [field, stack, stack.dots.first, DotPopper::Countdown.new(remaining: 3),
              DotPopper::DotSize.for(DotPopper::Platform::PHONE, unit: "points"), DotPopper::DotSize.fitted(395, 850), DotPopper::DotSizing::SIZED_TO_SCREEN,
              DotPopper::SizeClass::FITTED, DotPopper::Events::Missed.new(x: 1, y: 2),
              DotPopper::Events::Popped.new(dot: stack.dots.first.pop, x: 1, y: 2, points: 1, seconds: 1.0,
                                            spawned: stack.dots.last, **stands),
              DotPopper::Events::Penalized.new(dot: stack.dots.last, x: 1, y: 2, points: -2, seconds: -2.0, **stands)]

    values.each { assert Ractor.shareable?(it), "#{it.class} is not shareable" }
  end

  # An event records what happened, and nothing changes it afterwards: a
  # listener that keeps one never sees the game as it is later. So every
  # event, the ones a Cabinet tells and the ones a paused game's presses
  # return to the tutorial, is deeply frozen, with no game in it.
  def test_every_event_is_a_value_with_no_game_in_it
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(3))
    heard = []
    cabinet.subscribe { heard << it }
    heard.concat(play_paused_then_on(cabinet))

    assert_equal [DotPopper::Events::GameEnded, DotPopper::Events::GameStarted, DotPopper::Events::HomeShown,
                  DotPopper::Events::Missed, DotPopper::Events::Penalized, DotPopper::Events::Popped],
                 heard.map(&:class).uniq.sort_by(&:name)
    heard.each { assert Ractor.shareable?(it), "#{it.class} is not a value" }
  end

  def test_the_rule_numbers_can_be_read_from_any_ractor
    DotPopper::Rules.constants.each { assert Ractor.shareable?(DotPopper::Rules.const_get(it)), it }
    [DotPopper::Platform::COMPUTER, DotPopper::Platform::PHONE].each { assert Ractor.shareable?(it), it }
  end

  # Ruby 4.0.9 on Windows (x64-mingw-ucrt) deadlocks when a Ractor other
  # than the main one collects garbage while the main Ractor has another
  # thread asleep, as Minitest's worker threads are: the game's garbage
  # starts a collection in the Ractor, and the suite never ends. Three
  # lines show it with no game at all (doc/design/development.md), so it is
  # Ruby's, not the rules'. Linux and macOS play it as ever.
  WINDOWS_RACTOR_GC = "Ruby 4.0.9 on Windows deadlocks a Ractor's GC beside a sleeping thread (doc/design/development.md)"

  def test_a_game_played_in_a_ractor_matches_one_played_here
    skip WINDOWS_RACTOR_GC if Gem.win_platform?

    here = RactorTest.play_a_game(field)

    assert_equal here, played_in_a_ractor(field)
    assert_operator here.first, :>, 0
  end

  # Taps the center of the bright dot every half second, from a seeded
  # Random, and answers the score and the dots' final places.
  def self.play_a_game(field)
    game = DotPopper::Game.new(field, random: Random.new(7))
    until game.over?
      game.update(0.5)
      bright = game.dots.find(&:bright?)
      game.tap_at(bright.x, bright.y) unless game.over?
    end
    [game.score, game.dots.map { [it.x, it.y, it.popped?] }]
  end

  private

  # A paused game the tutorial pops a dot in, then play on it to Game
  # Over and Home, with a mistake and a miss on the way. Answers the
  # events the paused game's presses returned.
  def play_paused_then_on(cabinet)
    cabinet.start_paused(DotPopper::Stack.new(dots: [dot(300, 300, id: 0)]))
    returned = [cabinet.press_paused(300, 300)]
    cabinet.unpause
    game = cabinet.game
    bright = game.dots.find(&:bright?)
    clear_around!(game, bright)
    cabinet.press(bright.x, bright.y)
    popped = game.dots.find(&:popped?)
    cabinet.press(popped.x, popped.y)
    cabinet.press(-1, -1)
    cabinet.update(20)
    cabinet.update(1)
    cabinet.press(0, 0)
    returned
  end

  def played_in_a_ractor(field)
    experimental = Warning[:experimental]
    Warning[:experimental] = false
    Ractor.new(field) { RactorTest.play_a_game(it) }.value
  ensure
    Warning[:experimental] = experimental
  end
end
