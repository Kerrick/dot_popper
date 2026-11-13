<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# Progress: Stats, records, the daily goal and achievements

What Dot Popper keeps about a player's games, and how: the games log, Stats, records and size classes, the daily goal and its streak, achievements, and clearing Stats. It is for anyone changing what is counted, saved or shown about past games. The keeping is Lota-free, in `lib/dot_popper/*.rb`; what the screens say is in `lib/dot_popper/presentation/`, and how the screens look is in [screens.md](screens.md).

## Saved files

Every file lives in Lota's save folder (paths per system are in [README.md](../../README.md)), is read and written through a store that answers `read` and `write(text)` (`Shell::SaveFile` in the game, `ScoreRecord::Memory` in tests), and is declared in [doc/privacy.json](../privacy.json) ([privacy.md](privacy.md)). Every file here is read leniently: a line that can't be read keeps its starting value, so a damaged or missing file costs some numbers, never the game.

| File | Holds | Class |
| --- | --- | --- |
| `score_record.txt` | the highest score of each size class, as `class=score` lines | `ScoreRecord` |
| `stats.txt` | totals, the last 20 scores, the goal streak, each class's records, as `key=value` lines | `StatsBook`, `Stats` |
| `achievements.txt` | each achievement earned and the day, as `id=YYYY-MM-DD` lines | `Achievements` |
| `games.csv` | one line per finished game | `PlaytestLog` |
| `games-YYYYMMDD-HHMMSS.csv` | an older log, kept whole when its columns changed | `PlaytestLog` |
| `score_record-…`, `stats-…`, `achievements-YYYYMMDD-HHMMSS.txt` | the backup made by the last clearing | `StatsKeeper` |
| `cleared.txt` | when Stats were last cleared, and the backups' names | `StatsKeeper` |

The composition root (`Composition::Root`) makes each store, asking the engine for a save file by name (`Shell::Engine#file`, a `Shell::SaveFile`). Lota's save folder can neither rename nor append to a file, so every store is rewritten whole, and "keeping a file whole" means writing a copy.

## The games log

`PlaytestLog` (`lib/dot_popper/playtest_log.rb`) listens to the `Cabinet` and adds one line to `games.csv` for each finished game (`Events::GameEnded`). Its columns, `PlaytestLog::COLUMNS`:

`time seed score duration pops mistakes softened mean_time_to_pop longest_time_to_pop goal goal_met`

`time` is ISO 8601; `seed` is the game's ([rules.md](rules.md#seeds)), so any game can be replayed; times are in seconds to two places; `softened` counts the mistakes the score floor softened; `goal` is the day's goal as `DailyGoal#to_s` names it (`clean_run_15`), and `goal_met` whether this game met it. A game still in play is not logged.

**A header change.** When the log's first line is not the current header, because an older version wrote it, the old log is copied whole to `games-YYYYMMDD-HHMMSS.csv` and a new `games.csv` starts under the current header. A CSV whose rows disagree with its header would mislead anyone comparing playtests, and keeping the old file loses nothing.

The log is rewritten whole each time, which is fine for the few hundred lines a playtest makes. The game prints the log's path at launch. Clearing Stats never touches it. Tests: `test/playtest_log_test.rb`.

## One game's numbers: `GameStats`

`GameStats` (`lib/dot_popper/game_stats.rb`) is built from the rules' events by `GameStats::Recorder`, and decides nothing. It counts dots popped, mistakes, softened mistakes, each pop's time to pop (from the bright dot appearing to its pop), the game's duration (`Game#elapsed`, clock time only, as `Events::GameEnded#elapsed` carries it), the score, `dots_in_a_row` and `most_dots_in_a_row`, and `bonuses`. From these it gives `longest_time_to_pop`, `shortest_time_to_pop`, `mean_time_to_pop` and `dots_popped_within(seconds)`.

