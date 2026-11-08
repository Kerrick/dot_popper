# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every sentence about friend groups, kept apart from Words so that
    # they read together.
    module GroupWords
      NAME_LONGEST = 16
      CODE_LENGTH = 6
      CONTACT = "github.com/setdef/dot_popper/issues"

      module_function

      def button = "Group"
      def heading = "Friend group"
      def blurb = "Beat your friends and take the trophy. Its score falls a point a day."
      def name_label = "Name"
      def code_label = "Code"
      def join = "Join"
      def create(paid) = paid ? "Create" : "Create (paid)"
      def needs_paid = "Creating a group comes with the paid version. Joining is free."
      def privacy = "Joining or creating sends your name and scores to the group's server."
      def need_name = "Pick a name first."
      def need_code = "Type your friend's code."
      def leave = "Leave group"
      def delete = "Delete my data"
      def block = "Block"
      def unblock = "Unblock"
      def report = "Report"
      def reported = "Reported, and blocked for you."
      def hold_to_leave = "Hold to leave the group."
      def hold_to_delete = "Hold to delete your name and scores from the server."
      def contact = "Problems? #{CONTACT}"
      def code_line(code) = "Invite code: #{code}"
      def standard_note = "Rounds with standard dots do not count. Choose dots sized to the screen."

      # Who holds the trophy, and the score to beat today.
      def trophy_line(trophy)
        holder = trophy["holder_name"]
        return "Nobody holds the trophy yet. Score any points to take it." unless holder

        "#{holder} holds the trophy. Beat #{trophy["standing"]} to take it."
      end

      # The one message a theft or a win makes.
      def message(message)
        case message.kind
        in :stolen then "#{message.who} took your trophy with #{message.score}."
        in :taken then "You took the trophy with #{message.score}!"
        end
      end

      def error(reason)
        { offline: "Can't reach the group right now.", no_such_group: "No group has that code.",
          group_full: "That group is full.", bad_name: "Please pick another name.",
          already_in_group: "You are already in a group.", too_many_tries: "Too many tries. Wait a while.",
          not_in_group: "You are not in that group any more." }.fetch(reason, "Something went wrong.")
      end
    end

    # How long a group's message stays on screen, and how it fades.
    class GroupBanner < Data.define(:text, :at, :seconds)
      FADE = 0.4

      def over?(now) = now - at >= seconds
      def alpha(now) = (((seconds - (now - at)) / FADE)).clamp(0.0, 1.0) * ((now - at) / FADE).clamp(0.0, 1.0)
    end

    # The Friend group screen's state, over the title, and the one
    # message a theft makes: what the player has typed, which field has
    # the keyboard, what a long press would do, and what to tell them
    # next. It asks the Session (Groups) for everything, and never waits
    # for it. Paid only changes whether Create creates (+entitlement+).
    class GroupPanel
      BANNER_SECONDS = 7.0
      HOLD = 2.0

      attr_reader :groups, :name, :code, :focus, :banner, :hold, :note

      def initialize(groups:, entitlement:, sounds:)
        @groups = groups
        @entitlement = entitlement
        @sounds = sounds
        @open = false
        @name = groups.name.to_s
        @code = ""
        @focus = nil
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
      def editing? = !@focus.nil?

      def open
        @open = true
        @note = nil
        @name = groups.name.to_s if @name.empty?
        groups.refresh
        @sounds.play(:tick)
      end

      def close
        @open = false
        stop_editing
        @hold = hold.cancel
        @sounds.play(:tick, pitch: 0.8)
      end

      def stop_editing = @focus = nil

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
        @banner = GroupBanner.new(text: GroupWords.message(message), at: now, seconds: BANNER_SECONDS)
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
        in :group_name then edit(:name)
        in :group_code then edit(:code)
        in :group_join then join
        in :group_create then create
        in :group_leave then start_hold(:leave, by, now)
        in :group_delete then start_hold(:delete, by, now)
        in [:group_block, id] then groups.block(id)
        in [:group_unblock, id] then groups.unblock(id)
        in [:group_report, id] then report(id)
        end
      end

      def tap_away = stop_editing

      # Text the keyboard typed, into the field that has it.
      def type(text)
        case focus
        when :name then @name = (name + text.gsub(/[\r\n]/, ""))[0, GroupWords::NAME_LONGEST]
        when :code then @code = (code + text.upcase.gsub(/[^A-Z0-9]/, ""))[0, GroupWords::CODE_LENGTH]
        end
      end

      # A key while a field is focused; says whether it was the field's.
      def key(key)
        case key
        when :backspace then erase
        when :return, :kpenter, :escape then stop_editing
        end
        editing?
      end

      def let_go(by, now) = @hold = hold.release(by, now)
      def cancel_hold = @hold = hold.cancel

      # What the hold's prompt says while one is under way.
      def holding_words = @holding == :delete ? GroupWords.hold_to_delete : GroupWords.hold_to_leave

      private

      def edit(field)
        @focus = field
        @sounds.play(:tick)
      end

      def erase
        case focus
        when :name then @name = name[0...-1].to_s
        when :code then @code = code[0...-1].to_s
        end
      end

      def join
        return @note = GroupWords.need_name if name.strip.empty?
        return @note = GroupWords.need_code if code.empty?

        stop_editing
        groups.join(name.strip, code)
      end

      def create
        return @note = GroupWords.needs_paid unless paid?
        return @note = GroupWords.need_name if name.strip.empty?

        stop_editing
        groups.create(name.strip)
      end

      def report(id)
        groups.report(id)
        @note = GroupWords.reported
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
