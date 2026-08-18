# Markup

Bodies and titles are parsed for a small markup dialect and compiled to
`RichText`. Everything that is *not* markup is escaped first, so text you did
not write cannot inject tags.

```lua
Flare.toast("*Rin* joined — press `E` to greet"):show()
```

## Syntax

| Written | Renders |
| --- | --- |
| `*bold*` or `**bold**` | **bold** |
| `_italic_` | *italic* |
| `~strike~` | ~~strike~~ |
| `` `code` `` | monospaced, tinted |
| `[ok]…[/ok]` | tone-coloured |
| `[#FF00AA]…[/]` | any hex colour |
| `[b] [i] [u] [s]` | explicit tags, closed with `[/b]` and so on |

The tone names inside brackets are the same six as `:tone()` — `neutral`,
`info`, `ok`, `warn`, `danger`, `accent` — and they take their colours from
the active theme, so `[danger]` matches whatever red the theme uses.

## Escaping comes first

This is the part that matters. A player named `<b>Rin</b>` shows up as the
literal text `<b>Rin</b>`, not as bold text:

```lua
Flare.toast(`{player.Name} joined`):show()
```

Markup is compiled *after* escaping, so the two never race: your `*bold*`
works, their `<font>` does not.

If a body should not be interpreted at all — a chat line, a player's own
input — turn it off for that notice:

```lua
Flare.toast(message):literal():show()
```

Or globally:

```lua
Flare.Start({ Markup = false })
```

## Directly

The compiler is exported, if you want it elsewhere:

```lua
local Markup = require(ReplicatedStorage.Flare).Markup

Markup.parse("*hi*", theme.Rich)  -- "<b>hi</b>"
Markup.escape("<b>hi</b>")        -- "&lt;b&gt;hi&lt;/b&gt;"
Markup.strip("*hi* [ok]there[/ok]")  -- "hi there"
```

`strip` is what to reach for when the same string has to go somewhere without
rich text — a chat message, a log line, an analytics event.
