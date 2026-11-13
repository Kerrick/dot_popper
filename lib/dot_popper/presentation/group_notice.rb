# frozen_string_literal: true

module DotPopper
  module Presentation
    # Whether a Join or Create first shows the friend groups' notice: that
    # Dot Popper keeps the player's scores online, with a link to the
    # privacy policy. It shows until the player goes on past it once, and
    # never again; the store, which answers +read+ and +write(text)+ as
    # ScoreRecord's does, keeps that, apart from Stats, so clearing
    # them leaves it.
    class GroupNotice
      READ = "read"

      # A notice already read, for a Show that asks nothing.
      def self.read = new(ScoreRecord::Memory.new(READ))

      def initialize(store) = @store = store

      # Whether the next Join or Create asks first.
      def due? = @store.read.to_s.strip != READ

      # The player went on past it: it is never shown again.
      def read! = (@store.write(READ) if due?)
    end
  end
end
