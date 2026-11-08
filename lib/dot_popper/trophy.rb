# frozen_string_literal: true

module DotPopper
  # A friend group's one trophy: who holds it, the score that took it, and
  # the day it was taken. The game's server and its tests both use this
  # file, so the rules live in one place; the server is the one that
  # decides, and the game only shows what it answers.
  #
  # The holder's score falls by FALL_PER_DAY each day until someone beats
  # it, so one freak round can never end the contest. A holder's own
  # rounds change nothing: the trophy only ever moves to someone else, and
  # nobody has to play to defend it (doc/decisions.md). A day is a whole
  # UTC day (+Trophy.day+), the same one for every member.
  class Trophy < Data.define(:holder, :score, :day)
    FALL_PER_DAY = 1
    LOWEST_STANDING = 0
    SECONDS_A_DAY = 86_400

    # A trophy nobody holds yet, which any round that scores takes.
    def self.vacant = new(holder: nil, score: 0, day: 0)

    # The day number of +time+ (seconds since the epoch, or anything that
    # answers to_i).
    def self.day(time) = time.to_i / SECONDS_A_DAY

    # Whether a round counts toward a trophy: only rounds with dots sized
    # to the screen do, so a loss is fair between a phone and a monitor.
    def self.counts?(sized_to_screen:) = sized_to_screen == true

    def vacant? = holder.nil?

    # How many whole days the holder's score has been falling by +today+.
    def days_held(today) = vacant? ? 0 : [today - day, 0].max

    # The score to beat on +today+.
    def standing(today)
      return LOWEST_STANDING if vacant?

      [score - (FALL_PER_DAY * days_held(today)), LOWEST_STANDING].max
    end

    # Whether +player+ scoring +points+ on +today+ takes the trophy.
    def beaten_by?(player, points, today)
      player != holder && points > standing(today)
    end

    # The trophy after +player+ took it with +points+ on +today+.
    def taken_by(player, points, today) = with(holder: player, score: points, day: today)
  end
end
