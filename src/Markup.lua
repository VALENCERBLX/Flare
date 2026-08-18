--!strict

--- A small markup language that compiles to Roblox RichText.
---
--- Roblox already understands RichText, so why a layer on top: because a
--- notification body is usually written by somebody who is not thinking about
--- markup at all, and `<font color="#FF7E7E">` in the middle of a sentence is
--- a hostile thing to ask for. This is the shorthand, and — more importantly —
--- everything that is *not* markup is escaped, so a player's name containing
--- `<` cannot break the label or inject tags.
---
--- ```
--- *bold*            **also bold**
--- _italic_          ~strike~
--- `code`            mono, dimmed
--- [ok]green[/ok]    any tone name
--- [#FF00AA]raw hex[/]
--- [b]…[/b] [i]…[/i] [u]…[/u]
--- ```
---
--- Unclosed tags are closed at the end rather than producing invalid RichText,
--- because a truncated string is a normal thing to be handed.
--- @section Core

local Markup = {}

local ESCAPES: { [string]: string } = {
	["&"] = "&amp;",
	["<"] = "&lt;",
	[">"] = "&gt;",
	['"'] = "&quot;",
	["'"] = "&apos;",
}

--- Escapes a string so RichText renders it literally.
function Markup.escape(text: string): string
	return (string.gsub(text, "[&<>\"']", ESCAPES))
end

--- Strips every tag, leaving what a player actually sees. Used for measuring
--- and for logging, where markup is noise.
function Markup.strip(text: string): string
	--// parsed first, so inline forms like *bold* become tags that the next
	--// pass removes. Bracket forms are then stripped directly rather than
	--// through the palette, because strip must not depend on a theme being
	--// loaded to know that `[ok]` is markup
	local without = string.gsub(Markup.parse(text, {}), "<[^<>]->", "")

	without = string.gsub(without, "%[/?[%w#]*%]", "")

	without = string.gsub(without, "&lt;", "<")
	without = string.gsub(without, "&gt;", ">")
	without = string.gsub(without, "&quot;", '"')
	without = string.gsub(without, "&apos;", "'")
	without = string.gsub(without, "&amp;", "&")

	return without
end

--// locals ---------------------------------------------------------------------
local INLINE = {
	{ pattern = "%*%*(.-)%*%*", open = "<b>", close = "</b>" },
	{ pattern = "%*(.-)%*", open = "<b>", close = "</b>" },
	{ pattern = "__(.-)__", open = "<u>", close = "</u>" },
	{ pattern = "_(.-)_", open = "<i>", close = "</i>" },
	{ pattern = "~(.-)~", open = "<s>", close = "</s>" },
}

--- Applies a paired-delimiter rule without letting the replacement be re-scanned.
local function inline(text: string, pattern: string, open: string, close: string): string
	return (string.gsub(text, pattern, function(inner)
		return open .. inner .. close
	end))
end

--// public api ------------------------------------------------------------------
--- Compiles markup into RichText.
---
--- `palette` maps tone names to hex, so `[ok]…[/ok]` picks up whatever the
--- current theme calls "ok". An unknown name is left as literal text rather
--- than emitting a tag with a nil colour.
function Markup.parse(text: string, palette: { [string]: string }?): string
	local colours = palette or {}
	local out = Markup.escape(tostring(text))

	--// named tone spans: [ok]…[/ok]
	for name, hex in colours do
		out = string.gsub(out, `%[{name}%](.-)%[/{name}%]`, function(inner)
			return `<font color="{hex}">{inner}</font>`
		end)
	end

	--// raw hex spans: [#FF00AA]…[/]
	out = string.gsub(out, "%[(#%x%x%x%x%x%x)%](.-)%[/%]", function(hex, inner)
		return `<font color="{hex}">{inner}</font>`
	end)

	--// explicit tags, for anybody who wants them
	out = string.gsub(out, "%[b%](.-)%[/b%]", "<b>%1</b>")
	out = string.gsub(out, "%[i%](.-)%[/i%]", "<i>%1</i>")
	out = string.gsub(out, "%[u%](.-)%[/u%]", "<u>%1</u>")
	out = string.gsub(out, "%[s%](.-)%[/s%]", "<s>%1</s>")

	--// `code`
	local code = colours.code or colours.muted

	out = string.gsub(out, "`(.-)`", function(inner)
		if code then
			return `<font face="Code" color="{code}">{inner}</font>`
		end

		return `<font face="Code">{inner}</font>`
	end)

	for _, rule in INLINE do
		out = inline(out, rule.pattern, rule.open, rule.close)
	end

	return out
end

--- Wraps a whole string in one colour, escaping it first.
function Markup.colour(text: string, hex: string): string
	return `<font color="{hex}">{Markup.escape(text)}</font>`
end

return Markup
