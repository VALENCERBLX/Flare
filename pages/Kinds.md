# Kinds

Thirteen kinds, four groups. They differ in shape, anchor and lifetime — not
in how you drive them.

## The core set

Transient, cornered, and gone on their own.

```lua
Flare.Toast("Saved"):Ok():Show()
Flare.Banner("Server restarting in 5 minutes"):Warn():Show()
Flare.Alert("You were kicked from the party"):Danger():Show()
Flare.Snackbar("Message deleted", "Undo", restore):Show()
```

| Kind | Anchor | Lifetime |
| --- | --- | --- |
| `toast` | `bottomRight` | 5s |
| `banner` | `top`, full width | 6s |
| `alert` | `bottomRight` | until dismissed |
| `snackbar` | `bottom` | 6s |

`alert` is sticky on purpose: it is the kind you reach for when the player
must have seen it.

`snackbar` takes its action inline, because "Deleted. **Undo**" is the whole
reason the kind exists:

```lua
Flare.Snackbar("Message deleted", "Undo", function(notice)
    restore()

    notice:Update("Restored"):Ok()

    return false  -- keep it open to show the new text
end):Show()
```

Any action callback returning `false` keeps the notice open. Anything else
closes it.

## Interactive

They ask something, so none of them expire.

```lua
local answer = Flare.Confirm("Delete everything?"):Danger():Await()

local name = Flare.Prompt("Name your save")
    :Placeholder("Slot 1")
    :Default("Autosave")
    :Await()

local pick = Flare.Choice("Where to?", {
    "Spawn",
    { Id = "arena", Text = "Arena", Description = "PvP enabled" },
}):Await()
```

Each resolves with a `Result`:

| Kind | `Result.Kind` | `Result.Value` |
| --- | --- | --- |
| `confirm` | `Accepted` / `Cancelled` | `true` / `false` |
| `prompt` | `Value` / `Cancelled` | the text typed |
| `choice` | `Value` / `Dismissed` | the chosen `Id` |

A choice entry can be a plain string — its text becomes its id — or a table
with `Id`, `Text`, `Icon` and `Description`.

## Live

They stay while something happens, then resolve.

```lua
local job = Flare.Progress("Uploading"):Show()

job:Progress(0.4)     -- 0 to 1
job:Progress(75)      -- or a percentage
job:Finish("Uploaded")
job:Fail("Upload failed")

local wait = Flare.Loading("Finding a match"):Show()
wait:Finish("Match found")

Flare.Countdown("Round ends", 90):Show()
```

`progress` and `loading` are sticky until you finish them; `finish` tones the
notice green, fills the bar and gives it two seconds to be read. `countdown`
paints a clock — `1:30`, then `45s` under a minute — and expires when it
reaches zero.

## Rich

Big, centred, and allowed to interrupt.

```lua
Flare.Achievement("First Blood", "Win a round without dying")
    :Icon("rbxassetid://1234567")
    :Priority(10)
    :Show()

Flare.Reward("Loot", "+50 coins")
    :Image("rbxassetid://7654321")
    :Show()

Flare.Hint("Click here to equip", button, "top"):Show()
```

`hint` pins itself to a `GuiObject` instead of a screen corner, so it points
at the thing it is talking about. The side is `top`, `bottom`, `left` or
`right`.

## Common setters

Every kind takes all of these.

| Setter | What it does |
| --- | --- |
| `:Title(text)` | A heading above the body |
| `:Body(text)` / `:Update(text)` | The body, live-updatable |
| `:Icon(asset)` / `:Image(asset)` | A small icon, or a large image |
| `:Tone(name)` | `neutral` `info` `ok` `warn` `danger` `accent` |
| `:Info()` `:Ok()` `:Warn()` `:Danger()` `:Accent()` | Shorthands for the above |
| `:At(anchor)` | Any of Lume's nine anchors |
| `:Width(px)` | Overrides the theme width |
| `:Duration(s)` / `:Sticky()` | Lifetime |
| `:Priority(n)` | Higher outlives the cap — see [Queue](Queue.md) |
| `:Group(key)` | Collapse duplicates under one key |
| `:Dismissible(bool)` `:Pausable(bool)` | Player controls |
| `:Sound(asset)` | Played on show, beating any theme default |
| `:Action(text, run, tone)` | Adds a button |
| `:Literal()` | Turns markup off for this notice |
| `:Attach(target, side)` | Pins to a GuiObject |
| `:Draggable(bool)` | Lets it be dragged, with Lume's weighted drag |
| `:Shadow(bool)` | Overrides the theme's shadow for this one |
| `:Layer(name)` | Draws it on a different Lume layer |
| `:Meta(table)` | Carries anything you like; Flare never reads it |
| `:Until(clock)` | The deadline a countdown counts to |

And on a live handle: `:Refresh()`, `:Rebuild()`, `:Dismiss()`,
`:Resolve(result)`, `:Await()`, `:Alive()`.

Every one of them returns the notice and is declared as doing so, so a chain of
twenty stays typed all the way down.

## Dismissing

A notice with nothing else to click is itself the button — clicking anywhere on
it dismisses it. One that waits for an answer instead gets a close ×, because a
sticky notice with no way out is a bug. Interactive kinds get neither: their own
buttons are the way out.

```lua
Flare.Toast("Saved"):Dismissible(false):Show()  -- opt out
```
