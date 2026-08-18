<div align="center">

# Flare

**Notifications for Roblox — toasts, banners, dialogs, progress and celebration, on one queue.**

**[Read the docs](https://valencerblx.github.io/Flare/)**

</div>

---

```lua
local Flare = require(ReplicatedStorage.Flare)

Flare.toast("Saved"):ok():show()

Flare.confirm("Delete everything?")
    :danger()
    :onAccept(wipe)
    :show()

local job = Flare.progress("Uploading"):show()

job:progress(0.4)
job:finish("Uploaded")
```

No setup call, no provider to mount. The first `:show()` builds the UI; a game
that never notifies pays nothing for having Flare installed.

## Thirteen kinds

**Core** — `toast` `banner` `alert` `snackbar`
**Interactive** — `confirm` `prompt` `choice`
**Live** — `progress` `loading` `countdown`
**Rich** — `achievement` `reward` `hint`

They differ in shape, anchor and lifetime. They are driven identically.

## The builder is the handle

Every setter returns the same object, before and after `:show()`. A builder
that goes inert the moment it is shown is the wrong shape for notifications,
half of which are alive — a progress bar you fill, a countdown that ticks, a
prompt waiting on an answer.

```lua
local notice = Flare.loading("Finding a match"):show()

notice:update("Found 3 players")
notice:finish("Match starting")
```

`:await()` blocks and returns the result, so asking a question is one
expression:

```lua
if Flare.confirm("Delete your save?"):danger():await().Kind == "Accepted" then
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

## Markup

```lua
Flare.toast("*Rin* joined — press `E` to greet"):show()
```

`*bold*` `_italic_` `~strike~` `` `code` `` `[ok]tone[/ok]` `[#FF00AA]hex[/]`,
compiled to RichText. Everything that is not markup is **escaped first**, so a
player named `<b>Rin</b>` renders as that literal text rather than as bold.
`:literal()` turns parsing off for a body you did not write.

## Looks

Flare renders through [Lume](https://github.com/VALENCERBLX/Lume), vendored
inside it — there is nothing else to install. Pure black surfaces at partial
transparency, springs rather than tweens, and the same visual language as the
rest of Valence Libs.

Themes are tokens, and yours can extend the default:

```lua
Flare.defineTheme("Mine", { Color = { Ok = Color3.fromHex("#7dcfff") } }, "Default")
Flare.setTheme("Mine")
```

## Install

**Wally**

```toml
[dependencies]
Flare = "valence/flare@0.1.0"
```

**Rojo** — `default.project.json` maps `src/` to `ReplicatedStorage.Flare`.

**Neither** — paste `dist/install.luau` into the Studio command bar.

## Docs

[valencerblx.github.io/Flare](https://valencerblx.github.io/Flare/) — getting
started, every kind, markup, and the queue rules.

---

MIT. Part of **Valence Libs**, by Valence.
