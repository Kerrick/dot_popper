# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every screen of the game, each an object that answers for itself
    # (doc/design/screens.md, ADR-0018). The Show makes one of each as it is
    # made, and Show#screen is the one place that says which is on top;
    # every press, button, key and scroll asks that screen.
    module Screens
      # One of each screen for +show+, by name: a screen over Home by the
      # name Show#page gives it, the rest by their own. +clipboard+ takes
      # what the share preview copies; the offer of Pro sells through
      # +buy_pro+, as +storefront+ and +entitlement+ say; Game Over starts
      # the next game through +start_game+ and shares through +sharing+;
      # an achievement's dialog shows what +view_achievements+ may; Stats
      # shows +stats_book+ and +achievements+, cleared through +keeper+
      # with a buzz of +haptics+; Credits says +notices+; Settings keeps the
      # dot size in +sizing_store+; Change Server chooses +server_choice+;
      # Themes and the new-theme card use themes through +use_theme+, and
      # the card tells +theme_keeper+ it was told.
      def self.made_for(show, clipboard:, buy_pro:, storefront:, entitlement:, start_game:, sharing:, view_achievements:, keeper:,
                        stats_book:, achievements:, haptics:, notices:, sizing_store:, server_choice:, theme_keeper:, use_theme:)
        { home: Home.new(show), new_theme: NewTheme.new(show, theme_keeper:, use_theme:), tutorial: Tutorial.new(show), game: Game.new(show),
          game_over: GameOver.new(show, start_game:, sharing:), share_preview: SharePreview.new(show, clipboard:),
          offer: Offer.new(show, buy_pro:, storefront:, entitlement:),
          stats: Stats.new(show, keeper:, stats_book:, achievements:, haptics:), achievements: Achievements.new(show), achievement_dialog: AchievementDialog.new(show, view_achievements:),
          themes: Themes.new(show, use_theme:), settings: Settings.new(show, sizing_store:), credits: Credits.new(show, notices:), privacy: Privacy.new(show),
          server: ChangeServer.new(show, server_choice:), friend_groups: FriendGroups.new(show) }.freeze
      end

      # What every screen answers, and what a screen answers where it has
      # nothing of its own. +show+ is the Show the screen belongs to, whose
      # state it reads and changes.
      class Screen
        attr_reader :show

        def initialize(show) = @show = show

        # The buttons this screen offers (Control), each where it is drawn
        # and where a press reaches it. Show#controls keeps their reaches
        # apart.
        def controls = []

        # A tap at +x+, +y+, by +by+ (a finger's id, :mouse, or :gamepad,
        # which Show#let_go names when it lets go): it presses the button
        # under it, or, on a list's row, waits for its release, so a drag
        # that starts on a row scrolls the list instead.
        def tap(x, y, by)
          name = show.control_at(x, y)&.name
          return show.press_list(x, y, by) if list_row?(name)

          press(name, x, y, by)
        end

        # What a press does: the control +name+ pressed, or with none, a
        # gamepad's A presses the main button, and anything else presses
        # empty space at +x+, +y+.
        def press(name, x, y, by)
          return pressed(name, by) if name
          return primary if by == :gamepad

          empty(x, y, by)
        end

        # The control +name+ this screen offers was pressed, by +by+.
        def pressed(name, by) = nil

        # A press at +x+, +y+ that reached no button: nothing, unless the
        # screen says otherwise.
        def empty(x, y, by) = nil

        # Whether the control +name+ is a row of a list that scrolls.
        def list_row?(name) = false

        # Whether a press at +x+, +y+ waits to be let go before it counts,
        # as it may become a drag of Game Over's pile (PileGrabs).
        def waits_for_release?(x, y) = false

        # Presses this screen's main button, as Enter, Space, a gamepad's
        # Start, or its A aimed at no button do.
        def primary = nil

        # Escape, Android's Back, or a gamepad's B: Back, Close or Home
        # where the screen has one. Says whether it had, so that elsewhere
        # the key can do its usual job.
        def back = false

        # A gamepad's X, Y, LB, RB, LT or View/Select (+button, as
        # GamepadButtons names it) on this screen, as the screen labels it.
        def pad(button) = nil

        # A gamepad's Start: the main button, unless the screen holds it.
        def start = primary

        # A key typed on a keyboard (+key+, as Shell::LotaInput names it)
        # that this screen takes as its own. Says whether it took it.
        def type(key) = false

        # The system's paste shortcut (Ctrl+V, or Cmd+V on a Mac), where the
        # screen takes a paste. Says whether it took it.
        def paste = false

        # Ctrl+B or Cmd+B: Buy, where the screen has it. Says whether it
        # took it.
        def buy = false

        # Whether this screen's list scrolls, by the wheel, the keys, a
        # drag and the right stick.
        def scrolls? = false

        # Whether the left stick and d-pad scroll it too, instead of moving
        # the gamepad's cursor.
        def stick_scrolls? = false

        # Whether it covers the screens under it, veiled, so that none of
        # them is drawn; a dialog or card over a screen shows it.
        def covers? = false

        # Whether a title change's announcement shows over it (GroupBanner).
        def announces? = false

        # Whether this screen is open over the screen for the game's state
        # (Show#layers).
        def opened? = show.layer?(self)

        private

        def layout = show.layout
        def words = show.words
        def style = show.style
        def sounds = show.sounds
        def now = show.now
        def measure = show.measure

        # A button drawn at +frame+, which a press reaches within a dot's
        # width, short of the safe area's bottom.
        def button(name, frame) = Control.new(name:, frame:, reach: within_safe(frame.reach(2 * show.radius)))

        # A screen's main button, which a press reaches more generously.
        def primary_button(name, frame) = Control.new(name:, frame:, reach: layout.primary_reach(frame, show.cabinet.field.radius))

        def back_button = button(:back, layout.back_button)

        def within_safe(reach) = reach.with(height: [reach.height, layout.safe.bottom - reach.y].min)
      end

      # A screen over Home, which Show#page names, with Back in its corner:
      # Back, and its main button, close it.
      class Page < Screen
        def covers? = true

        def primary = show.close_page

        def pressed(name, by) = (show.close_page if name == :back)

        def back
          show.close_page
          true
        end
      end
    end
  end
end
