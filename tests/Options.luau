--!nocheck

--- What `Flare.Start` does with the options it is given — including the ones
--- people actually type by mistake. Every check here failed silently before it
--- existed: an ignored key, a table read as a boolean, a boolean read as a gate.

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

local function reset()
	Flare.Destroy()

	table.clear(Shim.played)
	table.clear(Shim.warnings)
end

local ICON = "rbxassetid://112646028896644"
local SOUND = "rbxassetid://18771193427"

--// the exact shape the user wrote --------------------------------------------
Flare.Start({
	Tokens = { Radius = { Notice = 1, Pill = 1, Bar = 1 } },
	Shadow = { Spread = 50 },
	Icon = { Ok = ICON, Danger = "rbxassetid://121531099128987" },
	Sound = { Danger = SOUND },
})

check("Shadow table sets Spread", Flare.Theme.Shadow.Spread == 50, `got {Flare.Theme.Shadow.Spread}`)
check("Shadow table keeps Enabled", Flare.Theme.Shadow.Enabled == true)
check("Shadow table keeps other tokens", Flare.Theme.Shadow.Transparency ~= nil)
check("Icon alias reaches the theme", Flare.Theme.Icon.Ok == ICON, `got {tostring(Flare.Theme.Icon.Ok)}`)
check("Sound table reaches the theme", Flare.Theme.Sound.Danger == SOUND, `got {tostring(Flare.Theme.Sound.Danger)}`)
check("Sound table does not silence", Flare.Defaults.Sound == true)
check("Tokens set Radius", Flare.Theme.Radius.Notice == 1)
check("no warnings for a valid config", #Shim.warnings == 0, table.concat(Shim.warnings, " | "))

local danger = Flare.Toast("No shadow"):Danger():Show()
local ok = Flare.Toast("No shadow"):Ok():Show()

Shim.step()

check("tone icon is applied", ok.Spec.Icon == ICON, `got {tostring(ok.Spec.Icon)}`)
check("tone sound played", table.find(Shim.played, SOUND) ~= nil, table.concat(Shim.played, " | "))
check("a tone with no sound stays quiet", #Shim.played == 1, table.concat(Shim.played, " | "))
--// a button rounds tighter than the notice around it, which on a square
--// theme used to work out to a negative radius
local confirm = Flare.Confirm("Sure?")

confirm:Show()
Shim.step()

check("square theme renders buttons", confirm.Panel ~= nil and #Shim.warnings == 0, table.concat(Shim.warnings, " | "))

confirm:Resolve({ Kind = "Dismissed" })

check("both toasts survived a square theme", danger ~= nil and ok ~= nil)

reset()

--// unknown keys are reported --------------------------------------------------
Flare.Start({ Anchr = "topRight" } :: any)

check("unknown key warns", #Shim.warnings == 1, table.concat(Shim.warnings, " | "))
check(
	"unknown key suggests the real one",
	#Shim.warnings == 1 and Shim.warnings[1]:find("Anchor") ~= nil,
	table.concat(Shim.warnings, " | ")
)

reset()

Flare.Start({ Sonds = { Ok = SOUND } } :: any)

check(
	"a transposed plural is suggested",
	#Shim.warnings == 1 and Shim.warnings[1]:find("Sounds") ~= nil,
	table.concat(Shim.warnings, " | ")
)

reset()

Flare.Start({ Bananas = true } :: any)

check(
	"a key close to nothing gets no guess",
	#Shim.warnings == 1 and Shim.warnings[1]:find("Did you mean") == nil,
	table.concat(Shim.warnings, " | ")
)

reset()

Flare.Start({ anchor = "topRight" } :: any)

check("wrong case is suggested", #Shim.warnings == 1 and Shim.warnings[1]:find("Anchor") ~= nil, table.concat(Shim.warnings, " | "))

reset()

--// the documented spellings still work -----------------------------------------
Flare.Start({ Icons = { Ok = ICON }, Sounds = { Ok = SOUND }, Shadow = false })

check("Icons still works", Flare.Theme.Icon.Ok == ICON)
check("Sounds still works", Flare.Theme.Sound.Ok == SOUND)
check("Shadow false still disables", Flare.Theme.Shadow.Enabled == false)
check("plural spellings warn about nothing", #Shim.warnings == 0, table.concat(Shim.warnings, " | "))

Flare.Toast("hi"):Ok():Show()
Shim.step()

check("Sounds asset plays", table.find(Shim.played, SOUND) ~= nil, table.concat(Shim.played, " | "))

reset()

--// Sound as a gate and as an asset ----------------------------------------------
Flare.Start({ Sound = SOUND })

check("Sound string is the default asset", Flare.Defaults.DefaultSound == SOUND)
check("Sound string enables sound", Flare.Defaults.Sound == true)

Flare.Toast("hi"):Show()
Shim.step()

check("Sound string plays for any tone", table.find(Shim.played, SOUND) ~= nil, table.concat(Shim.played, " | "))

reset()

Flare.Start({ Sound = false, Sounds = { Ok = SOUND } })

Flare.Toast("hi"):Ok():Show()
Shim.step()

check("Sound false silences everything", #Shim.played == 0, table.concat(Shim.played, " | "))

reset()

--// a kind beats a tone ------------------------------------------------------------
Flare.Start({ Icons = { Accent = "rbxassetid://1", Achievement = "rbxassetid://2" } })

local achievement = Flare.Achievement("Won", "nice"):Show()

Shim.step()

check("kind icon wins over tone", achievement.Spec.Icon == "rbxassetid://2", tostring(achievement.Spec.Icon))

reset()

print(`Options: {passed} passed, {failed} failed`)

if failed > 0 then
	process.exit(1)
end
