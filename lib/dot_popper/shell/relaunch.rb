# frozen_string_literal: true

module DotPopper
  module Shell
    # How the game starts itself again, as it first started:
    #
    # - in a Windows app Fledge built, the app's NAME.exe, two folders
    #   above the program Ruby runs (ROOT\app\main.rb), since Fledge's
    #   launcher there is what sets the app's Ruby up;
    # - in a macOS or Linux app, `RbConfig.ruby $0 ARGV`, which Fledge
    #   hands back to the app's launcher;
    # - under `lota run`, not fused, `RbConfig.ruby $0 run ARGV`: $0 is
    #   lota's own program, which took "run" off ARGV, leaving the game's
    #   folder and arguments, and `bundle exec` left its setup in the
    #   environment. (Lota's own restart is the same since 0.3.0, but ends
    #   with no message when it can't start the game; see ADR-0007.)
    # - on a phone, not at all: the player starts it again (#command is
    #   nil).
    #
    # +ruby_platform+ is RUBY_PLATFORM, +program+ $PROGRAM_NAME, +arguments+ ARGV, +ruby+ RbConfig.ruby,
    # +title+ the window's title (the app's name), and +exists+ answers
    # whether a file is there.
    class Relaunch < Data.define(:ruby_platform, :fused, :program, :arguments, :ruby, :title, :exists)
      # The command, as a program and its arguments, or nil when there is
      # none.
      def command
        return if ruby_platform.match?(/android|ios/)
        return [ruby, program, "run", *arguments] unless fused
        return [ruby, program, *arguments] unless ruby_platform.match?(/mingw|mswin/)

        launcher = File.join(File.dirname(program, 2), "#{title}.exe")
        [launcher, *arguments] if exists.call(launcher)
      end
    end
  end
end
