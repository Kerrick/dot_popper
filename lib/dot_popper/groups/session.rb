# frozen_string_literal: true

module DotPopper
  module Groups
    # What this device knows about its friend groups, and everything it
    # asks the server for. Called only from the game's own thread, and
    # asks for nothing while a game is in play (#update's +quiet+).
    #
    # Nothing is sent until the player creates or joins a group: a Session
    # with no saved token makes no connection at all. +store+ answers
    # read and write, as a SaveFile does, and +clock+ gives the time.
    #
    # Every failure is quiet: a job the player asked for leaves a reason in
    # #error for a screen to show, and any other is forgotten until the next
    # chance to ask. A title change is learned from the group's history, and
    # only that, so a reply lost on the way still gets its announcement: the
    # history is fetched whenever a group's title looks different from when
    # it was last read, and the newest entry already shown is kept here for
    # each group, so only what is new is announced.
    class Session
      # A request to make (+sent+, a Network::Job, whose kind, verb, path
      # and body it answers), and +then+ one to make after it succeeds.
      # +group_id+ is the group it is about, and +loud+ that the player is
      # waiting to hear how it went. Made only by Job.of, from what
      # REQUESTS declares, by Network::Job.of, so nothing goes out that
      # isn't declared.
      class Job < Data.define(:sent, :then, :group_id, :loud)
        def initialize(sent:, then: nil, group_id: nil, loud: false) = super

        def self.of(kind, body: nil, group_id: nil, **rest)
          new(sent: Network::Job.of(REQUESTS.fetch(kind), body:, id: group_id), group_id:, **rest)
        end

        private_class_method :new, :[]

        def kind = sent.kind
        def verb = sent.verb
        def path = sent.path
        def body = sent.body
      end

      # The highest score the server takes (the Outbox's).
      HIGHEST_SCORE = Outbox::HIGHEST_SCORE
      # What a status means, by the kind of job it answers.
      REFUSALS = {
        player: { 429 => :too_many_tries },
        create: { 429 => :too_many_tries },
        join: { 400 => :no_such_group, 404 => :no_such_group, 422 => :no_such_group, 429 => :too_many_tries }
      }.freeze
      # What a 409's "error" means.
      CONFLICTS = { "group_full" => :group_full, "already_member" => :already_member, "group_limit" => :group_limit }.freeze
      # The answers to a game that mean the server will never take it.
      NEVER_TAKEN = [400, 404, 422].freeze
      # The longest a Retry-After is believed, in seconds, and how long to
      # wait when a 429 names no time.
      LONGEST_RETRY_WAIT = 3_600
      USUAL_WAIT = 60
      # A Network::Worker that is never asked to do anything.
      NO_WORKER = Struct.new(:none) do
        def start(*) = nil
        def finished = []
      end.new

      # A Session with no server, for a game that offers no groups.
      def self.off = new(store: ScoreRecord::Memory.new, worker: NO_WORKER, available: false)

      # The Session for a game whose server is at +url+, or Session.off.
      def self.at(url, store:) = url ? new(store:, worker: Network::Worker.new(Network::Link.new(url))) : off

      attr_reader :error, :token, :game_result

      def initialize(store:, worker:, clock: -> { Time.now }, available: true)
        @store = store
        @worker = worker
        @clock = clock
        @available = available
        @waiting = []
        @running = 0
        @fetching = []
        @error = nil
        @game_result = nil
        @result_due = false
        load_saved
      end

      def available? = @available
      def known? = !@token.nil?
      def busy? = @running.positive?
      # Whether this player belongs to any group, as far as is known: after
      # a launch with no network the groups are unknown, but their games
      # still count.
      def member? = @read.member?
      def groups = @read.groups
      def group(id) = @read.group(id)
      # A group's title changes, newest first, or nil before they are read.
      def title_changes(id) = @read.title_changes(id)
      # A group's history, title changes and members' achievements together,
      # newest first, or nil before it is read.
      def history(id) = @read.history(id)
      # Whether a counting game has ended and its result is still awaited.
      def result_due? = @result_due

      # Fetches the groups, at launch and when the groups' screen opens.
      # Without a token there is nothing to look up and nothing is sent.
      def refresh
        return unless known?

        @error = nil if groups.empty?
        ask(Job.of(:groups, loud: groups.empty?))
      end

      def create = as_player(Job.of(:create, loud: true))
      def join(code) = as_player(Job.of(:join, body: { join_code: code }, loud: true))

      def look_at(id)
        ask(Job.of(:group, group_id: id))
        fetch_changes(id)
      end

      def leave(id) = ask(Job.of(:left, group_id: id, loud: true))

      # Keys of achievements a Pro player has earned, sent once each to
      # the groups they are in (retries are harmless, and a key that
      # could not be sent waits for the next contact).
      def report_achievements(keys)
        return unless @outbox.owe_achievements(keys)

        save
        send_achievements
      end

      def delete_everything = ask(Job.of(:deleted, loud: true))

      # A game just ended. The server cannot tell how a score was won, so
      # only a game that counts is sent: one played by a member, not the
      # tutorial's (+counts+ is false for that one), with a score above 0,
      # whatever its dot size. If it cannot be sent now, the highest-scoring such game
      # waits and is sent with the next contact.
      def game_finished(score:, counts:)
        @game_result = nil
        @result_due = false
        score = @outbox.owe_game(score:, counts:, member: member?)
        return unless score

        @last_score = score
        @result_due = @outbox.score == score
        save
        send_pending
      end

      # A game began, so the last game's result no longer stands.
      def game_started
        @game_result = nil
        @result_due = false
      end

      # Moves on: hears what the server said, and unless a game is in play
      # (+quiet+ false), hands over what is waiting.
      def update(quiet:)
        @worker.finished.each { |job, reply| settle(job, reply) }
        return unless quiet

        @worker.start(@waiting.shift, @token) until @waiting.empty?
      end

      # The next title change to tell the player, once, or nil.
      def next_announcement = @read.next_announcement

      # The group just created or joined, once, for a screen to open.
      def take_arrival = @read.take_arrival

      private

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

        known? ? ask(job) : ask(Job.of(:player, then: job, loud: true))
      end

      def send_achievements
        return unless known? && !waiting_out?

        @outbox.take_achievements(member: member?).each { ask(Job.of(:achievement, body: { key: it })) }
      end

      def finish_achievement(key, body)
        @outbox.drop_achievement(key)
        (body.is_a?(Hash) && body["groups"].is_a?(Array) ? body["groups"] : []).filter_map { Group.parse(it) }.each { upsert(it) }
        save
      end

      def drop_achievement(key)
        @outbox.drop_achievement(key)
        save
      end

      def send_pending
        send_achievements
        return if waiting_out?

        score = @outbox.take_score(member: member?)
        ask(Job.of(:game, body: { score: })) if score
      end

      def fetch_changes(id)
        return if @fetching.include?(id)

        @fetching << id
        ask(Job.of(:history, group_id: id))
      end

      def waiting_out? = @wait_until && @clock.call.to_i < @wait_until

      def wait_out(seconds)
        @wait_until = @clock.call.to_i + (seconds || USUAL_WAIT).clamp(0, LONGEST_RETRY_WAIT)
      end

      def settle(job, reply)
        @running -= 1
        @outbox.score_settled if job.kind == :game
        @fetching.delete(job.group_id) if job.kind == :history
        @outbox.achievement_settled(job.body[:key]) if job.kind == :achievement
        return @error = :offline if reply.offline? && job.loud
        return if reply.offline?
        return forget_identity if reply.status == 401

        reply.ok? ? settled(job, reply) : refused(job, reply)
      end

      def settled(job, reply)
        @error = nil if job.loud
        apply(job, reply)
        ask(job.then) if job.then
      end

      def refused(job, reply)
        wait_out(reply.retry_after) if reply.status == 429
        return give_up_pending if job.kind == :game && NEVER_TAKEN.include?(reply.status)
        return gone(job.group_id) if reply.status == 404 && %i[group history left].include?(job.kind)
        return drop_achievement(job.body[:key]) if job.kind == :achievement && NEVER_TAKEN.include?(reply.status)
        return forget_identity if reply.status == 404 && job.kind == :deleted

        @error = reason(job, reply) if job.loud
      end

      def reason(job, reply)
        return REFUSALS.dig(job.kind, reply.status) || :failed unless reply.status == 409

        CONFLICTS.fetch(reply.body.is_a?(Hash) ? reply.body["error"] : nil, :failed)
      end

      def apply(job, reply)
        case job.kind
        when :player then adopt(reply.body)
        when :groups then read_groups(reply.body)
        when :create, :join then arrived(reply.body, job)
        when :group then read_group(reply.body)
        when :history then read_history(job.group_id, reply.body)
        when :achievement then finish_achievement(job.body[:key], reply.body)
        when :left then gone(job.group_id)
        when :deleted then forget_identity
        when :game then finish_game(job.body[:score], reply.body)
        end
      end

      def adopt(body)
        token = body["token"] if body.is_a?(Hash)
        return @error = :failed unless token.is_a?(String) && !token.empty?

        @token = token
        save
      end

      def read_groups(body)
        return unless body.is_a?(Array)

        @read.replace(body.filter_map { Group.parse(it) })
        remember_membership
        groups.each { follow(it) }
        send_pending
      end

      def read_group(body) = Group.parse(body)&.then { upsert(it) }

      def arrived(body, job)
        group = Group.parse(body)
        return @error = :failed if group.nil? && job.loud
        return unless group

        upsert(group)
        @read.arrived(group.id)
      end

      def upsert(group)
        @read.upsert(group)
        remember_membership
        follow(group)
        send_pending
      end

      def gone(id)
        @read.gone(id)
        remember_membership
        save
      end

      # Reads a group's history if its title has moved since it last was.
      def follow(group)
        fetch_changes(group.id) if @read.title_moved?(group)
      end

      def read_history(id, body)
        save if @read.read_history(id, body)
      end

      def finish_game(score, body)
        @outbox.score_taken(score)
        results = body.is_a?(Hash) && body["groups"].is_a?(Array) ? body["groups"] : []
        outcomes = results.filter_map { outcome(it) }
        save
        @game_result = result_of(outcomes, score) if score == @last_score && @result_due
        @result_due = false
        send_pending
      end

      # A group's part in a game's reply, as [group, won_title, raised],
      # with the group brought up to date. A champion beating their own
      # score is no title change, so the server reports it as no win, and
      # it shows only in the top score having risen.
      def outcome(item)
        return unless item.is_a?(Hash) && (group = Group.parse(item["group"]))

        before = group(group.id)
        raised = before&.champion? == true && group.top_score > before.top_score
        upsert(group)
        [group, item["won_title"] == true, raised]
      end

      def result_of(outcomes, score)
        won = outcomes.count { |_, won, _| won }
        raised = outcomes.count { |_, _, raised| raised }
        chasing = outcomes.reject { |group, won, _| won || group.champion? }
        GameResult.new(won:, raised:, short: chasing.map { |group, _, _| group.score_to_win - score }.select(&:positive?).min,
                       reigning: !outcomes.empty? && won.zero? && raised.zero? && chasing.empty?,
                       taken: outcomes.select { |_, won, _| won }.map { |group, _, _| group.id })
      end

      def give_up_pending
        @outbox.drop_score
        @result_due = false
        save
      end

      # Leaving the last group drops the score waiting, as it has no group
      # to go to.
      def remember_membership
        return unless @read.remember_membership || (!member? && @outbox.score)

        @outbox.drop_score unless member?
        save
      end

      def forget_identity
        @token = nil
        @outbox.forget
        @read.forget
        @wait_until = nil
        @result_due = false
        @game_result = nil
        save
      end

      # group.txt (GroupFile).
      def load_saved
        saved = GroupFile.parse(@store.read)
        @token = saved.token
        @outbox = Outbox.new(score: saved.unsent_score, achievements: saved.unsent_achievements)
        @read = ReadModel.new(last_known_member: saved.member, seen: saved.seen)
      end

      def save
        @store.write(GroupFile.new(token: @token, unsent_score: @outbox.score, member: @read.last_known_member, seen: @read.seen,
                                   unsent_achievements: @outbox.achievements).to_s)
      end
    end
  end
end
