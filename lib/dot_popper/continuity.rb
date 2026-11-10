# frozen_string_literal: true

module DotPopper
  # Pro outliving setdef (doc/decisions.md, "Pro outlives setdef"): license
  # keys checked offline, one device at a time while setdef's server
  # answers, and the one test of whether setdef is gone. None of it
  # touches Lota, and none of it reaches the network but by a port.
  module Continuity
  end
end

%w[ed25519 certificate pins test_keys license_key signed_answers license setdef_server watch].each { require_relative "continuity/#{it}" }
