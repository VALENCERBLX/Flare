--!nocheck

--- Asking a question and getting an answer back, both ways round: a `Confirm`
--- with two buttons, and a `Choice` with two rows. `:Await()` blocks the
--- calling thread, which is the whole point of it and also the part most
--- likely to quietly never return.

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

--- Presses the button with this label on the first live notice.
local function press(label: string): boolean
	for _, notice in Flare.Live() do
		if notice.Shown and not notice.Done then
			for _, action in notice.Spec.Actions do
				if action.Text == label then
					if action.Run then
						action.Run(notice)
					end

					return true
				end
			end
		end
	end

	return false
end

Flare.Start()

--// the buttons say what you told them to ------------------------------------
local asked = Flare.Confirm("Switch to your other character?"):Title("Switch character?"):Labels("Switch", "Stay")

check("first button relabelled", asked.Spec.Actions[1].Text == "Switch", asked.Spec.Actions[1].Text)
check("second button relabelled", asked.Spec.Actions[2].Text == "Stay", asked.Spec.Actions[2].Text)
check("still only two buttons", #asked.Spec.Actions == 2, `{#asked.Spec.Actions}`)
check("the first is still primary", asked.Spec.Actions[1].Primary == true)

--// and still resolve the way a Confirm does ---------------------------------
local answer
local thread = coroutine.create(function()
	answer = asked:Await()
end)

coroutine.resume(thread)
Shim.step()

check("Await blocks until answered", answer == nil)
check("Switch is on screen", press("Switch"))

Shim.step()

check("Await returned", answer ~= nil)
check("relabelling kept Accepted", answer and answer.Kind == "Accepted", answer and answer.Kind)
check("relabelling kept the value", answer and answer.Value == true)

--// the other button ----------------------------------------------------------
local declined
local second = Flare.Confirm("Switch to your other character?"):Labels("Switch", "Stay")

thread = coroutine.create(function()
	declined = second:Await()
end)

coroutine.resume(thread)
Shim.step()
press("Stay")
Shim.step()

check("Stay cancels", declined and declined.Kind == "Cancelled", declined and declined.Kind)
check("Cancelled carries false", declined and declined.Value == false)

--// dismissing without answering ------------------------------------------------
local ignored
local third = Flare.Confirm("Switch to your other character?"):Labels("Switch", "Stay")

thread = coroutine.create(function()
	ignored = third:Await()
end)

coroutine.resume(thread)
Shim.step()
third:Resolve({ Kind = "Dismissed" })
Shim.step()

check("a dismissed question still returns", ignored ~= nil)
check("dismissed is neither yes nor no", ignored and ignored.Value ~= true, ignored and tostring(ignored.Value))

--// fewer names than buttons ----------------------------------------------------
local partial = Flare.Confirm("Sure?"):Labels("Yes")

check("one name relabels one button", partial.Spec.Actions[1].Text == "Yes")
check("the rest are left alone", partial.Spec.Actions[2].Text == "Cancel", partial.Spec.Actions[2].Text)

--// a Confirm never expires on its own --------------------------------------------
local patient = Flare.Confirm("Still here?"):Show()

Shim.advance(60)

check("a question waits as long as it takes", patient.Alive and patient:Alive())

--// a Choice asks the same question with rows instead of buttons ---------------
local picked
local choice = Flare.Choice("Would you like to switch your character?", {
	{ Id = "switch", Text = "Switch", Description = "Swap to your other character" },
	{ Id = "stay", Text = "Stay", Description = "Keep the one you have" },
}):Title("Switch character?"):Accent()

thread = coroutine.create(function()
	picked = choice:Await()
end)

coroutine.resume(thread)
Shim.step()

check("two rows", #choice.Spec.Choices == 2, `{#choice.Spec.Choices}`)
check("a string id survives the table form", choice.Spec.Choices[1].Id == "switch")
check("a Choice has no buttons of its own", #choice.Spec.Actions == 0, `{#choice.Spec.Actions}`)
check("the list rendered", choice.Refs.List ~= nil)

--// click the first row the way a player would, through the button Lume built
--// rather than by calling Resolve — the wiring between them is the part worth
--// testing, and it has been wrong before
local rows = choice.Refs.List and (choice.Refs.List :: any).rows

check("rows exist as instances", rows ~= nil and #rows >= 2, if rows then `{#rows}` else "none")

if rows and rows[1] then
	rows[1].button.Activated:Fire()
end

Shim.step()

check("clicking a row answers", picked ~= nil)
check("a Choice resolves Value", picked and picked.Kind == "Value", picked and picked.Kind)
check("the value is the row id", picked and picked.Value == "switch", picked and tostring(picked.Value))

--// bare strings are their own ids ----------------------------------------------
local simple = Flare.Choice("Pick one", { "Switch", "Stay" })

check("a bare string is its own id", simple.Spec.Choices[1].Id == "Switch")
check("and its own text", simple.Spec.Choices[1].Text == "Switch")

simple:Resolve({ Kind = "Dismissed" })

print(`Ask: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
