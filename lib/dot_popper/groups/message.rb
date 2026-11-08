# frozen_string_literal: true

module DotPopper
  module Groups
    # One thing to tell the player, once: :stolen when the member wearing
    # mark +who+ (Groups::Mark) took their
    # trophy with +score+, or :taken when this player took it. +id+ is
    # the theft the server should stop telling them of, or nil.
    class Message < Data.define(:kind, :who, :score, :id)
      def self.stolen(who, score, id) = new(kind: :stolen, who:, score:, id:)
      def self.taken(score) = new(kind: :taken, who: nil, score:, id: nil)
    end
  end
end
