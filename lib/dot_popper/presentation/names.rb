# frozen_string_literal: true

module DotPopper
  module Presentation
    # The names the game gives friend groups and their members, made here
    # from a group's id and a member's number as icons are (MemberIcon),
    # so everyone sees the same names and the server stores none. A group
    # reads plural and a member singular, from separate lists, so one is
    # never mistaken for the other: "Brave Puffins", "Purple Kiwi". The
    # words are a hand-picked subset of Ivan Malopinsky's wordlists (MIT;
    # assets/wordlists-LICENSE.txt): adjectives/character.txt with
    # nouns/birds.txt, and adjectives/colors.txt with nouns/fruit.txt.
    # Left out on purpose: unkind words, words with a second meaning, and
    # colors that also name skin tones; test/presentation/names_test.rb tries
    # every pair against a list of bad words.
    module Names
      ADJECTIVES = %w[adventurous affable amiable bold brave calm careful cheerful clever creative curious daring eager
                      elegant energetic friendly funny generous gentle graceful happy helpful honest humble inventive
                      kind loyal merry neat patient pleasant polite proud quick quiet silly smart strong warm wise
                      witty].freeze
      # Written out plural, so an irregular one is simply right.
      BIRDS = %w[albatrosses avocets budgies canaries chickadees doves ducks eagles falcons finches flamingos goldfinches
                 hawks herons jackdaws jays kestrels larks macaws magpies ospreys ostriches owls parakeets parrots
                 pelicans penguins pigeons puffins quails quetzals ravens skylarks sparrows starlings storks swifts
                 toucans warblers].freeze
      COLORS = %w[amber aquamarine azure blue burgundy celeste cerulean champagne chartreuse cobalt coral crimson cyan
                  emerald fuchsia gold gray green heather indigo lime magenta maroon mint navy orange pink plum purple
                  red salmon silver teal tomato violet yellow].freeze
      FRUIT = %w[apple apricot cantaloupe fig guava kiwi lemon mango melon mulberry nectarine peach pear pineapple
                 raspberry tangerine].freeze
      COMBINATIONS = COLORS.size * FRUIT.size
      STEPS = (11...COMBINATIONS).select { it.gcd(COMBINATIONS) == 1 }.freeze

      module_function

      # The name of the group with this id: "Brave Puffins".
      def group(group_id)
        seed = MemberIcon.seed("#{group_id}/group")
        "#{ADJECTIVES[seed % ADJECTIVES.size].capitalize} #{BIRDS[(seed >> 8) % BIRDS.size].capitalize}"
      end

      # The name of member +number+ of that group: "Purple Kiwi". Numbers
      # fewer than COMBINATIONS apart never share one, in a group.
      def member(group_id, number)
        seed = MemberIcon.seed("#{group_id}/member")
        at = ((seed % COMBINATIONS) + (STEPS[(seed >> 8) % STEPS.size] * number)) % COMBINATIONS
        "#{COLORS[at % COLORS.size].capitalize} #{FRUIT[at / COLORS.size].capitalize}"
      end
    end
  end
end
