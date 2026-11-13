# frozen_string_literal: true

module DotPopper
  module Presentation
    # Asks the game's server which themes are unlocked, and tells the
    # ThemeKeeper: at launch, and again when Refresh says, each read on
    # its own thread (Network::Worker), so a frame never waits; offline,
    # it simply does nothing, and what was saved stays. The server asks
    # only for the date the player first played, with no account and no
    # group, so one date is kept for every player, set once, the first
    # time the game runs.
    class ThemeFeed
      # The one request themes make; #ask makes it only from here.
      REQUESTS = [
        Network::Request.new(kind: :themes, verb: :get, path: "/themes", feature: "themes",
                             query: { started_on: Network::Field.new(what: "the date this device first played", label: :other_usage) },
                             happens: "When the game starts, to learn which themes are available; for every player, Free too, with no private code. #{Refresh::HAPPENS}")
      ].to_h { [it.kind, it] }.freeze

      # Keys in the server's answer: [{"key": "ghost"}, ...].
      def self.keys(body)
        return nil unless body.is_a?(Array)

        body.filter_map { it["key"] if it.is_a?(Hash) && it["key"].is_a?(String) }
      end

      def initialize(worker:, theme_keeper:, store:, clock: -> { Time.now })
        @worker = worker
        @theme_keeper = theme_keeper
        @store = store
        @clock = clock
      end

      # The UTC date to send, kept once, from the first run on. It is the
      # date in UTC, not the player's own, because that is the date the
      # server asks for (+clock+ answers a Time).
      def started_on
        @store.read.to_s.strip.empty? ? @store.write(@clock.call.getutc.to_date.iso8601) : nil
        @store.read.to_s.strip
      end

      # Starts one read.
      def ask = @worker.start(Network::Job.of(REQUESTS.fetch(:themes), query: { started_on: }), nil)

      # Takes up finished reads. Says whether anything new arrived.
      def update
        @worker.finished.map { |_job, reply| receive(reply) }.any?
      end

      private

      def receive(reply)
        return false unless reply.ok?

        keys = self.class.keys(reply.body)
        keys ? @theme_keeper.receive(keys) : false
      end
    end
  end
end
