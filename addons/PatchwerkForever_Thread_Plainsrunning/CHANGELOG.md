# Patchwerk Forever: Immersive Plainsrunning (Thread)

## 1.3.0

- **Other ways of going fast.** Speed mode can also run while you are mounted and moving (**Mounts**), while you are moving in Travel Form, Aquatic Form or Ghost Wolf or under Aspect of the Cheetah or Aspect of the Pack (**Travel Forms**), and while you are on a flight (**Flight Paths**). Each is a setting of its own under the new heading **Other Ways Of Going Fast**, each is off until you enable it, and they work for every race.
  - They have no stacks. Once you have kept moving for five seconds (**Seconds Before Fading**, from 0 to 30), the interface fades over about ten seconds, much as it does while Plainsrunning stacks up at a run, and then the effects come in.
  - Everything that brings the interface back still does: combat, a window, typing, standing still, dying, the held key and `/plains show`. Keep While Faded, the camera and the preview work as before.
  - With Flight Paths enabled, a flight fades the interface instead of bringing it back.
  - Getting off the mount, leaving the form, landing or standing still for ten seconds ends the run.
  - Plainsrunning itself is unchanged and still for Tauren only. Its stacks come first when both apply, and the run records count Plainsrunning runs only.
- `/plains` says what speed mode is running on, and lists the other sources that are enabled.
- **Wind Shows The Way** (on Plainsrunning: Effects, off until you enable it): with Routes (Thread) installed and a route being followed, the point the effects rush out from leans left or right toward where the route goes next, so you can follow the route with the interface gone. Straight ahead is the middle, a turn to come leans it that way, and a route beside or behind you leans it all the way to the nearer side. **How Far It Leans** sets how far that is, from 5% to 30% of the screen's width. It does nothing without Routes (Thread), without a route, on a flight, or where the game does not say where you are or which way you face, as in instances.

## 1.2.2

- **Now named Patchwerk Forever: Immersive Plainsrunning (Thread)**: the name comes first and what kind of addon it is after it, in brackets (it was Thread (Immersive Plainsrunning)). The options page is named the same way.

## 1.2.1

- A key bound while this addon is not running (its base too old) does nothing instead of giving an error.
- **Key bindings** are in a section of their own, **Patchwerk Forever**, with the rest of the family's. Your bindings are kept.
- Sliders measured in percent (Hidden Interface Opacity, Clear Middle, Vertical Offset and the effects' brightness, size, length, thickness, speed and darkness) show a percent sign.
- Chat lines reworded to read as plain sentences: "New record! Longest at full speed: ...", and the lines after a problem. `/plains help` lists one command to a line, and `/plains config` in combat says the options cannot be opened in combat.

## 1.2.0

- **Standing still for five seconds** brings the interface back (it was two). **Once you move again for five seconds**, it fades away again, if Plainsrunning is still on you; before, it faded away the moment you moved. The new setting **Seconds Moving Again** changes that wait, from 0 to 10 seconds.

## 1.1.0

- **Tauren only.** On any other race speed mode reads nothing and does nothing; the preview still plays.
- **No more "a problem in speed mode" in a fight.** The game now keeps some numbers secret while it restricts them, your speed among them; speed mode stopped on them. It never counts with a secret number now: a secret speed counts as the last one known, a secret aura changes nothing, and a stretch of a run whose speed is secret is not added to its yards.

## 1.0.0

The first release: speed mode as in 0.1.0, with everything 0.2.0 added (both listed below; neither was uploaded before).

## 0.2.0 (beta)

- **Four more effects at full speed**, each with its own tick box and settings, all off until you turn them on. They add up: any of them can show together with the streaks and the darkened edges.
  - **Wind Gusts**: long, thin ribbons of wind ripple sideways across the lower half of the screen. Number, brightness and color.
  - **Dust And Seeds**: specks of dust and grass seeds fly past you, most of them low. Amount, size, brightness and color.
  - **Warp Rings**: faint rings swell outward from the horizon ahead. Number, brightness and color.
  - **Edge Glow**: a glow along the edges of the screen that beats with your stride. Brightness, color, and whether it pulses.
- **Keep While Faded**: keep the minimap (with what other addons draw over it, such as the route of Routes (Thread)), your unit frames (player, pet, target and its target) or the chat while the rest of the interface fades. Each is its own tick box; all are off at first.
- **Pull The Camera Back**: the camera eases back 3 yards when the effects come in and returns when the run ends or the interface comes back. The distance can be set from 1 to 10 yards. It never takes back more than it moved, so a camera already at the game's furthest zoom stays where it was.
- **Run records**, kept for each character: longest time at full speed, fastest time to 30 stacks, farthest run, runs at full speed and the yards covered in all. A new record is told in chat (this can be turned off); `/plains records` lists them, `/plains records reset` forgets them.
- The second options page is now **Plainsrunning: Effects**. **Show Streaks At** is now **Show Effects At**, and Match My Speed, Vertical Offset and Clear Middle work for all the effects.

## 0.1.0 (beta)

The first release.

- **The interface fades away as Plainsrunning stacks up**: from 10 stacks it fades a little with every stack, and at 30 it is gone, leaving only the world. Both numbers can be changed, and so can how much of the interface is left.
- **Speed streaks** rush outward across the screen once the interface is gone, faster the faster you run, with the edges of the screen darkening. Their number, length, thickness, brightness, speed, color and the clear space in the middle can all be changed.
- **The interface comes back** when the buff ends, at once when a fight starts, while a window is open or you type in chat, when you stand still for two seconds, and when you die or take a flight. Each of these can be turned off.
- **Safe in combat**: the interface is only made see-through, never hidden or moved, so nothing the game guards in a fight is touched, and the interface is always put back as it was.
- **Preview Speed Mode** (or `/plains test`) pretends to run for fifteen seconds, for those who are not Tauren or not on the plains.
- Key bindings **Show Interface While Held** and **Turn Speed Mode On Or Off**; `/plains show` brings the interface back for the rest of a run.
- Needs **Patchwerk Forever**.