A game the tutorial played over (`GameStats.opening`) begins play with a pop for each of its popped dots, its score, and its dots in a row (1 at the tutorial's end); those dots have no time to pop, and the guide's mistake is not counted. `AchievementRecorder` starts the game's row at the same count. It is the same whether the tutorial ended or was skipped.

## Stats

`Stats` (`lib/dot_popper/stats.rb`) is every game this device has played, added up. `StatsBook` (`lib/dot_popper/stats_book.rb`) keeps it in `stats.txt` and adds each finished game (`StatsBook#record`, called as the game is finished, `UseCases::FinishGame`).

Across every screen:

- **Totals:** games, dots popped, mistakes, seconds played, and days played (distinct local dates, counted by `last_day`).
- **The last 20 scores** (`Stats::RECENT`), oldest first, each with the size class it was played in (`recent_classes`, saved as `recent_classes=?,medium,fitted`; `?` is a class not known).
- **The daily goal's streak** (`GoalStreak`), below.

For each size class, `Stats::RecordSet`:

| Record | Key | On screen |
| --- | --- | --- |
| Games played in the class | `games` | (not shown) |
| The longest game | `longest_game` | Longest game |
| The most dots in a row without a mistake | `most_dots_in_a_row` | Most dots in a row without a mistake |
| The shortest time to pop | `shortest_time_to_pop` | Shortest Time to Pop |
| The longest time to pop | `longest_time_to_pop` | Longest Time to Pop |

A class's records are saved under its name: `medium.most_dots_in_a_row=18`.

**The highest score** is not in `Stats`. It stays in `ScoreRecord` (`score_record.txt`), because the rules read it to decide a new record, and one number should have one home.

Why keep all this: a player who comes back wants to see that they are improving, and a single highest score hides most of that.

**Older files.** A `score_record.txt` holding one bare number, or a `stats.txt` whose records have no class name, gives those records to the class of the screen the game opens on (`legacy:`, `SizeClass.of(screen)` in `Composition::Root`), and is saved again in the new form at once, so they stay in that class whichever screen the game opens on next.

Tests: `test/stats_test.rb`, `test/stats_book_test.rb`, `test/score_record_test.rb`, `test/game_stats_test.rb`.

## Size classes

A game's records count only among games of its size class (`SizeClass`, `lib/dot_popper/size_class.rb`), the class of the screen it started on. A game keeps its class if the window changes size during it.

| Class | Which games | Rule |
| --- | --- | --- |
| `SizeClass::FITTED` | every game with standard dots | `DotSizing#size_class` |
| `SizeClass::SMALL` | the fixed size, field under 250 R² | `Rules::SMALL_FIELD_BELOW` |
| `SizeClass::MEDIUM` | the fixed size, 250 to under 700 R² | |
| `SizeClass::LARGE` | the fixed size, 700 R² or more | `Rules::LARGE_FIELD_FROM` |

With the fixed size an upright phone is 134 R² (small), an 11-inch iPad, a 13-inch iPad Pro and the 24 × 16 R desktop window are 384 to 566 (medium), and a big monitor full screen is 1,475 to 2,035 (large). The cut-offs sit in the wide gaps between those devices, so a window resized a little stays in its class. Games with standard dots are one class, since their field is about as crowded on any screen ([rules.md](rules.md#dot-size-standard-and-bigger-or-smaller)). The class names saved in `score_record.txt` and `stats.txt` (`fitted`, `small`, `medium`, `large`) never change, since builds in players' hands wrote them.

**Why.** The same model player scores about 6 on a phone, 21 to 24 on a tablet or the desktop window, and 77 on a 6K monitor with the fixed size ([rules.md](rules.md#how-crowded-the-field-gets)). Comparing those would tell a phone player they are bad at the game when the screen is the cause; Juul (*The Art of Failure*) holds that a failure should feel like the player's own, which is only fair when the comparison is. The totals, the chart and the streak stay across every class because they describe how much and how often someone plays, which isn't a contest.

The Stats screen shows the records of the class a game started now would count in (`Cabinet#size_class`): the current dot size on the current screen.

## Game Over and records

**The highest score.** `ScoreRecord#record(score, size_class)` keeps the score if it is higher than the class's, and says whether it beat it. A class's first game sets the class's highest score, even at 0, but is never a new record, since there was nothing to beat (`ScoreRecord#first?`; `Events::GameEnded#first`). Its Game Over says only "Your record: 18", with no "New record!", celebration or fanfare, and the shared result claims neither a new record nor a tie. Praising a first game praises what the player didn't earn and cheapens the next real "New record!" (Juul, *The Art of Failure*; Hodent, *The Gamer's Brain*; Podmajersky, *Strategic Writing for UX*); the maintainer chose the plain line, since it is true and sets the target for next time.

Otherwise Game Over says "New record!", or how the score compares (`Words#short_of_score_record`): "Just 2 points short of your record of 27" within 3 points (`Words::CLOSE_TO_SCORE_RECORD`), "Your record is 27" further off, or "You tied your record of 27".

**The other records.** `Stats#records_set_by(stats, size_class)` lists the records a game beat in its class, most impressive first, in `Stats::Record::ORDER`:

1. most dots in a row without a mistake,
2. the longest game,
3. the longest time to pop,
4. the shortest time to pop.

Game Over names only the first, once the score has counted up, in the gain color: "New record: 18 dots in a row without a mistake" (`Words#record`). The share text puts the same line under the score. The order puts skill before luck: a long row without a mistake is the patience the game asks for, and it is what makes a game last; a fast pop mostly means a dot appeared in the open. One line keeps the screen quiet.

A class's first game sets no record. Neither does a game that only equals a record as the game shows it: a game's length counts in whole seconds, a time to pop in tenths, so "New record" always shows a bigger number than before. A record must also beat something more than nothing.

## The Stats chart

The Stats screen's chart shows the last 20 scores as bars, oldest on the left, in 20 places of equal width so it fills up as games are played (`Presentation::ScoreBars`). Bars share one scale, the highest score shown; a 0 still shows a one-pixel stub. The highest bar among the games that count toward the records shown is brighter; on a tie, the latest.

A bar from a game outside the class whose records are shown is drawn at 30% (`Shell::StatsPainter::DIM`), keeps its true height, and is never the brighter one. When any bar is dimmed, a line under the chart says which bars count (`Words#chart_note`): "Brighter bars are games that count here." The line over the cards names the dot size where Settings does ("Stats for bigger dots"), so this line need not, and it fits across the narrowest card (Strunk & White: omit needless words) Scores whose class is unknown are dimmed too. Dimming keeps the history visible while showing which games the records compare (Ferrara, *Playful Design*; Garfield, *Characteristics of Games*: honest feedback).

The rest of the Stats screen's layout (`StatsSheet`, `StatsLayout`) is in [screens.md](screens.md). Tests: `test/presentation/stats_test.rb`.

## The daily goal and its streak

**The goal.** Each local date picks one goal from `DailyGoal::LIST` (`lib/dot_popper/daily_goal.rb`), by a 32-bit FNV-1a hash of the ISO date (`DailyGoal.fnv("2026-11-05")`) modulo the list's length, so the goal is the same all day, on every device and in every run. (Ruby's `String#hash` changes from run to run.) Changing the hash, or the list's order or length, changes which goal every date gets. `DOT_POPPER_TODAY` pretends a date, for testing.

A goal is met within one game, judged from that game's `GameStats` when it ends (`DailyGoal#met?`):

| Kind | Target | Met when | Home says |
| --- | ---: | --- | --- |
| `clean_run` | 15 | `most_dots_in_a_row` ≥ 15 | Pop 15 bright dots in a row without a mistake. |
| `patient_pop` | 3 | `longest_time_to_pop` ≥ 3 s | Pop a bright dot that has been on screen for at least 3 seconds. |
| `quick_start` | 10 | 10 dots popped within the first 10 s (`QUICK_START_SECONDS`) | Pop 10 bright dots in the first 10 seconds of a game. |
| `long_game` | 50 | duration ≥ 50 s | Keep one game going for 50 seconds. |
| `comeback` | 30 | at least one mistake, and score ≥ 30 | Finish a game with 30 points even after a mistake. |
| `score` | 30 | score ≥ 30 | Score 30 points in one game. |
| `clean_game` | 10 | no mistake, and score ≥ 10 | Score 10 points in a game without a single mistake. |

The words are `goals:` in `Style::WORDS`. A bonus pop is a pop.

**Why these.** A goal judged only against the player's own game needs no shared screen, so it is as fair on a phone as on a monitor. Most goals reward the game's real skill, patience, rather than a surface reward (Ferrara, *Playful Design*). The one speed goal applies while the field is nearly empty, so it doesn't invite mistakes. Three seconds of patience is a deliberate test: the model player almost never waits that long, but a person can choose to.

**How the targets were set** (measured, with the simulator's model player on the 24 × 16 R window). The bonus dot lengthens games and raises scores, so the three targets that count time or points were raised to 50 s, 30 points and a comeback of 30. With the bonus dot, those were met by 14%, 49% and 49% of the model's games. The model taps fast and makes many mistakes, so its figures for the goals without a mistake mean little; 10 points without a mistake is a modest game for a careful player.

**When the goal is met.** `StatsBook#record` says `goal_met` for the first game of the day to meet it; Game Over shows "You met today's goal!" with a check, once. Home's goal card shows "Today's goal", the sentence, and a check once it is met (`StatsBook#goal_done?`).

**The streak** (`GoalStreak`, `lib/dot_popper/goal_streak.rb`) is the days in a row the goal was met: `current`, `longest`, and `last_met`, saved in `stats.txt` as `goal_streak`, `longest_goal_streak` and `goal_met_on`. Meeting the goal again the same day changes nothing. Meeting it the day after `last_met` adds one; any later day starts again at 1. `GoalStreak#current_on(today)` is the streak as it stands: still whole through the day after it was last met, and 0 once a day has gone by without it. `longest` keeps.

Home's goal card shows the current streak beside the goal, as a number over "days in a row"; the Stats screen shows "Days in a row" and "Most days in a row". A missed day costs nothing and is never mentioned, because a reward for coming back can crowd out the reason to play (Nguyen, *Games: Agency as Art*), and a failure should feel fair (Juul).

Home shows the goal card only once a game has finished, or Stats have been cleared (below), so a first-time player's Home says only how to play. On the smallest windows the card is left out; Stats shows the streak too.

Tests: `test/daily_goal_test.rb`, `test/goal_streak_test.rb`, `test/stats_book_test.rb`.

## Achievements

Eleven goals, each earned once, each for skill and none for time spent (Ferrara, *Playful Design*; Nguyen, *Games: Agency as Art*). Their numbers are in `Achievement` (`lib/dot_popper/achievement.rb`), apart from the rules, which they never touch. `Achievement::IDS` is the order they are listed in.

| Id | Name | Earned by | Constants |
| --- | --- | --- | --- |
| `sharpshooter` | Sharpshooter | a pop with under 10% of the dot showing | `SHARP` 0.10 |
| `sharp_trio` | Sharp trio | three dots popped in one game, each with under 25% showing | `SHARP_TRIO` 3, `SHARP_TRIO_BELOW` 0.25 |
| `patience` | Patience | a dot that spawned with no room for a touch target, waited for at least 3 s with no tap at all, then popped | `PATIENCE` 3.0 |
| `blink` | Blink | a pop within 0.4 s of the pop before (never a game's first) | `BLINK` 0.4 |
| `steady` | Steady hand | 20 dots in a row without a mistake | `STEADY` 20 |
| `unshaken` | Unshaken | 40 dots in a row without a mistake | `UNSHAKEN` 40 |
| `shake_off` | Shake it off | 10 dots in a row after a mistake | `SHAKE_OFF` 10 |
| `comeback` | Back from the brink | the clock at 2 s or less, then back to 10 s or more | `BRINK` 2.0, `BACK` 10.0 |
| `fast_start` | Fast start | 15 dots popped within a game's first 10 s | `FAST_START` 15, `FAST_START_SECONDS` 10.0 |
| `big_score` | Big score | a score of 75 | `BIG_SCORE` 75 |
| `long_haul` | Long haul | a game of 90 s | `LONG_HAUL` 90.0 |

Names, figures and sentences are in `Presentation::AchievementWords`. Each has a short figure ("<10%", "3 × <25%", "20") so none needs its sentence read.

**Sharpshooter's 10%** was measured with `Visibility`, the share of a dot's disc no dot above it covers (400 sample points in a sunflower spiral, within about half a percent). With the real rules, a model player that taps the moment a fingertip-sized (44-unit) target fits pops with 31% to 50% showing, never under 10%; one that taps any sliver, which no person can aim, does so on over half the dots it pops. Under a tenth is a crescent a few units wide: a deliberate tap. The other thresholds were set against a model player of about 0.5 s a pop that never loses, and are constants in `Achievement`.

**Detection** is Lota-free. `AchievementRecorder` (`lib/dot_popper/achievement_recorder.rb`), which `UseCases::FinishGame` keeps, listens to the `Cabinet`'s events and reads the dots, the clock and the time played from each event, which carries them as they stood when it was told; it keeps no game, and decides nothing. A "covered" spawn for Patience is one where `TouchTarget#clear_on?` finds no room among the dots above, and any tap, a miss included, spoils the wait.

**Saving.** At each Game Over, `UseCases::FinishGame` gives the recorder's finds to `Achievements#award`, which keeps the ones not earned before with today's date and writes `achievements.txt`. Achievements are earned and saved whether or not the player has Pro. An id a newer version saved and this one doesn't know is dropped on reading.

**Showing.** Nothing shows during a game. For a Pro player, Game Over adds "New achievement: Sharpshooter" (or "New achievements: …") for the ones first earned that game, and friend groups hear of them. A Free player sees how each is earned on the Achievements screen but no earned marks, dates, count or progress; what they earned is kept, shown once Pro is bought, and then reported to their friend groups. What the screen may show is `UseCases::ViewAchievements`'s to say (`#earned?`, `#day`, `#count`, `#progress`, all held back while `#locked?`), so the `Show` and the painters only draw it. See [store-and-pro.md](store-and-pro.md) and [screens.md](screens.md).

Tests: `test/achievement_recorder_test.rb`, `test/achievements_test.rb`, `test/visibility_test.rb`, `test/presentation/achievements_test.rb`.

## Clearing Stats

The Stats screen has **Clear my stats…**, offered while there is something to clear and no Undo is offered (`Show#clear_offered?`). It clears only once held for 2 s (`Style::STATS_CLEAR`, a `ClearStyle` of hold 2.0, undo 10.0, hint 2.5; `HoldToConfirm`).

- While it is held, a bar fills and the prompt reads "Keep holding to clear your records, totals, chart, achievements, and streak."
- Let go sooner, and nothing happens; "Press and hold to clear…" stays for 2.5 s.
- A gamepad holds Y, or A with the cursor on it, and the words name the button held.
- Going back, or the window losing focus, stops the hold (`Show#let_go_of_everything`), since a release may never be heard. Another finger letting go does not.
- Once cleared, "Stats cleared." and **Undo** take the corner for 10 s (`UndoOffer`). Gamepad Y presses Undo. Starting a game ends the offer, because undoing after it would lose that game.

Forgiveness, from Lidwell's *Universal Principles of Design*: an Undo serves the player better than a confirmation they learn to dismiss, and a held press is hard to make by accident yet the same with a finger, a mouse or a gamepad. The control is quiet because records aren't the point of the game (Ferrara).

**What clears.** `StatsKeeper` (`lib/dot_popper/stats_keeper.rb`) clears the three stores that are records: `ScoreRecord`, `StatsBook` and `Achievements`. That is every class's highest score and records, the totals, the chart, the goal streaks and today's goal met, and every achievement earned. Achievements are records of what the player did, as a highest score is. Nothing else is touched: the games log, the settings (`dot_size.txt`, `sound.txt`), what the game has taught, themes, friend groups, free games and Pro stay as they are.

**Backup.** Before emptying anything, `StatsKeeper#clear` copies each store's text exactly to `<name>-YYYYMMDD-HHMMSS.txt` (`score_record-…`, `stats-…`, `achievements-…`) and notes them in `cleared.txt` (`cleared=<time>`, then `score_record.txt=score_record-….txt` and so on). The next clearing first removes the backups the note names, and only names shaped like backups (`StatsKeeper::BACKUP`), so the folder keeps one backup. A store never written gets no backup. Since the save folder can't rename, the copy is written before anything is lost.

**Undo** restores each store's exact text, kept in memory (`StatsKeeper#restore` with the `Cleared` value). The backup stays on disk for support.

Tests: `test/stats_keeper_test.rb`, `test/presentation/clearing_stats_test.rb`, `test/presentation/hold_to_confirm_test.rb`.

## Home after clearing

`StatsKeeper#cleared?` is true once `cleared.txt` exists, so the game knows this player has played though their Stats say nothing. Home is laid out as for a player who has played (`Show#stats_offered?` is `played? || keeper.cleared?`): Play, the goal card, the four large buttons and How to play stay, and the first launch's legend does not come back. The Stats button's value reads "Your record: 0", and the goal card's streak 0, until the next game. The tutorial does not come back either (`TutorialFlag#due?` is asked with `played: stats_offered?`; see [tutorial.md](tutorial.md)). The player asked for their records to go, not for the game to forget them as a player.
