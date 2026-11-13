# frozen_string_literal: true

# A stand-in for Lota on an Android phone, with no window, for
# test/android/kit_test.rb. It is found as "lota" ahead of the real gem,
# so the phone project's main.rb (android/android_kit) and the game's
# bin/dot_popper run unchanged on top of it. Lota::Boot loads the game's
# conf.rb and main.rb as Lota's does, and then, instead of a window,
# plays the game frame by frame on a clock of its own and does to it what
# the Android emulator checks do (.github/android_emulator_checks.sh),
# as SDL would hand it over: Back is the key :escape, the Home button is
# the window's focus lost, and starting the activity again is the focus
# gained. FAKE_ANDROID_DRIVE (JSON) says what to do and when:
#
#   {"keys": [[SECONDS, "KEYCODE_BACK", "REGEX"], ...],
#    "shells": [[SECONDS, "am start ..."], ...], "ready": "REGEX", "timeout": SECONDS}
#
# Every line the game prints goes to standard output, as Fledge's host
# sends it to the log; the host's own last line, "Dot Popper exited with
# status N", follows once the game quits or fails. What draws, sounds or
# senses (the pen, the renderer, the speaker, the pile's physics, the
# accelerometer) is left out: a stand-in that answers nil to everything.

require "json"

module Lota
  VERSION = "0.0.0-fake-android"

  # A module that answers every method with nil and makes a module of the
  # same kind for every constant asked of it.
  class Anything < Module
    def const_missing(name) = const_set(name, Anything.new)
    def method_missing(*, **) = nil
    def respond_to_missing?(*) = true
  end

  # An object that answers every method with nil.
  class Nothing < BasicObject
    def initialize(*, **); end
    def method_missing(*, **) = nil
    def respond_to_missing?(*) = true
  end

  def self.const_missing(name) = const_set(name, Anything.new)

  WIDTH = 320
  HEIGHT = 640
  DPI_SCALE = 2.625

  System = Anything.new
  def System.os = "Android"
  def System.open_url(_url) = true

  Timer = Anything.new
  class << Timer
    attr_accessor :now

    def time = @now || 0.0
  end

  Event = Anything.new
  class << Event
    attr_reader :quit_asked

    def quit(*) = @quit_asked = true
  end

  Keyboard = Anything.new
  def Keyboard.down?(*) = false

  Mouse = Anything.new
  def Mouse.cursor_supported? = false

  Graphics = Anything.new
  def Graphics.dimensions = [WIDTH, HEIGHT]
  def Graphics.width = WIDTH
  def Graphics.height = HEIGHT
  def Graphics.pixel_dimensions = [(WIDTH * DPI_SCALE).round, (HEIGHT * DPI_SCALE).round]
  def Graphics.dpi_scale = DPI_SCALE
  def Graphics.renderer_info = ["OpenGL ES", "3.0 fake", "Google", "a stand-in"]

  Window = Anything.new
  Flags = Struct.new(:fullscreen, :fullscreentype, :highdpi, :usedpiscale)
  def Window.mode = [WIDTH, HEIGHT, Flags.new(true, :desktop, true, true)]
  def Window.safe_area = [0, 0, WIDTH, HEIGHT]
  def Window.native_dpi_scale = DPI_SCALE
  def Window.fullscreen = [true, :desktop]
  def Window.desktop_dimensions = [WIDTH, HEIGHT]
  def Window.open? = true

  # The save folder, in memory.
  Filesystem = Anything.new
  class << Filesystem
    attr_accessor :identity

    def files = @files ||= {}
    def fused? = true
    def save_directory = "/data/user/0/com.setdef.DotPopper/files/save/#{identity}"
    def read(name) = files[name]&.then { [it, it.bytesize] }
    def write(name, text) = (files[name] = text.to_s) && [true]
    def info(name) = files.key?(name) ? { type: :file, size: files[name].bytesize } : nil
    def remove(name) = !files.delete(name).nil?
  end

  # What conf.rb's Lota.conf fills in: settings, each of whose groups is
  # another such.
  class Settings
    def initialize = @values = {}
    def window = @values[:window] ||= Settings.new
    def graphics = @values[:graphics] ||= Settings.new
    def method_missing(name, *arguments) = name.end_with?("=") ? @values[name.to_s.chomp("=").to_sym] = arguments.first : @values[name]
    def respond_to_missing?(*) = true
  end

  # Starts the game in +folder+ as Lota's Boot does, then plays it
  # (FakeAndroid).
  class Boot
    def initialize(folder, _arguments, fused:)
      @folder = folder
      @fused = fused
    end

    def call
      settings = Settings.new
      require File.join(@folder, "conf.rb")
      Lota.conf(settings) if Lota.respond_to?(:conf)
      Filesystem.identity = settings.identity
      require File.join(@folder, "main.rb")
      FakeAndroid.new(JSON.parse(ENV.fetch("FAKE_ANDROID_DRIVE", "{}"))).run
    end
  end

  # Plays the game loaded by Boot, a frame at a time, and does what
  # +drive+ says when its lines say to.
  class FakeAndroid
    FRAME = 1 / 30.0

    def initialize(drive)
      @keys = drive.fetch("keys", []).map { |seconds, code, pattern| [seconds, code, Regexp.new(pattern)] }
      @shells = drive.fetch("shells", []).sort_by(&:first)
      @ready = Regexp.new(drive.fetch("ready", "loaded"))
      @timeout = drive.fetch("timeout", 240).to_f
      @lines = []
    end

    def run
      leave_out_what_needs_a_screen
      record_lines
      status = play
      $stdout = STDOUT
      puts "Dot Popper exited with status #{status}"
      status
    end

    private

    # The shell's parts that draw, sound or sense, as Nothing.
    def leave_out_what_needs_a_screen
      shell = DotPopper::Shell
      %i[Renderer Bloom ParticleSystems Pile Tilting Accelerometer FakeAccelerometer Dragging].each do |name|
        shell.send(:remove_const, name)
        shell.const_set(name, Class.new(Nothing))
      end
      engine = Class.new(shell::Engine) do
        def pen(shaders:) = Nothing.new
        def measure(_pen) = DotPopper::Presentation::RoughMeasure.new
        def speaker(store:) = Nothing.new
      end
      shell.send(:remove_const, :Engine)
      shell.const_set(:Engine, engine)
    end

    # Every line the game prints, kept to act on, and passed on.
    def record_lines
      lines = @lines
      $stdout = Object.new.tap do |out|
        out.define_singleton_method(:write) do |*texts|
          texts.join.each_line { lines << it.chomp }
          STDOUT.write(*texts)
        end
        out.define_singleton_method(:sync=) { |_| nil }
        out.define_singleton_method(:sync) { true }
        out.define_singleton_method(:flush) { STDOUT.flush }
      end
    end

    def play
      now = 0.0
      Timer.now = 100.0
      Lota.load
      seen = 0
      ready_at = nil
      until Event.quit_asked || now > @timeout
        now += FRAME
        Timer.now += FRAME
        Lota.update(FRAME)
        Lota.draw
        @lines.drop(seen).each do |line|
          ready_at ||= now if @ready.match?(line)
          @keys.each { |key| key[3] ||= now + key[0] if key[2].match?(line) }
        end
        seen = @lines.size
        @keys.each { |key| (key[4] = true) && press(key[1]) if key[3] && !key[4] && now >= key[3] }
        @shells.shift.then { shell(it[1]) } while ready_at && @shells.first && now - ready_at >= @shells.first[0]
      end
      Event.quit_asked ? 0 : 1
    rescue Exception => e # rubocop:disable Lint/RescueException
      warn "#{e.class}: #{e.message}\n\t#{e.backtrace&.first(8)&.join("\n\t")}"
      1
    end

    # What SDL hands the game for each key the checks send.
    def press(code)
      STDOUT.puts "fake android: sent #{code}"
      case code
      when "KEYCODE_BACK" then Lota.keypressed(:escape, :acback, false)
      when "KEYCODE_HOME" then Lota.focus(false) if Lota.respond_to?(:focus)
      else raise "the fake Android has no #{code}"
      end
    end

    # Starting the activity again brings the game back to the front.
    def shell(command)
      raise "the fake Android can't run #{command}" unless command.start_with?("am start")

      Lota.focus(true) if Lota.respond_to?(:focus)
    end
  end
end
