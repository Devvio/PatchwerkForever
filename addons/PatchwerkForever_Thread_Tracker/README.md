# Patchwerk Forever: Thread (Tracker)

**Patchwerk had a list. Patchwerk lost the list. Patchwerk made a list that cannot be lost.**

Patchwerk is given many jobs. Fetch the heads. Find the pools. Bring back the hooves. By the third job Patchwerk has forgotten the first, and by the fifth he is fairly sure he was a tailor.

So Patchwerk sewed the jobs to the side of the screen. Every quest you track, and under each one what it still wants of you. Done things go quiet. Things ready to hand in say so.

The game's own list is asked, politely, to stand in the corner and be invisible. It is not thrown out. Patchwerk knows what it is to be thrown out.

Patchwerk wants more jobs! Patchwerk wants them written down!

*One list. Hand-stitched. Mostly in order.*

---

A quest tracker for **World of Warcraft: Forever**: the quests you track, each with what it still asks of you, in a list of our own that you can move, size and colour.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the settings pages, and nothing else.

**This is an early beta.** It lists your tracked quests and keeps the game's own tracker quiet. Clicking a quest, sorting, quest item buttons, tracked recipes and the steps of a guide are being built and are not in it yet.

## What it shows

- **Each quest you track**, with its level and, in the game's colours, how hard it is for you.
- **Its objectives** and how far each has got. One that is done is dimmed, or hidden if you prefer.
- **A quest that is ready** says where to hand it in, in the colour of a thing done.
- **How many quests you hold**, beside the heading.

Tracking and untracking a quest are still done in the game's quest log; the list follows it.

## Using it

- **Fold it** by clicking the heading, with `/tracker fold`, or with a key or gamepad button you bind.
- **Move it** with `/tracker move` (or the button in the settings): drag it by the bar along its top, then `/tracker lock`.
- **Past a height you set**, the list scrolls with the mouse wheel. While everything fits, the wheel is left to the camera.
- Clicks pass through the list to the world, except on a heading.

## The game's own tracker

While this one is shown, the game's tracker is made invisible and lets clicks through, so you do not see every quest twice. It is not removed or hidden, which is what makes other things go wrong. Unticking **Hide The Game's Own Tracker**, or `/tracker off`, brings it back as it was.

- **In dungeons, raids and battlegrounds** the game's tracker is let back, because it shows things there that this one does not. A setting changes that.
- **A quest's usable item** has its button on the game's tracker. That button cannot be touched by an addon, so it stays where it was, unseen, until this tracker has item buttons of its own.
- **EllesmereUI's quest tracker**, if you run it, is a third. You are told once; untick one of the two in the addon list.

## Settings

**Options → AddOns → Patchwerk Forever → Thread: Tracker**, or `/tracker config`: on or off, the game's tracker, levels, done objectives, width, the tallest it grows, and its place. **Tracker: Look** has its size, the size of the writing, the background, and the colours.

## Commands

| Command | Does |
|---|---|
| `/tracker` | lists the commands (`/pftr` is the same) |
| `/tracker on` / `off` | shows it, or goes back to the game's own |
| `/tracker move` / `lock` / `reset` | drag it somewhere; fix it there; put it back under the minimap |
| `/tracker fold` | folds it up, or opens it again |
| `/tracker config` | opens the settings |

## Credits

The code and pictures are under the MIT License. English only.
