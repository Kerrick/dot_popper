# frozen_string_literal: true

require_relative "presentation_helper"

# Buying Pro: the URLs the hosts catch, the answers they
# write back, and the calm screen that offers it.
class StorefrontTest < Minitest::Test
  include PresentationTest

  class FakeOpener
    attr_reader :urls
    attr_writer :refuses

    def initialize = @urls = []

    def open(url)
      @urls << url
      !@refuses
    end
  end

  class FakeAnswers
    attr_accessor :text
    attr_reader :removed

    def read = @text
    def remove = (@removed = true) && (@text = nil)
    def path = "/save dir/answer.txt"
  end

  RECEIPT = DotPopper::Receipt.issue

  def setup
    @opener = FakeOpener.new
    @answers = FakeAnswers.new
    @entitlement = DotPopper::Entitlement.test
    @store = Storefront.new(port: port, entitlement: @entitlement)
  end

  def port = DotPopper::Presentation::NativeStore.new(opener: @opener, answers: @answers)

  # The two adapters a build chooses between, at the composition root.
  def stores
    @native ||= port
    @fake ||= DotPopper::Presentation::FakeStore.new(DotPopper::ScoreRecord::Memory.new)
    { native: @native, fake: @fake }
  end

  def hear(text)
    @answers.text = text
    @store.update(Storefront::EVERY)
  end

  def test_a_url_names_the_action_the_request_the_product_and_where_to_answer
    assert_equal "dotpopper-store://buy?n=3&product=com.setdef.DotPopper.pro&file=%2Fsave%20dir%2Fanswer.txt",
                 Storefront.url(:buy, 3, "/save dir/answer.txt")
  end

  def test_a_phone_test_build_is_metered_like_the_final_game
    assert_predicate Storefront, :test_build?
    %w[iOS Android].each do |os|
      store = Storefront.for(os, **stores, entitlement: @entitlement)
      games = DotPopper::FreeGames.new(DotPopper::ScoreRecord::Memory.new, today: -> { Date.today }, entitlement: @entitlement,
                                                                         metered: store.offered?)

      assert_predicate games, :metered?, os
    end
  end

  def test_a_test_build_uses_the_fake_store_on_every_system
    assert_nil Storefront::BUILD_CHANNEL
    ["iOS", "Android", "Linux", "Windows", "OS X"].each do |os|
      store = Storefront.for(os, **stores, entitlement: @entitlement)

      assert_same @fake, store.instance_variable_get(:@port), os
    end
  end

  def test_a_store_build_uses_the_native_store_on_phones
    %w[iOS Android].each do |os|
      store = Storefront.for(os, **stores, entitlement: @entitlement, channel: "app-store")

      assert_same @native, store.instance_variable_get(:@port), os
    end
  end

  def test_connecting_asks_the_store_and_a_pro_player_needs_no_asking
    @store.connect

    assert @answers.removed
    assert_match %r{\Adotpopper-store://open\?n=1&}, @opener.urls.last
    assert_equal :loading, @store.status

    @entitlement.prove(RECEIPT)
    @store.connect

    assert_equal 1, @opener.urls.size
  end

  def test_an_answer_sets_the_price_and_status
    @store.connect
    hear("answer=1\nowned=0\nstate=ready\nprice=$1.99\n")

    assert_equal "$1.99", @store.price
    assert_equal :ready, @store.status
    refute_predicate @entitlement, :pro?
  end

  def test_a_receipt_proves_pro_whatever_request_the_answer_is_to
    @store.connect
    @store.connect
    hear("answer=1\nowned=1\nstate=ready\nprice=$1.99\nreceipt=#{RECEIPT}\n")
  
    assert_predicate @entitlement, :pro?
  end
  
  # The maintainer's rule: editing a text file must never grant Pro.
  def test_an_answer_that_only_says_owned_proves_nothing
    @store.connect
    hear("answer=1\nowned=1\nstate=ready\nprice=$1.99\n")
    hear("answer=1\nowned=1\nstate=ready\nprice=$1.99\nreceipt=pro\n")
    hear("answer=1\nowned=1\nstate=ready\nprice=$1.99\nreceipt=#{RECEIPT.sub("play:", "play:A")}\n")
  
    refute_predicate @entitlement, :pro?
  end
  
  def test_a_receipt_the_test_key_signed_proves_nothing_in_a_store_build
    store = Storefront.new(port:, entitlement: entitlement = DotPopper::Entitlement.free)
    store.connect
    @answers.text = "answer=1\nowned=1\nstate=ready\nprice=$1.99\nreceipt=#{RECEIPT}\n"
    store.update(Storefront::EVERY)
  
    refute_predicate entitlement, :pro?
  end

  def test_an_older_answer_does_not_overturn_a_newer_request
    @store.connect
    hear("answer=1\nowned=0\nstate=ready\nprice=$1.99\n")
    @store.buy
    hear("answer=1\nowned=0\nstate=ready\nprice=$1.99\n")

    assert_equal :busy, @store.status
    hear("answer=2\nowned=0\nstate=cancelled\nprice=$1.99\n")

    assert_equal :ready, @store.status
  end

  def test_buying_needs_a_price_and_is_not_asked_twice
    @store.buy

    assert_empty @opener.urls
    @store.connect
    hear("answer=1\nowned=0\nstate=ready\nprice=$1.99\n")
    @store.buy
    @store.buy

    assert_equal(1, @opener.urls.count { it.include?("://buy") })
    assert_includes @opener.urls.last, "n=2"
  end

  def test_restore_says_when_there_is_nothing_to_restore
    @store.restore
    hear("answer=1\nowned=0\nstate=none\n")

    assert_equal :none, @store.status
  end

  def test_a_refusal_or_an_unknown_state_is_said_plainly
    @opener.refuses = true
    @store.connect

    assert_equal :unavailable, @store.status
    @opener.refuses = false
    @store.connect
    hear("answer=2\nowned=0\nstate=gibberish\n")

    assert_equal :failed, @store.status
  end

  def test_a_store_that_later_says_not_owned_takes_nothing_back
    @entitlement.prove(RECEIPT)
    hear("answer=9\nowned=0\nstate=ready\n")

    assert_predicate @entitlement, :pro?
  end

  def test_the_answer_is_read_only_every_so_often
    @answers.text = "answer=0\nowned=1\nstate=ready\nreceipt=#{RECEIPT}\n"
    @store.update(Storefront::EVERY / 2)

    refute_predicate @entitlement, :pro?
    @store.update(Storefront::EVERY)

    assert_predicate @entitlement, :pro?
  end

  def test_a_computer_is_free_by_default_and_the_setting_still_stands_in
    refute DotPopper::Entitlement.forced?({}, os: "Linux")
    refute DotPopper::Entitlement.forced?({}, os: "Windows")
    refute DotPopper::Entitlement.forced?({}, os: "OS X")
    assert DotPopper::Entitlement.forced?({ "DOT_POPPER_PRO" => "1" }, os: "Linux")
    refute DotPopper::Entitlement.forced?({}, os: "iOS")
    refute DotPopper::Entitlement.forced?({}, os: "Android")
    refute DotPopper::Entitlement.forced?({ "DOT_POPPER_PRO" => "0" }, os: "Windows")
    assert DotPopper::Entitlement.forced?({ "DOT_POPPER_PRO" => "1" }, os: "iOS")
    assert DotPopper::Entitlement.forced?({ "DOT_POPPER_PRO" => "1" })
  end

  def test_a_computer_store_build_uses_its_channel_or_offers_nothing
    refute_predicate Storefront.for("Linux", **stores, entitlement: @entitlement, channel: "steam"), :offered?
    made = Object.new
    channels = { "steam" => ->(entitlement:) { made.tap { @given = entitlement } } }

    assert_same made, Storefront.for("Linux", **stores, entitlement: @entitlement, channel: "steam", channels:)
    assert_same @entitlement, @given
    assert_instance_of Storefront, Storefront.for("iOS", **stores, entitlement: @entitlement, channel: "steam", channels:)
  end

  def test_no_word_of_the_offer_calls_it_a_trial_or_a_demo
    words = Style::WORDS.offer.values.flatten.join(" ")

    refute_match(/trial|demo/i, words)
  end

  def test_a_store_is_not_read_during_a_game
    show, = offer_show
    @answers.text = "answer=0\nowned=1\nstate=ready\nreceipt=#{RECEIPT}\n"
    show.primary
    show.update(Storefront::EVERY * 2)

    refute_predicate @entitlement, :pro?
  end

  def test_a_build_with_no_store_offers_nothing
    show = build_show(storefront: NoStorefront.new)
    show.open_stats

    refute_includes show.controls.map(&:name), :offer
  end

  private

  def overlap?(one, other)
    one.x < other.right && other.x < one.right && one.y < other.bottom && other.y < one.bottom
  end

  def build_show(**options)
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(3))
    Show.new(cabinet:, layout: layout, sounds: FakeSounds.new, radius: R, measure: RoughMeasure.new, **options)
  end

  def offer_show
    opener = FakeOpener.new
    store = Storefront.new(port: DotPopper::Presentation::NativeStore.new(opener:, answers: @answers), entitlement: @entitlement)
    show = build_show(storefront: store, entitlement: @entitlement)
    [show, opener]
  end

  def answer(text, show)
    @answers.text = text
    show.update(Storefront::EVERY)
  end
end
