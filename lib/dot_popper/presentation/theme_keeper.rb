# frozen_string_literal: true

module DotPopper
  module Presentation
    # The player's themes as the presentation draws them: what
    # DotPopper::Themes answers by key, as each theme's art (Theme). The
    # rules (which themes are released, told and chosen, and opening by
    # date once setdef is gone) are DotPopper::Themes', which this keeps
    # (#rules) and passes everything to.
    class ThemeKeeper
      GONE_DAYS = DotPopper::Themes::GONE_DAYS

      # A theme_keeper that keeps nothing, for a Show made without one.
      def self.plain(themes) = new(ScoreRecord::Memory.new, themes:)

      def initialize(store, themes:)
        @themes = themes
        @rules = DotPopper::Themes.new(store, themes: themes.map { DotPopper::Theme.new(key: it.key, opens_on: it.opens_on) })
      end

      # The rules this draws (DotPopper::Themes).
      attr_reader :rules

      def ordinary = look(@rules.ordinary)
      def chosen = look(@rules.chosen)
      def receive(keys) = @rules.release(keys)
      def call(event) = @rules.call(event)
      def open_by_date(today, gone_days) = @rules.open_by_date(today, gone_days)
      def choices = @rules.choices.map { look(it) }
      def shown = choices
      def earned?(theme) = @rules.open?(theme.key)
      def open?(theme) = @rules.open?(theme.key)
      def offered? = @rules.offered?
      def arrival = @rules.new_theme&.then { look(it) }
      def told(theme) = @rules.told(theme.key)
      def use(theme) = @rules.use(theme.key)

      private

      def look(key) = @themes.find { it.key == key }
    end
  end
end
