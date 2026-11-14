# frozen_string_literal: true

require "etc"
require "fileutils"
require "tmpdir"

module DotPopperGui
  # The X displays the GUI scenarios play on when several play at once,
  # one game to a display at a time.
  #
  # Two games can't share a display: a window opening, closing or going
  # fullscreen over another sends the one beneath an Enter or a Leave,
  # which SDL hands the game as a move of the mouse to wherever the
  # pointer rests, so one scenario would move another's mouse. So the
  # first game plays on the display the suite was given, and each game
  # that starts while every display is busy gets one of its own: a virtual
  # display (Xvfb) of the size the GUI workflow's xvfb-run makes, with
  # Openbox managing its windows, as script/with-openbox.sh manages the
  # first. A display serves one game after another, as the one display
  # served the whole suite before.
  #
  # The displays close when the suite ends, and with it however it ends:
  # each is started by a shell that holds the read end of a pipe only
  # this process writes to, and stops the display once the pipe closes.
  #
  # Games play at once only on Linux under X with Xvfb and Openbox on the
  # PATH. Anywhere else, Displays.workers is 1, and every game plays on
  # the display given, one after another.
  class Displays
    SCREEN = "1280x1024x24"
    WAIT = 60 # seconds for a display, and then Openbox, to be ready, as with-openbox.sh waits
    MOST = 8 # games at once by default; more gained little on a 24-thread machine

    # Runs its arguments until standard input closes, then stops them.
    WHILE_OPEN = '"$@" & child=$!; read -r _; kill "$child" 2> /dev/null; wait "$child"'

    class << self
      # How many games play at once: DOT_POPPER_GUI_WORKERS if set, else
      # one a processor, at most MOST; 1 where no display can be started.
      def workers(env = ENV, platform: RUBY_PLATFORM, found: method(:on_path?))
        return 1 unless platform.include?("linux") && !env.fetch("DISPLAY", "").empty? && %w[Xvfb openbox].all?(&found)

        asked = env.fetch("DOT_POPPER_GUI_WORKERS", "").strip
        return [Integer(asked), 1].max unless asked.empty?

        Etc.nprocessors.clamp(1, MOST)
      end

      def on_path?(command) = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { File.executable?(File.join(it, command)) }
    end

    def initialize(given = ENV.fetch("DISPLAY", nil))
      @free = Queue.new
      @free << given
      @shells = []
      @folders = []
      @lock = Mutex.new
      @lifeline, @lifeline_writer = IO.pipe
    end

    # Lends the block a display no other game is playing on, starting one
    # if there is none, and takes it back after.
    # The display given may be none (nil), where the games play one after
    # another on whatever the system gives them.
    def lend
      display = begin
        @free.pop(true)
      rescue ThreadError
        start
      end
      begin
        yield display
      ensure
        @free << display
      end
    end

    # Stops the displays this started, and waits until they have.
    def close
      @lifeline_writer.close unless @lifeline_writer.closed?
      @shells.each do |pid|
        Process.wait(pid)
      rescue Errno::ECHILD
        nil
      end
      @folders.each { FileUtils.rm_rf(it) }
    end

    private

    def start
      folder = Dir.mktmpdir("dot_popper_gui_display")
      @lock.synchronize { @folders << folder }
      display = xvfb(folder)
      openbox(display, folder)
      display
    end

    # Starts a display and returns its name, which Xvfb chooses from the
    # numbers free and writes to the pipe it is given (-displayfd).
    def xvfb(folder)
      log = File.join(folder, "xvfb.log")
      reader, writer = IO.pipe
      begin
        run("Xvfb", "-displayfd", writer.fileno.to_s, "-screen", "0", SCREEN, "-nolisten", "tcp", log:, writer => writer)
        writer.close
        number = reader.wait_readable(WAIT) && reader.gets
      ensure
        writer.close unless writer.closed?
        reader.close
      end
      raise "Xvfb gave no display within #{WAIT} seconds: #{File.read(log)}" unless number

      ":#{number.strip}"
    end

    # Starts Openbox on +display+ and waits until it has taken the screen,
    # which it says by running its --startup command.
    def openbox(display, folder)
      ready = File.join(folder, "ready")
      log = File.join(folder, "openbox.log")
      run({ "DISPLAY" => display }, "openbox", "--startup", "touch '#{ready}'", log:)
      (WAIT * 10).times do
        return if File.exist?(ready)

        sleep 0.1
      end
      raise "Openbox did not take #{display} within #{WAIT} seconds: #{File.read(log)}"
    end

    def run(*command, log:, **options)
      pid = Process.spawn(*command.take_while { it.is_a?(Hash) }, "sh", "-c", WHILE_OPEN, "sh",
                          *command.drop_while { it.is_a?(Hash) }, in: @lifeline, %i[out err] => log, **options)
      @lock.synchronize { @shells << pid }
    end
  end
end
