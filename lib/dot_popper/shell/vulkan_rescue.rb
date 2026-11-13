# frozen_string_literal: true

require "date"
require "rbconfig"
require_relative "renderer_choice"
require_relative "vulkan_failure"
require_relative "relaunch"
require_relative "save_file"

module DotPopper
  module Shell
    # Gets the game past a computer whose Vulkan can't start it. conf.rb
    # loads this before Lota opens anything, so main.rb isn't loaded yet:
    # VulkanRescue.choose picks the renderers there, and conf.rb's
    # Lota.errorhandler hands each error to #rescue first.
    #
    # When Vulkan fails, #rescue notes the day in the save folder
    # (VulkanFailure), and starts the game again at once with
    # DOT_POPPER_NO_VULKAN=1 (Relaunch), so the player sees the game, not
    # an error, on the very first launch. The note
    # spares the next launches the failed try, for a month. Where the game
    # can't start itself again, as on a phone, one line asks the player
    # to, and the note makes that start work.
    class VulkanRescue
      NOTE = "vulkan_failed.txt"
      # What LÖVE says when the renderer it picked can't start the game:
      # Vulkan finding no GPU it can use ("Vulkan: failed to find a
      # suitable GPU."), or any other Vulkan error, none of the listed
      # renderers creating at all, or the system refusing the window.
      FAILED_START = Regexp.union("Vulkan", "suitable GPU", "no supported renderer", "Could not set window mode")
      NO_VULKAN = "DOT_POPPER_NO_VULKAN"
      START_AGAIN = "Dot Popper will use different graphics now. Please start it again."

      # The rescue for the game saving as +identity+, whose window is
      # called +title+. It reads the note from that save folder, which it
      # makes the save folder now: until conf.rb returns, Lota's is the
      # one named after the game's folder.
      def self.choose(identity:, title:, env: ENV, today: Date.today)
        note = note(identity)
        noted = note&.holds?(today) || false
        puts "Dot Popper: Vulkan failed here on #{note}, so it is left out until #{note&.retry_on}" if noted
        failed = noted || env.fetch(NO_VULKAN, "") == "1"
        asked = RendererChoice.asked(env["DOT_POPPER_RENDERERS"])
        choice = RendererChoice.decide(asked:, ruby_platform: RUBY_PLATFORM, vulkan_failed: failed)
        new(choice, title:, env:, today:)
      end

      # The note in +identity+'s save folder, or nil, as when `lota fuse`
      # reads the settings with no filesystem open.
      def self.note(identity)
        ::Lota::Filesystem.identity = identity
        contents, = ::Lota::Filesystem.read(NOTE) if ::Lota::Filesystem.info(NOTE)
        VulkanFailure.parse(contents)
      rescue RuntimeError
        nil
      end
      private_class_method :note

      attr_reader :choice

      def initialize(choice, title:, env: ENV, today: Date.today)
        @choice = choice
        @title = title
        @env = env
        @today = today
      end

      # Puts the choice into conf.rb's t.graphics.
      def apply(graphics)
        graphics.renderers = choice.renderers if choice.renderers
        graphics.excluderenderers = choice.excluded unless choice.excluded.empty?
      end

      # Whether +error+, raised before or while the game started, is LÖVE
      # failing to start a renderer (FAILED_START).
      def self.failed_start?(error) = error.is_a?(RuntimeError) && FAILED_START.match?(error.message)

      # Whether leaving Vulkan out may get past +error+: a failed start,
      # while Vulkan may still be tried (RendererChoice#vulkan_allowed?).
      def rescues?(error) = choice.vulkan_allowed? && self.class.failed_start?(error)

      # The frame Lota runs in place of the game's after +error+, or nil
      # when leaving Vulkan out can't help, for Lota's own error screen.
      def rescue(error)
        return unless rescues?(error)

        warn "Dot Popper: Vulkan couldn't start the game (#{error.message.split("\n").map(&:strip).join(' ')}), " \
             "so it starts again without Vulkan"
        SaveFile.new(name: NOTE).write(VulkanFailure.new(day: @today).to_s)
        @env[NO_VULKAN] = "1"
        start_again
      end

      private

      # The game itself in place of this process (on Windows, Ruby's exec
      # runs it, waits, and exits with its status), or else one line for
      # the player.
      def start_again
        relaunch = Relaunch.new(ruby_platform: RUBY_PLATFORM, fused: ::Lota::Filesystem.fused?,
                                program: File.expand_path($PROGRAM_NAME), arguments: ARGV.dup,
                                ruby: RbConfig.ruby, title: @title, exists: File.method(:file?))
        command = relaunch.command or return ask_to_start_again
        ::Lota::Window.close if ::Lota::Window.open?
        $stdout.flush
        $stderr.flush
        program, *arguments = command
        Kernel.exec([program, program], *arguments) # never through a shell, though the name has a space
      rescue SystemCallError => e
        warn "Dot Popper: could not start again: #{e.message}"
        ask_to_start_again
      end

      def ask_to_start_again
        warn "Dot Popper: #{START_AGAIN}"
        ::Lota::Window.show_message_box(@title, START_AGAIN, :info, false)
        -> { 1 }
      rescue RuntimeError
        -> { 1 }
      end
    end
  end
end
