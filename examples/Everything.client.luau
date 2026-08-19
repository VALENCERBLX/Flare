--!strict

--- Every widget Lume has, in one panel, and every Flare kind that asks a
--- question, from a button beside it.
---
--- Drop it in `StarterPlayerScripts` with Lume and Flare synced, and fire the
--- `Kek` RemoteEvent at yourself to open it. The panel is a plain
--- `app:panel("window")` — nothing here is special-cased, it is the same
--- vocabulary any other panel gets.
---
--- The one rule worth carrying away: **a widget's job decides its events.**
--- Anything draggable fires `changed` continuously and `committed` once, so a
--- preview follows the pointer while the write happens on release. Anything
--- discrete fires `changed` and means it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lume = require(ReplicatedStorage:WaitForChild("Lume"))
local Flare = require(ReplicatedStorage:WaitForChild("Flare"))

local Kek = ReplicatedStorage:WaitForChild("Kek")

Flare.Start({
	Anchor = "bottomRight",
	Max = 4,
})

local app = Lume.app({ name = "Widgets" })

--// state ---------------------------------------------------------------------
--- Every control writes to one of these, and the readouts at the bottom are
--- bound to the same values — so nothing has to be copied from one place to
--- another when something changes.
local state = {
	team = Lume.value("red"),
	grid = Lume.value(4),
	hour = Lume.value(12),
	opacity = Lume.value(80),
	zoom = Lume.value(1),
	position = Lume.value(Vector3.new(0, 5, 0)),
	highlight = Lume.value(Color3.fromRGB(126, 170, 255)),
	score = Lume.value(0),
	page = Lume.value(1),
}

local load = { 12, 18, 9, 24, 31, 22, 40, 28, 35, 19 }

