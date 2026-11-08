# Dot Popper's server: what it must do

This spec is for the Rails app in `~/Developer/dot_popper-server`. It says what the server does, and leaves its shape to you. Prefer whatever a vanilla Rails app would do.

## What the server is for

Dot Popper is a one-minute arcade game. Friends form a small group that holds one trophy. A player takes the trophy by beating the holder's score. The server keeps who is in which group and who holds its trophy. Everything else about the game stays on the player's device, and a player with no group never contacts the server.

## Rules of the trophy

The server decides these. The game only shows the answer.

- A group has one trophy. At first nobody holds it, and any round that scores more than 0 takes it.
- Each day a holder keeps the trophy, the score to beat falls by 1, and it never falls below 0. A day is a whole UTC day, the same for every member, and the server's clock is the only one that counts.
- A round takes the trophy when it scores more than the score to beat today and the player is not the holder. A taking round sets the score to beat to that round's score, and the falling starts again from that day.
- A holder's own rounds change nothing. The holder never has to play to defend the trophy.
- Only rounds played with dots sized to the screen count. The game says which kind a round was. Refuse a round of any other kind, and a score that is not a whole number from 0 to 100,000.

For example, a player takes the trophy with 30 on Monday. On Wednesday the score to beat is 28, so a round of 28 from someone else does nothing and a round of 29 takes the trophy.

The prototype that stated these rules in code (`lib/dot_popper/trophy.rb`) has been removed; the Rails app is now the only statement of them.

## Players

- A player has no account, login, email, or password. On first use the server issues a long random token, and it stores only a hash of that token. The game sends the token with every request.
- **The server accepts no text from players.** Players have no names, and groups have no names. Nothing a player types is stored or shown to anyone else. A field that would hold free text doesn't exist.
- Within a group, each member appears as one of 8 dot looks. A look is one member's alone within the group. A player picks one when joining, and if it's taken the server assigns one that's free. Accept only a whole number from 0 to 7. The game draws the looks; the server only keeps which of the 8 each member has.
- A player can delete everything about themselves at any time. That removes the player, their membership, and every record of a theft they took part in. A trophy they held falls vacant, and a group left with nobody goes too. This must work from inside the game, with no contact with us (Apple's guideline 5.1.1(v)).

## Groups

- A player is in at most one group.
- A group holds at most 8 players. A full group refuses new members.
- The server gives each new group a join code of 7 digits, which players enter on an on-screen keypad. Accept digits only. Players share the code themselves, in their own chat.
- A player can try at most 20 join codes an hour, counting wrong codes, so that codes can't be guessed.
- Any player may leave. Leaving gives up the trophy if they held it, and removes their part in the group's thefts. An empty group goes.
- A group has no owner. A creator who leaves costs the group nothing.

## Free and Paid

- Creating a group needs the paid version of the game. Joining a group and taking its trophy are free.
- At first the server may take the game's word that a creator has paid. Build it so that checking a purchase later is a change in one place, because the sale will come from different stores: the App Store, Google Play, perhaps the Microsoft Store, the Mac App Store, Steam, itch.io, or a merchant of record such as Lemon Squeezy. Don't build any of those checks yet.

## What the game needs to see

- A member's view of their group: its join code, each member and their look, which member is the player asking, who holds the trophy, the score to beat today, and any news for that player.
- After a round is reported: whether that round took the trophy, and the group as it stands.
- **News** is one thing: your trophy was taken, by this look, with this score. Only the person who lost the trophy is told, and each theft is told once. The game says which news it has shown, and the server doesn't repeat it. Keep nothing that would let the game nag, such as reminders or counts of time away.
- A group's trophy never appears to anyone outside the group. There is no global leaderboard.
- A round played offline may arrive up to two days late. The server scores it when it arrives, by the server's day.

## The game's client

The game makes HTTPS requests from one background thread, and treats every failure as quiet: rounds play on whether the server answers or not. Answer in JSON, and use plain status codes for refusals (unknown token, no such group, group full, already in a group, too many join tries). `lib/dot_popper/groups/session.rb` is the client today, and the prototype's paths are under `/v1`. If a different shape suits Rails better, say what changed, and the game's client will follow. Refuse request bodies over 4 KB. The server's address is one setting in the game, `Groups::Settings::SERVER_URL`.

## Privacy

Dot Popper's privacy promise is short, and the server must keep it:

- Keep no IP addresses, and don't write them to logs. That includes Rails' request logs and any host in front of the app.
- Keep no analytics, third-party trackers, advertising identifiers, or device identifiers.
- Keep only what this spec lists.

## Operating it

- HTTPS in production, with a health check a host can poll.
- Deleted data is gone, not flagged.
- One small server and a SQLite database should be enough: a group is at most 8 players, and a round is reported at most about once a minute per player. Don't add infrastructure this load doesn't need.
- Tests cover the trophy rules, including the day boundary and a late round, the limits on groups and join tries, deletion leaving nothing behind, and news being told once and only to the loser.

## Not in this version

Display names, group names, chat, avatars of a player's own, global leaderboards, multiple groups per player, friend lists, push notifications, and accounts. Each adds either user content or pressure that the game's design rules out.
