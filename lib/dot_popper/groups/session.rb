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
    #
    # The server's refusals have empty bodies, so what went wrong is read
    # from the status alone (REFUSALS). Members have no ids: a member is
    # their look (the game's Mark), and the one with "you" set is this player.
    class Session
      # A request to make, and +then+ one to make after it succeeds.
      class Job < Data.define(:kind, :verb, :path, :body, :then)
        def initialize(kind:, verb:, path:, body: nil, then: nil) = super
      end

      # The server's kind of round for dots sized to the screen, the only
      # kind that counts, and the highest score it takes.
      SIZED_TO_SCREEN = 1
      HIGHEST_SCORE = 100_000
      SECONDS_A_DAY = 86_400
      # How long a round played offline may wait to be reported, in days.
      PENDING_DAYS = 2
      # What a status means, by the kind of job it answers. :forget means
      # the player is in no group; :drop means the server will never take
      # the round waiting.
      REFUSALS = {
        group: { 402 => :not_paid, 409 => :already_in_group, 422 => :bad_mark },
        joined: { 403 => :group_full, 404 => :no_such_group, 409 => :already_in_group, 422 => :no_such_group, 429 => :too_many_tries },
        round: { 404 => :forget, 422 => :drop }
      }.freeze
      # A Worker that is never asked to do anything.
      NO_WORKER = Struct.new(:none) do
        def start(*) = nil
        def finished = []
      end.new

      # A Session with no server, for a game that offers no groups.
      def self.off = new(store: BestScore::Memory.new, worker: NO_WORKER, available: false)

      # The Session for a game whose server is at +url+, or Session.off.
      def self.at(url, store:) = url ? new(store:, worker: Worker.new(Link.new(url))) : off

      attr_reader :group, :error, :token, :mark

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
      def score_to_beat = @group&.fetch("score_to_beat")
      # The look of the member holding the trophy, or nil if it is vacant.
      def holder_look = @group&.fetch("holder_look")

      # Looks up the group, at launch and when its screen opens. Without
      # a token there is nothing to look up and nothing is sent.
      def refresh = known? ? ask(Job.new(kind: :group, verb: :get, path: "/group")) : nil

      # Makes a group, or joins the one with +code+ (digits), wearing +mark+
      # (Groups::Mark) if no one there does, else the lowest that is free.
      # Only the game decides whether a player may create (Entitlement),
      # so the server is told the player has paid.
      def create(mark) = as_player(Job.new(kind: :group, verb: :post, path: "/group", body: { look: mark, paid: true }))
      def join(mark, code) = as_player(Job.new(kind: :joined, verb: :post, path: "/membership", body: { join_code: code, look: mark }))
      def leave = ask(Job.new(kind: :left, verb: :delete, path: "/membership"))
      def delete_everything = ask(Job.new(kind: :deleted, verb: :delete, path: "/player"))

      # A round just ended. Only one played by a member, with dots sized
      # to the screen, counts; if it cannot be sent now, the best such
      # round waits and is sent with the next contact.
      def round_finished(score:, sized_to_screen:)
        return unless belongs? && sized_to_screen == true && score.positive?

        @pending = [score.clamp(0, HIGHEST_SCORE), @pending.to_i].max
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

      # Whether this player is in a group, as far as is known: after a
      # launch with no network the group is unknown, but its rounds count.
      def belongs? = member? || @was_member

      def ask(job)
        @running += 1
        @waiting << job
        nil
      end

      # Makes +job+ on behalf of this player, making them known to the
      # server first if they are not. A player is only a token: they give
      # the server no name or anything else.
      def as_player(job)
        @error = nil
        known? ? ask(job) : ask(Job.new(kind: :player, verb: :post, path: "/player", body: nil, then: job))
      end

      def send_pending
        return unless @pending && belongs?

        ask(Job.new(kind: :round, verb: :post, path: "/group/rounds", body: { score: @pending, kind: SIZED_TO_SCREEN }))
      end

      # The theft is told: the server is asked to forget it, and until it
      # has, this device does not tell it again.
      def tell_server(id)
        @told << id
        save
        delete_news(id)
      end

      def delete_news(id) = ask(Job.new(kind: :told, verb: :delete, path: "/group/news/#{id}"))

      def settle(job, reply)
        @running -= 1
        return @error = :offline if reply.offline?
        return forget_identity if reply.status == 401
        return refused(job, reply.status) unless reply.ok?

        @error = nil
        apply(job, reply)
        ask(job.then) if job.then
      end

      def refused(job, status)
        case job.kind
        when :told then nil
        when :left then look_at(nil) if status == 404
        when :group then status == 404 ? look_at(nil) : @error = REFUSALS[:group].fetch(status, :failed)
        else
          case REFUSALS.dig(job.kind, status)
          when :forget then left_meanwhile
          when :drop then give_up_pending
          when nil then @error = :failed
          else @error = REFUSALS.dig(job.kind, status)
          end
        end
      end

      def apply(job, reply)
        case job.kind
        when :player then adopt(reply.body)
        when :group, :joined then look_at(reply.body)
        when :left then look_at(nil)
        when :deleted then forget_identity
        when :round then finish_round(reply.body)
        end
      end

      def adopt(body)
        @token = body["token"]
        save
      end

      def look_at(group)
        @group = group
        remember_membership(!group.nil?)
        return unless group

        wearing = group["members"].find { it["you"] }
        remember_mark(wearing["look"]) if wearing
        tell_of(group["news"])
        drop_stale_pending
        send_pending
      end

      # Queues a Message for each theft not yet told, and asks the server
      # again to forget those already told that it still keeps.
      def tell_of(news)
        news.each do |item|
          if @told.include?(item["id"])
            delete_news(item["id"])
          elsif @messages.none? { it.id == item["id"] }
            @messages << Message.stolen(item["thief_look"], item["score"], item["id"])
          end
        end
        kept = @told & news.map { it["id"] }
        return if kept == @told

        @told = kept
        save
      end

      def remember_mark(mark)
        return if @mark == mark

        @mark = mark
        save
      end

      def remember_membership(member)
        return if @was_member == member

        @was_member = member
        save
      end

      # The server says this player is in no group, so a waiting round
      # has nowhere to go.
      def left_meanwhile
        @was_member = false
        give_up_pending
      end

      def give_up_pending
        @pending = nil
        save
      end

      def finish_round(body)
        give_up_pending
        @messages << Message.taken(body["group"]["score_to_beat"]) if body["took_trophy"]
        look_at(body["group"])
      end

      def drop_stale_pending
        return unless @pending && today - @pending_day.to_i > PENDING_DAYS

        give_up_pending
      end

      def forget_identity
        @token = nil
        @mark = nil
        @group = nil
        @was_member = false
        @pending = nil
        @messages.clear
        @told = []
        save
      end

      def today = @clock.call.to_i / SECONDS_A_DAY

      # Saved one per line: token, mark, unsent score and its day, and
      # the thefts already told, and whether they were last in a group.
      def load_saved
        token, mark, pending, told, member = @store.read.to_s.split("\n", -1)
        @token = token unless token.to_s.empty?
        @mark = Integer(mark, exception: false)
        @mark = nil unless Mark.valid?(@mark)
        @pending, @pending_day = pending.to_s.split.map(&:to_i)
        @told = told.to_s.split.map(&:to_i)
        @was_member = member == "1"
      end

      def save
        @store.write([@token.to_s, @mark.to_s, (@pending ? "#{@pending} #{@pending_day}" : ""), @told.join(" "), (@was_member ? "1" : "")].join("\n"))
      end
    end
  end
end
