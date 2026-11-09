# frozen_string_literal: true

require "socket"

module DotPopper
  # Whether this run is an automated one, and the guard that keeps every
  # automated run off the internet. An automated run is the test suite, a
  # GUI scenario, the autoplay bot, or any run told to quit or take
  # screenshots by itself: CI's packaged-app playthroughs and its Android
  # and iOS emulator checks among them. Such a run reaches no outside host
  # at all, so what happens in production (a theme released, a store's
  # answer, the network being down) never changes its result. It may talk
  # to a fake on this machine (localhost), as test/privacy and the gallery
  # scenarios do with script/group_stub.rb.
  module Automation
    FLAGS = %w[DOT_POPPER_AUTOMATED DOT_POPPER_AUTOPLAY DOT_POPPER_SCENARIO DOT_POPPER_QUIT_AFTER DOT_POPPER_SHOTS].freeze
    LOCAL = %w[localhost 127.0.0.1 ::1].freeze

    # An automated run tried to reach a host that is not this machine.
    class OutsideConnection < Exception; end # rubocop:disable Lint/InheritException

    module_function

    def on?(env = ENV) = FLAGS.any? { !env.fetch(it, "").to_s.empty? && env[it] != "0" }

    def local?(host) = LOCAL.include?(host.to_s.delete("[]").downcase)

    # Refuses every connection to an outside host from now on in this
    # process: in the tests it raises, and in a game it says so and ends
    # the run with status 70, so the check that started it fails.
    def guard!(exit_on_attempt: false)
      @exit_on_attempt = exit_on_attempt
      return if @guarded

      @guarded = true
      TCPSocket.singleton_class.prepend(Guard)
      Socket.singleton_class.prepend(SocketGuard)
    end

    def refuse(host)
      return if local?(host)

      message = "Dot Popper: an automated run tried to reach #{host}; automated runs stay off the internet (DotPopper::Automation)"
      raise OutsideConnection, message unless @exit_on_attempt

      warn message
      Kernel.exit!(70)
    end

    # TCPSocket.new and .open, which Net::HTTP uses.
    module Guard
      def new(host, *rest, **options)
        Automation.refuse(host)
        super # steep:ignore UnexpectedSuper
      end

      def open(host, *rest, **options)
        Automation.refuse(host)
        super
      end
    end

    # Socket.tcp, the other way Ruby opens a connection.
    module SocketGuard
      def tcp(host, *rest, **options, &block)
        Automation.refuse(host)
        super # steep:ignore UnexpectedSuper
      end
    end
  end
end
