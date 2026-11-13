# frozen_string_literal: true

module DotPopper
  module UseCases
    # Joining or creating a friend group: a group is Metagame's (+groups+,
    # the Groups::Session that asks the server), and taking part is Pro's
    # (+entitlement+, Entitlement), since everyone who competes for a
    # title has Pro. A Free player is offered Pro instead, as they choose
    # Join or Create, before anything is asked of them; each answer says
    # so, and the screen acts on it. Leaving a group and deleting friend
    # group data never need Pro, so they are not here.
    class JoinOrCreateFriendGroup
      def initialize(groups:, entitlement:)
        @groups = groups
        @entitlement = entitlement
      end

      # Whether Join and Create lead to Pro, as for a Free player.
      def locked? = !@entitlement.pro?

      # The player chose Join or Create: :offer for a Free player, who is
      # offered Pro instead and goes no further; :go otherwise, on to what
      # comes before a request (the friend groups' notice, the code pad).
      def choose = locked? ? :offer : :go

      # Creates a group: :sent, or :offer for a Free player.
      def create
        return :offer if locked?

        @groups.create
        :sent
      end

      # Joins the group whose code is +code+: :sent, or :offer for a Free
      # player.
      def join(code)
        return :offer if locked?

        @groups.join(code)
        :sent
      end
    end
  end
end
