# frozen_string_literal: true

module DotPopper
  # Friend groups, from the game's side: a Session that knows who this
  # player is and what their group looks like, and talks to the server
  # through a Link on a Worker's thread. None of it touches Lota.
  module Groups
  end
end

%w[settings requests group link worker session].each { require_relative "groups/#{it}" }
