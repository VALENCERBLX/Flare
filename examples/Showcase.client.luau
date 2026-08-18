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
Flare.toast("Saved"):ok():show()

task.wait(1)

Flare.banner("Server restarting in 5 minutes"):warn():show()

task.wait(2)

Flare.snackbar("Message deleted", "Undo", function(notice)
	notice:update("Restored"):ok()

	--// false keeps it open, so the new text can be read
	return false
end):show()

task.wait(3)

--// grouping: three identical events, one notice reading ×3
for _ = 1, 3 do
	Flare.toast("Item picked up"):info():show()

	task.wait(0.4)
end

task.wait(3)

--// live
local job = Flare.progress("Uploading save"):show()

for step = 1, 10 do
	job:progress(step / 10)

	task.wait(0.25)
end

job:finish("Uploaded")

task.wait(2)

Flare.countdown("Round ends", 30):accent():show()

task.wait(2)

--// rich
Flare.achievement("First Blood", "Win a round without dying")
	:priority(10)
	:show()

task.wait(4)

--// interactive: this one blocks until it is answered
local answer = Flare.confirm("Delete your save?"):danger():await()

Flare.toast(if answer.Kind == "Accepted" then "Deleted" else "Kept")
	:tone(if answer.Kind == "Accepted" then "danger" else "ok")
	:show()

task.wait(2)

local where = Flare.choice("Where to?", {
	"Spawn",
	{ Id = "arena", Text = "Arena", Description = "PvP enabled" },
	{ Id = "shop", Text = "Shop" },
}):await()

if where.Kind == "Value" then
	Flare.toast(`Travelling to {where.Value}`):info():show()
end
