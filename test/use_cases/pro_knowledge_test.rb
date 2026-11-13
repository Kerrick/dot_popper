# frozen_string_literal: true

require "test_helper"

# The rules of play and the Metagame's objects never know that Pro exists
# (ADR-0017): only Monetization's own code, the use cases, the offer of
# Pro on screen, and the composition root that wires them name it.
class ProKnowledgeTest < Minitest::Test
  KNOWS = %w[
    lib/dot_popper/composition/root.rb
    lib/dot_popper/continuity/license.rb
    lib/dot_popper/entitlement.rb
    lib/dot_popper/free_games.rb
    lib/dot_popper/presentation/fake_store.rb
    lib/dot_popper/presentation/screens/offer.rb
    lib/dot_popper/presentation/show.rb
    lib/dot_popper/presentation/storefront.rb
    lib/dot_popper/presentation/website_store.rb
    lib/dot_popper/use_cases/buy_pro.rb
    lib/dot_popper/use_cases/finish_game.rb
    lib/dot_popper/use_cases/join_friend_group.rb
    lib/dot_popper/use_cases/use_theme.rb
    lib/dot_popper/use_cases/view_achievements.rb
  ].freeze

  def test_only_monetization_the_use_cases_and_the_offer_name_pro
    root = File.expand_path("../..", __dir__)
    knowing = Dir["#{root}/lib/**/*.rb"].select { File.read(it).match?(/\bpro\?|\bEntitlement\b/) }.map { it.delete_prefix("#{root}/") }

    assert_equal KNOWS, knowing.sort
  end
end
