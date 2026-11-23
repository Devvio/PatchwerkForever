# Patchwerk Forever: Races (Thread)

## 0.2.0 (beta)

- **Course rules.** A course is **Anything Goes** or **On Foot**. Under On Foot, a run during which you are mounted or on a flight path does not count: it is said once, on screen and in chat, the race goes on to the finish, and no best run is kept from it. Shapeshift forms and speed buffs are allowed. `/race rule foot [name]` and `/race rule any [name]` set a course's rule; `/race list` and `/race best` show it. New setting **Rule For New Courses** (Anything Goes to begin with).
- **A best run for each rule.** A course keeps one best run under On Foot and one under Anything Goes, and the split times compare with the one under its current rule. The courses and best runs you have are kept, as Anything Goes. `/race reset` forgets the best run under the course's current rule only.
- **The rule is sent with a shared course.** Races 0.1 can still keep a course sent from 0.2, and 0.2 one from 0.1; the rule is then Anything Goes.
- **Race together.** `/race together [name]` invites your party or raid to race a course at the same time. Members who have the course are told and join with `/race join`; a member without it is told to ask for it. Everyone goes to the start, and the one who invited gives it with `/race go` (or `/race together` again): one countdown for all.
- **During a race together**, each checkpoint shows the gap to the racer ahead of you or the lead you have, with the name, beside your own split. As each racer finishes, the placings with times are shown on screen and in chat. A racer who stops or leaves the group is listed as not finished. Your own best run is kept as in a race alone; a run that does not count under On Foot still places, marked as such.
- Nobody is put into a race without joining: new setting **Join Party Races Automatically**, off to begin with. Nothing is sent to your group unless you invite or have joined, and what others send is checked before it is shown.
- Key bindings **Race Together** (invites with the last course; pressed again, gives the start) and **Join Race**.
- Not raced in the game yet, like the rest of this beta.

## 0.1.2 (beta)

- **Now named Patchwerk Forever: Races (Thread)**: the name comes first and what kind of addon it is after it, in brackets (it was Thread (Races)). The options page is named the same way.

## 0.1.1 (beta)

- A key bound while this addon is not running (its base too old) does nothing instead of giving an error.
- **Key bindings** are in a section of their own, **Patchwerk Forever**, with the rest of the family's. Your bindings are kept.
- Checkpoints are counted in plain words ("1 checkpoint", "2 checkpoints"), `/race help` lists one command to a line, and `/race config` in combat says the options cannot be opened in combat.

## 0.1.0 (beta)

The first release.

- **Make a course as you ride it**: `/race new <name>` places the start where you stand; `/race mark` (or the Place Checkpoint key binding) places each checkpoint; `/race save` keeps it, the last checkpoint being the finish.
- **Race it against the clock**: `/race start`. The next checkpoint is your map pin, tracked, and a ring and a beam of light are drawn on the game's waypoint marker for it. A countdown at the start, your time and how far ahead of or behind your best run at each checkpoint, and your best run kept.
- **The pin you had** is put back when a race ends.
- **Send a course** to your party, or to one player, with `/race share`; they keep it with `/race accept`.
- Settings on **Races (Thread)** and **Races: Marker**; key bindings Place Checkpoint, Start Last Race and Stop Race.
- Needs **Patchwerk Forever**.
