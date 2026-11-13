# frozen_string_literal: true

require "test_helper"
require "dot_popper/presentation"
require "dot_popper/composition/use_cases"

module PresentationTest
  include DotPopperTest
  include DotPopper::Presentation

  Style = DotPopper::Presentation::Style

  # Sounds that only remember what they were asked to play.
  class FakeSounds
    attr_reader :played, :pans

    def initialize = (@played = []) && (@pans = []) && (@muted = false)

    def play(name, pitch: 1.0, pan: 0.0)
      @played << [name, pitch]
      @pans << pan
    end

    def muted? = @muted
    def toggle_mute = @muted = !@muted
    def names = played.map(&:first)
  end

  # A desktop's window that only remembers what it was asked: whether it
  # is fullscreen, and how many times it was asked to quit.
  class FakeWindow
    attr_reader :quits

    attr_accessor :display

    def initialize = (@display = :window) && (@quits = 0)

    def offered? = true
    def fullscreen? = display != :window
    def toggle_fullscreen = self.display = fullscreen? ? :window : :borderless
    def quit = @quits += 1
  end

  # Haptics that only remember how long each buzz was.
  class FakeHaptics
    attr_reader :buzzes

    def initialize = @buzzes = []
    def buzz(seconds) = @buzzes << seconds
  end

  # A Show on +cabinet+, built as the composition root builds the game's:
  # its use cases made by Composition.use_cases from the areas' objects
  # (memory stores and harmless stand-ins unless given), the Show
  # subscribed to the rules' events and the offer to Pro arriving, each
  # after them. Every Show a test makes on one
  # cabinet starts its games through the cabinet's one Starts. The rest
  # of +options+ go to the Show as they are.
  def self.show(cabinet:, entitlement: DotPopper::Entitlement.free, storefront: NoStorefront.new, games: DotPopper::FreeGames.unlimited,
                stats_book: DotPopper::StatsBook.new(DotPopper::ScoreRecord::Memory.new),
                achievements: DotPopper::Achievements.new(DotPopper::ScoreRecord::Memory.new), groups: DotPopper::Groups::Session.off,
                themes: DotPopper::Themes.new(DotPopper::ScoreRecord::Memory.new), use_theme: DotPopper::UseCases::UseTheme.new(themes:, entitlement:),
                **options)
    use_cases = DotPopper::Composition.use_cases(cabinet:, free_games: games, entitlement:, store: storefront, achievements:, stats_book:,
                                                 friend_groups: groups, use_theme:, starts: DotPopperTest.starts_of(cabinet))
    show = Show.new(cabinet:, stats_book:, achievements:, groups:, themes:, **use_cases, **options)
    cabinet.subscribe(show)
    entitlement.subscribe(show.offer)
    show
  end

  def new_show(**) = PresentationTest.show(**)

  # Presses Play on Home, or Home on Game Over.
  def press_main(show = @show)
    reach = show.play_reach || show.home_reach
    show.tap(reach.center_x, reach.center_y)
  end

  def layout(width = 800, height = 600)
    Layout.new(width:, height:, safe: Rect.new(x: 0, y: 0, width:, height:), style: Style::LAYOUT)
  end
end
