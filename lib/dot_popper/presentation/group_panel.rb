# frozen_string_literal: true

require "time"

module DotPopper
  module Presentation
    # Every sentence about friend groups, kept apart from Words so that
    # they read together.
    module GroupWords
      CODE_LENGTH = 7

      module_function

      def button = "Groups"
      def heading = "Friend groups"
      def group_heading = "Your group"
      def history_heading = "History"
      def join_heading = "Join with a code"
      def blurb = "Beat your friends and take the title."
      def join = "Join"
      def create = "Create"
      # The notice a first Join or Create shows, once: who keeps the scores,
      # in words that name the game, and a link to the privacy policy.
      def notice = "Dot Popper keeps your scores online so your friend group can see them."
      def notice_policy = ByInput.new(touch: "Read the privacy policy", mouse: "Read the privacy policy", gamepad: "Read the privacy policy (X)")
      def notice_later = ByInput.new(touch: "Not now", mouse: "Not now", gamepad: "Not now (B)")

      # The notice's main button names what it goes on to do: Join or Create.
      def notice_go(asking) = asking == :create ? ByInput.new(touch: "Create", mouse: "Create", gamepad: "Create (A)") : ByInput.new(touch: "Join", mouse: "Join", gamepad: "Join (A)")
      def erase = "Delete"
      def open_group = "Open group"
      def hold_start_to_leave = "Hold Start to leave"

      # A button's word, and on a controller the button that presses it:
      # "Join (X)".
      def pressed_by(word, button, input) = input == InputKind::GAMEPAD ? "#{word} (#{button})" : word
      def submit = "Join"
      def you = "You"
      def champion = "Champion"
      def history = "History"
      def leave = "Leave"
      def delete = "Delete my data"
      def hold_to_leave = "Hold to leave this group."
      def hold_to_delete = "Hold to delete your scores from the server."
      def fixed_note = "Only games with standard dots count. Choose Standard in Settings."
      def no_history = "Nothing has happened here yet."
      def show = "Show"
      def copy = "Copy"
      def hidden_code = "●●●-●●●●"

      # When something happened, in the player's own time: "November 8,
      # 8:14 PM". +at+ is the server's ISO 8601 time; +offset+ stands in for
      # the device's time zone in the tests.
      def when(at, offset: nil)
        time = Time.iso8601(at.to_s)
        time = offset ? time.getlocal(offset) : time.getlocal
        time.strftime("%B %-d, %-l:%M %p")
      rescue ArgumentError
        ""
      end

      # What a history entry says, as runs of [text, bold]: who took the
      # title from whom and with what (or to whom it passed when its
      # champion left), or who earned which achievement.
      def entry(group_id, change)
        name = ->(number) { [Names.member(group_id, number), true] }
        case change
        in Groups::MemberAchievement
          [name.(change.member_number), [" earned ", false], [AchievementWords.name(change.key), true], [".", false]]
        in { passed_on: true }
          [["The title passed to ", false], name.(change.champion_number), [" with ", false], [change.score.to_s, true], [".", false]]
        else
          took = [name.(change.champion_number)]
          took += change.previous_champion_number ? [[" took the title from ", false], name.(change.previous_champion_number)] : [[" took the title", false]]
          took + [[" with ", false], [change.score.to_s, true], [".", false]]
        end
      end

      # The group's standing, with the score that wins the title.
      def title_line(group)
        return "Score any points to take the title." if group.vacant?
        return "You hold the title with #{group.top_score}." if group.champion?

        "Beat #{group.top_score} to take the title."
      end

      # "You took the Brave Puffins title!", naming the group where it is known.
      def took(result)
        id = result.taken.first
        id ? "You took the #{Names.group(id)} title!" : "You took the title!"
      end

      # The one line a title change makes, by its kind (Groups::Announcement).
      def announcement(item)
        case item.kind
        in :you_won then "You took the title with #{item.score}!"
        in :you_lost then "A friend took your title with #{item.score}."
        in :passed_to_you then "The title is yours."
        in :passed then "The title passed to a friend."
        in :changed then "A friend took the title with #{item.score}."
        end
      end

      # Game Over's line for a game (Groups::GameResult).
      def game_line(result)
        if result.won.positive? then result.won == 1 ? took(result) : "You took #{result.won} titles!"
        elsif result.raised.positive? then "You raised the bar!"
        elsif result.reigning then "The title stays yours."
        elsif result.short then "#{result.short} short of the title."
        end
      end

      def error(reason)
        { offline: "Can't reach the groups right now.", no_such_group: "No group has that code.",
          group_full: "That group is full.", already_member: "You are already in that group.",
          group_limit: "You are in as many groups as you can be.", too_many_tries: "Too many tries. Wait a while." }
          .fetch(reason, "Something went wrong.")
      end
    end

    # How long an announcement stays on screen, and how it fades. +number+
    # and +group_id+ say whose icon and crest it shows.
    class GroupBanner < Data.define(:text, :at, :seconds, :group_id, :number)
      FADE = 0.4

      def over?(now) = now - at >= seconds
      def alpha(now) = (((seconds - (now - at)) / FADE)).clamp(0.0, 1.0) * ((now - at) / FADE).clamp(0.0, 1.0)
    end

    # The friend groups' screens' state, over Home, and the
    # announcements a title change makes: which screen is showing, the code
    # tapped so far, what a long press would do, and what to tell the
    # player next. Nothing here is typed, so a controller can do all of it.
    # It asks the Session (Groups) for everything, and never waits for it.
    # Pro changes only what Create and Join do, which go through +joining+
    # (UseCases::JoinOrCreateFriendGroup): where it answers :offer, as it
    # does for a Free player, they call +pro_offer+ with :groups, which
    # opens the offer of Pro over this panel, where it was. Leaving and
    # deleting never need it.
    # A Pro player's first Join or Create asks first (+notice+, a
    # GroupNotice): it says who keeps the scores, once ever, before any
    # score is sent (#asking). +shown+ hears true as the screens open and
    # false as they close.
    class GroupPanel
      BANNER_SECONDS = 4.0
      HOLD = 2.0
      PAGES = %i[list group history join].freeze

      attr_reader :groups, :code, :banner, :hold, :note, :page, :group_id

      def initialize(groups:, joining:, sounds:, pro_offer: ->(_feature) {}, notice: GroupNotice.read, shown: ->(_open) {})
        @pro_offer = pro_offer
        @shown = shown
        @notice = notice
        @asking = nil
        @groups = groups
        @joining = joining
        @sounds = sounds
        @open = false
        @page = :list
        @group_id = nil
        @code = ""
        @hold = HoldToConfirm.idle(HOLD)
        @holding = nil
        @banner = nil
        @note = nil
        groups.refresh
      end

      def open? = @open
      def available? = groups.available?
      def member? = groups.member?
      def known? = groups.known?

      # How many of the player's groups they hold the title of, for Home.
      def titles_held = groups.groups.count(&:champion?)
      def group = @group_id && groups.group(@group_id)

      # Opens on the list of groups, or at the code pad for someone with
      # none, which is what they came for.
      def open
        @open = true
        @shown.call(true)
        @note = nil
        show(:list)
        groups.refresh
        @sounds.play(:tick)
      end

      def close
        @open = false
        @shown.call(false)
        @asking = nil
        @hold = hold.cancel
        @sounds.play(:tick, pitch: 0.8)
      end

      # Back up a level: history to its group, a group or the code pad to
      # the list, the list out.
      def back
        @note = nil
        @hold = hold.cancel
        return answer(go: false) if asking

        case page
        when :history then show(:group)
        when :group, :join then show(:list)
        else close
        end
      end

      # The moving parts of each frame: the Session's replies, a long
      # press finished, and the next announcement at a moment for one.
      # +quiet+ is false during a game, when the network waits; +showing+
      # says the screen can show a message now, on Home or at Game
      # Over.
      def update(now, quiet:, showing: quiet)
        groups.update(quiet:)
        finish_hold if hold.done?(now)
        arrive
        leave_page_if_gone
        @banner = nil if @banner&.over?(now)
        return if @banner || !showing || open?

        item = groups.next_announcement or return
        @banner = GroupBanner.new(text: GroupWords.announcement(item), at: now, seconds: BANNER_SECONDS,
                                  group_id: item.group_id, number: item.champion_number)
      end

      def game_started = groups.game_started

      # Game Over's line about the groups: its words, a blank that holds
      # the line's place while the result is on its way, or nil.
      def game_line
        result = groups.game_result
        return GroupWords.game_line(result) if result

        groups.result_due? ? " " : nil
      end

      # The group whose title the last game took, for Game Over's line to
      # open, or nil when it took none, or more than one.
      def game_title_taken
        result = groups.game_result or return
        result.taken.first if result.taken.size == 1
      end

      # Opens the friend groups at +id+'s screen, from Game Over's line.
      def open_at(id)
        open
        open_group(id)
      end

      # A control this screen offers was pressed; +by+ is what pressed it
      # and +now+ the time, for the long presses.
      def press(name, by, now)
        @note = nil
        case name
        in [:code_digit, String => digit] then tap_digit(digit)
        in :code_erase then erase
        in :code_submit then submit_join
        in [:group_show, id] then open_group(id)
        in :group_join_open then open_join
        in :group_create then create
        in :group_history then open_history
        in :group_code then reveal_code
        in :group_leave then start_hold(:leave, by, now)
        in :group_delete then start_hold(:delete, by, now)
        in :group_prev then step_group(-1)
        in :group_next then step_group(1)
        in :group_open_first then pad(:rb)
        in :notice_go then answer(go: true)
        in :notice_later then answer(go: false)
        else nil
        end
      end

      # Enter, Space or A aimed at nothing, on this screen: leaves, except
      # the keypad, which joins with a whole code.
      def primary
        return answer(go: true) if asking

        page == :join ? submit_join : back
      end

      # What the notice of a first Join or Create waits to do, :join or
      # :create, while it is open over the screen; nil otherwise.
      attr_reader :asking

      # The notice answered: going on remembers it was read, and does what
      # was pressed; Not now closes it, and the next Join or Create asks
      # again.
      def answer(go:)
        what = asking or return
        @asking = nil
        return @sounds.play(:tick, pitch: 0.8) unless go

        @notice.read!
        what == :create ? create : open_join
      end

      # Whether Join can be pressed: once all seven digits are in.
      def code_complete? = code.size == GroupWords::CODE_LENGTH

      # A key typed on a keyboard, on the keypad's screen: a digit adds
      # itself, Backspace or Delete takes the last one away. Says whether
      # the key was one of those.
      def type(key)
        return false unless open? && page == :join && !asking

        if (digit = key.to_s[/\A\d\z/]) then tap_digit(digit)
        elsif %i[backspace delete].include?(key) then erase
        else return false
        end
        true
      end

      # The player's groups, in the order the list shows them.
      def listed = groups.groups.sort_by { Names.group(it.id) }

      # A gamepad's button on this screen (Show#pad), as each screen labels
      # it: on the list, X Join, Y Create and RB the first group; on a
      # group, X Show then Copy, Y History, and LB and RB the previous or
      # next group; on the keypad, X Delete. Start's long press, which
      # leaves a group, is #start's.
      def pad(name)
        @note = nil
        case [page, name]
        in [:list, :x] then open_join
        in [:list, :y] then create
        in [:list, :rb] then (first = listed.first) && open_group(first.id)
        in [:group, :x] then reveal_code
        in [:group, :y] then open_history
        in [:group, :lb] then step_group(-1)
        in [:group, :rb] then step_group(1)
        in [:join, :x] then erase
        else nil
        end
      end

      # A gamepad's Start, held by +by+: on a group, the start of leaving
      # it; elsewhere the screen's main button (#primary).
      def start(by, now)
        return primary if asking || page != :group

        start_hold(:leave, by, now)
      end

      # Holds Delete my friend group data, from the Privacy screen.
      def hold_delete(by, now) = start_hold(:delete, by, now)

      def let_go(by, now) = @hold = hold.release(by, now)
      def cancel_hold = @hold = hold.cancel

      # What the hold's prompt says while one is under way.
      def holding_words = @holding == :delete ? GroupWords.hold_to_delete : GroupWords.hold_to_leave

      # Moves the page of a long list by one, for GroupScreen to bound.
      # Whether the group's code shows: hidden until Show is pressed, and
      # hidden again when the player leaves the group's screen.
      def code_shown? = !@code_shown.nil? && @code_shown == @group_id && page == :group

      # The group's history, newest first, without achievements this game
      # does not know.
      def history_entries
        list = groups.history(@group_id) || groups.title_changes(@group_id) || []
        list.reject { it.is_a?(Groups::MemberAchievement) && !Achievement::IDS.include?(it.key) }
      end

      # Show, then Copy: the code shows, then goes to the clipboard.
      def reveal_code
        if code_shown?
          @copy&.call(CodeText.hyphenated(group.join_code))
          @sounds.play(:tick, pitch: 1.3)
        else
          @code_shown = @group_id
          @sounds.play(:tick)
        end
      end

      # Where Copy puts the code (+copy+ answers call(text)).
      attr_writer :copy

      private

      def show(page, id = @group_id)
        @code_shown = nil unless id == @group_id && %i[group history].include?(page) && %i[group history].include?(@page)
        @page = page
        @group_id = id
      end

      def open_group(id)
        show(:group, id)
        groups.look_at(id)
        @sounds.play(:tick)
      end

      def open_history
        show(:history)
        groups.look_at(@group_id)
        @sounds.play(:tick)
      end

      def open_join
        return offer_pro if @joining.choose == :offer
        return ask(:join) if @notice.due?

        @code = ""
        show(:join)
        @sounds.play(:tick)
      end

      # The previous or next group in the list's order, round its ends.
      def step_group(by)
        list = listed
        return if list.size < 2

        at = list.index { it.id == @group_id }.to_i
        open_group(list[(at + by) % list.size].id)
      end

      def arrive
        id = groups.take_arrival or return
        open_group(id) if open?
      end

      # A group left, or lost, takes its pages with it.
      def leave_page_if_gone
        show(:list) if %i[group history].include?(page) && !group
      end

      def tap_digit(digit)
        return unless digit.match?(/\A\d\z/) && code.size < GroupWords::CODE_LENGTH

        @code += digit
        @sounds.play(:tick)
      end

      def erase
        @code = code[0...-1].to_s
        @sounds.play(:tick, pitch: 0.8)
      end

      def submit_join
        return offer_pro if @joining.choose == :offer
        return @sounds.play(:tick, pitch: 0.8) unless code_complete? # Join looks disabled until then

        offer_pro if @joining.join(code) == :offer
      end

      def create
        return offer_pro if @joining.choose == :offer
        return ask(:create) if @notice.due?

        offer_pro if @joining.create == :offer
      end

      # The offer of Pro over this panel, leading with friend groups.
      def offer_pro = @pro_offer.call(:groups)

      def ask(what)
        @asking = what
        @sounds.play(:tick)
      end

      def start_hold(what, by, now)
        @holding = what
        @hold = hold.press(by, now)
        @sounds.play(:tick, pitch: 0.7)
      end

      def finish_hold
        @hold = hold.cancel
        @holding == :delete ? groups.delete_everything : groups.leave(@group_id)
        show(:list)
        @sounds.play(:bonk, pitch: 0.7)
      end
    end
  end
end
