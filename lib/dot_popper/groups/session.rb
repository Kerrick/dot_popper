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
    # It is made of parts, each with its own rules: what the game owes the
    # server (Outbox), what it last heard from it (ReadModel), each kind of
    # request and what its answers mean (Jobs), and group.txt (GroupFile).
    # Session holds the player's token, the queue of jobs and a 429's wait,
    # and ties the parts together.
    #
    # Every failure is quiet: a job the player asked for leaves a reason in
    # #error for a screen to show, and any other is forgotten until the next
    # chance to ask. A title change is learned from the group's history, and
    # only that, so a reply lost on the way still gets its announcement: the
    # history is fetched whenever a group's title looks different from when
    # it was last read.
    class Session
      # The highest score the server takes (the Outbox's).
      HIGHEST_SCORE = Outbox::HIGHEST_SCORE
      # The longest a Retry-After is believed, in seconds, and how long to
      # wait when a 429 names no time.
      LONGEST_RETRY_WAIT = 3_600
      USUAL_WAIT = 60

      # A Network::Worker that is never asked to do anything.
      class NoWorker
        def start(_job, _token) = nil
        def finished = []
      end

      NO_WORKER = NoWorker.new

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
        ask(Jobs::ListGroups.new(loud: groups.empty?))
      end

      def create = as_player(Jobs::CreateGroup.new)
      def join(code) = as_player(Jobs::JoinGroup.new(code))

      def look_at(id)
        ask(Jobs::ReadGroup.new(id))
        fetch_changes(id)
      end

      def leave(id) = ask(Jobs::LeaveGroup.new(id))

      # Keys of achievements a Pro player has earned, sent once each to
      # the groups they are in (retries are harmless, and a key that
      # could not be sent waits for the next contact).
      def report_achievements(keys)
        return unless @outbox.owe_achievements(keys)

        save
        send_achievements
      end

      def delete_everything = ask(Jobs::DeletePlayer.new)

      # A game just ended. The server cannot tell how a score was won, so
      # only a game that counts is sent: one played by a member, not the
      # tutorial's (+counts+ is false for that one), with a score above 0,
      # whatever its dot size (Outbox#owe_game). If it cannot be sent now,
      # the highest-scoring such game waits and is sent with the next
      # contact.
      def game_finished(score:, counts:)
        @game_result = nil
        @result_due = false
        # Without a token nothing owed is sent, so nothing is owed.
        score = @outbox.owe_game(score:, counts:, member: member? && known?)
        return unless score

        @last_score = score
        @result_due = @outbox.score == score
        save
        send_owed
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

      # What the server's answers do (_Answers). Each kind of job (Jobs)
      # calls these from its #settled, #taken and #refused; nothing else
      # should.

      # The token the server gave this player, or a failure if it gave none.
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
        send_owed
      end

      def read_group(body) = Group.parse(body)&.then { upsert(it) }

      # A group just created or joined; a reply that is no group is a
      # failure the player hears of when they asked.
      def arrived(body, loud:)
        group = Group.parse(body)
        return @error = :failed if group.nil? && loud
        return unless group

        upsert(group)
        @read.arrived(group.id)
      end

      def history_settled(id) = @fetching.delete(id)

      def read_history(id, body)
        save if @read.read_history(id, body)
      end

      def gone(id)
        @read.gone(id)
        remember_membership
        save
      end

      def achievement_settled(key) = @outbox.achievement_settled(key)

      def achievement_taken(key, body)
        @outbox.drop_achievement(key)
        listed_groups(body).filter_map { Group.parse(it) }.each { upsert(it) }
        save
      end

      def drop_achievement(key)
        @outbox.drop_achievement(key)
        save
      end

      def score_settled = @outbox.score_settled

      # The server took +score+, and says what it did in each group.
      def game_taken(score, body)
        @outbox.score_taken(score)
        outcomes = listed_groups(body).filter_map { outcome(it) }
        save
        @game_result = GameResult.of(outcomes, score) if score == @last_score && @result_due
        @result_due = false
        send_owed
      end

      def give_up_score
        @outbox.drop_score
        @result_due = false
        save
      end

      # Forgets the player and everything known of them, as when the server
      # no longer knows their token.
      def forget_identity
        @token = nil
        @outbox.forget
        @read.forget
        @wait_until = nil
        @result_due = false
        @game_result = nil
        save
      end

      private

      def ask(job)
        @running += 1
        @waiting << job
        nil
      end

      # Makes +job+ on behalf of this player, making them known to the
      # server first if they are not.
      def as_player(job)
        @error = nil
        return @error = :too_many_tries if waiting_out?

        known? ? ask(job) : ask(Jobs::NewPlayer.new(next_job: job))
      end

      def send_achievements
        return unless known? && !waiting_out?

        @outbox.take_achievements(member: member?).each { ask(Jobs::SendAchievement.new(it)) }
      end

      # Sends what is owed: achievements, then the score. Nothing goes
      # out without a token.
      def send_owed
        send_achievements
        return unless known? && !waiting_out?

        score = @outbox.take_score(member: member?)
        ask(Jobs::SendGame.new(score)) if score
      end

      def fetch_changes(id)
        return if @fetching.include?(id)

        @fetching << id
        ask(Jobs::ReadHistory.new(id))
      end

      def waiting_out? = (wait_until = @wait_until) ? @clock.call.to_i < wait_until : false

      def wait_out(seconds)
        @wait_until = @clock.call.to_i + (seconds || USUAL_WAIT).clamp(0, LONGEST_RETRY_WAIT)
      end

      # What every kind of job's answer means alike: no network is an error
      # only for a loud job, a 401 forgets the player, and a 429 starts a
      # wait. The rest is the job's own.
      def settle(job, reply)
        @running -= 1
        job.settled(self)
        return @error = :offline if reply.offline? && job.loud?
        return if reply.offline?
        return forget_identity if reply.status == 401

        reply.ok? ? taken(job, reply) : refused(job, reply)
      end

      def taken(job, reply)
        @error = nil if job.loud?
        job.taken(self, reply)
        ask(job.next_job) if job.next_job
      end

      def refused(job, reply)
        wait_out(reply.retry_after) if reply.status == 429
        return if job.refused(self, reply)

        @error = job.reason(reply) if job.loud?
      end

      def upsert(group)
        @read.upsert(group)
        remember_membership
        follow(group)
        send_owed
      end

      # Reads a group's history if its title has moved since it last was.
      def follow(group)
        fetch_changes(group.id) if @read.title_moved?(group)
      end

      # A group's part in a game's reply, as [group, won_title, raised],
      # with the group brought up to date. A champion beating their own
      # score is no title change, so the server reports it as no win, and
      # it shows only in the top score having risen.
      def outcome(item)
        return unless item.is_a?(Hash) && (group = Group.parse(item["group"]))

        before = group(group.id)
        raised = before ? before.champion? && group.top_score > before.top_score : false
        upsert(group)
        [group, item["won_title"] == true, raised]
      end

      # The "groups" an answer lists, or none.
      def listed_groups(body)
        body.is_a?(Hash) && body["groups"].is_a?(Array) ? body["groups"] : [] #: Array[untyped]
      end

      # Leaving the last group drops the score waiting, as it has no group
      # to go to.
      def remember_membership
        return unless @read.remember_membership || (!member? && @outbox.score)

        @outbox.drop_score unless member?
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
