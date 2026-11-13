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
      end
    end
  end
end
