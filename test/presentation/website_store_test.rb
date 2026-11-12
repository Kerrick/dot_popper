# frozen_string_literal: true

require_relative "presentation_helper"

# Selling Pro to copies no store controls: Buy reaches a checkout, Paste
# license key enters the key, and while setdef is gone Pro is no longer
# sold, and Change Server appears. Played through the Show, with the test
# build's fake checkout.
class WebsiteStoreTest < Minitest::Test
  include PresentationTest

  C = DotPopper::Continuity
  Memory = DotPopper::ScoreRecord::Memory

  def setup
    @clipboard = MemoryClipboard.new
    @gone_store = Memory.new
    @gone = C::Gone.new(@gone_store)
    @license = C::License.new(Memory.new, pins: C::TEST_PINS)
    @entitlement = DotPopper::Entitlement.new(license: @license)
    @entered = 0
    @store = WebsiteStore.new(checkout: FakeCheckout.new(clipboard: @clipboard), license: @license, gone: @gone, clipboard: @clipboard,
                              entered: -> { @entered += 1 })
    @choice = ServerChoice.new(Memory.new, gone: @gone, clipboard: @clipboard)
  end

  def show
    cabinet = DotPopper::Cabinet.new(field(1200, 800), random: Random.new(2))
    book = DotPopper::StatsBook.new(Memory.new)
    book.record(DotPopper::GameStats.start, DotPopper::SizeClass::MEDIUM)
    Show.new(cabinet:, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R, stats_book: book, clipboard: @clipboard,
             entitlement: @entitlement, storefront: @store, server_choice: @choice)
  end

  def click(show, name)
    reach = show.reach_of(name)
    assert reach, "#{name} is offered"
    show.tap(reach.center_x, reach.center_y)
    show.let_go(:tap)
  end

  def names(show) = show.controls.map(&:name)

  def test_the_offer_has_buy_and_paste_license_key_and_no_restore
    s = show
    s.open_offer

    assert_equal %i[back buy paste], names(s).sort
    assert_equal "Buy for $1.99", format(s.words.offer[:buy], s.offer_price)
  end

  # Enter, Space, Start, Escape, B and the tap-less A mean "continue" or
  # "back" elsewhere, so a purchase never starts from them: they close the
  # offer. Buy keeps its own control for each input that can complete a
  # purchase alone.
  def test_no_press_that_means_continue_or_back_buys
    s = show
    [-> { s.primary }, -> { s.start }, -> { s.back }].each do |press|
      s.open_offer
      press.call

      refute s.offer?
      assert_empty s.offer_status.to_s
    end
  end

  def test_a_tap_or_a_click_on_buy_buys
    s = show
    s.open_offer
    click(s, :buy)

    assert_equal s.words.offer[:copied], s.offer_status
  end

  def test_a_controllers_y_buys_and_the_button_says_so
    s = show
    s.input = InputKind::GAMEPAD
    s.open_offer

    assert_equal "Buy for $1.99 (Y)", s.buy_label
    s.pad(:y)

    assert_equal s.words.offer[:copied], s.offer_status
  end

  def test_the_keyboards_buy_shortcut_buys_only_on_the_offer
    s = show

    refute s.buy_shortcut
    s.open_offer

    assert s.buy_shortcut
    assert_equal s.words.offer[:copied], s.offer_status
  end

  def test_the_buy_label_names_the_keyboards_key_until_a_pointer_or_controller_is_used
    s = show
    s.open_offer
    s.keyboard_used("Ctrl+B")

    assert_equal "Buy for $1.99 (Ctrl+B)", s.buy_label
    s.keyboard_used("\u2318B")

    assert_equal "Buy for $1.99 (\u2318B)", s.buy_label
    s.input = InputKind::MOUSE

    assert_equal "Buy for $1.99", s.buy_label
    s.keyboard_used("Ctrl+B")
    s.input = InputKind::GAMEPAD

    assert_equal "Buy for $1.99 (Y)", s.buy_label
  end

  def test_the_buy_label_has_no_controller_button_for_a_finger_or_mouse
    s = show
    s.open_offer

    assert_equal "Buy for $1.99", s.buy_label
  end

  def test_buy_then_paste_license_key_makes_the_player_pro
    s = show
    s.open_offer
    click(s, :buy)

    assert_equal s.words.offer[:copied], s.offer_status
    refute s.pro?
    click(s, :paste)

    assert s.pro?
    assert_equal 1, @entered
    assert_equal s.words.offer[:thanks], s.offer_status
    assert_equal %i[back], names(s)
  end

  def test_the_keyboards_paste_takes_the_key_too
    s = show
    @clipboard.copy(C::LicenseKey.issue(C::TestKeys::LICENSE).text)

    refute s.paste_shortcut, "nothing to paste into on Home"
    s.open_offer

    assert s.paste_shortcut
    assert s.pro?
  end

  def test_a_keyboard_types_the_key_ignoring_case_spaces_and_hyphens
    s = show
    s.open_offer
    text = C::LicenseKey.issue(C::TestKeys::LICENSE).text
    refute s.type_key(:return), "Enter with nothing typed is the button's"
    text.each_char do |c|
      next if c == " "

      assert s.type_key(c == "-" ? :minus : c.downcase.to_sym), c
    end
    assert_equal "#{s.words.offer[:typing]} …#{text.upcase[-24..]}", s.offer_status
    refute s.pro?
    s.type_key(:backspace)
    s.type_key(text[-1].downcase.to_sym)
    assert s.type_key(:return)
    assert s.pro?
  end

  def test_typing_does_nothing_on_other_screens
    s = show

    refute s.type_key(:a)
  end

  def test_paste_says_what_was_wrong_and_changes_nothing
    s = show
    s.open_offer
    click(s, :paste)

    assert_equal s.words.offer[:empty], s.offer_status
    @clipboard.copy("my shopping list")
    click(s, :paste)

    assert_equal s.words.offer[:invalid], s.offer_status
    @clipboard.copy(C::LicenseKey.issue(C::TestKeys::ONLINE).text)
    click(s, :paste)

    assert_equal s.words.offer[:invalid], s.offer_status
    refute s.pro?
  end

  def test_while_setdef_is_gone_buy_goes_and_the_offer_says_pro_is_no_longer_sold
    @gone.heard(:gone, Date.new(2027, 1, 1))
    s = show
    s.open_offer

    assert_equal %i[back paste], names(s).sort
    assert_equal s.words.offer[:not_sold], s.offer_status
    assert_nil s.offer_price
    @clipboard.copy(C::LicenseKey.issue(C::TestKeys::LICENSE).text)
    click(s, :paste)

    assert s.pro?, "a key bought before still works"
  end

  def test_a_stores_copy_never_shows_paste_license_key
    s = Show.new(cabinet: DotPopper::Cabinet.new(field(1200, 800)), layout: layout(1200, 800), sounds: FakeSounds.new, radius: R,
                 storefront: Storefront.new(port: FakeStore.new(Memory.new), entitlement: DotPopper::Entitlement.free))
    s.open_offer

    refute_includes names(s), :paste
    assert_includes names(s), :restore
    refute s.paste_shortcut
  end

  def test_storefront_for_gives_computers_the_website_and_never_ios
    made = []
    website = ->(fake:) { made << fake && :website }
    args = { native: :native_port, fake: FakeStore.new(Memory.new), entitlement: DotPopper::Entitlement.free, website: }

    assert_equal :website, Storefront.for("Linux", **args, channel: nil)
    assert_kind_of Storefront, Storefront.for("Android", **args, channel: nil)
    assert_equal :website, Storefront.for("Windows", **args, channel: Storefront::WEBSITE)
    assert_equal :website, Storefront.for("Android", **args, channel: Storefront::WEBSITE)
    refute_equal :website, Storefront.for("iOS", **args, channel: Storefront::WEBSITE)
    assert_equal [true, false, false], made
  end

  def test_change_server_appears_only_while_setdef_is_gone
    s = show
    click(s, :settings)

    refute_includes names(s), :server
    @gone.heard(:gone, Date.new(2027, 1, 1))
    click(s, :server)

    assert s.server?
    @clipboard.copy("http://example.com")
    click(s, :server_paste)

    assert_equal :not_https, @choice.status
    assert_nil @choice.address
    @clipboard.copy(" https://groups.example.org \n")
    click(s, :server_paste)

    assert_equal "https://groups.example.org", @choice.address
    assert_equal "https://groups.example.org", @choice.server_url("https://server.dot-popper.setdef.com")
    assert_includes names(s), :server_reset
    click(s, :back)

    assert s.settings?
  end

  def test_when_setdef_answers_again_change_server_goes_and_setdefs_server_is_used
    @gone.heard(:gone, Date.new(2027, 1, 1))
    @clipboard.copy("https://groups.example.org")
    @choice.paste
    @gone.heard(:here, Date.new(2027, 2, 1))
    own = "https://server.dot-popper.setdef.com"

    assert_equal own, @choice.server_url(own)
    @choice.forget

    assert_nil @choice.address
  end

  def test_a_server_address_must_be_one_https_address
    ["https://a.example", "https://a.example:8443/api"].each { assert ServerChoice.https?(it), it }
    ["http://a.example", "https://", "https://u:p@a.example", "https://a.example b", "ftp://a.example", "a.example"].each { refute ServerChoice.https?(it), it }
  end

  def test_themes_open_by_their_dates_only_once_setdef_has_been_gone_180_days
    keeper = ThemeKeeper.new(Memory.new, themes: Style::THEMES, entitlement: DotPopper::Entitlement.free)
    today = Date.new(2027, 6, 1)

    refute keeper.open_by_date(today, 179)
    assert_equal [:classic], keeper.choices.map(&:key)
    assert keeper.open_by_date(today, 180)
    assert_equal %i[ghost gingerbread jack_o_lantern jingle_bell ornament peppermint pumpkin_pie santa snowman turkey], keeper.choices.reject(&:ordinary?).map(&:key).sort
    assert keeper.open_by_date(Date.new(2027, 10, 1), 400)
    assert_equal Style::THEMES.size, keeper.choices.size
  end
end
