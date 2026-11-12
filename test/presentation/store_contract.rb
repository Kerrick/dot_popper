# frozen_string_literal: true

# What any adapter behind Storefront's port must do. Include it in a test
# class and write two methods:
#
#   new_store(fails: nil)  an adapter on a fresh install; +fails+ is one of
#                          FakeStore::FAILURES, and makes it go that way
#   relaunched(store)      a new adapter on the same install: the same
#                          purchases, the same store, a game just started
#
# It reads answers only as Storefront does, through +read+, so the fake
# cannot drift from the port without failing here. Passing says the
# adapter speaks the port; it says nothing of Apple's or Google's real
# stores (ADR-0009).
module StoreContract
  Storefront = DotPopper::Presentation::Storefront
  STATES = %w[loading working ready pending cancelled restored none failed unavailable].freeze
  UNDER_WAY = %w[loading working].freeze

  def setup
    @number = 0
  end

  def test_it_says_a_request_was_taken_and_where_the_answer_goes
    store = new_store

    assert_kind_of String, store.path
    refute_empty store.path
    assert ask(store, :open)
  end

  def test_an_answer_comes_later_than_the_question
    store = new_store
    ask(store, :open)
    first = parse(store.read)

    assert first.nil? || UNDER_WAY.include?(first["state"]), "a store takes a moment: #{first.inspect}"
  end

  def test_every_answer_is_the_whole_state_and_names_its_request
    store = new_store
    ask(store, :open)
    answer = settled(store)

    assert_equal 1, answer["answer"].to_i
    %w[owned state price].each { assert answer.key?(it), it }
    assert_includes STATES, answer["state"]
    assert_includes %w[0 1], answer["owned"]
  end

  def test_opening_gives_a_price_and_owns_nothing_on_a_new_install
    store = new_store
    answer = open_it(store)

    assert_equal "ready", answer["state"]
    assert_equal "0", answer["owned"]
    refute_empty answer["price"]
  end

  def test_buying_after_the_price_owns_it
    store = new_store
    open_it(store)
    ask(store, :buy)
    answer = settled(store)

    assert_equal "ready", answer["state"]
    assert_equal "1", answer["owned"]
  end

  # A store build takes Pro only from the receipt, never from "owned".
  def test_owning_it_hands_over_a_receipt_the_test_build_trusts
    store = new_store
    assert_nil open_it(store)["receipt"]

    ask(store, :buy)
    receipt = settled(store)["receipt"]

    assert DotPopper::Receipt.valid?(receipt, DotPopper::Receipt::TEST), receipt
    assert DotPopper::Receipt.valid?(open_it(relaunched(store))["receipt"], DotPopper::Receipt::TEST), "a relaunch hands one over again"
  end

  def test_buying_without_asking_the_price_fails
    store = new_store
    ask(store, :buy)

    assert_equal "failed", settled(store)["state"]
  end

  def test_restoring_nothing_says_so
    store = new_store
    open_it(store)
    ask(store, :restore)
    answer = settled(store)

    assert_equal "none", answer["state"]
    assert_equal "0", answer["owned"]
  end

  def test_restoring_what_was_bought_finds_it
    store = new_store
    open_it(store)
    ask(store, :buy)
    settled(store)
    ask(store, :restore)
    answer = settled(store)

    assert_equal "restored", answer["state"]
    assert_equal "1", answer["owned"]
  end

  def test_a_purchase_is_known_after_a_relaunch
    store = new_store
    open_it(store)
    ask(store, :buy)
    settled(store)

    assert_equal "1", open_it(relaunched(store))["owned"]
  end

  def test_removing_the_answer_leaves_none
    store = new_store
    open_it(store)
    store.remove

    assert_nil store.read
  end

  def test_going_wrong_buying_owns_nothing
    %w[failed cancelled pending].each do |outcome|
      store = new_store(fails: outcome)
      open_it(store)
      ask(store, :buy)
      answer = settled(store)

      assert_equal outcome, answer["state"]
      assert_equal "0", answer["owned"], outcome
    end
  end

  def test_going_wrong_restoring_says_how
    %w[failed cancelled].each do |outcome|
      store = new_store(fails: outcome)
      open_it(store)
      ask(store, :restore)

      assert_equal outcome, settled(store)["state"]
    end
  end

  def test_no_store_answering_gives_no_price
    store = new_store(fails: "unavailable")
    answer = open_it(store)

    assert_equal "unavailable", answer["state"]
    assert_empty answer["price"]
  end

  def test_a_request_the_system_will_not_take_is_refused
    refute new_store(fails: "refused").open(Storefront.url(:open, 1, "anywhere"))
  end

  # The port as the game drives it, through the Storefront above it.

  def test_through_the_storefront_buying_unlocks_and_restoring_finds_it
    store = new_store
    entitlement = DotPopper::Entitlement.test
    front = Storefront.new(port: store, entitlement:)
    front.connect
    settle(front) { front.price }

    assert_equal :ready, front.status
    refute_predicate entitlement, :pro?

    front.buy

    assert_equal :busy, front.status
    settle(front) { entitlement.pro? }

    assert_equal :ready, front.status

    again = DotPopper::Entitlement.test
    other = Storefront.new(port: relaunched(store), entitlement: again)
    refute_predicate again, :pro?, "nothing is kept: a relaunch asks the store"
    other.connect
    settle(other) { again.pro? }

    assert_predicate again, :pro?, "a relaunch sees what was bought"
  end

  def test_through_the_storefront_a_failure_is_said_and_unlocks_nothing
    store = new_store(fails: "failed")
    entitlement = DotPopper::Entitlement.test
    front = Storefront.new(port: store, entitlement:)
    front.connect
    settle(front) { front.price }
    front.buy
    settle(front) { front.status != :busy }

    assert_equal :failed, front.status
    refute_predicate entitlement, :pro?
  end

  private

  def ask(store, action)
    @number += 1
    store.open(Storefront.url(action, @number, store.path))
  end

  def open_it(store)
    ask(store, :open)
    settled(store)
  end

  def parse(text) = text&.lines&.to_h { it.chomp.split("=", 2).then { |name, value| [name, value.to_s] } }

  # Reads until the request in hand has its final answer.
  def settled(store)
    30.times do
      answer = parse(store.read)
      return answer if answer && answer["answer"].to_i == @number && !UNDER_WAY.include?(answer["state"])
    end
    flunk "no final answer to request #{@number}"
  end

  # Lets a Storefront read until the block is true.
  def settle(front)
    30.times do
      return if yield

      front.update(Storefront::EVERY)
    end
    flunk "the storefront never heard"
  end
end
