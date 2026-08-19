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

--// a Confirm arrives with its own two buttons -------------------------------
local asked = Flare.Confirm("Switch to your other character?"):Title("Switch character?")

check("two buttons", #asked.Spec.Actions == 2, `{#asked.Spec.Actions}`)
check("the first says Confirm", asked.Spec.Actions[1].Text == "Confirm", asked.Spec.Actions[1].Text)
check("the second says Cancel", asked.Spec.Actions[2].Text == "Cancel", asked.Spec.Actions[2].Text)
check("the first is primary", asked.Spec.Actions[1].Primary == true)

--// and still resolve the way a Confirm does ---------------------------------
local answer
local thread = coroutine.create(function()
	answer = asked:Await()
end)

coroutine.resume(thread)
Shim.step()

check("Await blocks until answered", answer == nil)
check("Confirm is on screen", press("Confirm"))

Shim.step()

check("Await returned", answer ~= nil)
check("Confirm accepts", answer and answer.Kind == "Accepted", answer and answer.Kind)
check("Accepted carries true", answer and answer.Value == true)

--// the other button ----------------------------------------------------------
local declined
local second = Flare.Confirm("Switch to your other character?")

thread = coroutine.create(function()
	declined = second:Await()
end)

coroutine.resume(thread)
Shim.step()
press("Cancel")
Shim.step()

check("Cancel cancels", declined and declined.Kind == "Cancelled", declined and declined.Kind)
check("Cancelled carries false", declined and declined.Value == false)

--// dismissing without answering ------------------------------------------------
local ignored
local third = Flare.Confirm("Switch to your other character?")

thread = coroutine.create(function()
	ignored = third:Await()
end)

coroutine.resume(thread)
Shim.step()
third:Resolve({ Kind = "Dismissed" })
Shim.step()

check("a dismissed question still returns", ignored ~= nil)
check("dismissed is neither yes nor no", ignored and ignored.Value ~= true, ignored and tostring(ignored.Value))

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

--// a description gets its own line ---------------------------------------------
local list = choice.Refs.List :: any

check("described rows stack", list.stacked == true)
check("a stacked row is taller than a plain one", list:span() > list.rowHeight, `{list:span()} vs {list.rowHeight}`)

if rows and rows[1] then
	check(
		"the text block runs down the row",
		tostring(rows[1].lines.FillDirection) == "Enum.FillDirection.Vertical",
		tostring(rows[1].lines.FillDirection)
	)
	check("the description sits under the title", rows[1].detail.LayoutOrder > rows[1].title.LayoutOrder)
	check("both lines are visible", rows[1].detail.Visible == true)
end

--// resolving tears the panel down, so everything about the rendered row has
--// to be looked at before the click, not after
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

--// the stack has a cap, and a queued notice has no panel yet — clear the
--// screen first so this one is actually rendered
for _, notice in Flare.Live() do
	notice:Resolve({ Kind = "Dismissed" })
end

Shim.advance(2)

simple:Show()
Shim.step()

check("the list rendered once the screen was clear", simple.Refs.List ~= nil)

local plain = simple.Refs.List :: any

check("rows without descriptions stay inline", plain.stacked == false)
check("and stay one row tall", plain:span() == plain.rowHeight)

simple:Resolve({ Kind = "Dismissed" })

print(`Ask: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
