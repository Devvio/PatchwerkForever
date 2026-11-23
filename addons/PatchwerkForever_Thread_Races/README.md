# Patchwerk Forever: Races (Thread)

**Patchwerk is not fast. Patchwerk is thorough.**

Patchwerk was told there would be a race. Patchwerk asked where it went. Nobody could say. So Patchwerk sewed one of his own: a little flag here, a little flag there, and a ring of light on the ground to run through.

Ride the course once and stick a flag in at every turn. Then go back to the start, wait for three, and go. The next flag lights up as you reach each one, and Patchwerk keeps the time. Patchwerk keeps the best time too. Patchwerk is very good at keeping things.

Patchwerk wants a rematch! Patchwerk always wants a rematch!

*Hand-sewn course. Timed to the tenth. Head start not included.*

---

Race courses of your own for **World of Warcraft: Forever**. Place checkpoints as you ride a course, then race it against the clock: a ring and a beam of light mark the next checkpoint in the world, and each checkpoint says your time and how far ahead of or behind your best run you are. A course can be On Foot or Anything Goes, with a best run for each. Send a course to your party and race it together, with one start for everyone and the gap to the racer ahead at each checkpoint.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the options pages, and nothing else.

**This is a beta.** It passes its checks outside the game but has not been raced in the game yet. Please report what goes wrong, as a comment on the addon's CurseForge page.

## Making a course

1. Stand at the start and type `/race new <name>`. The start is placed where you stand.
2. Ride the course. At each turn type `/race mark`, or press the **Place Checkpoint** key binding. `/race undo` takes the last one back.
3. At the finish, place the last checkpoint and type `/race save`. The last checkpoint is the finish.

A checkpoint counts when you pass within **Checkpoint Size** yards of it (12 to begin with). A course keeps the size it was made with.

## Racing it

`/race start` races the last course you made or raced, or `/race start <name>` another. The **Start Last Race** key binding does the same.

- **Go to the start.** It is your map pin, and the marker shows it in the world. On reaching it the clock counts down from 3, then runs.
- **Each checkpoint in order.** The next one is marked; reach it and the one after lights up. A checkpoint you miss stays the next until you go back for it.
- **At each checkpoint** your time is shown in the middle of the screen, with how far ahead (green) or behind (red) your best run you were there.
- **At the finish**, your time, and a new best run kept if it was faster. `/race best` shows your best run, checkpoint by checkpoint.
- `/race stop` stops (the **Stop Race** key binding too). `/race` on its own, during a race, says where you are in it.

**The map pin.** A race uses your map pin for the next checkpoint. When it ends, the pin you had before is put back (a setting clears it instead). With Routes (Thread) installed, its trail leads to each checkpoint as the pin moves on.

## Rules

A course has a rule: **Anything Goes** or **On Foot**.

- **Anything Goes**: ride, fly, run. Every course starts with this rule unless **Rule For New Courses** says otherwise, and so does every course made before version 0.2.
- **On Foot**: a run during which you are mounted or on a flight path, at any moment between the start and the finish, does not count. The screen and chat say so once, when it happens, and why. The race goes on to the finish and your time is shown, but no best run is kept from it.

`/race rule foot [name]` and `/race rule any [name]` change a course's rule (the last course, without a name). `/race rule` on its own says what it is. `/race list` and `/race best` show the rule.

A course keeps **a best run for each rule**. Changing the rule does not throw the other one away, and the split times during a race compare with the best run under the rule the course has now. Best runs from before version 0.2 are kept as Anything Goes. `/race reset` forgets only the best run under the course's current rule.

On Foot judges only what the game tells plainly: mounted, or on a flight path. Shapeshift forms and speed buffs are allowed, so a druid in travel form is on foot. Being mounted during the countdown does not matter; the rule holds while the clock runs.

## The marker

An addon cannot draw in the world itself. It can draw on the screen, and the game tells it one place in the world on the screen: the waypoint marker of your tracked map pin. So the next checkpoint is your pin, tracked, and a ring lying on the ground with a beam of light is drawn on the game's marker, larger as you come nearer, with the checkpoint's number and distance under it. That is why one checkpoint is marked at a time.

When the checkpoint is off screen the game holds its marker at the edge and shows an arrow there; the ring is not drawn then.

