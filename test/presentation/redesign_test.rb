# frozen_string_literal: true

require_relative "presentation_helper"

# Home opens every other screen on purpose. The achievements a Free player
# sees say only how to earn them; Pro also sees the day and the progress.
class RedesignTest < Minitest::Test
  include PresentationTest

  # A store that has its price, and asks nothing.
  class Store
    def offered? = true
    def status = :ready
    def price = "$1.99"
    def connect = nil
    def buy = nil
    def restore = nil
    def keys? = false
    def sold? = true
    def paste = nil
    def update(_seconds) = nil
  end

  def show(pro: false, played: true)
    @sounds = FakeSounds.new
    @cabinet = DotPopper::Cabinet.new(field(1200, 800), random: Random.new(2))
    @book = DotPopper::StatsBook.new(DotPopper::ScoreRecord::Memory.new)
    @book.record(DotPopper::GameStats.start.with(most_dots_in_a_row: 19), DotPopper::SizeClass::MEDIUM) if played
    @earned = DotPopper::Achievements.new(DotPopper::ScoreRecord::Memory.new)
    new_show(cabinet: @cabinet, layout: layout(1200, 800), sounds: @sounds, radius: R, stats_book: @book, achievements: @earned,
             entitlement: pro ? DotPopper::Entitlement.new(forced: true) : DotPopper::Entitlement.free)
  end

  def middle(rect) = [rect.center_x, rect.center_y]

  # A Pro player's Game Over, ready for a press, with these lines.
  def game_over_with(**lines)
    s = show(pro: true)
    s.primary
    @cabinet.update(30)
    s.update(1.0)
    s.instance_variable_set(:@game_over, s.game_over.with(**lines))
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    s
  end

  def click(show, name)
    reach = show.reach_of(name)
    assert reach, "#{name} is offered"
    show.tap(reach.center_x, reach.center_y)
    show.let_go(:tap)
  end

  def test_home_opens_each_screen_and_back_returns
    s = show
    %i[stats achievements themes settings].each do |name|
      click(s, name)
      refute s.on_home?, "#{name} left Home"
      click(s, :back)
      assert s.on_home?, "#{name}'s Back returns Home"
    end
  end

  def test_a_first_launch_offers_only_play_and_settings_and_quit
    assert_equal %i[play settings], show(played: false).controls.map(&:name).sort
  end

  def test_settings_leads_to_credits_and_privacy_and_back_to_settings
    s = show
    click(s, :settings)
    click(s, :credits)
    assert s.credits?
    click(s, :back)
    assert s.settings?
    click(s, :privacy)
    assert s.privacy?
    click(s, :back)
    assert s.settings?
    click(s, :back)
    assert s.on_home?
  end

  def test_sound_is_set_in_settings
    s = show
    click(s, :settings)
    click(s, [:sound, false])
    assert @sounds.muted?
    click(s, [:sound, true])
    refute @sounds.muted?
  end

  def test_a_free_player_sees_how_to_earn_with_no_state_and_a_way_to_get_pro
    s = show
    @earned.award([:steady], day: "2026-11-03")
    click(s, :achievements)
    click(s, [:achievement, :steady])
    assert_equal :steady, s.dialog
    assert_nil s.dialog_status(:steady)
    assert_nil s.achievement_progress(:steady)
    refute s.achievement_earned?(:steady), "shown as not earned"
    assert_includes s.controls.map(&:name), :achievement_pro
  end

  def test_pro_sees_the_day_earned_while_free_and_the_progress_it_measures
    s = show(pro: true)
    @earned.award([:blink], day: "2026-11-03") # kept from Free play
    assert_equal "Earned November 3, 2026", s.dialog_status(:blink)
    assert_equal [19, 20], s.achievement_progress(:steady)
    assert_nil s.achievement_progress(:patience), "the game keeps no partial progress for it"
  end

  def test_a_gamepad_reaches_every_home_screen_by_its_button
    s = show
    { x: :stats, lb: :achievements, rb: :themes, select: :settings }.each do |button, page|
      s.pad(button)
      assert_equal page, s.page
      s.back
    end
  end

  # Only the mouse hovers, and on Home every button it offers lights
  # where a press reaches it.
  def test_home_hovers_its_buttons_and_only_for_the_mouse
    s = show
    s.controls.each do |control|
      s.pointer_at(control.frame.center_x, control.frame.center_y)
      assert_equal control.name, s.hovered
    end
    s.input = InputKind::TOUCH
    assert_nil s.hovered
  end

  # A Free player who taps a theme meets the offer over Themes, and Back
  # returns to Themes as it was; once Pro lands, the offer thanks them and
  # Buy goes.
  def test_a_free_tap_on_a_theme_opens_the_offer_over_themes_and_back_returns
    store = Store.new
    entitlement = DotPopper::Entitlement.test
    cabinet = DotPopper::Cabinet.new(field(1200, 800), random: Random.new(2))
    s = new_show(cabinet:, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R, entitlement:, storefront: store,
                 themes: DotPopper::Themes.new(DotPopper::ScoreRecord::Memory.new))
    s.open_themes
    s.use(s.themes.last)
    assert s.offer?
    assert_equal :themes, s.offer_focus
    assert_includes s.controls.map(&:name), :buy

    entitlement.prove(DotPopper::Receipt.issue)
    s.update(0.1)
    assert_equal Style::WORDS.offer[:thanks], s.offer_status
    refute_includes s.controls.map(&:name), :buy
    s.back
    assert s.themes?
  end

  # Game Over's line of a new achievement opens it, by a tap or by LB;
  # today's goal met opens nothing.
  def test_game_overs_new_achievement_opens_it_and_the_goal_opens_nothing
    [->(s) { s.tap(*middle(s.reach_of(:over_achievement))) }, ->(s) { s.pad(:lb) }].each do |press|
      s = game_over_with(achievements: [:blink], goal_met: true)
      assert_equal %i[over_goal over_achievement], s.game_over_chips.map(&:name)
      refute_includes s.controls.map(&:name), :over_goal
      press.call(s)
      assert s.achievements_open?
      assert_equal :blink, s.dialog
    end
  end

  def test_game_overs_play_again_starts_the_next_game_and_home_goes_home
    s = game_over_with
    assert_equal "Play again", s.game_over_screen.play_word
    s.tap(*middle(s.play_again_reach))
    assert s.playing?

    s = game_over_with
    s.tap(*middle(s.home_reach))
    assert s.on_home?
  end

  def test_the_controller_label_for_settings
    s = show
    s.input = InputKind::GAMEPAD
    assert_equal "Settings (Select)", s.words.settings
    assert_equal "Play (A)", s.play_word
  end
end
