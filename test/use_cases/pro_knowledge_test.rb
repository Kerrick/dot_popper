# frozen_string_literal: true

require_relative "../composition/fake_engine"

# The rules of play, the Metagame's objects and the screens never know
# that Pro exists (ADR-0017). Two guards, the first the one that holds:
#
# 1. The structure. The presentation is never handed what decides Pro
#    (Entitlement, FreeGames, the store and its license keys): only the
#    use cases that ask them, and only the offer of Pro holds the one for
#    buying it. An object that holds none of them cannot ask them,
#    however it is written. The game is walked as the composition root
#    builds it, from the Show through everything it holds, the screens,
#    the panels, and what each block and method it keeps can reach.
# 2. The names. Only Monetization's own code, the use cases and the
#    composition root name Pro's objects or ask "pro?".
#
# Neither sees an object reached through a constant or a global
# (ObjectSpace, Object.const_get with a name built at run time): the
# scan finds a constant named outright, and nothing finds one spelled
# at run time.
class ProKnowledgeTest < Minitest::Test
  include PresentationTest

  # What decides Pro, which only the use cases may hold, and the
  # composition root, which holds all of it.
  DECIDING = [DotPopper::Entitlement, DotPopper::FreeGames, DotPopper::Continuity::License, Storefront, NoStorefront, WebsiteStore,
              FakeStore, NativeStore, DotPopper::Composition::Root].freeze

  def test_the_presentation_holds_nothing_that_decides_pro_but_through_a_use_case
    show = game.show
    held = holdings(show)

    deciding = held.select { |object, _| DECIDING.any? { object.is_a?(it) } }
    assert_empty deciding.map { |object, owners| "#{object.class} in #{owners.map { |name, owner| "#{owner.class}'s #{name}" }}" },
                 "only a use case may hold what decides Pro"
    buy_pro = held.select { |object, _| object.is_a?(DotPopper::UseCases::BuyPro) }.values.flatten(1).map(&:last).uniq

    assert_equal [Screens::Offer], buy_pro.map(&:class), "only the offer of Pro holds BuyPro"
  end

  # The walk itself finds what it is meant to: a screen given the
  # Entitlement outright, or in a block it keeps.
  def test_the_walk_finds_an_entitlement_held_outright_or_in_a_block
    show = game.show
    entitlement = DotPopper::Entitlement.free
    show.screens[:home].instance_variable_set(:@entitlement, entitlement)
    show.screens[:stats].instance_variable_set(:@ask, -> { entitlement.pro? })

    owners = holdings(show).fetch(entitlement).map(&:last)
    assert_equal [show.screens[:home], show.screens[:stats].instance_variable_get(:@ask)], owners
  end

  KNOWS = %w[
    lib/dot_popper/composition/root.rb
    lib/dot_popper/composition/use_cases.rb
    lib/dot_popper/continuity/license.rb
    lib/dot_popper/entitlement.rb
    lib/dot_popper/fake_store.rb
    lib/dot_popper/free_games.rb
    lib/dot_popper/store.rb
    lib/dot_popper/use_cases/buy_pro.rb
    lib/dot_popper/use_cases/finish_game.rb
    lib/dot_popper/use_cases/join_or_create_friend_group.rb
    lib/dot_popper/use_cases/start_game.rb
    lib/dot_popper/use_cases/use_theme.rb
    lib/dot_popper/use_cases/view_achievements.rb
    lib/dot_popper/website_store.rb
  ].freeze

  # "pro?" with anything before it (has_pro?), or the Entitlement or the
  # free games by name in any case (@entitlement, free_games), in code or
  # in a comment; a line that only loads a file is not counted.
  NAMES = /pro\?|\bentitlement\b|\bfree_?games\b/i

  def test_only_monetization_the_use_cases_and_the_composition_root_name_pro
    root = File.expand_path("../..", __dir__)
    knowing = Dir["#{root}/lib/**/*.rb"].select { |path| File.foreach(path).any? { it.match?(NAMES) && !it.start_with?("require") } }
    knowing = knowing.map { it.delete_prefix("#{root}/") }

    assert_equal KNOWS, knowing.sort
  end

  private

  def game = DotPopper::Composition::Root.new(engine: FakeEngine.new("Windows"),
                                              settings: DotPopper::Composition::DeveloperSettings.new({ "DOT_POPPER_QUIT_AFTER" => "600" }))

  # Everything +from+ holds, and what that holds in turn, each with the
  # owners that reach it ([name, owner]): the presentation's objects'
  # instance variables, the items of arrays and hashes, the members of
  # values, and what a block or a method it keeps can reach (its receiver
  # and the variables it closes over). An object outside the presentation
  # (the Cabinet, the friend groups' Session, a use case) is a boundary:
  # what it holds is its own, and the walk notes it but goes no further.
  def holdings(from)
    held = Hash.new { |hash, key| hash[key] = [] }.compare_by_identity
    seen = {}.compare_by_identity
    queue = [from]
    until queue.empty?
      owner = queue.shift
      next if seen[owner]

      seen[owner] = true
      parts(owner).each do |name, part|
        next if SCALARS.any? { part.is_a?(it) }

        held[part] << [name, owner]
        queue << part if walked?(part)
      end
    end
    held
  end

  # What holds nothing worth walking into.
  SCALARS = [NilClass, TrueClass, FalseClass, Numeric, String, Symbol, Module, Range, Regexp, Encoding, Random, Time, Date].freeze

  def walked?(object)
    [Array, Hash, Proc, Method, Data, Struct].any? { object.is_a?(it) } ||
      (object.class.name.to_s.start_with?("DotPopper::Presentation::") && DECIDING.none? { object.is_a?(it) })
  end

  def parts(object)
    case object
    when Array then object.each_with_index.map { |item, at| [at, item] }
    when Hash then object.flat_map { |key, value| [[:key, key], [key, value]] }
    when Proc then closed_over(object)
    when Method, UnboundMethod then [[:receiver, (object.receiver if object.is_a?(Method))]]
    when Data then Data.instance_method(:to_h).bind_call(object).to_a + ivars(object)
    when Struct then object.each_pair.to_a + ivars(object)
    else ivars(object)
    end
  end

  def ivars(object) = object.instance_variables.map { [it, object.instance_variable_get(it)] }

  def closed_over(block)
    binding = block.binding
    [[:self, binding.receiver], *binding.local_variables.map { [it, binding.local_variable_get(it)] }]
  rescue ArgumentError # a block made from a method: no binding of its own
    []
  end
end
