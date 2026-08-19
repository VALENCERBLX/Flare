<div align="center">

# Flare

**Notifications for Roblox — toasts, banners, dialogs, progress and celebration, on one queue.**

**[Read the docs](https://valencerblx.github.io/Flare/)**

</div>

---

```lua
local Flare = require(ReplicatedStorage.Flare)

Flare.Toast("Saved"):Ok():Show()

Flare.Confirm("Delete everything?")
    :Danger()
    :OnAccept(wipe)
    :Show()

local job = Flare.Progress("Uploading"):Show()

job:Progress(0.4)
job:Finish("Uploaded")
```

No setup call, no provider to mount. The first `:Show()` builds the UI; a game
that never notifies pays nothing for having Flare installed.

## Fifteen kinds

**Core** — `toast` `banner` `alert` `snackbar`
**Interactive** — `confirm` `prompt` `choice` `color` `number`
**Live** — `progress` `loading` `countdown`
**Rich** — `achievement` `reward` `hint`

They differ in shape, anchor and lifetime. They are driven identically.

## The builder is the handle

Every setter returns the same object, before and after `:Show()`. A builder
that goes inert the moment it is shown is the wrong shape for notifications,
half of which are alive — a progress bar you fill, a countdown that ticks, a
prompt waiting on an answer.

```lua
local notice = Flare.Loading("Finding a match"):Show()

notice:Update("Found 3 players")
notice:Finish("Match starting")
```

`:Await()` blocks and returns the result, so asking a question is one
expression:

```lua
if Flare.Confirm("Delete your save?"):Danger():Await().Kind == "Accepted" then
    wipe()
end
```

## The queue

One queue per anchor, and four rules that matter in this order:

- **Priority.** Higher sorts nearer the front and displaces the least
  important notice on screen rather than queueing behind it. Displaced, not
  dropped — it goes to the front of the backlog.
- **Grouping.** Three identical events become one notice carrying `×3`, and
  the merge restarts its clock.
- **Cap and overflow.** Four per anchor by default; the rest wait for a slot.
- **Pause.** Hovering freezes the countdown, because a toast that vanishes as
  you reach for its button is worse than no toast.

The queue draws nothing. It decides membership and order and hands that to the
renderer, which is why every one of those rules is tested without a DataModel.

## Typed all the way down

```lua
local function announce(text: string): Flare.Notice
    return Flare.Toast(text):Ok():Show()
end
```

Every setter is declared as returning `Notice`, so a chain stays typed however
long it gets, and `Flare.Notice`, `Flare.Result`, `Flare.Tone`, `Flare.Anchor`,
`Flare.Theme` and `Flare.FlareOptions` are all exported for your own signatures.

## Markup

```lua
Flare.Toast("*Rin* joined — press `E` to greet"):Show()
```

`*bold*` `_italic_` `~strike~` `` `code` `` `[ok]tone[/ok]` `[#FF00AA]hex[/]`,
compiled to RichText. Everything that is not markup is **escaped first**, so a
player named `<b>Rin</b>` renders as that literal text rather than as bold.
`:Literal()` turns parsing off for a body you did not write.

## Looks

Flare renders through [Lume](https://github.com/VALENCERBLX/Lume), vendored
inside it — there is nothing else to install. Pure black surfaces at partial
transparency, springs rather than tweens, and the same visual language as the
rest of Valence Libs.

Themes are tokens — colours, fonts, sizes, radii, transparencies, motion specs,
durations, shadows, per-tone icons and sounds — and yours can extend the
default, one line at a time:

```lua
Flare.DefineTheme("Mine", { Color = { Ok = Color3.fromHex("#7dcfff") } }, "Default")
Flare.SetTheme("Mine")
```

Shadows are a tight contact shadow rather than Lume's console-sized one, and
tunable per theme, per session or per notice.

## Install

**Wally**

```toml
[dependencies]
Flare = "valence/flare@0.2.0"
```

**Rojo** — `default.project.json` maps `src/` to `ReplicatedStorage.Flare`.

**Neither** — paste `dist/install.luau` into the Studio command bar.

## Tests

```sh
lune run scripts/test
```

`tests/Shim.luau` is a small Roblox stand-in — instances with a real tree,
events, the datatypes Lume touches, and a clock you step by hand — so the suites
and the shipped examples actually **run** rather than merely compiling. Every
bug worth catching in this library so far has been invisible to a syntax check.

## Docs

[valencerblx.github.io/Flare](https://valencerblx.github.io/Flare/) — getting
started, every kind, markup, and the queue rules.

---

MIT. Part of **Valence Libs**, by Valence.
