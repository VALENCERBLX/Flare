# Getting Started

Flare is one require and one call.

```lua
local Flare = require(game:GetService("ReplicatedStorage").Flare)

Flare.toast("Saved"):ok():show()
```

Nothing is built until the first `:show()` — requiring Flare creates no
instances, so a game that never notifies pays nothing for having it installed.

## Install

Flare ships self-contained: Lume is vendored inside it, so there is nothing
else to install.

**With Rojo.** `default.project.json` maps `src/` to
`ReplicatedStorage.Flare`. Sync and you are done.

**With Wally.**

```toml
[dependencies]
Flare = "valence/flare@0.1.0"
```

**Without either.** Paste `dist/install.luau` into the Studio **command bar**
(not a script — `ModuleScript.Source` is not writable from one).

## The shape of every notice

Every kind returns the same object, and every setter returns it again:

```lua
Flare.toast("Connection lost")
    :warn()
    :icon("rbxassetid://1234567")
    :duration(8)
    :priority(5)
    :show()
```

The builder and the live handle are the same object. Setters keep working
after `:show()`, which is the point — half of these notices are alive:

```lua
local job = Flare.progress("Uploading"):show()

for index = 1, 10 do
    job:progress(index / 10)
    task.wait(0.2)
end

job:finish("Uploaded")
```

## Asking a question

`:await()` blocks the calling thread and returns a `Result`. It shows the
notice first if you have not, so it is one expression rather than two:

```lua
local answer = Flare.confirm("Delete your save?"):danger():await()

if answer.Kind == "Accepted" then
    wipe()
end
```

Or stay asynchronous with callbacks:

```lua
Flare.confirm("Delete your save?")
    :danger()
    :onAccept(wipe)
    :onCancel(function()
        Flare.toast("Nothing was deleted"):show()
    end)
    :show()
```

## Configuring

Optional — the first notice starts Flare implicitly with the defaults.

```lua
Flare.Start({
    Theme = "Default",
    Max = 4,          -- notices on screen per anchor
    Duration = 5,     -- seconds, for kinds that fade
    Group = true,     -- collapse duplicates into one with a count
    Pause = true,     -- freeze the countdown while hovered
    Markup = true,    -- parse *bold* and friends in bodies
    Sound = true,
})
```

Pass `App` to render into a Lume app you already have, or `Gui` to render into
a `ScreenGui` you own.

## Server to client

Flare draws on the client, so a server that wants to notify somebody sends
them a message and lets their client call Flare. A remote event and four lines
is the whole pattern:

```lua
-- server
Notify:FireClient(player, "ok", "Purchase complete")

-- client
Notify.OnClientEvent:Connect(function(tone, body)
    Flare.toast(body):tone(tone):show()
end)
```

Keep the body server-authored and Flare will still escape it — see
[Markup](Markup.md) — so a player name with a `<` in it cannot inject anything.
