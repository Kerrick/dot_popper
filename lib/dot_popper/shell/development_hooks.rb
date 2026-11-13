# frozen_string_literal: true

module DotPopper
  module Shell
    # The development and automation hooks main.rb describes, kept out of
    # App's own path: screenshots at set times (DOT_POPPER_SHOTS), quitting
    # after a while (DOT_POPPER_QUIT_AFTER), the frame meter
    # (DOT_POPPER_PERF), and the fake drag (DOT_POPPER_FAKE_DRAG). A run
    # with none of them set has none (DevelopmentHooks.for answers nil), so
    # its frames do nothing for them. What a build obeys is the build's
    # (Composition::Settings): these are all Build::HARMLESS.
    class DevelopmentHooks
      # The hooks +settings+ ask for, or nil for none. +show+, +pile+ and
      # +dragging+ are the game's; +pad+ is called with (action, x, y) for
      # the fake drag made with a gamepad (DOT_POPPER_FAKE_GAMEPAD).
      def self.for(settings, cabinet:, show:, pile:, dragging:, pad:)
        shots = Presentation::ShotSchedule.parse(settings["DOT_POPPER_SHOTS"]).then { it unless it.empty? }
        quit_after = Float(settings.fetch("DOT_POPPER_QUIT_AFTER"), exception: false)
        frames = Presentation::FrameMeter.start(5) if settings.flag?("DOT_POPPER_PERF")
        fake_drag = Presentation::FakeDrag.parse(settings["DOT_POPPER_FAKE_DRAG"])
        return unless shots || quit_after || frames || fake_drag

        new(shots:, quit_after:, frames:, fake_drag:, cabinet:, show:, pile:, dragging:,
            pad: (pad if settings.fake_gamepad?))
      end

      def initialize(shots:, quit_after:, frames:, fake_drag:, cabinet:, show:, pile:, dragging:, pad:)
        @shots = shots
        @quit_after = quit_after
        @frames = frames
        @fake_drag = fake_drag
        @show = show
        @pile = pile
        @dragging = dragging
        @pad = pad
        @elapsed = 0.0
        cabinet.subscribe { happened(it.class.name.split("::").last) } if @frames
      end

      # As a frame starts, with the +seconds+ it measured: with
      # DOT_POPPER_PERF=1, prints how smoothly the game ran every five
      # seconds, and every frame slow enough to notice with what was going
      # on, from each frame's real time.
      def frame_started(seconds)
        return unless @frames

        gcs = [GC.stat(:major_gc_count), GC.stat(:minor_gc_count)]
        puts "Dot Popper: #{slow_frame(seconds, gcs).report}" if @gcs && Presentation::SlowFrame.slow?(seconds)
        @gcs = gcs
        @frames, report = @frames.record(seconds)
        puts "Dot Popper: #{report}" if report
      end

      # DOT_POPPER_FAKE_DRAG's drag, a step each frame once Game Over has
      # been shown long enough. With DOT_POPPER_FAKE_GAMEPAD, the gamepad
      # makes it (+pad+): the cursor goes where the drag is, and A holds
      # the dot.
      def drag
        return unless @fake_drag && @show.game_over?

        width, height = ::Lota::Graphics.dimensions
        @fake_drag.step(@show.game_over.at, @show.now, width, height) do |action, x, y|
          x, y = nearest_ball(x, y) if action == :press
          unless action == :move
            puts "Dot Popper: the fake drag #{action == :press ? "takes" : "throws"} a dot at #{x.round}, #{y.round}, " \
                 "#{@elapsed.round(1)} seconds in"
          end
          @pad ? @pad.call(action, x, y) : @dragging.public_send(action, :fake, x, y)
        end
      end

      # As a frame ends, +seconds+ of game time later: the screenshots due,
      # and the quit once the time is up.
      def frame_ended(seconds)
        before = @elapsed
        @elapsed += seconds
        @shots&.due(before, @elapsed)&.each { screenshot(it) }
        ::Lota::Event.quit if @quit_after && @elapsed >= @quit_after
      end

      # Notes the latest thing to happen, for a slow frame's report.
      def happened(what)
        @recent = [what, @elapsed] if @frames
      end

      private

      def slow_frame(seconds, gcs)
        recent, at = @recent
        Presentation::SlowFrame.new(seconds:, screen: screen_name, recent:, since: at && (@elapsed - at),
                                    major_gcs: gcs[0] - @gcs[0], minor_gcs: gcs[1] - @gcs[1])
      end

      def screen_name
        if @show.stats? then "Stats"
        elsif @show.tutorial? then "the tutorial"
        elsif @show.playing? then "a game"
        elsif @show.game_over? then "Game Over"
        else "Home"
        end
      end

      # The middle of the pile's ball nearest +x+, +y+, or that point with
      # no pile.
      def nearest_ball(x, y)
        dot = @pile.stack&.dots&.min_by { Math.hypot(it.x - x, it.y - y) }
        dot ? [dot.x, dot.y] : [x, y]
      end

      def screenshot(number)
        name = "shot-#{number}.png"
        ::Lota::Graphics.capture_screenshot(name)
        puts "Dot Popper: screenshot #{File.join(::Lota::Filesystem.save_directory, name)}"
      end
    end
  end
end
