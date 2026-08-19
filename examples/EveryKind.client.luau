--!strict

--- Every kind of Flare notice, and every setter worth seeing, in the order
--- they are worth learning.
---
--- Drop it in `StarterPlayer/StarterPlayerScripts` next to a synced Flare and
--- watch it run. Each section prints its name to the output, so you can follow
--- along, and the whole thing is one linear script — no state machine, because
--- `:Await()` blocks and that is the point of it.
---
--- The one rule to take away: **kinds that ask a question never expire.**
--- Confirm, Prompt, Choice, Alert, Progress and Loading all sit there until
--- something resolves them. Fire them in a loop without answering and the
--- queue fills up, exactly as it should.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flare = require(ReplicatedStorage:WaitForChild("Flare"))

--// configuration ------------------------------------------------------------------
Flare.Start({
	Anchor = "bottomRight",
	Max = 4,
	Duration = 5,

	--// or per kind, when one number is not enough
	Durations = {
		Toast = 4,
		Banner = 8,
	},

	Group = true,
	Pause = true,
	Markup = true,
	Dismissible = true,
	Shadow = true,

	Gap = 8,
	Inset = 24,
})

local function section(name: string)
	print(`\n—— {name} ——`)

	task.wait(1)
end

local function beat(seconds: number?)
	task.wait(seconds or 2.5)
end

task.wait(3)

--// 1. tones ------------------------------------------------------------------------
--- Six tones. A tone is semantic, not a colour: the theme decides what danger
--- looks like, you only say that this is bad news.
section("tones")

Flare.Toast("Neutral — nothing special"):Show()
beat(0.4)
Flare.Toast("Info — something happened"):Info():Show()
beat(0.4)
Flare.Toast("Ok — it worked"):Ok():Show()
beat(0.4)
Flare.Toast("Warn — it nearly did not"):Warn():Show()
beat(0.4)
Flare.Toast("Danger — it did not"):Danger():Show()
beat(0.4)
Flare.Toast("Accent — look at this"):Accent():Show()

beat(4)

--// 2. titles, icons and images ------------------------------------------------------
section("titles, icons, images")

Flare.Toast("Your inventory is full")
	:Title("Cannot pick that up")
	:Warn()
	:Show()

beat()

Flare.Toast("Autosaved to slot 1")
	:Icon("rbxasset://textures/ui/GuiImagePlaceholder.png")
	:Ok()
	:Show()

beat()

Flare.Reward("Chest opened", "+50 coins")
	:Image("rbxasset://textures/ui/GuiImagePlaceholder.png")
	:Show()

beat(4)

--// 3. markup ------------------------------------------------------------------------
--- Everything that is not markup is escaped first, so text you did not write
--- cannot inject tags. The last line proves it.
section("markup")

Flare.Toast("*Rin* joined — press `E` to greet"):Show()
beat(1)
Flare.Toast("_italic_, ~struck~, and [ok]tone coloured[/ok]"):Show()
beat(1)
Flare.Toast("[#FF00AA]any hex you like[/]"):Show()
beat(1)

--// renders as literal text, not as bold
Flare.Toast("<b>not actually bold</b>"):Show()
beat(1)

--// and for a body somebody else wrote, turn parsing off entirely
Flare.Toast("*stays literal*"):Literal():Show()

beat(4)

--// 4. the core set -------------------------------------------------------------------
section("banner, alert, snackbar")

--- A bar across an edge, for something that affects the whole session.
Flare.Banner("Server restarting in 5 minutes"):Warn():Show()

beat(3)

--- Sticky on purpose: the kind you reach for when they must have seen it. It
--- gets a close × because a sticky notice with no way out is a bug.
local mustRead = Flare.Alert("You were removed from the party"):Danger():Show()

beat(3)
mustRead:Dismiss()

--- "Deleted. **Undo**" — the whole reason the kind exists. Returning false from
--- an action keeps the notice open, so it can report what it did.
Flare.Snackbar("Message deleted", "Undo", function(notice)
	notice:Update("Restored"):Ok()

	return false
end):Show()

beat(4)

--// 5. asking questions ------------------------------------------------------------------
--- `:Await()` blocks this thread and hands back a Result. It shows the notice
--- first if you have not, so asking is one expression.
section("confirm")

