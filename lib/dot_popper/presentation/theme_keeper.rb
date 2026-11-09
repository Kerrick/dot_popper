# frozen_string_literal: true

module DotPopper
  module Presentation
    # Which look the game wears. A holiday theme (Theme) appears during its
    # season, and one game played then earns it for good; an earned theme
    # is kept whether or not the player has bought Pro, and
    # is worn the day they do. Wearing a theme is Pro's, so
    # the wardrobe asks the +entitlement+ and nothing else: for a free
    # player the ordinary look is always worn. A free player is still shown
    # every look, and which of them they have earned (#shown): the same
    # rule as the achievements, to show what is there, plainly, in one
    # calm place.
    #
    # What is worn is settled when the wardrobe is made, when the title
    # shows (#refresh), and when the player chooses, never in the middle of
    # a game, so a game is never dressed twice. Until the player chooses,
    # the theme in season is worn; once they do, their choice is, all year.
    #
    # The store answers +read+ and +write(text)+ as ScoreRecord's does, and
    # keeps two lines: "earned: halloween winter" and "chosen: halloween".
    # +today+ answers the date.
    class ThemeKeeper
      EARNED = "earned"
      CHOSEN = "chosen"

      # A wardrobe that keeps nothing and has bought nothing, for a Show
      # made without one.
      def self.plain(themes)
        new(ScoreRecord::Memory.new, themes:, entitlement: Entitlement.free, today: -> { Date.today })
      end

      attr_reader :worn

      def initialize(store, themes:, entitlement:, today:)
        @store = store
        @themes = themes
        @entitlement = entitlement
        @today = today
        @earned, @chosen = read
        refresh
      end

      def ordinary = @themes.find(&:ordinary?)

      def palette = worn.palette

      # One game has been played: every theme in season is earned.
      def game_played
        fresh = in_season.map(&:key) - @earned
        return if fresh.empty?

        @earned += fresh
        save
      end

      # Whether +theme+ is the player's for good.
      def earned?(theme) = theme.ordinary? || @earned.include?(theme.key)

      # What the player can wear: the ordinary look, what they have
      # earned, and what is in season now, in the catalog's order.
      def choices
        @themes.select { it.ordinary? || earned?(it) || it.in_season?(@today.call) }
      end

      # What the Looks screen shows: what a pro player can wear, and for a
      # free player every look, the ones they have earned marked as such
      # (#earned?), none to wear.
      def shown = locked? ? @themes : choices

      # Whether the looks are shown but not to wear, as for a free player.
      def locked? = !@entitlement.pro?

      # Whether the Stats screen offers the Looks screen: to a free
      # player always, since there are looks to see, and to a pro player
      # once there is one besides the ordinary look to choose.
      def offered? = locked? || choices.size > 1

      # Wears +theme+ from now on, if it is a choice and the player may.
      def wear(theme)
        return unless !locked? && choices.size > 1 && choices.include?(theme)

        @chosen = theme.key
        save
        refresh
      end

      # Works out again what is worn: the player's choice, else what is in
      # season, else the ordinary look; and always the ordinary look
      # before the purchase.
      def refresh
        @worn = if !@entitlement.pro? then ordinary
                else choices.find { it.key == @chosen } || in_season.first || ordinary
                end
      end

      private

      def in_season = @themes.select { it.in_season?(@today.call) }

      def read
        lines = @store.read.to_s.lines.filter_map { it.split(":", 2).map(&:strip) if it.include?(":") }.to_h
        known = @themes.map(&:key)
        earned = lines.fetch(EARNED, "").split.map(&:to_sym) & known
        [earned, lines[CHOSEN]&.to_sym]
      end

      def save = @store.write("#{EARNED}: #{@earned.join(" ")}\n#{CHOSEN}: #{@chosen}\n")
    end
  end
end
