# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Settings, over Home (SettingsScreen): its rows of choices, Credits
      # and licenses, Privacy, Change Server while setdef is gone, and
      # Back. Only the buttons in view take presses.
      class Settings < Page
        # The dot-size choices in the order its row draws them: the
        # default, Standard, first.
        SIZINGS = [DotSizing::STANDARD, DotSizing::FIXED].freeze

        # +sizing_store+ keeps the player's DotSizing.
        def initialize(show, sizing_store:)
          super(show)
          @sizing_store = sizing_store
        end

        # Where its rows and buttons go (SettingsPlan), with its list fitted
        # to the page while it is open.
        def plan
          sounds = self.sounds
          rows = [[:sound, words.button(:sound), :speaker, [[words.button(:on), !sounds.muted?, [:sound, true]], [words.button(:off), sounds.muted?, [:sound, false]]]]]
          if sizing_shown?
            cabinet = show.cabinet
            rows << [:dot_size, words.button(:dot_size), :dot, SIZINGS.map { [words.sizing(it, show.sizing_preview), it == cabinet.sizing, it] }]
          end
          rows << [:display, words.button(:display), :corners, display_choices] if show.window.offered?
          open = show.settings?
          plan = SettingsScreen.new(layout:, rows:, offset: open && show.scroll ? show.scroll.offset : 0.0, server: show.server_offered?).plan
          show.list_fit(plan.height, layout.page.height) if open
          plan
        end

        # A visit to Settings begins (Show#open_settings).
        def visit = @chosen_here = false

        # Whether the Dot size row shows: where Show#sizing_offered? says,
        # and for the rest of a visit once a size is chosen in it, so a
        # choice that takes the row away elsewhere (Standard, where the two
        # sizes look alike) never pulls it from under the player.
        def sizing_shown? = show.sizing_offered? || @chosen_here == true

        # Sizes dots as +sizing+ (DotSizing) says, while it offers the
        # choice, and remembers it. Home's dots and score record change
        # with it, so the choice shows at once.
        def choose_sizing(sizing)
          cabinet = show.cabinet
          return unless show.settings? && sizing_shown?
          return sounds.play(:tick, pitch: 0.8) if sizing == cabinet.sizing

          @chosen_here = true
          cabinet.sizing = sizing
          @sizing_store.write(cabinet.sizing.to_text)
          show.sizing_changed
          sounds.play(:tick, pitch: cabinet.sizing.standard? ? 1.2 : 0.9)
        end

        # Sound on or off, as +on+ says.
        def set_sound(on)
          sounds.toggle_mute if sounds.muted? == on
          sounds.play(:tick)
        end

        # The next of the window's displays, round the end, on a computer.
        def next_display
          window = show.window
          return unless window.offered?

          order = %i[window borderless exclusive]
          window.display = order[(order.index(window.display).to_i + 1) % order.size]
        end

        def controls
          plan = self.plan
          rows = plan.rows.flat_map { |row| row.choices.zip(row.rects).map { |(_, _, name), rect| button(name, rect) } }
          page = layout.page
          seen = (rows + [button(:credits, plan.credits), button(:privacy, plan.privacy), *(button(:server, plan.server) if plan.server)])
                 .select { it.frame.center_y.between?(page.y, page.bottom) }
          seen.map { it.with(frame: it.frame.cut(top: page.y, bottom: page.bottom), reach: it.reach.cut(top: page.y, bottom: page.bottom)) } <<
            back_button
        end

        # C opens Credits and licenses.
        def type(key)
          return false unless key == :c

          show.open_credits
          true
        end

        # View/Select Sound, LB Dot size where it is offered, RB Display,
        # X Credits and licenses, Y Privacy.
        def pad(button)
          case button
          in :lb then choose_sizing(show.cabinet.sizing.toggled) if sizing_shown?
          in :rb then next_display
          in :x then show.open_credits
          in :y then show.open_privacy
          in :select then set_sound(sounds.muted?)
          else nil
          end
        end

        def scrolls? = true

        def pressed(name, by)
          case name
          in [:sound, on] then set_sound(on)
          in DotSizing => sizing then choose_sizing(sizing)
          in [:display, mode] then show.window.display = mode
          in :credits then show.open_credits
          in :privacy then show.open_privacy
          in :server then show.screens.fetch(:server).open
          else super
          end
        end

        def empty(_x, y, by) = show.start_scroll(by, y)

        private

        def display_choices
          window = show.window
          { window: :windowed, borderless: :full_screen_borderless, exclusive: :full_screen }.map { |mode, word| [words.button(word), window.display == mode, [:display, mode]] }
        end
      end
    end
  end
end
