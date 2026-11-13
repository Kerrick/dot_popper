# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The friend groups' screens, over Home: the list, a group, its
      # history and the keypad that joins one, each GroupPanel's page, and
      # the notice a first Join or Create shows over them (GroupScreen,
      # GroupNoticeDialog).
      class FriendGroups < Screen
        # Where the open page's parts go (GroupScreen), its list fitted to
        # its window, and scrolled back to its top when the page or the
        # group changes.
        def plan
          panel = show.group_panel
          where = [panel.page, panel.group_id]
          show.list_scroll_from_top unless @scrolled_at == where
          @scrolled_at = where
          offset = show.scroll&.offset || 0.0
          plan = GroupScreen.new(layout:, style: style::GROUPS, measure:, panel:,
                                 back_text: words.go_back, offset:, input: show.input).plan
          show.list_fit(plan.content, plan.window.height) if plan.window
          plan
        end

        # Where the notice of a first Join or Create puts its parts, while it
        # is open over the page (GroupNoticePlan), or nil.
        def notice_plan
          panel = show.group_panel
          return unless panel.open? && panel.asking

          GroupNoticeDialog.new(layout:, measure:, policy_text: word(GroupWords.notice_policy),
                                later_text: word(GroupWords.notice_later), go_text: word(GroupWords.notice_go(panel.asking))).plan
        end

        # A friend groups' word (a ByInput), said as the player's input would
        # press it.
        def word(byinput) = byinput.for(show.input)

        def controls = (notice_plan || plan).controls.map { |name, frame| button(name, frame) }

        def primary = show.group_panel.primary

        # Back up a level (GroupPanel#back).
        def back
          show.group_panel.back
          true
        end

        # Holding Start on a group leaves it; elsewhere it is the main
        # button (GroupPanel#start).
        def start = show.group_panel.start(:start, show.now)

        # The keypad's digits, and Backspace or Delete (GroupPanel#type).
        def key_bindings = KEY_BINDINGS
        KEY_BINDINGS = [KeyBinding.new(keys: [*(0..9).map { it.to_s.to_sym }, :backspace, :delete], does: :type)].freeze

        def type(key) = show.group_panel.type(key)

        # Each page's own (GroupPanel#pad); over the notice, X opens the
        # privacy policy, as it does on Privacy.
        def pad(button)
          return (show.open_policy if button == :x) if show.group_panel.asking

          show.group_panel.pad(button)
        end

        def scrolls? = true

        def answers = [:back, :policy, *GroupPanel::ANSWERS]

        # Back, the notice's privacy policy, and every other button the
        # panel's (GroupPanel#press).
        def pressed(name, by)
          case name
          in :back then show.group_panel.back
          in :policy then show.open_policy
          else show.group_panel.press(name, by, show.now)
          end
        end

        # A row of the list of groups.
        def list_row?(name) = show.group_panel.page == :list && (name in [:group_show, _])

        def empty(_x, y, by) = show.start_scroll(by, y)

        def covers? = true
      end
    end
  end
end
