# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The friend groups' screens, over Home: the list, a group, its
      # history and the keypad that joins one, each GroupPanel's page, and
      # the notice a first Join or Create shows over them (GroupScreen,
      # GroupNoticeDialog).
      class FriendGroups < Screen
        def controls = (show.group_notice_plan || show.group_plan).controls.map { |name, frame| button(name, frame) }

        def primary = show.group_panel.primary

        # Back up a level (GroupPanel#back).
        def back
          show.group_panel.back
          true
        end

        # Holding Start on a group leaves it; elsewhere it is the main
        # button (GroupPanel#start).
        def start = show.group_panel.start(:start, show.now)

        # The keypad's digits, and Backspace (GroupPanel#type).
        def type(key) = show.group_panel.type(key)

        # Each page's own (GroupPanel#pad); over the notice, X opens the
        # privacy policy, as it does on Privacy.
        def pad(button)
          return (show.open_policy if button == :x) if show.group_panel.asking

          show.group_panel.pad(button)
        end
      end
    end
  end
end
