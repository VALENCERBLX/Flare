--!nocheck

--- The Color kind: a Lume colour picker inside a notice, resolving with the
--- Color3 rather than a hex string.

local process = require("@lune/process")

local Shim = require("./Shim")

local Flare = Shim.load("./src", "Flare")

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
	else
		failed += 1

		print(`  FAIL  {name}{if detail then ` — {detail}` else ""}`)
	end
end

local function press(notice, label: string): boolean
	for _, action in notice.Spec.Actions do
		if action.Text == label then
			if action.Run then
				action.Run(notice)
			end

			return true
		end
	end

	return false
end

Flare.Start()

local blue = Shim.Color3.fromRGB(126, 170, 255)

--// it opens on the colour it was given ---------------------------------------
local answer
local notice = Flare.Color("Trail colour", blue):Title("Pick a colour")

local thread = coroutine.create(function()
	answer = notice:Await()
end)

coroutine.resume(thread)
Shim.step()

check("the picker rendered", notice.Refs.Picker ~= nil)
check("it opened on the colour given", notice.Refs.Picker:hex() == "#7EAAFF", notice.Refs.Picker:hex())
check("two buttons", #notice.Spec.Actions == 2, `{#notice.Spec.Actions}`)
check("a colour question does not expire", Flare.Transient("Color") == false)

--// dragging writes back to the spec ------------------------------------------
local picker = notice.Refs.Picker

picker:setSilent(Shim.Color3.fromRGB(255, 0, 0))
picker:emit("changed", picker:value())

check("the spec follows the picker", notice.Spec.Color == Shim.Color3.fromRGB(255, 0, 0), tostring(notice.Spec.Color))
check("Await has not returned yet", answer == nil)

--// picking ---------------------------------------------------------------------
check("Pick is on screen", press(notice, "Pick"))

Shim.step()

check("it resolves Value", answer and answer.Kind == "Value", answer and answer.Kind)
--// the suite runs in Lune, where `typeof` is Lune's — the shim's is the one
--// that knows a shim Color3 from a plain table
local typeOf = Shim.environment.typeof

check("with a Color3, not a string", answer and typeOf(answer.Value) == "Color3", answer and typeOf(answer.Value))
check("and it is the colour dragged to", answer and answer.Value == Shim.Color3.fromRGB(255, 0, 0), tostring(answer and answer.Value))

--// cancelling --------------------------------------------------------------------
local cancelled
local second = Flare.Color("Trail colour")

thread = coroutine.create(function()
	cancelled = second:Await()
end)

coroutine.resume(thread)
Shim.step()

check("no initial colour is fine", second.Refs.Picker ~= nil)

press(second, "Cancel")
Shim.step()

check("Cancel resolves Cancelled", cancelled and cancelled.Kind == "Cancelled", cancelled and cancelled.Kind)
check("and carries no colour", cancelled and cancelled.Value == nil)

--// setting the colour on a live notice ----------------------------------------------
local third = Flare.Color("Trail colour"):Show()

Shim.step()

third:Color(Shim.Color3.fromRGB(0, 255, 0))

check("Color on a live notice reaches the picker", third.Refs.Picker:hex() == "#00FF00", third.Refs.Picker:hex())
check("and the panel was not rebuilt underneath it", third.Refs.Picker ~= nil)

third:Resolve({ Kind = "Dismissed" })

print(`Color: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
