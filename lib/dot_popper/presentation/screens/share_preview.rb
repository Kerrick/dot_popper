# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The share preview over Game Over, on a computer (ShareScreen): the
      # game's result as it would be shared, Close, and Copy, the one press
      # that writes the +clipboard+.
      class SharePreview < Screen
        def initialize(show, clipboard:)
          super(show)
          @clipboard = clipboard
        end

        # What it shows (Presentation::SharePreview): the text, and when it
        # was copied.
        attr_reader :preview

        # Opens over Game Over, showing +preview+.
        def open_with(preview)
          @preview = preview
          show.open_layer(self)
        end

        # Where its card, words and buttons go (SharePlan).
        def plan = ShareScreen.new(layout:, type: style::TYPE, words:, measure:, style: style::SHARE_PREVIEW, lines: preview.lines).plan

        # Copy: exactly the text it shows.
        def copy
          @clipboard.copy(preview.text)
          @preview = preview.copy(now)
          sounds.play(:tick, pitch: 1.3)
        end

        # Back to Game Over as it was.
        def close
          show.close_layer(self)
          sounds.play(:tick, pitch: 0.8)
        end

        def controls
          plan = self.plan
          [button(:close, plan.close), button(:copy, plan.copy)]
        end

        def primary = copy

        def back
          close
          true
        end

        # Y again copies, as Copy does.
        def pad(button) = (copy if button == :y)

        def answers = %i[copy close]

        def pressed(name, by)
          case name
          in :copy then copy
          in :close then close
          else nil
          end
        end

        # A tap beside the card closes it; on the card it does nothing.
        def empty(x, y, _by) = (close unless plan.card.contains?(x, y))

        def announces? = true
      end
    end
  end
end
