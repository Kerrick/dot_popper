# frozen_string_literal: true

module DotPopper
  module Groups
    # One request to the server, of one kind: what it sends (+sent+, a
    # Network::Job, whose verb, path and body a Link reads), and what each
    # answer means. +loud+ is that the player is waiting to hear how it
    # went, and +next_job+ one to make after it succeeds. Each kind is a
    # class in Jobs, made only from its declaration in REQUESTS, by
    # Network::Job.of, so nothing goes out that isn't declared.
    #
    # Session answers the parts every kind shares (no network, a 401, a
    # 429's wait, a loud job's error); a kind says what its own answers do,
    # through Session's answer methods.
    class Job
      # What a 409's "error" means, for any kind.
      CONFLICTS = { "group_full" => :group_full, "already_member" => :already_member, "group_limit" => :group_limit }.freeze
      # The answers to something owed that mean the server will never take it.
      NEVER_TAKEN = [400, 404, 422].freeze

      attr_reader :sent, :next_job

      def initialize(kind, body: nil, id: nil, next_job: nil, loud: false)
        @sent = Network::Job.of(REQUESTS.fetch(kind), body:, id:)
        @next_job = next_job
        @loud = loud
      end

      def loud? = @loud
      def kind = sent.kind
      def verb = sent.verb
      def path = sent.path
      def body = sent.body

      # What a refusal's status means, for the player, by this kind.
      def refusals = {}

      # Why +reply+ refused this job, for the player.
      def reason(reply)
        return refusals.fetch(reply.status, :failed) unless reply.status == 409

        CONFLICTS.fetch(reply.body.is_a?(Hash) ? reply.body["error"] : nil, :failed)
      end

      # The server answered, however it went.
      def settled(session) = nil

      # The server took it.
      def taken(session, reply) = nil

      # The server refused it: answers true if this kind has dealt with it,
      # so it is no error.
      def refused(session, reply) = false
    end

    # A job about one group, the +group_id+ in its path. A group the
    # server no longer has for the player is gone.
    class GroupJob < Job
      attr_reader :group_id

      def initialize(kind, group_id, loud: false)
        @group_id = group_id
        super(kind, id: group_id, loud:)
      end

      def refused(session, reply)
        return false unless reply.status == 404

        session.gone(group_id)
        true
      end
    end

    # Each kind of request friend groups make, one class each, named for
    # what it does; its declaration is the entry of REQUESTS for the kind
    # it gives Job.
    module Jobs
      TOO_MANY_TRIES = { 429 => :too_many_tries }.freeze

      # :player, making this device known to the server, before
      # +next_job+. A player is only a token: they give the server no name
      # or anything else.
      class NewPlayer < Job
        def initialize(next_job:) = super(:player, next_job:, loud: true)
        def refusals = TOO_MANY_TRIES
        def taken(session, reply) = session.adopt(reply.body)
      end

      # :groups, the player's groups.
      class ListGroups < Job
        def initialize(loud:) = super(:groups, loud:)
        def taken(session, reply) = session.read_groups(reply.body)
      end

      # :create, a new group with the player in it.
      class CreateGroup < Job
        def initialize = super(:create, loud: true)
        def refusals = TOO_MANY_TRIES
        def taken(session, reply) = session.arrived(reply.body, loud: loud?)
      end

      # :join, a group by the code the player tapped in.
      class JoinGroup < Job
        REFUSALS = { 400 => :no_such_group, 404 => :no_such_group, 422 => :no_such_group, 429 => :too_many_tries }.freeze

        def initialize(code) = super(:join, body: { join_code: code }, loud: true)
        def refusals = REFUSALS
        def taken(session, reply) = session.arrived(reply.body, loud: loud?)
      end

      # :group, one group, as the player opens it.
      class ReadGroup < GroupJob
        def initialize(group_id) = super(:group, group_id)
        def taken(session, reply) = session.read_group(reply.body)
      end

      # :history, a group's title changes and members' achievements.
      class ReadHistory < GroupJob
        def initialize(group_id) = super(:history, group_id)
        def settled(session) = session.history_settled(group_id)
        def taken(session, reply) = session.read_history(group_id, reply.body)
      end

      # :left, leaving a group. Not being in it is as good as leaving it.
      class LeaveGroup < GroupJob
        def initialize(group_id) = super(:left, group_id, loud: true)
        def taken(session, _reply) = session.gone(group_id)
      end

      # :achievement, a +key+ owed to the player's groups. One the server
      # will never take is owed no longer.
      class SendAchievement < Job
        attr_reader :key

        def initialize(key)
          @key = key
          super(:achievement, body: { key: })
        end

        def settled(session) = session.achievement_settled(key)
        def taken(session, reply) = session.achievement_taken(key, reply.body)

        def refused(session, reply)
          return false unless NEVER_TAKEN.include?(reply.status)

          session.drop_achievement(key)
          true
        end
      end

      # :game, the +score+ owed for a game that counts. One the server will
      # never take is owed no longer.
      class SendGame < Job
        attr_reader :score

        def initialize(score)
          @score = score
          super(:game, body: { score: })
        end

        def settled(session) = session.score_settled
        def taken(session, reply) = session.game_taken(score, reply.body)

        def refused(session, reply)
          return false unless NEVER_TAKEN.include?(reply.status)

          session.give_up_score
          true
        end
      end

      # :deleted, everything the server keeps of the player. A player the
      # server does not know is as good as deleted.
      class DeletePlayer < Job
        def initialize = super(:deleted, loud: true)
        def taken(session, _reply) = session.forget_identity

        def refused(session, reply)
          return false unless reply.status == 404

          session.forget_identity
          true
        end
      end
    end
  end
end
