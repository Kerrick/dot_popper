# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every sentence about friend groups, kept apart from Words so that
    # they read together.
    module GroupWords
      CODE_LENGTH = 7

      module_function

      def button = "Group"
      def heading = "Friend group"
      def blurb = "Beat your friends and take the trophy. Its score falls a point a day."
      def mark_label = "Your dot"
      def code_label = "Code"
      def join = "Join"
      def create(paid) = paid ? "Create" : "Create (paid)"
      def needs_paid = "Creating a group comes with the paid version. Joining is free."
      def privacy = "Joining or creating sends your dot and scores to the group's server."
      def need_code = "Tap your friend's code."
      def erase = "Erase"
      def you = "You"
      def leave = "Leave group"
      def delete = "Delete my data"
      def hold_to_leave = "Hold to leave the group."
      def hold_to_delete = "Hold to delete your scores from the server."
      def code_line(code) = "Invite code: #{code}"
      def standard_note = "Rounds with standard dots do not count. Choose dots sized to the screen."

      # The score to beat today, or that nobody holds the trophy yet. Who
      # holds it shows in the members' rows, by their dot.
      def trophy_line(trophy)
        return "Nobody holds the trophy yet. Score any points to take it." unless trophy["holder_mark"]

        "Beat #{trophy["standing"]} to take the trophy."
      end

      # The one message a theft or a win makes.
      def message(message)
        case message.kind
        in :stolen then "A friend took your trophy with #{message.score}."
        in :taken then "You took the trophy with #{message.score}!"
        end
      end

      def error(reason)
        { offline: "Can't reach the group right now.", no_such_group: "No group has that code.",
          group_full: "That group is full.", bad_mark: "Pick one of the dots.",
          already_in_group: "You are already in a group.", too_many_tries: "Too many tries. Wait a while.",
          not_in_group: "You are not in that group any more." }.fetch(reason, "Something went wrong.")
      end
    end

    # How long a group's message stays on screen, and how it fades.
    class GroupBanner < Data.define(:text, :at, :seconds, :mark)
      FADE = 0.4

      def over?(now) = now - at >= seconds
      def alpha(now) = (((seconds - (now - at)) / FADE)).clamp(0.0, 1.0) * ((now - at) / FADE).clamp(0.0, 1.0)
    end

    # The Friend group screen's state, over the title, and the one
    # message a theft makes: the dot the player has picked (Groups::Mark),
    # the code they have tapped, what a long press would do, and what to
    # tell them next. Nothing here is typed: a dot is picked from the
    # eight the game draws, and a code is tapped on its digits, so a
    # controller can do both. It asks the Session (Groups) for everything,
    # and never waits for it. Paid only changes whether Create creates
    # (+entitlement+).
    class GroupPanel
      BANNER_SECONDS = 7.0
      HOLD = 2.0

      attr_reader :groups, :mark, :code, :banner, :hold, :note

      def initialize(groups:, entitlement:, sounds:)
        @groups = groups
        @entitlement = entitlement
        @sounds = sounds
        @open = false
        @mark = groups.mark || 0
        @code = ""
        @hold = HoldToConfirm.idle(HOLD)
        @holding = nil
        @banner = nil
        @news_due = true
        @note = nil
        groups.refresh
      end

      def open? = @open
      def available? = groups.available?
      def member? = groups.member?
      def paid? = @entitlement.paid?

      def open
        @open = true
        @note = nil
        groups.refresh
        @sounds.play(:tick)
      end

      def close
        @open = false
        @hold = hold.cancel
        @sounds.play(:tick, pitch: 0.8)
      end

      # The moving parts of each frame: the Session's replies, a long
      # press finished, and the next message at a moment for one (at
      # launch and at Game Over only, so it never nags). +quiet+ is false
      # during a round, when the network waits; +showing+ says the screen
      # can show a message now, on the title or at Game Over.
      def update(now, quiet:, showing: quiet)
        groups.update(quiet:)
        finish_hold if hold.done?(now)
        @banner = nil if @banner&.over?(now)
        return unless @news_due && !@banner && showing && !open?

        message = groups.next_message or return
        @banner = GroupBanner.new(text: GroupWords.message(message), at: now, seconds: BANNER_SECONDS, mark: message.who)
        @news_due = false
      end

      # A round began, so the moment for a message has passed.
      def round_started = @news_due = false

      # A round ended: reports it if it counts, and a message may show.
      def round_finished(score:, sized_to_screen:)
        groups.round_finished(score:, sized_to_screen:)
        @news_due = true
      end

      # A control this screen offers was pressed; +by+ is what pressed it
      # and +now+ the time, for the long presses.
      def press(name, by, now)
        @note = nil
        case name
        in [:group_mark, Integer => mark] then pick(mark)
        in [:group_digit, String => digit] then tap_digit(digit)
        in :group_erase then erase
        in :group_join then join
        in :group_create then create
        in :group_leave then start_hold(:leave, by, now)
        in :group_delete then start_hold(:delete, by, now)
        else nil
        end
      end

      # A tap on nothing in particular. Nothing here has the keyboard.
      def tap_away = nil

      def let_go(by, now) = @hold = hold.release(by, now)
      def cancel_hold = @hold = hold.cancel

      # What the hold's prompt says while one is under way.
      def holding_words = @holding == :delete ? GroupWords.hold_to_delete : GroupWords.hold_to_leave

      private

      def pick(mark)
        return unless Groups::Mark.valid?(mark)

        @mark = mark
        @sounds.play(:tick)
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

      def join
        return @note = GroupWords.need_code if code.size < GroupWords::CODE_LENGTH

        groups.join(mark, code)
      end

      def create
        return @note = GroupWords.needs_paid unless paid?

        groups.create(mark)
      end

      def start_hold(what, by, now)
        @holding = what
        @hold = hold.press(by, now)
        @sounds.play(:tick, pitch: 0.7)
      end

      def finish_hold
        @hold = hold.cancel
        @holding == :delete ? groups.delete_everything : groups.leave
        @sounds.play(:bonk, pitch: 0.7)
      end
    end
  end
end
