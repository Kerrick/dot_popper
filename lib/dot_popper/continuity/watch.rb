# frozen_string_literal: true

module DotPopper
  module Continuity
    # A check left setdef gone, as it found or as it could not tell
    # otherwise: gone +since+ the day it was first found gone, as of
    # +today+.
    class SetdefGone < Data.define(:since, :today)
      # Whole days it has been gone.
      def days = (today - since).to_i
    end

    # setdef's server proved itself in a check.
    class SetdefHere < Data.define; end

    # Whether setdef is gone, kept as the day it was first found gone
    # (setdef.txt): the one test every rule about it uses. setdef is gone
    # when its server gives no valid signed proof and at least one
    # connectivity check answers as expected. With no internet the test is
    # false, and nothing changes: a device found gone stays gone until
    # setdef's server proves itself again. Each answer it hears is
    # announced to its listeners (#subscribe): SetdefHere when setdef
    # answered, and SetdefGone whenever setdef is gone after it.
    class Gone
      def initialize(store)
        @store = store
        @listeners = []
        @since = begin
          Date.iso8601(store.read.to_s.strip)
        rescue Date::Error
          nil
        end
      end

      # The day setdef was first found gone, or nil while it is not.
      attr_reader :since

      def gone? = !since.nil?

      # Whole days setdef has been gone by +today+, or 0.
      def days(today) = since ? (today - since).to_i : 0

      # Adds a listener: anything that answers +call(event)+.
      def subscribe(listener)
        @listeners << listener
        self
      end

      # The answer to a check (Watch): :here, :gone or :unknown.
      def heard(answer, today)
        case answer
        when :here
          @store.write("") if gone?
          @since = nil
          return announce(SetdefHere.new)
        when :gone
          unless gone?
            @since = today
            @store.write(today.iso8601)
          end
        end
        announce(SetdefGone.new(since:, today:)) if gone?
      end

      private

      def announce(event) = @listeners.each { it.call(event) }
    end

    # Asks, on a thread of its own and at low priority, so no frame waits:
    # first setdef's +server+ for a proof, and, only if it gives none, the
    # +connectivity+ checks. While setdef answers, it also asks what the
    # +license+ owes it. What it learns is taken up on the game's thread,
    # by #update, so Gone and License change only there.
    class Watch
      PRIORITY = -2
      Result = Data.define(:answer, :due, :nonce, :reply)

      def initialize(server:, connectivity:, gone:, license:, today:, pins: PINNED)
        @pins = pins
        @server = server
        @connectivity = connectivity
        @gone = gone
        @license = license
        @today = today
        @done = Queue.new
      end

      # The license's verdict from the last check taken up: :current,
      # :moved, or nil for none.
      attr_reader :gone, :license, :verdict

      # Starts a check: at launch, and when a key is entered, so it
      # registers at once while setdef answers. One asked for while a check
      # runs starts when that one is taken up.
      def start
        return @again = true if @thread&.alive?

        @again = false

        nonce = SignedAnswers.fresh
        due = @license.due(nonce)
        @thread = Thread.new do
          Thread.current.priority = PRIORITY
          @done << check(due, nonce)
        end
      end

      # Takes up a finished check. Answers what it found: :here, :gone or
      # :unknown, or nil while none has finished.
      def update
        return nil if @done.empty?

        result = @done.pop
        @thread&.join
        @gone.heard(result.answer, @today.call)
        @verdict = (@license.heard(result.due, result.nonce, result.reply) if result.reply)
        start if @again
        result.answer
      end

      # Waits for a running check, for tests.
      def join = @thread&.join

      # The check itself, on the watch's thread.
      def check(due, nonce)
        proof = SignedAnswers.fresh
        reply = @server.proof(proof)
        unless reply.ok? && SignedAnswers.proof?(reply.body, proof, @pins)
          gone = Ed25519.available? && @connectivity.online?
          return Result.new(answer: gone ? :gone : :unknown, due:, nonce:, reply: nil)
        end

        Result.new(answer: :here, due:, nonce:, reply: due && @server.ask(due))
      end
    end

    # No watch: a build with no server to check, as a store build before
    # setdef's real keys exist. setdef is never gone, and a key is never
    # moved.
    class NoWatch
      def initialize(gone:, license:)
        @gone = gone
        @license = license
      end

      attr_reader :gone, :license

      def start = nil
      def update = nil
      def join = nil
    end
  end
end