local function open(author: Player?, message: string?)
	local window = app:panel("window")

	window:setTitle("Every widget")
	window:setAnchor("center")
	window:setWidth(420)

	--// 1. a menu bar across the top ---------------------------------------------
	--- One popover shared by every title, which is what lets the pointer cross
	--- the strip and switch menus without a click.
	window:menuBar({
		{
			text = "File",
			items = {
				{ id = "new", text = "New", shortcut = "Ctrl+N" },
				{ id = "save", text = "Save", shortcut = "Ctrl+S" },
				{ divider = true, text = "" },
				{ id = "close", text = "Close", danger = true, action = function()
					window:close()
				end },
			},
		},
		{
			text = "Edit",
			items = {
				{ id = "undo", text = "Undo", shortcut = "Ctrl+Z" },
				{ id = "redo", text = "Redo", disabled = true },
			},
		},
		{ id = "help", text = "Help", items = { { id = "about", text = "About" } } },
	}):onPicked(function(item, from)
		Flare.Toast(`{from} → *{item.text}*`):Show()
	end)

	--// 2. where you are ----------------------------------------------------------
	window:breadcrumb({ "Home", "Settings", "Widgets" }):onPicked(function(id)
		Flare.Toast(`Back to *{id}*`):Show()
	end)

	window:divider()

	--// 3. the sections -------------------------------------------------------------
	local sections = window:accordion()

	sections:setExclusive(true)

	--// picking one of a few -------------------------------------------------------
	local choosing = sections:section("Choosing")

	--- A radio group shows every option at once; a select hides them behind a
	--- click. Three options with consequences want to be read side by side.
	choosing:radio("Team")
		:setOptions({
			{ id = "red", text = "Red", description = "Attackers" },
			{ id = "blue", text = "Blue", description = "Defenders" },
			{ id = "spec", text = "Spectator" },
		})
		:setValue(state.team)
		:onChanged(function(id)
			state.team:set(id)
		end)

	choosing:select("Render mode"):setOptions({ "Solid", "Wireframe", "Points" })

	choosing:toggle("Wireframe"):setDescription("Draw collision volumes")

	choosing:chips():setChips({ "melee", "ranged", "support" }):setSelectable(true)

	--// numbers ---------------------------------------------------------------------
	local numbers = sections:section("Numbers")

	--- Four ways to enter a number, and they are not interchangeable. A slider
	--- has a range you can see. A stepper is for short ranges where every value
	--- matters. A scrubber has no range at all. A vector is three numbers that
	--- mean one thing.
	numbers:slider("Opacity")
		:setRange(0, 100)
		:setStep(1)
		:setValue(state.opacity)
		:setFormat(function(value)
			return `{math.round(value)}%`
		end)
		:onCommitted(function(value)
			state.opacity:set(value)
		end)

	numbers:stepper("Grid size")
		:setRange(1, 16)
		:setStep(1)
		:setValue(state.grid)
		:setFormat(function(value)
			return `{value} studs`
		end)
		:onCommitted(function(value)
			state.grid:set(value)
		end)

	--- Wrapping: past 23 comes back to 0, because the ends of a clock are
	--- neighbours rather than walls.
	numbers:stepper("Hour"):setRange(0, 23):setWrap(true):setValue(state.hour):onCommitted(function(value)
		state.hour:set(value)
	end)

	--- No minimum, no maximum, no rail to draw — drag it sideways.
	numbers:scrubber("Zoom"):setStep(0.05):setSensitivity(0.5):setValue(1):onCommitted(function(value)
		state.zoom:set(value)
	end)

	numbers:vector("Position", 3):setStep(0.5):setValue(state.position:get()):onCommitted(function(value)
		state.position:set(Vector3.new(value[1], value[2], value[3]))
	end)

	--// colour and score --------------------------------------------------------------
	local colour = sections:section("Colour")

	colour:colorPicker("Highlight"):setValue(state.highlight:get()):onChanged(function(value)
		state.highlight:set(value)
	end)

	colour:rating("Rate this panel"):onChanged(function(score)
		state.score:set(score)
	end)

	--// reading rather than editing ------------------------------------------------------
	local reading = sections:section("Reading")

	--- A meter is a level, not a task: its colour is the point, and it turns as
	--- the value crosses a band you care about.
	reading:meter("Memory")
		:setRange(0, 100)
		:setBands(50, 80)
		:setOptimum("low")
		:setValue(64)
		:setFormat(function(value, max)
			return `{value}/{max} MB`
		end)

	reading:progress():setValue(0.35)

	--- No axes, no grid — the shape is the whole message.
	reading:sparkline(load):setHeight(28)

	reading:spinner("Still working")

	local scores = reading:table()

	scores:setColumns({
		{ key = "name", title = "Player", weight = 2 },
		{ key = "score", title = "Score", align = "right" },
	})

	scores:setRows({
		{ name = "Rin", score = 1240 },
		{ name = "Kai", score = 980 },
		{ name = "Ada", score = 410 },
	})

	scores:setSelectable(true)
	scores:onActivated(function(row)
		Flare.Toast(`*{row.name}* — {row.score}`):Info():Show()
	end)

	reading:pagination(12):setPage(state.page):onChanged(function(page)
		state.page:set(page)
	end)

	--// nested things -----------------------------------------------------------------
	local nested = sections:section("Nested")

	local tree = nested:tree()

	tree:setNodes({
		{
			id = "world",
			text = "Workspace",
			children = {
				{ id = "map", text = "Map", children = { { id = "spawn", text = "Spawn" } } },
				{ id = "props", text = "Props" },
			},
		},
		{ id = "lighting", text = "Lighting" },
	})

	tree:expandNode("world")
	tree:onSelected(function(node)
		Flare.Toast(`Selected *{node.text}*`):Show()
	end)

	--// the Flare half -----------------------------------------------------------------
	local asking = sections:section("Flare")

	--- Every one of these is a notification that asks something and blocks on
	--- the answer, so each runs on a thread of its own. `:Await()` inside a
	--- button handler would freeze the button, not the game.
	local function ask(label: string, run: () -> ())
		asking:button(label):setFill(true):onClicked(function()
			task.spawn(run)
		end)
	end

	ask("Confirm", function()
		local answer = Flare.Confirm("Delete everything?"):Danger():Await()

		Flare.Toast(`You said *{answer.Kind}*`):Show()
	end)

	ask("Choice", function()
		local answer = Flare.Choice("Where to?", {
			{ Id = "spawn", Text = "Spawn", Description = "Back to the start" },
			{ Id = "arena", Text = "Arena", Description = "PvP enabled" },
		}):Await()

		if answer.Kind == "Value" then
			Flare.Toast(`Travelling to *{answer.Value}*`):Ok():Show()
		end
	end)

	ask("Prompt", function()
		local answer = Flare.Prompt("Name your save"):Placeholder("Slot 1"):Await()

		if answer.Kind == "Value" then
			Flare.Toast(`Saved as *{answer.Value}*`):Ok():Show()
		end
	end)

	ask("Colour", function()
		local answer = Flare.Color("Trail colour", state.highlight:get()):Await()

		if answer.Kind == "Value" then
			state.highlight:set(answer.Value)

			Flare.Toast("Trail updated"):Ok():Show()
		end
	end)

	ask("Number", function()
		local answer = Flare.Number("How many?", 1):Range(1, 99):Await()

		if answer.Kind == "Value" then
			Flare.Toast(`Bought *{answer.Value}*`):Ok():Show()
		end
	end)

	ask("Rating", function()
		local answer = Flare.Rate("How was that round?"):Await()

		if answer.Kind == "Value" then
			Flare.Toast(`{answer.Value} stars — thank you`):Ok():Show()
		end
	end)

	--- The escape hatch. A notice can hold any Lume element at all, which is
	--- how a toast ends up with a chart in it.
	ask("A notice with a chart", function()
		Flare.Toast("Server load")
			:Custom(function(panel)
				panel:sparkline(load):setHeight(24)
				panel:meter("Memory"):setRange(0, 100):setBands(50, 80):setOptimum("low"):setValue(64)
			end)
			:Duration(8)
			:Show()
	end)

	--- And a notice about a player wears their face rather than a glyph.
	ask("A notice with a face", function()
		local player = author or Players.LocalPlayer

		Flare.Toast(`*{player.DisplayName}* joined`)
			:Avatar(player.UserId, player.DisplayName)
			:Ok()
			:Show()
	end)

	--// what everything did ----------------------------------------------------------
	window:divider():setLabel("Live")

	local readout = window:group("horizontal")

	readout:setFill(true)
	readout:setGap(8)

	readout:avatar(if author then author.UserId else 1):setDiameter(28):setStatus("online")

	local lines = readout:group("vertical")

	lines:setGrow(true)
	lines:setGap(2)

	--- Bound to the same values the controls write to, so nothing has to be
	--- copied across when one of them changes.
	lines:label(Lume.format(state.team, "team: %s")):setMuted(true)
	lines:label(Lume.format(state.grid, "grid: %d studs")):setMuted(true)
	lines:label(Lume.format(state.hour, "hour: %02d:00")):setMuted(true)

	local swatch = lines:label("highlight")

	swatch:setColor(state.highlight)

	if message then
		window:label(`from {if author then author.DisplayName else "someone"}: _{message}_`):setMuted(true)
	end

	window:open()

	--// something to look at while you read the panel
	Flare.Toast("Everything is open"):Ok():Show()

	return window
end

Kek.OnClientEvent:Connect(function(author: Player, message: string)
	open(author, message)
end)

--// and open it once at startup so there is something to look at
open(nil, nil)
