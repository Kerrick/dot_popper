# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Change Server, over Settings, only while setdef is gone
      # (ServerScreen; ADR-0011): Paste server address, the reset, and Back.
      class ChangeServer < Page
        # +server_choice+ (ServerChoice) is the server chosen, if any, or
        # nil where there is no choice to make.
        def initialize(show, server_choice:)
          super(show)
          @choice = server_choice
        end

        # Whether Settings offers it: only while setdef is gone.
        def offered? = @choice&.offered? || false

        # Opens over Settings, where it is offered.
        def open = (show.open_page(:server) if show.settings? && offered?)

        # Where its words and buttons go (ServerScreen).
        # Laid out again only when the window, the words or the choice
        # changes.
        def plan
          choice = @choice
          words = self.words
          layout = self.layout
          (@plan ||= Memo.new).fetch([layout, words, choice&.address, choice&.status]) do
            now = format(words.button(:server_now), choice&.address || words.button(:server_setdef))
            status = choice&.status && words.button(:"server_#{choice.status}")
            ServerScreen.new(layout:, measure:, lines: [[:crown, words.button(:server_warning)], [:copy, words.button(:server_how)]],
                             now:, status:, resettable: !choice&.address.nil?).plan
          end
        end

        # Everything its painter draws (ServerDrawing), made again only when
        # the plan, the words or a button's light changes.
        def drawing
          plan = self.plan
          hover = show.hover
          words = self.words
          (@drawing ||= Memo.new).fetch([plan, words, hover]) do
            ServerDrawing.new(header: HeaderDrawing.for(words.button(:server_heading), layout:, measure:, words:, hover:), plan:,
                              paste: words.button(:server_paste), reset: words.button(:server_reset),
                              paste_hover: hover.level(:server_paste), reset_hover: hover.level(:server_reset))
          end
        end

        # Paste server address: the clipboard's, as the server to use.
        def paste_address
          return unless show.server?

          @choice.paste
          sounds.play(:tick)
        end

        # Back to setdef's server.
        def reset
          return unless show.server?

          @choice.reset
          sounds.play(:tick, pitch: 0.8)
        end

        def controls
          plan = self.plan
          [button(:server_paste, plan.paste), (button(:server_reset, plan.reset) if plan.reset), back_button].compact
        end

        # Paste server address.
        def paste
          paste_address
          true
        end

        def pressed(name, by)
          case name
          in :server_paste then paste_address
          in :server_reset then reset
          else super
          end
        end
      end
    end
  end
end
