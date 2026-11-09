# frozen_string_literal: true

module DotPopper
  module Presentation
    # Asks the game's server which themes are unlocked, and tells the
    # ThemeKeeper. One read, on its own thread (Groups::Worker), so a frame
    # never waits; offline, it simply does nothing, and what was saved
    # stays. The server asks only for the date the player first played,
    # with no account and no group, so one date is kept for every player,
    # set once, the first time the game runs.
    class ThemeFeed
      Job = Data.define(:verb, :path, :body)

      # Keys in the server's answer: [{"key": "ghost"}, ...].
      def self.keys(body)
        return nil unless body.is_a?(Array)

        body.filter_map { it["key"] if it.is_a?(Hash) && it["key"].is_a?(String) }
      end

      def initialize(worker:, theme_keeper:, store:, today:)
        @worker = worker
        @theme_keeper = theme_keeper
        @store = store
        @today = today
      end

      # The date to send, kept once, from the first run on.
      def started_on
        @store.read.to_s.strip.empty? ? @store.write(@today.call.iso8601) : nil
        @store.read.to_s.strip
      end

      # Starts one read.
      def ask = @worker.start(Job.new(verb: :get, path: "/themes?started_on=#{started_on}", body: nil), nil)

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
