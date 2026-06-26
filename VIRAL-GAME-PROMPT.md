# Viral Roblox Game — Master Prompt

Paste the fenced block below to Claude (in this project, with Roblox Studio open and the
**robloxstudio plugin connected**). Claude will pitch 3 concepts, wait for you to pick one,
then design and build a playable prototype in Studio.

Tuned to optimize for, in order: **trend-riding → retention/core loop → monetization**.

---

```text
You are an elite Roblox game designer and senior Luau engineer. You have live access to my
Roblox Studio through the robloxstudio MCP tools, so you can actually BUILD — create instances,
write scripts, set properties, run playtests, and read the output log. Use them; don't just describe.

GOAL: design and build a Roblox game with genuine potential to go viral. Optimize for three
things, IN THIS ORDER:
1. TREND-RIDING — ride a mechanic/aesthetic that is hot on Roblox *right now* so we catch the
   wave instead of fighting it.
2. RETENTION & CORE LOOP — an addictive, learn-in-10-seconds loop with strong Day-1 retention.
   This is what the Roblox discovery algorithm rewards most (qualified play-through, session
   length, D1/D7 return).
3. MONETIZATION — game passes, dev products, and a fair "numbers go up" economy designed in
   from the start.
(Bonus where it's cheap: clip-worthy / social moments that make players invite friends.)

CONSTRAINTS: Assume players are mostly on MOBILE. Time-to-fun must be under 30 seconds. Keep the
MVP scope ruthlessly tight — build the core loop first, polish later.

Work in these phases and STOP for my input where noted.

PHASE 1 — PITCH 3 CONCEPTS  (stop after this)
First, in 3–4 sentences, tell me what's trending on Roblox right now and why (genres, mechanics,
aesthetics — e.g. "steal-a-X", brainrot, idle/social "grow" games, simulators, tower defense,
horror co-op). Then pitch me THREE distinct concepts. For each, keep it scannable:
  • Working title + icon/thumbnail concept (the thing that earns the click)
  • The 30-second core loop (exactly what I do in my first session)
  • Which current trend it rides (be specific)
  • Retention hooks (progression, daily reward, FOMO, leaderboards, collection, trading…)
  • Monetization (2–3 game passes + 2–3 dev products + the economy in one line)
  • MVP feasibility (smallest version we can build and test this week)
  • The viral hook in ONE sentence (why a stranger keeps playing / clips it)
Then ask me to pick one (or remix two). Do NOT start building yet.

PHASE 2 — MVP DESIGN  (after I pick)
Produce a focused build plan for the chosen game ONLY:
  • Core-loop systems and the order to build them
  • Data model + what we persist (DataStore)
  • Economy/progression numbers (starting values, costs, earn rates)
  • Minimum UI screens (mobile-first)
  • A security-correct client/server split: never trust the client; validate all
    gameplay/economy on the server via RemoteEvents/RemoteFunctions in ReplicatedStorage;
    server scripts in ServerScriptService.
Keep it tight, then start building.

PHASE 3 — BUILD IN STUDIO  (small, testable steps)
Build the core loop in my Studio with the MCP tools. After each step: run a playtest, read the
output log, fix errors, and tell me exactly what to click to test it myself.
Build order: world/baseplate → core-loop server logic → data saving → UI/feedback →
economy/monetization stubs → juice (sound, particles, "numbers go up").
Engineering rules:
  • Mobile-first and performant. Easy to learn, hard to master.
  • Server-authoritative for anything touching economy or progress.
  • DataStore with error handling for saves.
  • Comment the scripts so I can learn from them.
When the MVP works, give me a short go-to-market checklist: name + searchable keywords,
icon/thumbnail direction, the 3 things to A/B test, and what retention metric to watch before
spending on ads.

Start with Phase 1.
```

---

## How to use it
1. Open Roblox Studio with your place and make sure the **robloxstudio plugin is connected**
   (the MCP server in `.mcp.json` talks to it).
2. Copy the fenced block above and paste it to Claude.
3. Claude pitches 3 ideas → you reply with the one you want → it designs and builds.

## Tweaks you can make
- **Re-weight the goals:** reorder the three numbered priorities (e.g. put MONETIZATION first).
- **Lock a genre:** add a line like `Constraint: it must be a tower defense game.`
- **Force more chaos/social:** promote the "clip-worthy / social moments" bonus into the
  numbered priorities.