Options on **Races: Marker**: size, a vertical offset to set the ring on the ground, the beam, the words, a color for the start, the checkpoints and the finish, and **Hide Game Waypoint Icon During Races** (off to begin with). **Preview Marker** shows it in the middle of the screen.

## Sharing a course

`/race share <name>` sends a course to your party or raid; `/race share <name> <player>` to one player. They need Races (Thread) too. They are told who sent which course, and `/race accept` keeps it. Only the checkpoints, the size and the rule are sent; best runs are not.

A player still on Races 0.1 can keep a course sent from 0.2, and send one to you. The rule does not reach 0.1 or come from it: such a course is Anything Goes.

## Racing together

Race the same course at the same time with your party or raid. Everyone needs Races (Thread) 0.2 or later and the course (send it with `/race share` first).

1. **Invite.** `/race together [name]` invites your group to a course (the last one, without a name), or press the **Race Together** key binding. Each member who has the course is told who invites them to which course. A member who does not have it is told to ask for it.
2. **Join.** `/race join`, or the **Join Race** key binding. Nobody is put into a race without joining, unless they have enabled **Join Party Races Automatically** (off to begin with).
3. **Go to the start.** As in a race alone, the start is your map pin. At the start you wait.
4. **The start.** The one who invited types `/race go`, or `/race together` again, or presses **Race Together** again, standing at the start. The countdown is the same for everyone: it is sent as one message and runs on each racer's screen from when it arrives. The inviter's **Countdown At The Start** decides whether there is one. A racer who joined but is not at the start when it is given is told they are not in this race.

During the race:

- **At each checkpoint** your time goes to the group. Beside your own split you see the racer just ahead of you there and by how much, in red ("Mira +2.4 s"), or the lead you have over the racer behind, in green ("Mira -2.4 s"). When you are the first at a checkpoint, your lead is shown when the next racer gets there.
- **At the finish** the placings so far are shown, with times, on screen for a moment and in chat, each time a racer finishes. A racer who stops (`/race stop`) or leaves the group is listed as not finished.
- **Your own best run** is kept as in a race alone. The race is run under the rule of the inviter's course for everyone. A run that does not count under On Foot still gets its place, marked "does not count".

Each racer's time is taken by their own clock, from their own start to their own finish, so a slow connection does not cost anyone time. Places are reckoned from those times.

`/race stop` before the start leaves the race (the inviter stopping calls it off for everyone). The settings for the countdown, split times, sounds, chat and the map pin apply as in a race alone.

Nothing is sent to your group unless you invite or have joined. The messages are few and small: the invitation or your joining, the start, one for each checkpoint you reach, and one when you finish or stop. What others send is checked before it is used and is only ever shown; it cannot change your courses or your best runs.

## Options

**Options → AddOns → Patchwerk Forever → Races (Thread)**, or `/race config`. Checkpoint Size, Countdown At The Start, Show Split Times, Play Sounds, Restore Map Pin After A Race, Split Times In Chat, Rule For New Courses and Join Party Races Automatically are on the first page; the marker has the page **Races: Marker**.

## Commands

| Command | Does |
|---|---|
| `/race` | lists the commands; during a race, says where you are in it (`/pfr` is the same) |
| `/race new <name>` | starts a course where you stand |
| `/race mark` / `undo` | places a checkpoint where you stand; takes the last one back |
| `/race save` / `cancel` | keeps the course; throws it away |
| `/race start [name]` / `stop` | races a course (the last one without a name); stops |
| `/race together [name]` | invites your party or raid to race a course together; again, gives the start |
| `/race go` | gives the start of the race you invited your group to (otherwise the same as `start`) |
| `/race join` | joins the race you were invited to |
| `/race list` / `best [name]` | lists your courses with their rule; shows a best run |
| `/race rule foot [name]` / `rule any [name]` | sets a course's rule to On Foot; to Anything Goes (`/race rule` alone says what it is) |
| `/race delete <name>` / `reset <name>` | deletes a course; forgets its best run under its rule |
| `/race share [name] [player]` / `accept` | sends a course; keeps one you were sent |
| `/race config` | opens the options |

Bind these under Options → Keybindings → Patchwerk Forever, or in Console Port's binding list: **Place Checkpoint**, **Start Last Race**, **Stop Race**, **Race Together** (invites with the last course; pressed again, gives the start) and **Join Race**.

## Credits

The code and pictures are under the MIT License. English only.
