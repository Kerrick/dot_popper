# Dot Popper's friend groups: what the server does

Dot Popper is a one-minute arcade game. Friends form small groups that compete for one title each. The server's API is `docs/api.md` in `~/Developer/dot_popper-server`, which is the source of truth; this is the game's summary of it.

## The title

- A group has one title, and whoever holds it is the champion. While nobody does, it is vacant.
- Any game scoring strictly higher than the group's top score wins the title, in every group of the player's where that is true. Ties never win.
- A champion's own higher game raises the top score and carries on the same reign; it is not a title change.
- Nothing decays and nothing happens daily.
- If a champion leaves, the title passes to the remaining member with the score record above 0, or goes vacant if nobody has scored.
- Every title change stays visible to every member, permanently, with nothing to acknowledge.
- Only games played with dots sized to the screen are sent. A score is a whole number from 0 to 100,000.

## Players and groups

- A player is an anonymous token, with no account, name, email, or password. Nothing a player types is kept, because nothing is typed.
- A player can be in at most 20 groups; a group holds at most 8 at once. Each has a 7-digit join code that players share themselves.
- Within a group a member is a number, in join order, never reused. The game draws it as an icon.
- A player can leave any group, and delete everything about themselves, at any time.
- Creating and joining a group need the paid version; the game alone decides that. Leaving and deleting never do.

## Not included

Display names, group names, chat, friend lists, push notifications, reminders, accounts, and analytics.
