# frozen_string_literal: true

# A stand-in for a computer's store helper (macos/store/main.swift,
# windows/store/dot_popper_store.c), for the store contract: it takes one
# dotpopper-store: URL, answers "loading" or "working" at once and the
# outcome a moment later, each the whole state followed by an empty line,
# on its standard output, and exits. What the store knows lives in
# +folder+ (owned, and whether the price was asked), as a store's own
# record would. Its receipts are the test build's, as the fake store's
# are. Run as:
#
#   ruby -Ilib store_helper_stand_in.rb FOLDER FAILS URL
require "dot_popper/receipt"

folder, fails, url = ARGV
fails = nil if fails.to_s.empty?
action = url[%r{://(\w+)}, 1]
number = url[/[?&]n=(\d+)/, 1]
file = url[/[?&]file=([^&]*)/, 1]
abort "answers go down the pipe" unless file == "-"

owned_at = File.join(folder, "owned")
priced_at = File.join(folder, "priced")
owned = -> { File.exist?(owned_at) }
price = -> { File.exist?(priced_at) ? "$1.99" : "" }

answer = lambda do |state|
  receipt = owned.call ? "receipt=#{DotPopper::Receipt.issue}\n" : ""
  $stdout.write("answer=#{number}\nowned=#{owned.call ? 1 : 0}\nstate=#{state}\nprice=#{price.call}\n#{receipt}\n")
  $stdout.flush
end

answer.call(action == "open" ? "loading" : "working")
sleep 0.02

outcome = if fails == "unavailable" then "unavailable"
          else
            case action
            when "open"
              File.write(priced_at, "")
              "ready"
            when "buy"
              if price.call.empty? then "failed"
              elsif fails then fails
              else
                File.write(owned_at, "")
                "ready"
              end
            when "restore"
              if %w[failed cancelled].include?(fails) then fails
              else owned.call ? "restored" : "none"
              end
            else "failed"
            end
          end
answer.call(outcome)
