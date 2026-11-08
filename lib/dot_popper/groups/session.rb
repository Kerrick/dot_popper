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
    # What went wrong is read from the status (REFUSALS) and, for a 409 or
    # a 422, from the body. The server calls a member's place in a group a
    # seat, 1 to 8; the game draws it as a Mark, 0 to 7 (Mark.of_seat), and
    # a member is known by nothing else. The group's own +seat+ is this
    # player's. A 429 says how long to wait (Retry-After), and until then
    # nothing is sent that it would refuse.
    class Session
      # A request to make, and +then+ one to make after it succeeds.
      class Job < Data.define(:kind, :verb, :path, :body, :then)
        def initialize(kind:, verb:, path:, body: nil, then: nil) = super
      end

      # One member of the group, by the Mark they wear, and whether it is
      # this player.
      Member = Data.define(:mark, :you)

      # The highest score the server takes.
      HIGHEST_SCORE = 100_000
      SECONDS_A_DAY = 86_400
      # How long a round played offline may wait to be reported, in days.
      PENDING_DAYS = 2
      # What a status means, by the kind of job it answers. :forget means
      # the player is in no group; :drop means the server will never take
      # the round waiting.
      REFUSALS = {
        player: { 429 => :too_many_tries },
        group: { 422 => :bad_mark, 429 => :too_many_tries },
        joined: { 400 => :no_such_group, 404 => :no_such_group, 422 => :no_such_group, 429 => :too_many_tries },
        round: { 400 => :drop, 404 => :forget, 422 => :drop }
      }.freeze
      # What a 409's "error" means.
      CONFLICTS = { "group_full" => :group_full, "already_in_group" => :already_in_group }.freeze
      # The longest a Retry-After is believed, in seconds, and how long to
      # wait when a 429 names no time.
      LONGEST_WAIT = 3_600
      USUAL_WAIT = 60
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
      # The members, each a Member, in seat order.
      def members = @group ? @group["member_seats"].sort.map { Member.new(mark: Mark.of_seat(it), you: it == @group["seat"]) } : []
      def join_code = @group&.fetch("join_code")
      def score_to_beat = @group&.fetch("score_to_beat")
      # The Mark of the member holding the trophy, or nil if it is vacant.
      def holder_mark = @group&.fetch("holder_seat")&.then { Mark.of_seat(it) }

      # Looks up the group, at launch and when its screen opens. Without
      # a token there is nothing to look up and nothing is sent.
      def refresh = known? ? ask(Job.new(kind: :group, verb: :get, path: "/group")) : nil

      # Makes a group, or joins the one with +code+ (digits), wearing +mark+
      # (Groups::Mark) if no one there does, else the lowest that is free.
      # Only the game decides whether a player may create or join
      # (Entitlement); the server has no say in it.
      def create(mark) = as_player(Job.new(kind: :group, verb: :post, path: "/group", body: { seat: Mark.seat(mark) }))
      def join(mark, code) = as_player(Job.new(kind: :joined, verb: :post, path: "/membership", body: { join_code: code, seat: Mark.seat(mark) }))
      def leave = ask(Job.new(kind: :left, verb: :delete, path: "/membership"))
      def delete_everything = ask(Job.new(kind: :deleted, verb: :delete, path: "/player"))

      # A round just ended. The server cannot tell how a score was won, so
      # only a round that counts is sent: one played by a member, with dots
      # sized to the screen, and not the tutorial's (+sized_to_screen+ is
      # false for the others). If it cannot be sent now, the best such
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
        return @error = :too_many_tries if waiting_out?

        known? ? ask(job) : ask(Job.new(kind: :player, verb: :post, path: "/player", body: nil, then: job))
      end

      def send_pending
        return unless @pending && belongs?

        ask(Job.new(kind: :round, verb: :post, path: "/group/rounds", body: { score: @pending }))
      end

      # The theft is told: the server is asked to forget it, and until it
      # has, this device does not tell it again.
      def tell_server(id)
        @told << id
        save
        delete_news(id)
      end

      def delete_news(id) = ask(Job.new(kind: :told, verb: :delete, path: "/group/thefts/#{id}"))

      def waiting_out? = @wait_until && @clock.call.to_i < @wait_until

      def wait_out(seconds)
        @wait_until = @clock.call.to_i + (seconds || USUAL_WAIT).clamp(0, LONGEST_WAIT)
      end

      def settle(job, reply)
        @running -= 1
        return @error = :offline if reply.offline?
        return forget_identity if reply.status == 401
        return refused(job, reply) unless reply.ok?

        @error = nil
        apply(job, reply)
        ask(job.then) if job.then
      end

      def refused(job, reply)
        status = reply.status
        wait_out(reply.retry_after) if status == 429
        case job.kind
        when :told then nil
        when :left, :thefts then look_at(nil) if status == 404
        when :group
          status == 404 ? look_at(nil) : conflict_or(job, reply)
        else conflict_or(job, reply)
        end
      end

      # A 409 says which in its body; a 422 on a seat is a bad mark; and
      # the rest are read from the status. A player who is in a group
      # already is shown it.
      def conflict_or(job, reply)
        status = reply.status
        body = reply.body.is_a?(Hash) ? reply.body : {}
        reason = if status == 409 then CONFLICTS.fetch(body["error"], :failed)
                 elsif status == 422 && job.kind == :joined && body.dig("errors", "seat") then :bad_mark
                 else REFUSALS.dig(job.kind, status)
                 end
        case reason
        when :forget then left_meanwhile
        when :drop then give_up_pending
        when nil then @error = :failed
        else
          @error = reason
          refresh if reason == :already_in_group
        end
      end

      def apply(job, reply)
        case job.kind
        when :player then adopt(reply.body)
        when :group, :joined then look_at(reply.body)
        when :thefts then tell_of(reply.body)
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
        return @error = :failed unless group.nil? || group?(group)

        @group = group
        remember_membership(!group.nil?)
        return unless group

        remember_mark(Mark.of_seat(group["seat"]))
        ask(Job.new(kind: :thefts, verb: :get, path: "/group/thefts"))
        drop_stale_pending
        send_pending
      end

      # Whether +group+ is a group as the server describes one.
      def group?(group)
        group.is_a?(Hash) && Mark.seat?(group["seat"]) && group["member_seats"].is_a?(Array) &&
          group["member_seats"].all? { Mark.seat?(it) } && group["join_code"].is_a?(String) &&
          group["score_to_beat"].is_a?(Integer) && (group["holder_seat"].nil? || Mark.seat?(group["holder_seat"]))
      end

      # Queues a Message for each theft not yet told, and asks the server
      # again to forget those already told that it still keeps. The
      # server keeps a theft until told it was acknowledged.
      def tell_of(news)
        return unless news.is_a?(Array)

        news = news.select { it.is_a?(Hash) && it["id"].is_a?(Integer) && Mark.seat?(it["thief_seat"]) }
        news.each do |item|
          if @told.include?(item["id"])
            delete_news(item["id"])
          elsif @messages.none? { it.id == item["id"] }
            @messages << Message.stolen(Mark.of_seat(item["thief_seat"]), item["score"], item["id"])
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
        group = body["group"]
        return unless group?(group)

        @messages << Message.taken(group["score_to_beat"]) if body["took_trophy"]
        look_at(group)
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
        @wait_until = nil
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
