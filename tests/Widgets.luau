--!nocheck

--- What Flare gained from Lume's wider widget set: the Custom escape hatch,
--- the Rating kind, and avatars on any notice.

local process = require("@lune/process")

local Shim = require("./Shim")

local Flare = Shim.load("./src", "Flare")
local Lume = Shim.load("../Lume/src", "Lume")

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
	else
		failed += 1

		print(`  FAIL  {name}{if detail then ` — {detail}` else ""}`)
	end
end

Flare.Start()

--// Custom: any Lume element, in a notice ---------------------------------------
do
	local built = {}

	local notice = Flare.Toast("Server load")
		:Custom(function(panel)
			built.spark = panel:sparkline({ 4, 9, 6, 12, 7 })
			built.meter = panel:meter("Memory"):setRange(0, 100):setValue(64)
			built.table = panel:table()
		end)
		:Sticky()
		:Show()

	Shim.step()

	check("a Custom builder runs", built.spark ~= nil)
	check("more than one element is fine", built.meter ~= nil and built.table ~= nil)
	check("the elements belong to the notice's panel", built.spark.owner == notice.Panel)
	check("the notice still built its own body", notice.Refs.Column ~= nil)

	--// the builder runs on every rebuild, which is why it must build rather
	--// than mutate. A plain text change is a refresh, not a rebuild, and
	--// leaves what it made alone
	local first = built.spark

	notice:Body("Server load, still")
	Shim.step()

	check("a text change does not rebuild", built.spark == first)

	notice:Rebuild()
	Shim.step()

	check("a rebuild runs it again", built.spark ~= first)

	notice:Resolve({ Kind = "Dismissed" })
end

