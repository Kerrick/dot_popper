# frozen_string_literal: true

module DotPopper
  module Shell
    # The native port's adapter on a computer whose build is sold through
    # its own store (Presentation::Storefront::HELPER_CHANNELS). The game
    # can't call StoreKit or Windows.Services.Store, so it starts a small
    # program shipped in the app, its store helper (macos/store,
    # windows/store), once for each request. The helper takes the same
    # dotpopper-store: URL the phones' hosts catch and answers the same
    # whole state, but writes it to its standard output, the pipe the
    # game opened, not to a file. Each answer ends with an empty line.
    #
    # The pipe matters on Windows. There the answer is Windows' word,
    # with nothing signed the game could check (Receipt::Microsoft), so it
    # must come by a road no player can write to without changing the
    # app's own files. A file in the save folder would be such a road; a
    # pipe from a program in the app's read-only install folder is not.
    #
    # An automated run starts no helper: the store is the internet, and
    # an automated run stays off it (Automation). Its request is refused,
    # as on a system that will not open the URL.
    class StoreHelper
      NAMES = { "OS X" => "dot-popper-store", "Windows" => "dot-popper-store.exe" }.freeze
      # The helper's path in what +path+ answers, which the URL names.
      PIPE = "-"
      # How many folders up from a start the helper is looked for.
      DEPTH = 6

      # The helper beside this game on +os+, or none: on macOS in the app's
      # Contents/Helpers, on Windows beside the program. Looked for from
      # each folder in +starts+ and the folders above it.
      def self.find(os, starts:)
        name = NAMES[os] or return nil
        starts.each do |start|
          folder = File.expand_path(start)
          DEPTH.times do
            [File.join(folder, name), File.join(folder, "Helpers", name)].each { return it if File.file?(it) && File.executable?(it) }
            folder = File.dirname(folder)
          end
        end
        nil
      end

      # +command+ is the helper and anything to put before the URL, or nil
      # where there is none.
      def initialize(command, automated: false)
        @command = command && Array(command)
        @automated = automated
        @lock = Mutex.new
        @answer = nil
        @running = 0
      end

      def path = PIPE

      # Starts the helper for +url+, and reads its answers as they come.
      # False if there is none, or it would not start.
      def open(url)
        return false if @automated || @command.nil?

        pipe = IO.popen([*@command, url], "r", err: File::NULL)
        @lock.synchronize { @running += 1 }
        Thread.new { listen(pipe) }.tap { it.report_on_exception = false }
        true
      rescue SystemCallError, IOError
        false
      end

      def read = @lock.synchronize { @answer }
      def remove = @lock.synchronize { @answer = nil }

      # Whether a helper is still working on a request.
      def busy? = @lock.synchronize { @running.positive? }

      private

      def listen(pipe)
        lines = []
        pipe.each_line do |line|
          if line.strip.empty?
            heard(lines.join) unless lines.empty?
            lines = []
          else
            lines << line
          end
        end
        heard(lines.join) unless lines.empty?
      rescue IOError, SystemCallError
        nil
      ensure
        pipe.close
        @lock.synchronize { @running -= 1 }
      end

      # Keeps the newest request's answer: a helper still finishing an
      # older request (two can run at once) never hides a newer one's.
      def heard(text)
        @lock.synchronize do
          @answer = text if number(text) >= number(@answer)
        end
      end

      def number(text) = text.to_s[/^answer=(\d+)$/, 1].to_i
    end
  end
end
