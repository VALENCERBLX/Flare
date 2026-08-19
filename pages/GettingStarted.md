# Getting Started

Flare is one require and one call.

```lua
local Flare = require(game:GetService("ReplicatedStorage").Flare)

Flare.Toast("Saved"):Ok():Show()
```

Nothing is built until the first `:Show()` — requiring Flare creates no
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
Flare.Toast("Connection lost")
    :Warn()
    :Icon("rbxassetid://1234567")
    :Duration(8)
    :Priority(5)
    :Show()
```

The builder and the live handle are the same object. Setters keep working
after `:Show()`, which is the point — half of these notices are alive:

```lua
local job = Flare.Progress("Uploading"):Show()

for index = 1, 10 do
    job:Progress(index / 10)
    task.wait(0.2)
end

job:Finish("Uploaded")
```

## Asking a question

`:Await()` blocks the calling thread and returns a `Result`. It shows the
notice first if you have not, so it is one expression rather than two:

```lua
local answer = Flare.Confirm("Delete your save?"):Danger():Await()

if answer.Kind == "Accepted" then
    wipe()
end
```

Or stay asynchronous with callbacks:

```lua
Flare.Confirm("Delete your save?")
    :Danger()
    :OnAccept(wipe)
    :OnCancel(function()
        Flare.Toast("Nothing was deleted"):Show()
    end)
    :Show()
```

## Configuring

Optional — the first notice starts Flare implicitly with the defaults.

```lua
Flare.Start({
    Theme = "Default",       -- a registered theme name
    Tokens = { … },          -- one-off token overrides on top of it

    Anchor = "bottomRight",  -- where notices go when they do not say
    Max = 4,                 -- on screen per anchor; the rest wait
    Duration = 5,            -- seconds, for kinds that fade
    Durations = {            -- or per kind
        Toast = 4,
        Banner = 8,
    },

    Group = true,            -- collapse duplicates into one with a count
    Pause = true,            -- freeze the countdown while hovered
    Markup = true,           -- parse *bold* and friends in bodies
    Sound = true,            -- or an asset id, to give every notice that sound
    Sounds = { Danger = "rbxassetid://…" },  -- per tone, or per kind
    Icons = { Ok = "rbxassetid://…" },       -- per tone, or per kind
    Dismissible = true,      -- click to dismiss, × on the sticky ones
    Draggable = false,       -- let them be dragged around
    Shadow = true,          -- or a table: { Spread = 14, Transparency = 0.9 }

    Width = 320,
    Gap = 8,                 -- between notices
    Inset = 24,              -- between the stack and the screen edge

    App = nil,               -- render into a Lume app you already have
    Gui = nil,               -- or a ScreenGui you own
    DisplayOrder = 9000,
})
```

Call it again whenever you like — it merges, so changing one setting later does
not reset the rest, and a raised `Max` reaches queues that already exist.

An option Flare does not recognise warns, and names the closest one it does:

```
[Flare] Start does not have an option called "Anchr", so it was ignored. Did you mean "Anchor"?
```

A setting that quietly does nothing is worse than one that complains, so a
misspelled key says so in the output rather than leaving you to wonder why the
notices are still in the corner you did not ask for.

## Types

Everything is typed, so the whole chain autocompletes and a typo is a red
squiggle rather than a runtime surprise:

```lua
local Flare = require(ReplicatedStorage.Flare)

local function announce(text: string): Flare.Notice
    return Flare.Toast(text):Ok():Show()
end

local function ask(question: string): boolean
    local result: Flare.Result = Flare.Confirm(question):Await()

    return result.Kind == "Accepted"
end
```

`Flare.Notice`, `Flare.Result`, `Flare.Tone`, `Flare.Kind`, `Flare.Anchor`,
`Flare.Theme`, `Flare.Spec` and `Flare.FlareOptions` are all exported. Every
setter is declared as returning `Notice`, so the chain stays typed however long
it gets.

## Server to client

Flare draws on the client, so a server that wants to notify somebody sends
them a message and lets their client call Flare. A remote event and four lines
is the whole pattern:

```lua
-- server
Notify:FireClient(player, "ok", "Purchase complete")

-- client
Notify.OnClientEvent:Connect(function(tone, body)
    Flare.Toast(body):Tone(tone):Show()
end)
```

Keep the body server-authored and Flare will still escape it — see
[Markup](Markup.md) — so a player name with a `<` in it cannot inject anything.
