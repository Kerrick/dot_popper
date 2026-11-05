# frozen_string_literal: true

module DotPopper
  # A fresh dot as Spawner drew it, and how many draws it took: how many
  # times its velocity was drawn again, and then its place and velocity
  # together. +exposed+ is false only when every try failed and the last
  # draw was kept anyway.
  class Spawn < Data.define(:dot, :velocity_redraws, :position_redraws, :exposed)
    def initialize(dot:, velocity_redraws: 0, position_redraws: 0, exposed: true) = super

    def redrawn? = velocity_redraws.positive?
    def moved? = position_redraws.positive?
    def exhausted? = !exposed
  end
end
