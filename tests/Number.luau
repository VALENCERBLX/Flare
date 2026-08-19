--!nocheck

--- The Number kind: a Lume stepper inside a notice, resolving with the number.

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

--// it opens on the number it was given ----------------------------------------
local answer
local notice = Flare.Number("How many?", 3):Range(1, 99):Title("Buy")

local thread = coroutine.create(function()
	answer = notice:Await()
end)

coroutine.resume(thread)
Shim.step()

check("the stepper rendered", notice.Refs.Stepper ~= nil)
check("it opened on the number given", notice.Refs.Stepper:value() == 3, `{notice.Refs.Stepper:value()}`)
check("the range took", notice.Refs.Stepper.minimum == 1 and notice.Refs.Stepper.maximum == 99)
check("a number question does not expire", Flare.Transient("Number") == false)

--// stepping writes back to the spec ---------------------------------------------
local stepper = notice.Refs.Stepper

stepper.refs.plus.MouseButton1Down:Fire()
stepper.refs.plus.MouseButton1Up:Fire()

check("the spec follows the stepper", notice.Spec.Number == 4, `{notice.Spec.Number}`)
check("Await has not returned yet", answer == nil)

--// the range is honoured ----------------------------------------------------------
for _ = 1, 10 do
	stepper.refs.minus.MouseButton1Down:Fire()
	stepper.refs.minus.MouseButton1Up:Fire()
end

check("it will not go below the floor", notice.Spec.Number == 1, `{notice.Spec.Number}`)

--// answering -----------------------------------------------------------------------
check("Confirm is on screen", press(notice, "Confirm"))

Shim.step()

check("it resolves Value", answer and answer.Kind == "Value", answer and answer.Kind)
check("with the number", answer and answer.Value == 1, tostring(answer and answer.Value))

--// cancelling -----------------------------------------------------------------------
local cancelled
local second = Flare.Number("How many?")

thread = coroutine.create(function()
	cancelled = second:Await()
end)

coroutine.resume(thread)
Shim.step()

check("no initial number is fine", second.Refs.Stepper ~= nil)
check("and the spec still carries one", second.Spec.Number == 0, tostring(second.Spec.Number))

press(second, "Cancel")
Shim.step()

check("Cancel resolves Cancelled", cancelled and cancelled.Kind == "Cancelled", cancelled and cancelled.Kind)
check("and carries no number", cancelled and cancelled.Value == nil)

--// setters on a live notice ------------------------------------------------------------
local third = Flare.Number("How many?"):Show()

Shim.step()

third:Range(0, 5):Step(1):Number(4)

check("Number on a live notice reaches the stepper", third.Refs.Stepper:value() == 4, `{third.Refs.Stepper:value()}`)
check("Range reaches it too", third.Refs.Stepper.maximum == 5, `{third.Refs.Stepper.maximum}`)
check("and the panel was not rebuilt underneath it", third.Refs.Stepper ~= nil)

third:Resolve({ Kind = "Dismissed" })

print(`Number: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
