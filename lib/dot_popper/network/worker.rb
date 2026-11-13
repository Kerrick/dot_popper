# frozen_string_literal: true

module DotPopper
  module Network
    # Runs a Link's requests in order on a thread of its own, so a frame
    # never waits on the network. The thread starts with its first job,
    # so nothing asked means no thread, and it runs at low priority, so
    # what little Ruby it runs between its waits cannot hold up a frame.
    class Worker
      PRIORITY = -2

      def initialize(link)
        @link = link
        @jobs = Queue.new
        @done = Queue.new
      end

      # Starts +job+ (a Job, or what answers its verb, path and body) with
      # +token+.
      def start(job, token)
        @thread ||= Thread.new { work }
        @jobs << [job, token]
      end

      # Every finished job with its Reply, as [job, reply] pairs.
      def finished
        pairs = []
        pairs << @done.pop until @done.empty?
        pairs
      end

      private

      def work
        Thread.current.priority = PRIORITY
        loop do
          job, token = @jobs.pop
          @done << [job, @link.call(job, token)]
        end
      end
    end
  end
end
