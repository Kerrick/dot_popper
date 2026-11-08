# Dot Popper's friend groups: what the server does

Dot Popper is a one-minute arcade game. Friends form a small group that competes for one trophy. A player takes the trophy by beating the holder's score. The server keeps who is in which group and who holds its trophy.

## The trophy

- A group has one trophy. At first nobody holds it, and any round that scores more than 0 takes it.
- Each day a holder keeps the trophy, the score to beat falls by 1. It never falls below 0. A day is a whole UTC day, the same for every member.
- A round takes the trophy when it scores more than the score to beat that day and the player is not the holder. That round's score becomes the new score to beat, and the falling starts again from that day.
- A holder's own rounds change nothing. A holder never has to play to defend the trophy.
- Only rounds played with dots sized to the screen count. A score is a whole number from 0 to 100,000.
- A round played offline may arrive up to two days late. It counts on the day it arrives.

For example, a player takes the trophy with 30 on Monday. On Wednesday the score to beat is 28, so a round of 28 from someone else does nothing and a round of 29 takes the trophy.

## Players

- A player has no account, login, email, or password. They are recognized anonymously from their first use.
- Players provide no text. Players and groups have no names, and nothing a player types is kept or shown to anyone else.
- Within a group, each member is one of 8 distinct identities, unique within that group. A player asks for one when joining, and gets a free one if theirs is taken.
- A player can delete everything about themselves at any time. A trophy they held falls vacant, and a group left with nobody goes too.

## Groups

- A player is in at most one group.
- A group holds at most 8 players.
- Each new group gets a join code of 7 digits. Players share it themselves.
- A player can try at most 20 join codes an hour, so that codes can't be guessed.
- Any player may leave. Leaving gives up the trophy if they held it. An empty group goes.
- A group has no owner.

## Free and Paid

Friend groups are for players with the paid version: both creating a group and joining one need it. Leaving a group and deleting everything are always available. Proving a purchase comes later, and will involve several stores.

## What a member can find out

- Their group: its join code, its members, which member they are, who holds the trophy, and the score to beat today.
- After a round: whether it took the trophy, and how the group now stands.
- News: your trophy was taken, by whom, with what score. Only the person who lost the trophy is told, and each theft is told once.

A group's trophy never appears to anyone outside the group. There is no global leaderboard.

## Not included

Display names, group names, chat, friend lists, push notifications, reminders, accounts, and analytics.
