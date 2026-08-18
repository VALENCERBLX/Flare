--!strict

--- Theme registry. Resolves a name to a token table.
---
--- Extending never mutates the parent, so a game can register a variant
--- without leaking its overrides into the default.
--- @section Themes

local Default = require(script.Default)

local Themes = {}

export type Theme = typeof(Default)

local registry: { [string]: Theme } = { default = Default }

local function isPlain(value: any): boolean
	--// Color3 and friends are userdata, so a plain table really is a token
	--// group worth recursing into
	return type(value) == "table" and getmetatable(value) == nil
end

local function merge(base: { [string]: any }, overrides: { [string]: any }?): { [string]: any }
	local out: { [string]: any } = {}

	for key, value in base do
		out[key] = if isPlain(value) then merge(value, nil) else value
	end

	for key, value in overrides or {} do
		if isPlain(value) and isPlain(out[key]) then
			out[key] = merge(out[key], value)
		else
			out[key] = value
		end
	end

	return out
end

--- Looks a theme up. Unknown names warn and fall back rather than erroring, so
--- a bad saved setting cannot stop notices appearing.
function Themes.Resolve(name: string?): Theme
	if not name then
		return Default
	end

	local found = registry[string.lower(name)]

	if not found then
		warn(`[Flare] unknown theme '{name}', using Default`)

		return Default
	end

	return found
end

function Themes.Register(name: string, tokens: { [string]: any }, extends: string?): Theme
	local base = if extends then Themes.Resolve(extends) else Default
	local built = merge(base :: any, tokens) :: Theme

	built.Name = name
	registry[string.lower(name)] = built

	return built
end

function Themes.List(): { string }
	local names = {}

	for name in registry do
		table.insert(names, name)
	end

	table.sort(names)

	return names
end

Themes.Default = Default

return Themes
