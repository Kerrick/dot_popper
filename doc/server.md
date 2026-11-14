# Dot Popper's friend groups: what the server does

Dot Popper is a one-minute arcade game. Friends form small groups that compete for one title each. The server's API is `docs/api.md` in the server's private repository, which is the source of truth; this is the game's summary of it.

The server's tests make every exchange the game has with it against the real server and publish them, with the values both sides hold, as its `docs/exchanges.json`. The game's copy is `test/fixtures/server/exchanges.json`, whose SHA-256 is `0f8aae590acd47bae17e9095f1f3e0ba4abefada050441b67deb9b1ed068c3ce`, as the server's `docs/api.md` states it; `test/server_exchanges_test.rb` replays it with the game's own client. When the server publishes a new one, copy it and its SHA-256 here, and run the test with `DOT_POPPER_SERVER_CHECKOUT` naming a checkout of the server to check the copy.

## The title

- A group has one title, and whoever holds it is the champion. While nobody does, it is vacant.
- Any game scoring strictly higher than the group's top score wins the title, in every group of the player's where that is true. Ties never win.
- A champion's own higher game raises the top score and carries on the same reign; it is not a title change.
- Nothing decays and nothing happens daily.
- If a champion leaves, the title passes to the remaining member with the score record above 0, or goes vacant if nobody has scored.
- Every title change stays visible to every member, permanently, with nothing to acknowledge.
- A game a member plays counts, except the tutorial's, if it scored above 0, whatever its dot size; the game sends its score, or keeps the highest such score until it can (not while a 429's wait lasts, and never without the player's token). A score is a whole number from 0 to 100,000.

## Players and groups

- A player is an anonymous token, with no account, name, email, or password. Nothing a player types is kept, because nothing is typed.
- A player can be in at most 20 groups; a group holds at most 8 at once. Each has a 7-digit join code that players share themselves.
- Within a group a member is a number, in join order, never reused. The game draws it as an icon.
- A player can leave any group, and delete everything about themselves, at any time.
- Creating and joining a group need Pro; the game alone decides that. Leaving and deleting never do.

## Not included

Display names, group names, chat, friend lists, push notifications, reminders, accounts, and analytics.