local answer: Flare.Result = Flare.Confirm("Delete your save?")
	:Title("This cannot be undone")
	:Danger()
	:Await()

Flare.Toast(if answer.Kind == "Accepted" then "Deleted" else "Kept")
	:Tone(if answer.Kind == "Accepted" then "Danger" else "Ok")
	:Show()

beat()

--- Or stay asynchronous. Same notice, callbacks instead of a block.
Flare.Confirm("Ask again?")
	:OnAccept(function()
		Flare.Toast("You said yes"):Ok():Show()
	end)
	:OnCancel(function()
		Flare.Toast("You said no"):Show()
	end)
	:OnDismiss(function()
		Flare.Toast("You ignored it"):Warn():Show()
	end)
	:Duration(8)
	:Show()

beat(9)

section("prompt")

local named = Flare.Prompt("Name your save")
	:Placeholder("Slot 1")
	:Default("Autosave")
	:Await()

if named.Kind == "Value" then
	Flare.Toast(`Saved as {named.Value}`):Ok():Show()
end

beat()

section("choice")

--- A bare string is its own id; a table gets a description and an icon.
local destination = Flare.Choice("Where to?", {
	"Spawn",
	{ Id = "arena", Text = "Arena", Description = "PvP enabled" },
	{ Id = "shop", Text = "Shop", Description = "Spend those coins" },
}):Await()

if destination.Kind == "Value" then
	Flare.Toast(`Travelling to {destination.Value}`):Info():Show()
end

beat(3)

section("color")

--- Lume's picker in a notice. It resolves with the `Color3` itself, and writes
--- every drag back to `notice.Spec.Color` — so a preview can follow the pointer
--- rather than waiting for the answer.
local colour = Flare.Color("Trail colour", Color3.fromRGB(126, 170, 255)):Title("Pick a colour"):Await()

if colour.Kind == "Value" then
	Flare.Toast("That colour it is"):Ok():Show()
end

beat(3)

section("number")

--- A stepper rather than a field: a quantity has a floor, a ceiling and a step,
--- and none of those survive being typed.
local many = Flare.Number("How many?", 1):Range(1, 99):Title("Buy potions"):Await()

if many.Kind == "Value" then
	Flare.Toast(`Bought {many.Value}`):Ok():Show()
end

beat(3)

--// 6. live notices -----------------------------------------------------------------------
--- The builder and the handle are the same object, so every setter still works
--- after `:Show()`. This is why a builder that goes inert would be wrong.
section("progress")

local job = Flare.Progress("Uploading save"):Show()

for step = 1, 10 do
	job:Progress(step / 10)

	task.wait(0.2)
end

job:Finish("Uploaded")

beat(3)

--- The same handle can fail instead. `:Fail()` stays longer than `:Finish()`,
--- because a failure is the one you actually have to read.
local doomed = Flare.Progress("Uploading screenshot"):Show()

for step = 1, 4 do
	doomed:Progress(step / 10)

	task.wait(0.2)
end

doomed:Fail("Upload failed — no connection")

beat(4)

section("loading")

--- Indeterminate: a bar that sweeps rather than fills, for work of unknown
--- length.
local matchmaking = Flare.Loading("Finding a match"):Show()

beat(3)
matchmaking:Update("Found 3 players")
beat(2)
matchmaking:Finish("Match starting")

beat(3)

section("countdown")

--- Paints a clock — 1:30, then 45s under a minute — and expires at zero.
Flare.Countdown("Round ends", 90):Accent():Show()

beat(4)

--- Without a length it is just a toast with a body, so always give it one.
Flare.Countdown("Shop closes", 20):Warn():Show()

beat(4)

--// 7. the rich ones ------------------------------------------------------------------------
--- Big, centred and allowed to interrupt — priority outlives the cap.
section("achievement and reward")

Flare.Achievement("First Blood", "Win a round without dying")
	:Priority(10)
	:Show()

beat(4)

Flare.Reward("Daily bonus", "+250 coins")
	:Priority(10)
	:Show()

beat(4)

--// 8. hint --------------------------------------------------------------------------------
--- Pinned to a GuiObject rather than a corner, so it points at the thing it is
--- talking about.
section("hint")

local gui = Instance.new("ScreenGui")
gui.Name = "FlareExample"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(160, 44)
button.Position = UDim2.fromScale(0.5, 0.5)
button.AnchorPoint = Vector2.new(0.5, 0.5)
button.Text = "Equip"
button.Parent = gui