do
	--// a builder that throws must not take the notice down with it
	table.clear(Shim.warnings)

	local notice = Flare.Toast("Fine"):Custom(function()
		error("deliberate")
	end):Show()

	Shim.step()

	check("a broken builder does not kill the notice", notice.Panel ~= nil)
	check("and says so", #Shim.warnings == 1 and Shim.warnings[1]:find("Custom builder") ~= nil, table.concat(Shim.warnings, " | "))

	notice:Resolve({ Kind = "Dismissed" })
end

--// Rating ------------------------------------------------------------------------
do
	local answer
	local notice = Flare.Rate("How was that round?")

	local thread = coroutine.create(function()
		answer = notice:Await()
	end)

	coroutine.resume(thread)
	Shim.step()

	check("the stars rendered", notice.Refs.Rating ~= nil)
	check("five of them", #notice.Refs.Rating.stars == 5, `{#notice.Refs.Rating.stars}`)
	check("a rating question does not expire", Flare.Transient("Rating") == false)

	notice.Refs.Rating.stars[4].Activated:Fire()
	Shim.step()

	--// there is no sensible second step after picking four stars
	check("picking answers immediately", answer ~= nil)
	check("with the score", answer and answer.Value == 4, tostring(answer and answer.Value))
	check("as a Value", answer and answer.Kind == "Value", answer and answer.Kind)
end

do
	local declined
	local notice = Flare.Rate("How was it?", 10)

	local thread = coroutine.create(function()
		declined = notice:Await()
	end)

	coroutine.resume(thread)
	Shim.step()

	check("the count can be set", #notice.Refs.Rating.stars == 10, `{#notice.Refs.Rating.stars}`)

	for _, action in notice.Spec.Actions do
		if action.Text == "Not now" then
			action.Run(notice)
		end
	end

	Shim.step()

	check("declining cancels", declined and declined.Kind == "Cancelled", declined and declined.Kind)
end

--// Avatar --------------------------------------------------------------------------
do
	local notice = Flare.Toast("*Rin* joined"):Avatar(1, "Rin Okabe"):Sticky():Show()

	Shim.step()

	check("the avatar rendered", notice.Refs.Avatar ~= nil)
	check("pointed at the player", notice.Refs.Avatar.image:find("id=1") ~= nil, notice.Refs.Avatar.image)
	check("with initials underneath", notice.Refs.Avatar.initials == "RO", notice.Refs.Avatar.initials)

	--// a face beats a glyph: the icon is not drawn as well
	check("and no icon beside it", notice.Refs.Icon == nil)

	notice:Resolve({ Kind = "Dismissed" })
end

do
	local notice = Flare.Toast("No avatar"):Icon("rbxassetid://1"):Sticky():Show()

	Shim.step()

	check("without a player the icon is still drawn", notice.Refs.Icon ~= nil)
	check("and no avatar", notice.Refs.Avatar == nil)

	notice:Resolve({ Kind = "Dismissed" })
end

--// widgets on any notice --------------------------------------------------------
do
	local notice = Flare.Toast("Server health")
		:Chart({ 12, 18, 9, 24, 31 })
		:Meter(64, { Label = "Memory", Low = 50, High = 80, Optimum = "low" })
		:Table({ { key = "name", weight = 2 }, { key = "score" } }, { { name = "Rin", score = 12 } })
		:Tree({ { id = "world", text = "Workspace", children = { { id = "map", text = "Map" } } } }, true)
		:Spinner("Working")
		:Chips({ "melee", "ranged" })
		:Crumbs({ "Home", "Stats" })
		:Sticky()
		:Show()

	Shim.step()

	check("a chart goes in a notice", notice.Refs.Chart ~= nil)
	check("so does a meter", notice.Refs.Meter ~= nil)
	check("and a table", notice.Refs.Table ~= nil)
	check("and a tree", notice.Refs.Tree ~= nil)
	check("and a spinner", notice.Refs.Spinner ~= nil)
	check("and chips", notice.Refs.Chips ~= nil)
	check("and a breadcrumb", notice.Refs.Crumbs ~= nil)

	notice:Graph({ 8, 12, 40 }, { Unit = "ms", Warn = 16, Fail = 33 })
	Shim.step()

	check("and a graph", notice.Refs.Graph ~= nil)
	check("which keeps taking samples while the notice is up", notice.Refs.Graph:push(9):last() == 9)
	check("and grades them", notice.Refs.Graph.refs.readout.Text == "9ms", notice.Refs.Graph.refs.readout.Text)

	check("the meter took its bands", notice.Refs.Meter.low == 50 and notice.Refs.Meter.high == 80)
	check("and its direction", Lume.Elements.Meter.zone(notice.Refs.Meter) == "warn", Lume.Elements.Meter.zone(notice.Refs.Meter))
	check("the tree was expanded", notice.Refs.Tree:count() == 2, `{notice.Refs.Tree:count()}`)

	--// they run in the order they were added, so a chart written above a meter
	--// appears above it
	check("order is kept", notice.Refs.Chart.instance.LayoutOrder < notice.Refs.Meter.instance.LayoutOrder)

	notice:Resolve({ Kind = "Dismissed" })
end

--// a notice with a widget is not one big dismiss button ---------------------------
do
	--// a slider handles raw input rather than consuming a click the way a
	--// Button does, so the drag that moved it reached the panel underneath and
	--// dismissed the notice out from under the pointer
	local notice = Flare.Toast("Server load"):Chart({ 1, 2, 3 }):Sticky():Show()

	Shim.step()

	check("a notice carrying a widget is not click-to-dismiss", notice.Panel.hitbox == nil)

	check("so there is nothing to click through to", notice:Alive())

	notice:Resolve({ Kind = "Dismissed" })

	--// a plain toast still is
	local plain = Flare.Toast("Just words"):Sticky():Show()

	Shim.step()

	check("a plain notice still has one", plain.Panel.hitbox ~= nil and plain.Panel.hitbox.Visible)

	plain.Panel.hitbox.Activated:Fire()
	Shim.step()

	check("and clicking it dismisses", not plain:Alive())
end

--// a dropdown must open above the notice it is in ---------------------------------
do
	local notice = Flare.Dropdown("Spawn where?", { "Base", "Arena" }):Show()

	Shim.step()

	notice.Refs.Select:toggle()
	Shim.step()

	local popover = notice.Refs.Select.popover

	check("the dropdown opened", popover ~= nil and popover.opened == true)

	--// a select opening inside a notice put its list on the popover layer at
	--// ZIndex 100, under the toast layer at 800 — so it opened into nothing
	local popoverLayer = popover.instance.Parent
	local noticeLayer = notice.Panel.instance.Parent

	check("its layer sits above the notice's", popoverLayer.ZIndex > noticeLayer.ZIndex,
		`{popoverLayer.ZIndex} vs {noticeLayer.ZIndex}`)

	notice:Resolve({ Kind = "Dismissed" })
end

--// dropdown ------------------------------------------------------------------------
do
	local answer
	local notice = Flare.Dropdown("Spawn where?", { "Base", "Arena", { Id = "docks", Text = "Docks" } })

	local thread = coroutine.create(function()
		answer = notice:Await()
	end)

	coroutine.resume(thread)
	Shim.step()

	check("the dropdown rendered", notice.Refs.Select ~= nil)
	check("with every option", #notice.Spec.Options == 3, `{#notice.Spec.Options}`)
	check("a bare string is its own id", notice.Spec.Options[1].Id == "Base")
	check("a dropdown question does not expire", Flare.Transient("Dropdown") == false)

	--// nothing chosen yet: confirming must not resolve with nil
	for _, action in notice.Spec.Actions do
		if action.Text == "Confirm" then
			action.Run(notice)
		end
	end

	Shim.step()

	check("confirming nothing keeps it open", answer == nil)

	notice.Refs.Select:emit("changed", "docks")

	check("picking writes back to the spec", notice.Spec.Default == "docks", tostring(notice.Spec.Default))

	for _, action in notice.Spec.Actions do
		if action.Text == "Confirm" then
			action.Run(notice)
		end
	end

	Shim.step()

	check("then confirming answers", answer and answer.Value == "docks", tostring(answer and answer.Value))
end

--// radio ---------------------------------------------------------------------------
do
	local answer
	local notice = Flare.Radio("Which team?", {
		{ Id = "red", Text = "Red", Description = "Attackers" },
		{ Id = "blue", Text = "Blue", Description = "Defenders" },
	}, "red")

	local thread = coroutine.create(function()
		answer = notice:Await()
	end)

	coroutine.resume(thread)
	Shim.step()

	check("the radio rendered", notice.Refs.Radio ~= nil)
	check("every option is a row", #notice.Refs.Radio.rows == 2, `{#notice.Refs.Radio.rows}`)
	check("an initial choice takes", notice.Refs.Radio:value() == "red", tostring(notice.Refs.Radio:value()))

	notice.Refs.Radio.rows[2].button.Activated:Fire()

	check("clicking a row writes back", notice.Spec.Default == "blue", tostring(notice.Spec.Default))

	for _, action in notice.Spec.Actions do
		if action.Text == "Confirm" then
			action.Run(notice)
		end
	end

	Shim.step()

	check("confirming answers with the choice", answer and answer.Value == "blue", tostring(answer and answer.Value))
end

print(`Widgets: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
