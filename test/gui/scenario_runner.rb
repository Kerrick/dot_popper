# frozen_string_literal: true

require_relative "scenario"
Dir[File.join(__dir__, "scenarios", "*.rb")].each { require it }

module DotPopperGui
  # Plays one Scenario in the real game, for rake test:gui. main.rb loads
  # this only when DOT_POPPER_SCENARIO names a scenario, so a normal
  # launch never does.
  #
  # The game boots as `lota run` boots it and draws every frame to its
  # window. The scenario runner only takes over the clock: each frame's update
  # gets the time the scenario asks for, a sixtieth of a second unless it
  # waits longer, instead of the time that really passed, so a run plays
  # the same on a busy runner as on an idle one, and as fast as the
  # window can draw. Between frames the scenario pushes its presses onto
  # Lota's event queue (Lota::Event.push), so they reach main.rb's
  # callbacks on the next frame as a player's would, and changes the
  # window through Lota::Window as the system would.
  #
  # The scenario prints a line for each check that passes. The run quits
  # with status 0 once the scenario ends, and with 1 on the first failed
  # check or any error, the game's own included, in place of Lota's
  # error screen, which would wait for a player. A quit the game asks for
  # while the scenario plays is counted (+quits+) and held back, so a
  # scenario can press Quit and check it asked, and play on.
  class ScenarioRunner
    class << self
      attr_reader :current

      def install(name)
        scenario = Scenario.named(name)
        @current = new(name, scenario)
        ::Lota.singleton_class.prepend(Hooks)
        @current
      end
    end

    attr_reader :quits

    def initialize(name, scenario)
      @name = name
      @scenario = scenario
      @step = Scenario::STEP
      @quits = 0
    end

    # The game has loaded: the scenario starts on the first frame.
    def start(app)
      ::Lota::Window.vsync = 0 # as fast as the window draws
      @fiber = Fiber.new { @scenario.new(app).play }
      say "save folder #{::Lota::Filesystem.save_directory}"
    end

    # One frame's update: the game moves on by the step the scenario
    # asked for, then the scenario takes its next step and says how far
    # the next frame should go.
    def frame
      yield @step
      return unless @fiber&.alive?

      step = @fiber.resume
      return @step = step if @fiber.alive?

      @fiber = nil
      say "scenario #{@name} passed"
      ::Lota::Event.quit(0)
    end

    def failed(error)
      message = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
      say "FAILED scenario #{@name}: #{message}"
      Array(error.backtrace).first(12).each { say "  #{it}" } if error.is_a?(Exception)
      nil # Lota exits with 1
    end

    # The game asked Lota to quit: held back, and counted, while the
    # scenario plays; the scenario runner's own quit, once it ends, goes through.
    def quit_asked
      return false unless @fiber

      @quits += 1
      true
    end

    def say(line) = puts("gui: #{line}")

    # What the scenario runner adds to Lota's callbacks, in front of main.rb's.
    module Hooks
      def load
        super
        ScenarioRunner.current.start(@app)
      end

      # Each frame moves on by the scenario's own step, straight to the
      # App, past its FrameClock, so a scenario plays alike on any machine.
      def update(_dt) = ScenarioRunner.current.frame { @app.update(it) }

      def errorhandler(error) = ScenarioRunner.current.failed(error)

      # A truthy answer keeps the game running (Lota::Callbacks.dispatch).
      def quit(*) = ScenarioRunner.current.quit_asked
    end
  end

  # The old name, until no commit uses it.
  Director = ScenarioRunner
end

$stdout.sync = true
DotPopperGui::ScenarioRunner.install(ENV.fetch("DOT_POPPER_SCENARIO"))
