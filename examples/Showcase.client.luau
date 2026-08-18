--!strict

--- Every kind of Flare notice, one after another.
---
--- Drop in `StarterPlayer/StarterPlayerScripts` next to a synced Flare and
--- watch the queue work: the toasts group, the alert holds, the urgent one
--- displaces, and hovering anything freezes its clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flare = require(ReplicatedStorage:WaitForChild("Flare"))

Flare.Start({
	Max = 4,
	Duration = 5,
})

task.wait(2)

--// the core set
Flare.Toast("Saved"):Ok():Show()

task.wait(1)

Flare.Banner("Server restarting in 5 minutes"):Warn():Show()

task.wait(2)

Flare.Snackbar("Message deleted", "Undo", function(notice)
	notice:Update("Restored"):Ok()

	--// false keeps it open, so the new text can be read
	return false
end):Show()

task.wait(3)

--// grouping: three identical events, one notice reading ×3
for _ = 1, 3 do
	Flare.Toast("Item picked up"):Info():Show()

	task.wait(0.4)
end

task.wait(3)

--// live
local job = Flare.Progress("Uploading save"):Show()

for step = 1, 10 do
	job:Progress(step / 10)

	task.wait(0.25)
end

job:Finish("Uploaded")

task.wait(2)

Flare.Countdown("Round ends", 30):Accent():Show()

task.wait(2)

--// rich
Flare.Achievement("First Blood", "Win a round without dying")
	:Priority(10)
	:Show()

task.wait(4)

--// interactive: this one blocks until it is answered
local answer = Flare.Confirm("Delete your save?"):Danger():Await()

Flare.Toast(if answer.Kind == "Accepted" then "Deleted" else "Kept")
	:Tone(if answer.Kind == "Accepted" then "danger" else "ok")
	:Show()

task.wait(2)

local where = Flare.Choice("Where to?", {
	"Spawn",
	{ Id = "arena", Text = "Arena", Description = "PvP enabled" },
	{ Id = "shop", Text = "Shop" },
}):Await()

if where.Kind == "Value" then
	Flare.Toast(`Travelling to {where.Value}`):Info():Show()
end
