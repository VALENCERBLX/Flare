# Kinds

Thirteen kinds, four groups. They differ in shape, anchor and lifetime — not
in how you drive them.

## The core set

Transient, cornered, and gone on their own.

```lua
Flare.toast("Saved"):ok():show()
Flare.banner("Server restarting in 5 minutes"):warn():show()
Flare.alert("You were kicked from the party"):danger():show()
Flare.snackbar("Message deleted", "Undo", restore):show()
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
Flare.snackbar("Message deleted", "Undo", function(notice)
    restore()

    notice:update("Restored"):ok()

    return false  -- keep it open to show the new text
end):show()
```

Any action callback returning `false` keeps the notice open. Anything else
closes it.

## Interactive

They ask something, so none of them expire.

```lua
local answer = Flare.confirm("Delete everything?"):danger():await()

local name = Flare.prompt("Name your save")
    :placeholder("Slot 1")
    :default("Autosave")
    :await()

local pick = Flare.choice("Where to?", {
    "Spawn",
    { Id = "arena", Text = "Arena", Description = "PvP enabled" },
}):await()
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
local job = Flare.progress("Uploading"):show()

job:progress(0.4)     -- 0 to 1
job:progress(75)      -- or a percentage
job:finish("Uploaded")
job:fail("Upload failed")

local wait = Flare.loading("Finding a match"):show()
wait:finish("Match found")

Flare.countdown("Round ends", 90):show()
```

`progress` and `loading` are sticky until you finish them; `finish` tones the
notice green, fills the bar and gives it two seconds to be read. `countdown`
paints a clock — `1:30`, then `45s` under a minute — and expires when it
reaches zero.

## Rich

Big, centred, and allowed to interrupt.

```lua
Flare.achievement("First Blood", "Win a round without dying")
    :icon("rbxassetid://1234567")
    :priority(10)
    :show()

Flare.reward("Loot", "+50 coins")
    :image("rbxassetid://7654321")
    :show()

Flare.hint("Click here to equip", button, "top"):show()
```

`hint` pins itself to a `GuiObject` instead of a screen corner, so it points
at the thing it is talking about. The side is `top`, `bottom`, `left` or
`right`.

## Common setters

Every kind takes all of these.

| Setter | What it does |
| --- | --- |
| `:title(text)` | A heading above the body |
| `:body(text)` / `:update(text)` | The body, live-updatable |
| `:icon(asset)` / `:image(asset)` | A small icon, or a large image |
| `:tone(name)` | `neutral` `info` `ok` `warn` `danger` `accent` |
| `:info()` `:ok()` `:warn()` `:danger()` `:accent()` | Shorthands for the above |
| `:at(anchor)` | Any of Lume's nine anchors |
| `:width(px)` | Overrides the theme width |
| `:duration(s)` / `:sticky()` | Lifetime |
| `:priority(n)` | Higher outlives the cap — see [Queue](Queue.md) |
| `:group(key)` | Collapse duplicates under one key |
| `:dismissible(bool)` `:pausable(bool)` | Player controls |
| `:sound(asset)` | Played on show |
| `:action(text, run, tone)` | Adds a button |
| `:literal()` | Turns markup off for this notice |
| `:attach(target, side)` | Pins to a GuiObject |

And on a live handle: `:refresh()`, `:rebuild()`, `:dismiss()`,
`:resolve(result)`, `:await()`, `:alive()`.
