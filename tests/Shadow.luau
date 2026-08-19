--!nocheck

--- No Notice field may be named after a Notice method.
---
--- An instance field shadows its metatable, so a field called `Color` would
--- make `notice:Color(…)` fail with *attempt to call a Color3 value* — which is
--- why the spec fields live on `notice.Spec` and the handler lists are called
--- `ShowHandlers` and `ResolveHandlers` rather than `OnShow` and `OnResolve`.
---
--- This has bitten four times across these libraries. It is mechanical, so it
--- gets checked mechanically.

local process = require("@lune/process")

local Shim = require("./Shim")

local Flare = Shim.load("./src", "Flare")

Flare.Start()

local passed, failed = 0, 0

--- Every method reachable through the metatable chain.
local function methods(class: any): { [string]: boolean }
	local found: { [string]: boolean } = {}
	local seen: { [any]: boolean } = {}
	local current = class

	while type(current) == "table" and not seen[current] do
		seen[current] = true

		for key, value in current do
			if type(value) == "function" and key ~= "__index" then
				found[key] = true
			end
		end

		local meta = getmetatable(current)

		current = if type(meta) == "table" then rawget(meta, "__index") else nil
	end

	return found
end

--// one of every kind, since a builder may add fields the constructor does not
local KINDS = {
	"Toast",
	"Banner",
	"Alert",
	"Snackbar",
	"Confirm",
	"Prompt",
	"Choice",
	"Color",
	"Number",
	"Rate",
	"Progress",
	"Loading",
	"Countdown",
	"Achievement",
	"Reward",
	"Hint",
}

for _, kind in KINDS do
	local notice = Flare[kind]("body")
	local reachable = methods(getmetatable(notice))
	local collisions = {}

	for key in notice do
		if reachable[key] then
			table.insert(collisions, key)
		end
	end

	if #collisions > 0 then
		failed += 1

		print(`  FAIL  {kind} has fields shadowing its methods: {table.concat(collisions, ", ")}`)
	else
		passed += 1
	end

	notice:Resolve({ Kind = "Dismissed" })
end

--// the spec is the other half: every kind's builder reads it by name, and a
--// spec key that matches a method is the same trap one level down
local spec = Flare.Toast("body").Spec
local reachable = methods(getmetatable(Flare.Toast("body")))
local shadowed = {}

for key in spec do
	if reachable[key] then
		table.insert(shadowed, key)
	end
end

--// this one is *allowed* — Spec is a separate table, so `Spec.Color` and
--// `Notice.Color` cannot collide. The check exists to say so out loud, and to
--// fail if the spec is ever flattened onto the notice itself
print(`  note  {#shadowed} spec keys share a method name: {table.concat(shadowed, ", ")}`)

print(`Shadow: {passed} kinds clean, {failed} with collisions`)

if failed > 0 then
	process.exit(1)
end
