# frozen_string_literal: true

module DotPopper
  module Presentation
    # Which themes the game can use, and which it does. A theme other
    # than the ordinary one exists to the player only once the server has
    # said it is unlocked (#receive), while online; from then on it is
    # kept for good, on this device, offline too. Before that no screen may
    # show a trace of it, though its art ships with the game.
    #
    # Using one is Pro's, so a free player always uses the ordinary
    # theme. A new theme is told once, at a calm moment (#arrival); telling
    # it never depends on buying anything.
    #
    # The store keeps three lines: "unlocked: ghost eclipse", "told:
    # ghost", and "chosen: ghost".
    class ThemeKeeper
      # How long setdef must have been gone before a theme opens by its
      # date alone (Theme#opens_on).
      GONE_DAYS = 180
      UNLOCKED = "unlocked"
      TOLD = "told"
      CHOSEN = "chosen"

      # A theme_keeper that keeps nothing and has bought nothing, for a Show
      # made without one.
      def self.plain(themes) = new(ScoreRecord::Memory.new, themes:, entitlement: Entitlement.free)

      attr_reader :in_use

      def initialize(store, themes:, entitlement:)
        @store = store
        @themes = themes
        @entitlement = entitlement
        @unlocked, @told, @chosen = read
        refresh
      end

      def ordinary = @themes.find(&:ordinary?)

      def palette = in_use.palette

      # The server's answer: every theme key unlocked so far. Unknown keys
      # are ignored, for a game older than the server. A key once saved
      # stays, even if a later answer leaves it out.
      def receive(keys)
        fresh = keys.map(&:to_sym).select { |key| known?(key) } - @unlocked
        return false if fresh.empty?

        @unlocked += fresh
        save
        true
      end

      # Opens every theme whose date has passed by +today+, once setdef has
      # been gone +gone_days+ of at least GONE_DAYS, as the server would
      # have released it. Says whether any was new.
      def open_by_date(today, gone_days)
        return false if gone_days < GONE_DAYS

        receive(@themes.select { it.opens_on && it.opens_on <= today }.map(&:key))
      end

      def choices = @themes.select { it.ordinary? || @unlocked.include?(it.key) }

      # What the Themes screen shows: every theme there is for this player.
      def shown = choices

      # Whether +theme+ may be chosen by this player.
      def earned?(theme) = choices.include?(theme)

      # Whether +theme+ is open to use; a Free player sees it open too,
      # and only using it asks for Pro.
      def open?(theme) = choices.include?(theme)

      # Whether themes are shown but not to use, as for a free player.
      def locked? = !@entitlement.pro?

      # Whether there is anything to choose among: not before the server
      # has unlocked a theme. Then the screen has something to offer.
      def offered? = choices.size > 1

      # The newest unlocked theme not yet told, or nil.
      def arrival
        key = (@unlocked - @told).first
        key && @themes.find { it.key == key }
      end

      # The player has seen +theme+ announced, however they answered.
      def told(theme)
        @told |= [theme.key]
        save
      end

      def use(theme)
        return unless !locked? && choices.include?(theme)

        @chosen = theme.key
        save
        refresh
      end

      def refresh
        @in_use = !@entitlement.pro? ? ordinary : (choices.find { it.key == @chosen } || ordinary)
      end

      private

      def known?(key) = @themes.any? { it.key == key && !it.ordinary? }

      def read
        lines = @store.read.to_s.lines.filter_map { it.split(":", 2).map(&:strip) if it.include?(":") }.to_h
        known = @themes.map(&:key)
        [lines.fetch(UNLOCKED, "").split.map(&:to_sym) & known, lines.fetch(TOLD, "").split.map(&:to_sym) & known, lines[CHOSEN]&.to_sym]
      end

      def save
        @store.write("#{UNLOCKED}: #{@unlocked.join(" ")}\n#{TOLD}: #{@told.join(" ")}\n#{CHOSEN}: #{@chosen}\n")
      end
    end
  end
end
