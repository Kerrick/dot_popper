# frozen_string_literal: true

module DotPopper
  module Shell
    # The game running in Lota's window. main.rb hands each of Lota's
    # callbacks to one of these methods. Each frame, taps go to the game
    # first, on the frame they happen; then the rules move on; then the
    # Show catches up; then the Renderer draws it.
    class App
      Look = Presentation::Look
      SMALLEST_WINDOW = [400, 320].freeze

      def initialize(env = ENV)
        @env = env
        @elapsed = 0.0
      end

      def load
        os = ::Lota::System.os
        @dot_size = DotSize.for(os)
        puts "Dot Popper: a dot's radius is #{@dot_size.reason}"
        open_window unless DotSize.touch?(os)
        random = seed ? Random.new(seed) : Random.new
        @game = Game.new(field, best: BestScore.new(SaveFile.new(name: "best_score.txt")), random:)
        @speaker = Speaker.new(Look::PATCHES, store: SaveFile.new(name: "sound.txt"), volume: Look::SOUND.volume)
        @show = Presentation::Show.new(game: @game, layout:, sounds: @speaker, radius: @dot_size.radius,
                                       random:, calm: flag?("DOT_POPPER_CALM"))
        @pile = Pile.new(flag?("DOT_POPPER_CALM") ? Look::CALM_PILE : Look::PILE)
        @game.subscribe(@pile)
        @pen = Pen.new(Look, shaders: !flag?("DOT_POPPER_NO_SHADERS"))
        @renderer = Renderer.new(@show, @pen, pile: @pile)
        @renderer.prepare
        @input = Presentation::InputRouter.new
        @autopilot = Presentation::Autopilot.new(Look::AUTOPILOT) if flag?("DOT_POPPER_AUTOPLAY")
        @shots = Presentation::ShotSchedule.parse(@env["DOT_POPPER_SHOTS"])
        @quit_after = Float(@env.fetch("DOT_POPPER_QUIT_AFTER", ""), exception: false)
      end

      def update(seconds)
        seconds = seconds.clamp(0.0, Rules::LONGEST_FRAME)
        if @autopilot
          x, y = @autopilot.update(seconds, @game)
          tap(x, y) if x
        end
        @game.update(seconds)
        @show.update(seconds)
        @pile.update(seconds)
        development(seconds)
      end

      def draw = @renderer.draw

      def mouse_pressed(x, y, button, istouch)
        tap = @input.mouse_pressed(x, y, button, istouch)
        tap(tap.x, tap.y) if tap
      end

      def touch_pressed(id, x, y, devicetype, mouse)
        tap = @input.touch_pressed(id, x, y, devicetype, mouse)
        tap(tap.x, tap.y) if tap
      end

      def key_pressed(key)
        case key
        when :escape then ::Lota::Event.quit
        when :f11 then toggle_fullscreen
        when :return, :kpenter then toggle_fullscreen if ::Lota::Keyboard.down?(:lalt, :ralt, :lgui, :rgui)
        when :m then @speaker.toggle_mute
        end
      end

      # The window changed size, or moved to a screen of another density.
      def resize
        return unless @show

        @pen.refresh
        @game.field = field
        @show.resize(layout, @game.field)
        @pile.refit(@game.field)
        @renderer.prepare
      end

      private

      def tap(x, y) = @show.tap(x, y)

      def open_window
        size = Look::WINDOW.size_for(*::Lota::Window.desktop_dimensions, @dot_size.radius)
        ::Lota::Window.set_mode(*size, resizable: true, centered: true, minwidth: SMALLEST_WINDOW[0],
                                       minheight: SMALLEST_WINDOW[1])
      end

      def toggle_fullscreen
        fullscreen, = ::Lota::Window.fullscreen
        ::Lota::Window.set_fullscreen(!fullscreen, :desktop)
      end

      def field = @dot_size.field(*::Lota::Graphics.dimensions)

      def layout
        width, height = ::Lota::Graphics.dimensions
        x, y, safe_width, safe_height = ::Lota::Window.safe_area
        safe = Presentation::Rect.new(x:, y:, width: safe_width, height: safe_height)
        safe = Presentation::Rect.new(x: 0, y: 0, width:, height:) unless safe.width.to_f.positive?
        Presentation::Layout.new(width:, height:, safe:, look: Look::LAYOUT)
      end

      def flag?(name) = @env[name] == "1"
      def seed = Integer(@env.fetch("DOT_POPPER_SEED", ""), exception: false)

      # The development hooks main.rb describes.
      def development(seconds)
        before = @elapsed
        @elapsed += seconds
        @shots.due(before, @elapsed).each { screenshot(it) }
        ::Lota::Event.quit if @quit_after && @elapsed >= @quit_after
      end

      def screenshot(number)
        name = "shot-#{number}.png"
        ::Lota::Graphics.capture_screenshot(name)
        puts "Dot Popper: screenshot #{File.join(::Lota::Filesystem.save_directory, name)}"
      end
    end
  end
end
