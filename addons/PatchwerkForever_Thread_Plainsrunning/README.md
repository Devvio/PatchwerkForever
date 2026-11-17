# Patchwerk Forever: Thread (Immersive Plainsrunning)

**Patchwerk runs. Patchwerk runs faster. Patchwerk cannot see the buttons any more.**

Patchwerk borrowed a Tauren's hooves. Patchwerk does not want to talk about how. On the plains they go faster, and faster, and faster still, until the bars and the map and the little numbers all blow away in the wind and there is only the grass and the sky and the air rushing past.

When Patchwerk stops, everything comes back. Patchwerk sewed it all on very carefully.

*Hand-sewn wind. Buttons returned on arrival.*

---

For Tauren in **World of Warcraft: Forever**. As **Plainsrunning** stacks up, the interface slowly fades away until nothing is left but the world; then streaks of speed rush outward across the screen, with wind, dust, rings and a glow if you like, and the camera eases back. The moment the run ends, a fight starts or you open a window, it all comes back. Each character keeps its run records.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the settings pages, and nothing else.

## How it goes

Plainsrunning, the Tauren racial, gives a stack of extra speed for as long as you keep moving, up to 30. Speed mode runs only on Tauren: on any other race it does nothing (the preview still plays).

- **Below 10 stacks** nothing changes.
- **From 10 stacks** the interface fades a little with every stack.
- **At 30 stacks** it is gone. The effects come in, faster the faster you run, and the camera eases back a little.
- **When the buff ends** everything comes back in a quarter of a second, as it was.

The numbers are yours to change: **Start Fading At**, **Fully Hidden At**, and **Show Effects At** on the effects page. **Hidden Interface Opacity** keeps a little of the interface when you would rather not lose it all.

## Keeping parts of the interface

Under **Keep While Faded**, tick what should stay while everything else fades: **Keep The Minimap** (with what other addons draw over it, such as the route of Thread (Routes)), **Keep Player And Target** (your frame, your pet's, your target's and its target's) and **Keep The Chat**. All three are off at first.

## When the interface comes back

Even while the buff lasts, the interface comes back:

- **In combat**, at once, and stays for the whole fight.
- **When a window opens**: the map, your bags, the game menu, the options, a vendor, a quest, and so on, or while you type in chat.
- **When you stand still** for two seconds (the seconds can be changed).
- **When you die or take a flight.**

Each can be turned off on **Thread: Immersive Plainsrunning**. Hold the **Show Interface While Held** key to see the interface for a moment; `/plains show` brings it back for the rest of the run.

## Is it safe?

The interface is only made see-through, never hidden, moved or taken apart, so nothing the game protects during a fight is touched and nothing can be left broken: what you see is put back exactly as it was. Nameplates are part of the world, not the interface, so they stay. A `/reload` always brings everything back too, and should anything in speed mode ever go wrong, it puts your interface back and stops until the next `/reload`.

The buttons of a faded interface are still there: a click where an action button was still presses it.

## The effects

All on **Plainsrunning: Effects**. Each has its own tick box, and they add up: turn on as many as you like. At first only the streaks and the darkened edges are on.

- **Speed Streaks**: lines of light rush outward from the horizon ahead of you, longer and faster as they near the edge of the screen. Number, length, thickness, brightness, speed and color.
- **Wind Gusts**: long, thin ribbons of wind ripple sideways across the lower half of the screen, like wind running through tall grass. Number, brightness and color.
- **Dust And Seeds**: specks of dust and grass seeds fly past you toward the edges, most of them low, near the ground. Amount, size, brightness and color.
- **Warp Rings**: faint rings swell outward from the horizon ahead and pass beyond the edges. Number, brightness and color.
- **Edge Glow**: a glow along the edges of the screen, gold at first, beating in time with your stride. Brightness, color, and **Pulse With Your Stride**.
- **Darken The Edges**: the edges of the screen darken, for a sense of tunnel vision. Darkness.

For all of them: **Show Effects At** (the stacks they come in at), **Match My Speed** (faster the faster you run; they fade when you slow down), **Vertical Offset** (the point on the horizon they come from) and **Clear Middle** (a space kept clear so you can see where you are going). **Preview Speed Mode** pretends to run for fifteen seconds; close the options to watch it.

## The camera

**Pull The Camera Back** eases the camera back 3 yards when the effects come in, and returns it when the run ends or the interface comes back. **Camera Distance** sets how far, from 1 to 10 yards. Only its own part is taken back: zoom as you like during a run, and a camera already at the game's furthest zoom stays where it was.

## Run records

Each character keeps its records: the **longest time at full speed** (30 stacks) in one run, the **fastest time to 30 stacks**, the **farthest run** (on foot; mounted stretches and flights are not counted), the number of **runs at full speed** and the **yards covered** in all. When a run beats a record, it says so in chat (**Tell Me About New Records** turns that off). A run already under way when you log in or reload is counted, but not for the fastest time. The preview never counts.

## Commands

| Command | Does |
|---|---|
| `/plains` | says your stacks, how far the interface is faded, and why it is kept if it is |
| `/plains on` / `off` | turns speed mode on or off |
| `/plains test` | pretends to run with Plainsrunning for fifteen seconds |
| `/plains show` | brings the interface back for the rest of this run |
| `/plains records` | lists this character's run records |
| `/plains records reset` | forgets this character's run records |
| `/plains config` | opens the settings |

Two actions can be bound to a key or a gamepad button (Options → Keybindings → AddOns, or Console Port's binding list): Show Interface While Held and Turn Speed Mode On Or Off.

## Credits

The code and pictures are under the MIT License. English only.
