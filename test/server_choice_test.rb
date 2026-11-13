# frozen_string_literal: true

require "test_helper"

# Which server friend groups and themes use: setdef's, or while setdef is
# gone, one the player pasted.
class ServerChoiceTest < Minitest::Test
  Memory = DotPopper::ScoreRecord::Memory
  OWN = "https://server.dot-popper.setdef.com"

  class Clipboard
    attr_accessor :text

    def paste = text
  end

  def setup
    @store = Memory.new
    @gone = DotPopper::Continuity::Gone.new(Memory.new)
    @clipboard = Clipboard.new
    @choice = DotPopper::ServerChoice.new(@store, gone: @gone, clipboard: @clipboard)
  end

  def test_while_setdef_answers_nothing_is_offered_and_setdefs_server_is_used
    @store.write("https://groups.example.org\n")

    refute_predicate @choice, :offered?
    assert_equal OWN, @choice.server_url(OWN)
  end

  def test_while_setdef_is_gone_a_pasted_https_address_is_kept_and_used
    @gone.heard(:gone, Date.new(2027, 1, 1))
    assert_predicate @choice, :offered?
    assert_equal OWN, @choice.server_url(OWN)

    @clipboard.text = "  "
    assert_equal :empty, @choice.paste
    @clipboard.text = "http://groups.example.org"
    assert_equal :not_https, @choice.paste
    assert_nil @choice.address
    @clipboard.text = " https://groups.example.org \n"
    assert_equal :chosen, @choice.paste
    assert_equal :chosen, @choice.status
    assert_equal "https://groups.example.org\n", @store.read
    assert_equal "https://groups.example.org", @choice.server_url(OWN)
  end

  def test_when_setdef_answers_again_a_chosen_server_is_forgotten
    @gone.heard(:gone, Date.new(2027, 1, 1))
    @clipboard.text = "https://groups.example.org"
    @choice.paste
    @gone.subscribe(@choice)

    @gone.heard(:unknown, Date.new(2027, 1, 2))
    assert_equal "https://groups.example.org", @choice.address, "kept while setdef is still gone"
    @gone.heard(:here, Date.new(2027, 1, 3))
    assert_nil @choice.address
    assert_equal "", @store.read
    assert_equal OWN, @choice.server_url(OWN)
  end

  def test_a_chosen_server_is_forgotten_only_once_setdef_is_back
    @gone.heard(:gone, Date.new(2027, 1, 1))
    @clipboard.text = "https://groups.example.org"
    @choice.paste

    @choice.forget
    assert_equal "https://groups.example.org", @choice.address
  end

  def test_reset_goes_back_to_setdefs_server
    @gone.heard(:gone, Date.new(2027, 1, 1))
    @clipboard.text = "https://groups.example.org"
    @choice.paste
    @choice.reset

    assert_nil @choice.status
    assert_equal OWN, @choice.server_url(OWN)
  end

  def test_a_server_address_must_be_one_https_address
    ["https://a.example", "https://a.example:8443/api"].each { assert DotPopper::ServerChoice.https?(it), it }
    ["http://a.example", "https://", "https://u:p@a.example", "https://a.example b", "ftp://a.example", "a.example", "https://[bad"].each do
      refute DotPopper::ServerChoice.https?(it), it
    end
  end
end