Flare.Hint("Click here to equip it", button, "top"):Info():Show()

beat(5)

gui:Destroy()

--// 9. the queue ----------------------------------------------------------------------------
--- Three identical events collapse into one carrying a count, and the merge
--- restarts its clock so a repeating event keeps its notice on screen.
section("grouping")

for _ = 1, 5 do
	Flare.Toast("Item picked up"):Info():Show()

	task.wait(0.3)
end

beat(4)

--- Without an explicit key, "the same" means same kind, tone and body. Name
--- the group yourself when the bodies differ but the event does not.
for index = 1, 4 do
	Flare.Toast(`Ore x{index} mined`):Group("mining"):Ok():Show()

	task.wait(0.3)
end

beat(4)

section("priority and the cap")

--- Four sticky notices fill the corner...
for index = 1, 4 do
	Flare.Toast(`Filler {index}`):Sticky():Show()

	task.wait(0.2)
end

beat(2)

--- ...and a fifth waits, unless it outranks them, in which case it displaces
--- the least important one into the front of the backlog. Delayed, not lost.
Flare.Toast("Waiting for a slot"):Sticky():Show()

beat(2)

Flare.Alert("Urgent — displaces one"):Danger():Priority(50):Show()

beat(3)

local live, waiting = Flare.Count()

print(`{live} on screen, {waiting} waiting`)

Flare.Clear()

beat(2)

--// 10. anchors -------------------------------------------------------------------------------
--- Nine of them, each with its own queue, so a full corner never blocks a
--- banner.
section("anchors")

for _, anchor in { "topLeft", "top", "topRight", "left", "center", "right", "bottomLeft", "bottom", "bottomRight" } do
	Flare.Toast(anchor):At(anchor :: Flare.Anchor):Duration(4):Show()

	task.wait(0.15)
end

beat(5)

--// 11. per-notice appearance ---------------------------------------------------------------------
section("appearance")

Flare.Toast("Wider than the rest"):Width(460):Show()
beat(1)
Flare.Toast("No shadow on this one"):Shadow(false):Show()
beat(1)
Flare.Toast("Drag me around"):Draggable(true):Duration(8):Show()
beat(1)
Flare.Toast("Cannot be dismissed by clicking"):Dismissible(false):Show()
beat(1)
Flare.Toast("Never pauses on hover"):Pausable(false):Show()

beat(5)

--// 12. custom actions ------------------------------------------------------------------------------
--- Any kind can have buttons. The callback gets the handle, so it can update
--- the notice it came from; returning false keeps it open.
section("actions")

Flare.Alert("Your friend invited you to a party")
	:Title("Party invite")
	:Accent()
	:Action("Join", function(notice)
		notice:Update("Joining…"):Indeterminate(true)

		task.delay(1.5, function()
			notice:Finish("Joined")
		end)

		return false
	end)
	:Action("Ignore", nil, "Danger")
	:Show()

beat(6)

--// 13. theming ---------------------------------------------------------------------------------------
--- Tokens, deep-merged over whatever they extend. One colour is a one-line
--- theme, and live notices repaint when you switch.
section("theming")

Flare.DefineTheme("Ocean", {
	Color = {
		Ok = Color3.fromRGB(125, 207, 255),
		Accent = Color3.fromRGB(122, 162, 247),
	},
	Rich = {
		ok = "#7DCFFF",
		accent = "#7AA2F7",
	},
	Radius = { Notice = 4 },
	Shadow = { Spread = 14, Transparency = 0.8 },
})

Flare.SetTheme("Ocean")

Flare.Toast("Same notice, different theme"):Ok():Show()
beat(1)
Flare.Toast("[ok]markup follows the theme too[/ok]"):Show()

beat(4)

Flare.SetTheme("Default")

--// 14. carrying your own data -------------------------------------------------------------------------
--- `:Meta()` is never read by Flare. It is there so a resolve handler can tell
--- which notice it is looking at.
section("meta")

Flare.Confirm("Sell this sword?")
	:Meta({ ItemId = 4821 })
	:OnResolve(function(result)
		print("resolved", result.Kind)
	end)
	:Duration(6)
	:Show()

beat(7)

print("\ndone — every kind shown")
