--!nocheck

--- What Flare gained from Lume's wider widget set: the Custom escape hatch,
--- the Rating kind, and avatars on any notice.

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

print(`Widgets: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
