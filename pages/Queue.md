# The Queue

One queue per anchor. It decides what is on screen and in what order; it draws
nothing, which is why the rules below are testable without a DataModel.

Four behaviours, in the order they matter.

## Priority

Higher sorts nearer the front, and outlives the cap.

```lua
Flare.Toast("Saved"):Show()                    -- priority 0
Flare.Alert("Kicked"):Danger():Priority(10):Show()
```

When the cap is full, a higher-priority arrival **displaces** the least
important notice on screen rather than waiting behind it. The displaced one
goes to the front of the backlog, so it is the next thing shown — it is
delayed, never dropped.

Equal priorities keep arrival order, so a burst does not shuffle itself while
you are reading it.

## Grouping

Notices that are the same collapse into one carrying a count, instead of three
identical lines stacking up.

```lua
for _ = 1, 3 do
    Flare.Toast("Item picked up"):Show()
end
-- one notice: "Item picked up  ×3"
```

Without an explicit key, "the same" means same kind, same tone, same body —
which catches the common case without asking you to think about it. When that
is not what you want, name the group yourself:

```lua
Flare.Toast(`{item.Name} picked up`):Group("pickup"):Show()
```

Merging restarts the original's clock, so a repeating event keeps its notice
on screen rather than letting it expire on the original schedule. The
duplicate resolves immediately with `Result.Kind == "Grouped"` and
`Result.Value` set to the notice it merged into, so an `:Await()` on it
returns rather than hanging.

Turn it off per-session with `Flare.Start({ Group = false })`.

## Cap and overflow

Four per anchor by default. Past that, notices wait in a backlog and are shown
as slots free up — nothing is silently lost.

```lua
Flare.Start({ Max = 2 })

local live, waiting = Flare.Count()
```

The cap is per anchor, so a full corner does not block a banner.

## Pause

The countdown freezes while the pointer is over a notice, because a toast that
vanishes as you reach for its button is worse than no toast at all.

A paused notice has its deadline pushed forward each frame rather than merely
having its expiry skipped, so hovering holds it indefinitely and letting go
gives it its full remaining time back.

Opt out per notice with `:Pausable(false)`, or per session with
`Flare.Start({ Pause = false })`.

## Clearing

```lua
Flare.Clear()              -- everything, everywhere
Flare.Clear("bottomRight") -- one anchor
```

Each cleared notice resolves with `Result.Kind == "Dismissed"`, so anything
awaiting one wakes up.
