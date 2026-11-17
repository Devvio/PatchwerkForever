# Patchwerk Forever: Thread (Immersive Plainsrunning)

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
- **Keep While Faded**: keep the minimap (with what other addons draw over it, such as the route of Thread (Routes)), your unit frames (player, pet, target and its target) or the chat while the rest of the interface fades. Each is its own tick box; all are off at first.
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
