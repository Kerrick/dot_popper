# frozen_string_literal: true

module DotPopper
  # The game's HTTP client, for every part of the game that reaches a
  # server: the server's address (Settings), the one place the network is
  # used (Link), its answers (Reply), and the low-priority thread requests
  # run on (Worker). Each part of the game declares its own requests
  # (Request) and makes each one only from its declaration (Job). None of
  # it touches Lota.
  module Network
  end
end

%w[settings request link worker].each { require_relative "network/#{it}" }
