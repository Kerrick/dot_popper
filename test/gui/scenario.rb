# frozen_string_literal: true

require_relative "shot"

module DotPopperGui
  # A check a scenario made that did not hold.
  class Failure < StandardError; end

  # A short scripted session of the game, played frame by frame inside
  # the real game (Director). A subclass names itself with +scenario+ and
  # plays in #play, which reads top to bottom as the session does: every
  # verb pushes what a player would do onto Lota's event queue and
  # returns once the game has heard it, and every check prints a line, or
  # raises Failure.
  #
  # Time is the game's: +wait+ and +wait_for+ go on frame by frame, and a
  # wait for something gives up after a number of frames, never after a
  # time on the clock, so a slow machine only makes a run take longer.
  class Scenario
    L = ::Lota
    STEP = 1 / 60.0 # a frame, at sixty a second
    QUICK = 0.1 # the longest frame the rules take whole (Rules::LONGEST_FRAME)
    WINDOW_FRAMES = 5000 # frames to wait for the system to change the window

    class << self
      def scenario(name) = Scenario.registry[name.to_s] = self
      def registry = (@registry ||= {})

      def named(name)
        Scenario.registry.fetch(name.to_s) do
          raise ArgumentError, "no GUI scenario #{name.inspect}; there are #{Scenario.registry.keys.sort.join(", ")}"
        end
      end
    end

    attr_reader :app, :events

    def initialize(app)
      @app = app
      @events = []
      game.subscribe { @events << it }
    end

    def game = app.game
    def show = app.show
    def pile = app.pile
    def round = game.round
    def layout = show.layout
    def words = show.words

    # Time passing

    # Lets +count+ frames go by, each +step+ seconds of game time.
    def frames(count = 1, step: STEP) = count.times { Fiber.yield(step) }

    # Lets +seconds+ of game time go by, in frames of +step+.
    def wait(seconds, step: STEP)
      left = seconds
      while left > 1e-9
        frames(1, step: [step, left].min)
        left -= step
      end
    end

    # Plays frame by frame until the block is true, and returns what it
    # gave; fails if it never is within +within+ frames.
    def wait_for(what, within: 600, step: STEP)
      within.times do
        found = yield
        return found if found

        frames(1, step:)
      end
      fail!("never saw #{what} within #{within} frames")
    end

    # What a player does, through Lota's event queue. Each returns once
    # the game has heard it, on the next frame.

    def press(x, y, button: 1) = push(:mousepressed, x.to_f, y.to_f, button, false, 1)
    def release(x, y, button: 1) = push(:mousereleased, x.to_f, y.to_f, button, false, 1)
    def move(x, y) = push(:mousemoved, x.to_f, y.to_f, 0.0, 0.0, false)

    def click(x, y)
      press(x, y)
      release(x, y)
    end

    def touch(x, y, id: 1)
      push(:touchpressed, id, x.to_f, y.to_f, 0.0, 0.0, 1.0, "touchscreen", false)
      push(:touchreleased, id, x.to_f, y.to_f, 0.0, 0.0, 1.0, "touchscreen", false)
    end

    def touch_move(x, y, id: 1) = push(:touchmoved, id, x.to_f, y.to_f, 0.0, 0.0, 1.0, "touchscreen", false)

    def key(name) = push(:keypressed, name.to_s, name.to_s, false)

    # Lota cannot queue a Joystick yet, and its queue ends a message at
    # the first nil, so the pad's place holds a number; main.rb never
    # asks which pad pressed.
    PAD = 0

    def pad_down(button) = push(:gamepadpressed, PAD, button.to_s)
    def pad_up(button) = push(:gamepadreleased, PAD, button.to_s)

    def pad(button)
      pad_down(button)
      pad_up(button)
    end

    def push(name, *arguments)
      L::Event.push(name, *arguments) or fail!("Lota would not queue #{name}")
      frames
    end

    # The window, changed as the system changes it, and the game's
    # resize callback waited for.

    def resize(width, height)
      L::Window.update_mode(width, height)
      settled_window("a resize to #{width}x#{height}") { L::Graphics.dimensions == [width, height] }
    end

    def fullscreen(on)
      L::Window.set_fullscreen(on, :desktop)
      settled_window("fullscreen #{on ? "on" : "off"}") { L::Window.fullscreen.first == on }
    end

    # Waits until the window is as the block says and the game has heard
    # the size it has now. The system takes its own time over a window,
    # so the game stands still meanwhile: these frames pass it no time,
    # and the round plays the same however long the system takes.
    def settled_window(what)
      wait_for(what, within: WINDOW_FRAMES, step: 0.0) do
        yield && layout.width == L::Graphics.width && layout.height == L::Graphics.height
      end
      say "#{what}: the window is #{L::Graphics.width}x#{L::Graphics.height}"
    end

    # Looking at the screen

    # What the window showed on the last frame drawn.
    def screenshot
      shot = nil
      L::Graphics.capture_screenshot { shot = Shot.new(it, L::Graphics.width, L::Graphics.height) }
      wait_for("a screenshot", within: 10) { shot }
    end

    # Checks

    def check(truth, what)
      fail!(what) unless truth
      say "ok - #{what}"
    end

    def check_equal(expected, actual, what)
      fail!("#{what}: expected #{expected.inspect}, got #{actual.inspect}") unless expected == actual
      say "ok - #{what} (#{actual.inspect})"
    end

    def check_close(expected, actual, what, within: 1e-6)
      fail!("#{what}: expected #{expected}, got #{actual}") unless (expected - actual).abs <= within
      say "ok - #{what} (#{actual.round(6)})"
    end

    def fail!(what) = raise(Failure, what)
    def say(line) = puts("gui: #{line}")

    # Common moves

    # The events of these kinds the game has told of, as their classes'
    # last names, in order: [:RoundStarted, :Popped, ...].
    def story = events.map { it.class.name.split("::").last.to_sym }

    def fresh_dot = round.dots.find(&:fresh?)
    def uncovered?(dot) = round.dots.top_at(dot.x, dot.y)&.id == dot.id

    # Starts a round with a click in the middle of the title, away from
    # its buttons.
    def start_round(how = method(:click))
      check(show.title?, "the title is showing")
      how.call(layout.center_x, layout.center_y)
      check(show.playing?, "a press on the title starts a round")
    end

    # Waits for the fresh dot to come out from under the popped ones, and
    # clicks its middle. Returns the Popped event.
    def pop_fresh(how = method(:click))
      dot = wait_for("the fresh dot uncovered", within: 900) do
        fresh = fresh_dot
        fresh if uncovered?(fresh) && inside_window?(fresh)
      end
      before = events.size
      how.call(dot.x, dot.y)
      popped = events.drop(before).find { it.is_a?(DotPopper::Events::Popped) }
      fail!("a press on the uncovered fresh dot popped nothing") unless popped
      popped
    end

    def inside_window?(dot) = dot.x.between?(dot.radius, layout.width - dot.radius) &&
                              dot.y.between?(dot.radius, layout.height - dot.radius)

    # Lets the round's clock run out, in long frames.
    def run_out_the_clock
      wait_for("the round to end", within: 2000, step: QUICK) { show.finished? }
      check(show.finished?, "the round ends when its clock runs out")
    end

    # Waits out Game Over's grace and clicks away from "Copy my result".
    def continue_to_title(how = method(:click))
      wait_for("Game Over ready for a press") { game.state.ready? }
      how.call(layout.safe.x + (layout.safe.width * 0.12), layout.safe.y + (layout.safe.height * 0.5))
      wait_for("the title again", within: 5) { show.title? }
      check(show.title?, "a press after Game Over goes back to the title")
    end

    # A whole round, played quickly: one pop, then the clock runs out.
    def quick_round
      start_round
      pop_fresh
      run_out_the_clock
      continue_to_title
    end

    def saved(name) = File.join(L::Filesystem.save_directory, name)

    # Pixel checks, in graphics units

    # Checks the fresh dot's middle shows a fresh dot's warm, light body.
    def check_fresh_pixel(dot, shot = screenshot)
      check(shot.fresh?(dot.x, dot.y), "the fresh dot's middle looks fresh (#{shot.describe(dot.x, dot.y)})")
    end

    # Checks a dot of the game-over pile, dimmed behind the score, still
    # shows the fresh dot's warmth, where the night and popped dots are
    # cool.
    def check_warm_pixel(shot = screenshot)
      stack = pile.stack
      x, y = visible_point(stack, stack.find(&:fresh?)) || fail!("the pile's fresh dot is hidden")
      check(shot.warm?(x, y), "the pile's fresh dot looks fresh behind Game Over (#{shot.describe(x, y)})")
    end

    # A point well inside +dot+ where it is the top dot of +stack+, its
    # middle if it can be, or nil where others cover all of it.
    def visible_point(stack, dot)
      ring = (0...16).map { Math::PI * it / 8 }
      offsets = [[0.0, 0.0]] + [0.3, 0.6].flat_map { |out| ring.map { [Math.cos(it) * out, Math.sin(it) * out] } }
      offsets.map { |dx, dy| [dot.x + (dx * dot.radius), dot.y + (dy * dot.radius)] }
             .find { |x, y| stack.top_at(x, y)&.id == dot.id }
    end

    # Checks the score and time pill is drawn: its words are light.
    def check_hud_drawn(shot = screenshot)
      top = layout.top
      area = DotPopper::Presentation::Rect.new(x: layout.center_x - (layout.scaled(80)), y: top,
                                               width: layout.scaled(160), height: layout.scaled(70))
      lit = shot.lit_in(area)
      check(lit >= 10, "the HUD is drawn at the top (#{lit} light pixels)")
    end
  end
end
