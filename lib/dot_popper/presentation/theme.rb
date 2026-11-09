# frozen_string_literal: true

module DotPopper
  module Presentation
    # The days of a year a holiday theme appears, from [month, day] to
    # [month, day], both included. One that ends before it begins (Dec 15
    # to Jan 2) runs over New Year.
    class Season < Data.define(:from, :to)
      def cover?(date)
        today = [date.month, date.day]
        after_start = (from <=> today) <= 0
        before_end = (today <=> to) <= 0
        (from <=> to) <= 0 ? after_start && before_end : after_start || before_end
      end
    end

    # A theme for the whole game, as plain data: its +key+ (what is saved
    # of it), its +palette+ (Palette, usually the ordinary one with some
    # colors changed), and the +season+ it appears in. The ordinary theme
    # has no season, and is always there. Every dot, backdrop, button and
    # word takes its colors from the palette, so a theme needs no code.
    class Theme < Data.define(:key, :palette, :season)
      def initialize(key:, palette:, season: nil) = super

      def ordinary? = season.nil?

      def in_season?(date) = !season.nil? && season.cover?(date)
    end
  end
end
