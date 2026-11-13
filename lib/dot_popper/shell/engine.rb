# frozen_string_literal: true

module DotPopper
  module Shell
    # What only Lota can make or do, as the composition root asks for it
    # (Composition::Root, which lists each). Shell::App makes one as the
    # game loads, on the system Lota names (Platforms), and hands it over.
    class Engine
      Style = Presentation::Style

      attr_reader :platform, :unit

      # The engine on the system Lota::System.os calls +system+.
      def initialize(system)
        @platform = Platforms.for(system)
        @unit = Platforms.unit(system)
      end

      def file(name) = SaveFile.new(name:)
      def path(name) = File.join(::Lota::Filesystem.save_directory, name)
      def say(line) = puts("Dot Popper: #{line}")

      def dimensions = ::Lota::Graphics.dimensions

      # The window's layout, with the safe area Lota reports, or the whole
      # window where it reports none.
      def layout
        width, height = dimensions
        x, y, safe_width, safe_height = ::Lota::Window.safe_area
        safe = Presentation::Rect.new(x:, y:, width: safe_width, height: safe_height)
        safe = Presentation::Rect.new(x: 0, y: 0, width:, height:) unless safe.width.to_f.positive?
        Presentation::Layout.new(width:, height:, safe:, style: Style::LAYOUT)
      end

      # A phone or tablet's window already covers the screen; fullscreen
      # hides the status bar over it and, on iOS, makes a swipe from an
      # edge ask twice before it leaves the game (SDL's UIKit view
      # controller), so a tap near the edge stays a tap. Then the renderer
      # and the screen are reported, as for a computer's window.
      def fill_screen
        ::Lota::Window.set_fullscreen(true, :desktop)
        report_renderer
        report_screen
      end

      # The window, sized in graphics units: where the system's window
      # coordinates are pixels (Windows at 200%), its size and smallest
      # size are scaled to them, so a scaled display gets the same window.
      def open_window(radius:, wanted:, smallest:)
        width, = ::Lota::Window.mode
        per_unit = [width.to_f / ::Lota::Graphics.width, 1.0].max
        size = Style::WINDOW.mode_for(*::Lota::Window.desktop_dimensions, radius, per_unit:, smallest:, wanted:)
        ::Lota::Window.set_mode(size[0], size[1], resizable: true, centered: true, minwidth: size[2], minheight: size[3])
        report_renderer
        report_screen
      end

      def desktop_window(exclusive:) = DesktopWindow.new(exclusive:)
      def pen(shaders:) = Pen.new(Style, shaders:)
      def measure(pen) = FontMeasure.new(pen.fonts)
      def speaker(store:) = Speaker.new(Style::PATCHES, store:, volume: Style::SOUND.volume)
      def clipboard = Clipboard.new
      def opener = UrlOpener.new
      def buzzer = Haptics.new
      def store_answers = StoreAnswers.in_save_folder

      def notices
        NoticeFiles.new(cabinet: File.expand_path("../../..", __dir__), starts: [File.dirname(File.expand_path($PROGRAM_NAME))]).notices
      end

      def store_helper(automated:)
        StoreHelper.new(StoreHelper.find(platform, starts: [__dir__, File.dirname(File.expand_path($PROGRAM_NAME))]), automated:)
      end

      # The graphics renderer LÖVE chose, as Vulkan, OpenGL ES, or Metal,
      # its version, and the GPU's maker and name.
      def report_renderer
        name, version, vendor, device = ::Lota::Graphics.renderer_info
        say("renderer #{name} #{version} / #{vendor} / #{device}")
      end

      # One line on what the window is (Presentation::ScreenReport), to
      # compare a real device's run with an SDL test program's on it.
      def report_screen
        width, height, flags = ::Lota::Window.mode
        mode_flags = %i[fullscreen fullscreentype highdpi usedpiscale].filter_map do |name|
          [name, flags.public_send(name)] if flags.respond_to?(name)
        end.to_h
        report = Presentation::ScreenReport.new(
          units: ::Lota::Graphics.dimensions, pixels: ::Lota::Graphics.pixel_dimensions,
          dpi_scale: ::Lota::Graphics.dpi_scale, native: ::Lota::Window.native_dpi_scale,
          safe: ::Lota::Window.safe_area, mode: [width, height, mode_flags]
        )
        say(report.to_s)
      end
    end
  end
end
