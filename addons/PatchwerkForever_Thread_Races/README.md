# Patchwerk Forever: Thread (Races)

**Patchwerk is not fast. Patchwerk is thorough.**

Patchwerk was told there would be a race. Patchwerk asked where it went. Nobody could say. So Patchwerk sewed one of his own: a little flag here, a little flag there, and a ring of light on the ground to run through.

Ride the course once and stick a flag in at every turn. Then go back to the start, wait for three, and go. The next flag lights up as you reach each one, and Patchwerk keeps the time. Patchwerk keeps the best time too. Patchwerk is very good at keeping things.

Patchwerk wants a rematch! Patchwerk always wants a rematch!

*Hand-sewn course. Timed to the tenth. Head start not included.*

---

Race courses of your own for **World of Warcraft: Forever**. Place checkpoints as you ride a course, then race it against the clock: a ring and a beam of light mark the next checkpoint in the world, and each checkpoint says your time and how far ahead of or behind your best run you are. Send a course to your party and race the same one.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the settings pages, and nothing else.

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

**The map pin.** A race uses your map pin for the next checkpoint. When it ends, the pin you had before is put back (a setting clears it instead). With Thread (Routes) installed, its trail leads to each checkpoint as the pin moves on.

## The marker

An addon cannot draw in the world itself. It can draw on the screen, and the game tells it one place in the world on the screen: the waypoint marker of your tracked map pin. So the next checkpoint is your pin, tracked, and a ring lying on the ground with a beam of light is drawn on the game's marker, larger as you come nearer, with the checkpoint's number and distance under it. That is why one checkpoint is marked at a time.

When the checkpoint is off screen the game holds its marker at the edge and shows an arrow there; the ring is not drawn then.

Settings on **Races: Marker**: size, a vertical offset to set the ring on the ground, the beam, the words, a color for the start, the checkpoints and the finish, and **Hide Game Waypoint Icon During Races** (off to begin with). **Preview Marker** shows it in the middle of the screen.

## Sharing a course

`/race share <name>` sends a course to your party or raid; `/race share <name> <player>` to one player. They need Thread (Races) too. They are told who sent which course, and `/race accept` keeps it. Only the checkpoints and the size are sent; best runs are not.

## Settings

**Options → AddOns → Patchwerk Forever → Thread: Races**, or `/race config`. Checkpoint Size, Countdown At The Start, Show Split Times, Play Sounds, Restore Map Pin After A Race and Split Times In Chat are on the first page; the marker has the page **Races: Marker**.

## Commands

| Command | Does |
|---|---|
| `/race new <name>` | starts a course where you stand (`/pfr` is the same as `/race`) |
| `/race mark` / `undo` | places a checkpoint where you stand; takes the last one back |
| `/race save` / `cancel` | keeps the course; throws it away |
| `/race start [name]` / `stop` | races a course (the last one without a name); stops |
| `/race list` / `best [name]` | lists your courses; shows a best run |
| `/race delete <name>` / `reset <name>` | deletes a course; forgets its best run |
| `/race share [name] [player]` / `accept` | sends a course; keeps one you were sent |
| `/race config` | opens the settings |

Three actions can be bound to a key or a gamepad button (Options → Keybindings → AddOns, or Console Port's binding list): Place Checkpoint, Start Last Race and Stop Race.

## Credits

The code and pictures are under the MIT License. English only.
