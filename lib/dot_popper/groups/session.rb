# frozen_string_literal: true

module DotPopper
  module Groups
    # What this device knows about its friend group, and everything it
    # asks the server for. Called only from the game's own thread, and
    # asks for nothing while a round is in play (#update's +quiet+).
    #
    # Nothing is sent until the player creates or joins a group: a Session
    # with no saved token makes no connection at all. +store+ answers
    # read and write, as a SaveFile does, and +clock+ gives the time.
    class Session
      # A request to make, and +then+ one to make after it succeeds.
      class Job < Data.define(:kind, :verb, :path, :body, :then)
        def initialize(kind:, verb:, path:, body: nil, then: nil) = super
      end

      # How long a round played offline may wait to be reported, in days.
      PENDING_DAYS = 2
      # A Worker that is never asked to do anything.
      NO_WORKER = Struct.new(:none) do
        def start(*) = nil
        def finished = []
      end.new

      # A Session with no server, for a game that offers no groups.
      def self.off = new(store: BestScore::Memory.new, worker: NO_WORKER, available: false)

      # The Session for a game whose server is at +url+, or Session.off.
      def self.at(url, store:) = url ? new(store:, worker: Worker.new(Link.new(url))) : off

      attr_reader :group, :error, :token, :name

      def initialize(store:, worker:, clock: -> { Time.now }, available: true)
        @store = store
        @worker = worker
        @clock = clock
        @available = available
        @waiting = []
        @running = 0
        @messages = []
        @group = nil
        @error = nil
        load_saved
      end

      def available? = @available
      def member? = !@group.nil?
      def known? = !@token.nil?
      def busy? = @running.positive?
      def members = @group ? @group["members"] : []
      def trophy = @group&.fetch("trophy")

      # Looks up the group, at launch and when its screen opens. Without
      # a token there is nothing to look up and nothing is sent.
      def refresh = known? ? ask(Job.new(kind: :group, verb: :get, path: "/v1/group")) : nil

      def create(name) = as_player(name, Job.new(kind: :group, verb: :post, path: "/v1/groups", body: {}))
      def join(name, code) = as_player(name, Job.new(kind: :group, verb: :post, path: "/v1/groups/join", body: { code: }))
      def leave = ask(Job.new(kind: :left, verb: :delete, path: "/v1/groups/mine"))
      def delete_everything = ask(Job.new(kind: :deleted, verb: :delete, path: "/v1/players/me"))
      def block(id) = member_action(id, :post, "block")
      def unblock(id) = member_action(id, :delete, "block")
      def report(id) = member_action(id, :post, "report")

      # A round just ended. Only one played by a member, with dots sized
      # to the screen, counts; if it cannot be sent now, the best such
      # round waits and is sent with the next contact.
      def round_finished(score:, sized_to_screen:)
        return unless member? && Trophy.counts?(sized_to_screen:) && score.positive?

        @pending = [score, @pending.to_i].max
        @pending_day = today
        save
        send_pending
      end

      # Moves on: hears what the server said, and unless a round is in
      # play (+quiet+ false), hands over what is waiting.
      def update(quiet:)
        @worker.finished.each { |job, reply| settle(job, reply) }
        return unless quiet

        @worker.start(@waiting.shift, @token) until @waiting.empty?
      end

      # The next thing to tell the player, once, or nil.
      def next_message
        message = @messages.shift or return
        tell_server(message.id) if message.id
        message
      end

      private

      def ask(job)
        @running += 1
        @waiting << job
        nil
      end

      # Makes +job+ on behalf of a player called +name+, making them
      # known to the server first if they are not, or telling it a new
      # name if it has changed.
      def as_player(name, job)
        @error = nil
        @wanted_name = name
        if !known? then ask(Job.new(kind: :player, verb: :post, path: "/v1/players", body: { name: }, then: job))
        elsif name != @name then ask(Job.new(kind: :renamed, verb: :put, path: "/v1/players/me", body: { name: }, then: job))
        else ask(job)
        end
      end

      def member_action(id, verb, what) = ask(Job.new(kind: :group, verb:, path: "/v1/members/#{id}/#{what}"))

      def send_pending
        return unless @pending && member?

        ask(Job.new(kind: :round, verb: :post, path: "/v1/rounds", body: { score: @pending, sized_to_screen: true }))
      end

      def tell_server(id)
        @told << id
        save
        ask(Job.new(kind: :told, verb: :post, path: "/v1/news/seen", body: { ids: @told }))
      end

      def settle(job, reply)
        @running -= 1
        return @error = :offline if reply.offline?
        return forget_identity if reply.status == 401
        return @error = reply.error&.to_sym || :failed unless reply.ok?

        @error = nil
        apply(job, reply)
        ask(job.then) if job.then
      end

      def apply(job, reply)
        case job.kind
        when :player then adopt(reply.body)
        when :renamed then keep_name
        when :group then look_at(reply.body["group"])
        when :left then look_at(nil)
        when :deleted then forget_identity
        when :round then finish_round(reply.body)
        end
      end

      def adopt(body)
        @token = body["token"]
        keep_name
      end

      def keep_name
        @name = @wanted_name
        save
      end

      def look_at(group)
        @group = group
        return unless group

        group["news"].reject { @told.include?(it["id"]) }.each do |news|
          next if @messages.any? { it.id == news["id"] }

          @messages << Message.stolen(news["thief"], news["score"], news["id"])
        end
        drop_stale_pending
        send_pending
      end

      def finish_round(body)
        @pending = nil
        save
        @messages << Message.taken(body["group"]["trophy"]["score"]) if body["taken"]
        look_at(body["group"])
      end

      def drop_stale_pending
        return unless @pending && today - @pending_day.to_i > PENDING_DAYS

        @pending = nil
        save
      end

      def forget_identity
        @token = nil
        @name = nil
        @group = nil
        @pending = nil
        @messages.clear
        @told = []
        save
      end

      def today = Trophy.day(@clock.call)

      # Saved one per line: token, name, unsent score and its day, and
      # the thefts already told.
      def load_saved
        token, name, pending, told = @store.read.to_s.split("\n", -1)
        @token = token unless token.to_s.empty?
        @name = name unless name.to_s.empty?
        @pending, @pending_day = pending.to_s.split.map(&:to_i)
        @told = told.to_s.split.map(&:to_i)
      end

      def save
        @store.write([@token.to_s, @name.to_s, (@pending ? "#{@pending} #{@pending_day}" : ""), @told.join(" ")].join("\n"))
      end
    end
  end
end
