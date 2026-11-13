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

        # Where its card, words and buttons go (SharePlan), laid out again
        # only when the window, the words or the text changes.
        def plan
          layout = self.layout
          words = self.words
          text = preview.text
          (@plan ||= Memo.new).fetch([layout, words, text]) do
            ShareScreen.new(layout:, type: style::TYPE, words:, measure:, style: style::SHARE_PREVIEW, lines: preview.lines).plan
          end
        end

        # Everything its painter draws (ShareDrawing), made again only
        # while it comes in or confirms a copy, or when the plan, the words
        # or a button's light changes.
        def drawing
          plan = self.plan
          words = self.words
          hover = show.hover
          look = style::SHARE_PREVIEW
          shown = preview.arrival(now, look).clamp(0.0, 1.0)
          copied = preview.confirmation(now, look)
          (@drawing ||= Memo.new).fetch([plan, words, hover, shown, copied]) do
            ShareDrawing.new(shown:, veil: look.veil * shown, lift: (1 - shown) * look.lift * layout.ui, corner: look.corner * layout.ui, plan:,
                             runs: plan.lines.map { ShareGlyphs.runs(it) }, heading: words.share_heading, copied_word: words.copied, copied:,
                             close: words.close, copy: words.copy, close_hover: hover.level(:close), copy_hover: hover.level(:copy))
          end
        end

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
