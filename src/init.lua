--!strict

--- **Flare** — notifications for Roblox.
---
--- Thirteen kinds on one queue, every one of them the same chained builder:
---
--- ```lua
--- local Flare = require(ReplicatedStorage.Flare)
---
--- Flare.Toast("Saved"):Ok():Show()
---
--- Flare.Confirm("Delete everything?")
---     :Danger()
---     :OnAccept(wipe)
---     :Show()
---
--- local job = Flare.Progress("Uploading"):Show()
--- job:Progress(0.4)
--- job:Finish("Uploaded")
--- ```
---
--- The builder and the live handle are the same object, so a setter works
--- before and after `:Show()`. Half of these notices are alive — a progress
--- bar, a countdown, a prompt — and a builder that goes inert on show is the
--- wrong shape for them.
---
--- Nothing is built until the first `:Show()`, so a game that never notifies
--- pays nothing for having Flare installed.
---
--- Part of Valence Libs, by Valence.
--- @section Overview

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Types = require(script.Types)
local Markup = require(script.Markup)
local Themes = require(script._Themes)

local NoticeClass = require(script._Core.Notice)
local Queue = require(script._Core.Queue)
local Render = require(script._Core.Render)

local Lume = require(script._Packages.Lume)

--// types ------------------------------------------------------------------------
--- The chained builder and live handle. Every setter returns one.
export type Notice = NoticeClass.Notice
export type Result = Types.Result
export type ResultKind = Types.ResultKind
export type Spec = Types.Spec
export type Tone = Types.Tone
export type Kind = Types.Kind
export type Anchor = Types.Anchor
export type Side = Types.Side
export type Choice = Types.Choice
export type ChoiceLike = Types.ChoiceLike
export type Action = Types.Action
export type Theme = Types.Theme
export type ThemeOverride = Types.ThemeOverride
export type FlareOptions = Types.FlareOptions

--- What a notice's setters default to when it does not say otherwise. Read it
--- freely; change it through `Flare.Start`.
export type Defaults = {
	Anchor: Anchor,
	Max: number,
	Duration: number,
	Durations: { [string]: number },
	Group: boolean,
	Pause: boolean,
	Markup: boolean,
	Sound: boolean,
	--- Played by every notice that names no sound of its own.
	DefaultSound: string?,
	Dismissible: boolean,
	Draggable: boolean,
	Width: number?,
}

--// state ------------------------------------------------------------------------
local Flare = {}

Flare.Version = "0.2.0"

--- The markup compiler, exported so the same dialect can be used elsewhere.
Flare.Markup = Markup
--- The theme registry: `Resolve`, `Register`, `List`.
Flare.Themes = Themes
--- The Lume app notices are drawn into. Nil until the first notice.
Flare.App = nil :: any
--- The active theme's tokens.
Flare.Theme = Themes.Default :: Theme

local defaults: Defaults = {
	Anchor = "bottomRight",
	Max = 4,
	Duration = 5,
	Durations = {},
	Group = true,
	Pause = true,
	Markup = true,
	Sound = true,
	DefaultSound = nil,
	Dismissible = true,
	Draggable = false,
	Width = nil,
}

Flare.Defaults = defaults

--// Every key `Start` understands. An option Flare does not know is almost
--// always a typo for one it does, and swallowing it in silence turns a
--// one-letter slip into an afternoon of wondering why nothing happened.
local KnownOptions: { [string]: boolean } = {
	Theme = true,
	Tokens = true,
	App = true,
	Gui = true,
	DisplayOrder = true,
	Anchor = true,
	Max = true,
	Duration = true,
	Durations = true,
	Group = true,
	Pause = true,
	Markup = true,
	Sound = true,
	Sounds = true,
	Icon = true,
	Icons = true,
	Dismissible = true,
	Draggable = true,
	Shadow = true,
	Width = true,
	Gap = true,
	Inset = true,
}

local queues: { [string]: Queue.Queue } = {}
local stacks: { [string]: any } = {}
local stepping: RBXScriptConnection? = nil
local sequence = 0
local gap: number? = nil
local inset: number? = nil

--// locals -----------------------------------------------------------------------
--- How many single-character edits separate two strings, giving up once the
--- answer is past `limit`. Small and iterative rather than clever: option
--- names are short, and this runs once per unknown key at startup.
local function distance(a: string, b: string, limit: number): number
	if a == b then
		return 0
	end

	if math.abs(#a - #b) > limit then
		return limit + 1
	end

	local previous = table.create(#b + 1)

	for index = 0, #b do
		previous[index + 1] = index
	end

	for i = 1, #a do
		local current = { i }
		local best = i

		for j = 1, #b do
			local cost = if a:sub(i, i) == b:sub(j, j) then 0 else 1
			local value = math.min(current[j] + 1, previous[j + 1] + 1, previous[j] + cost)

			current[j + 1] = value
			best = math.min(best, value)
		end

		if best > limit then
			return limit + 1
		end

		previous = current
	end

	return previous[#b + 1]
end

--- The nearest known option to a misspelled one, if there is a close enough
--- candidate. Wrong case, a missing plural, and a dropped or doubled letter
--- between them cover nearly every real miss.
local function nearest(key: string): string?
	local lower = key:lower()
	--// one edit on a short name, two once there is enough word to get lost in
	local limit = if #key > 6 then 2 else 1
	local best: string? = nil
	local bestScore = limit + 1

	for known in KnownOptions do
		local candidate = known:lower()

		if candidate == lower .. "s" or lower == candidate .. "s" then
			return known
		end

		local score = distance(lower, candidate, limit)

		if score < bestScore then
			best = known
			bestScore = score
		end
	end

	return best
end

local function queueFor(anchor: string): Queue.Queue
	local existing = queues[anchor]

	if existing then
		return existing
	end

	local created = Queue.new(anchor :: any, defaults.Max, defaults.Group)

	queues[anchor] = created

	return created
end

local function stackFor(anchor: string): any
	local existing = stacks[anchor]

	if existing then
		return existing
	end

	local created = Flare.App:stack(anchor :: any)

	created:setGap(gap or Flare.Theme.Spacing.Stack)

	stacks[anchor] = created

	return created
end

--- One stepper for every queue, started on the first notice and stopped when
--- the last one goes, so an idle game is not paying for a connection.
local function ensureStepping()
	if stepping then
		return
	end

	local signal = if RunService:IsClient() then RunService.RenderStepped else RunService.Heartbeat

	stepping = signal:Connect(function(delta)
		local now = os.clock()
		local live = 0

		for _, queue in queues do
			--// a countdown repaints only when its whole-second reading
			--// changes, rather than sixty times a second for no visible gain
			for _, notice in queue.Live do
				local deadline = notice.Spec.Deadline

				if not deadline or not notice.Refs.Timer or notice.Done then
					continue
				end

				local reading = math.max(0, math.ceil(deadline - now))

				if reading ~= notice.Ticked then
					notice.Ticked = reading

					Render.Paint(Flare, notice)
				end
			end

			for _, expired in queue:Tick(now, delta) do
				expired:Resolve({ Kind = "Expired" })
			end

			live += queue:Count() + queue:Waiting()
		end

		if live == 0 and stepping then
			stepping:Disconnect()

			stepping = nil
		end
	end)
end

--- Plays a one-shot.
---
--- `PlayLocalSound` rather than parenting a Sound and calling `Play` on it: a
--- Sound only plays once its asset has loaded, and a freshly created one has
--- not, so `Play()` on the same frame is a coin flip that lands on silence more
--- often than not. `PlayLocalSound` is the engine's own path for this and does
--- not care where the Sound is parented.
local function play(asset: string?)
	if not asset or asset == "" or not defaults.Sound or not RunService:IsClient() then
		return
	end

	local sound = Instance.new("Sound")

	sound.SoundId = asset
	sound.Name = "FlareSound"
	sound.Parent = SoundService

	local played = pcall(function()
		SoundService:PlayLocalSound(sound)
	end)

	if not played then
		sound:Play()
	end

	sound.Ended:Once(function()
		sound:Destroy()
	end)

	--// a sound that fails to load never fires Ended, and would sit there
	task.delay(15, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

--// configuration ----------------------------------------------------------------
--- Configures Flare. Optional — anything left out keeps its default, and the
--- first notice starts it implicitly.
---
--- ```lua
--- Flare.Start({
---     Theme = "Default",
---     Max = 4,
---     Duration = 5,
---     Anchor = "topRight",
---     Shadow = true,
--- })
--- ```
function Flare.Start(options: FlareOptions?): typeof(Flare)
	local settings = options or {}

	for key in settings do
		if not KnownOptions[key] then
			local guess = nearest(key)

			warn(
				`[Flare] Start does not have an option called "{key}", so it was ignored.`
					.. if guess then ` Did you mean "{guess}"?` else ""
			)
		end
	end

	local theme = Themes.Resolve(settings.Theme)

	if settings.Tokens then
		theme = Themes.Extend(theme, settings.Tokens)
	end

	local shadow = settings.Shadow

	if type(shadow) == "boolean" then
		theme = Themes.Extend(theme, { Shadow = { Enabled = shadow } })
	elseif type(shadow) == "table" then
		--// `Shadow = { Spread = 50 }` is what someone reaching for a broader
		--// shadow writes. Read only as an on/off gate it was merely truthy,
		--// and the number they came for was dropped on the floor.
		theme = Themes.Extend(theme, { Shadow = shadow })
	end

	if settings.Anchor then
		defaults.Anchor = settings.Anchor
	end

	if settings.Max then
		defaults.Max = settings.Max
	end

	if settings.Duration then
		defaults.Duration = settings.Duration
	end

	if settings.Durations then
		defaults.Durations = settings.Durations
	end

	if settings.Group ~= nil then
		defaults.Group = settings.Group
	end

	if settings.Pause ~= nil then
		defaults.Pause = settings.Pause
	end

	if settings.Markup ~= nil then
		defaults.Markup = settings.Markup
	end

	--// `Sound` is the gate, `Sounds` is the table of assets, and one letter
	--// stands between them. `Icon` and `Icons` are the same trap. Both
	--// spellings are accepted rather than left to fail quietly.
	local sounds = settings.Sounds
	local icons = settings.Icons or settings.Icon

	if settings.Sound ~= nil then
		local sound = settings.Sound

		if type(sound) == "string" then
			--// a string is the sound itself, not a gate:
			--// `Sound = "rbxassetid://…"` is what people write, and silently
			--// treating it as `true` was worse than either reading
			defaults.Sound = true
			defaults.DefaultSound = sound
		elseif type(sound) == "table" then
			--// read as a gate, a table is not `true`, so `Sound = { Danger = … }`
			--// used to turn every sound off — the exact opposite of the ask
			sounds = sound
			defaults.Sound = true
		else
			defaults.Sound = sound == true
		end
	end

	if sounds then
		theme = Themes.Extend(theme, { Sound = sounds })
	end

	if icons then
		theme = Themes.Extend(theme, { Icon = icons })
	end

	Flare.Theme = theme

	if settings.Dismissible ~= nil then
		defaults.Dismissible = settings.Dismissible
	end

	if settings.Draggable ~= nil then
		defaults.Draggable = settings.Draggable
	end

	if settings.Width then
		defaults.Width = settings.Width
	end

	if settings.Gap then
		gap = settings.Gap
	end

	if settings.Inset then
		inset = settings.Inset
	end

	Flare.App = settings.App
		or Flare.App
		or Lume.app({
			name = "Flare",
			gui = settings.Gui,
			displayOrder = settings.DisplayOrder or 9000,
		})

	--// Lume's shadow is sized for a console window — 22px of bleed on every
	--// side. On a stack of notices that reads as haze, and neighbours bleed
	--// into each other, so Flare's own tokens replace it wholesale.
	local shadows = theme.Shadow

	Flare.App:restyle({
		shadow = {
			image = if shadows.Enabled then shadows.Image else "",
			slice = shadows.Slice,
			color = shadows.Color,
			transparency = shadows.Transparency,
			spread = shadows.Spread,
			offset = shadows.Offset,
		},
		space = {
			lg = inset or theme.Spacing.Inset,
		},
	})

	--// live queues follow a changed cap rather than waiting for a restart
	for _, queue in queues do
		queue.Max = defaults.Max
		queue.Group = defaults.Group
	end

	for _, stack in stacks do
		stack:setGap(gap or theme.Spacing.Stack)
	end

	return Flare
end

--- Ensures an app exists. Called lazily, so requiring Flare builds nothing.
function Flare.Ready(): any
	if not Flare.App then
		Flare.Start()
	end

	return Flare.App
end

--// engine -----------------------------------------------------------------------
--- Whether a kind fades on its own. Anything asking a question does not.
function Flare.Transient(kind: string): boolean
	return kind ~= "Confirm"
		and kind ~= "Prompt"
		and kind ~= "Choice"
		and kind ~= "Color"
		and kind ~= "Number"
		and kind ~= "Rating"
		and kind ~= "Dropdown"
		and kind ~= "Radio"
		and kind ~= "Alert"
end

--- Queues a notice. Called by `Notice:Show()`.
function Flare.Enqueue(_: any, notice: Notice)
	if notice.Shown or notice.Done then
		return
	end

	Flare.Ready()

	sequence += 1
	notice.Order = sequence
	notice.Shown = true

	local queue = queueFor(notice.Spec.Anchor)
	local outcome, other = queue:Add(notice)

	if outcome == "grouped" and other then
		--// merged into a live one: repaint its count and restart its clock, so
		--// a repeating event keeps the notice on screen rather than letting
		--// the original expire on the original schedule
		notice.Shown = false

		Render.Paint(Flare, other)

		if other.Expires then
			other.Expires = os.clock() + (other.Spec.Duration or defaults.Duration)
		end

		if other.Panel then
			other.Panel:flash(0.12)
		end

		notice:Resolve({ Kind = "Grouped", Value = other })

		return
	end

	if outcome == "queued" then
		return
	end

	if other then
		--// displaced by priority: take it off screen, it is in the backlog now
		Flare.Unmount(other)
	end

	Flare.Mount(notice)
end

--- Builds and shows a notice's panel.
function Flare.Mount(notice: Notice)
	local spec = notice.Spec
	local theme = Flare.Theme

	--// a kind's icon wins over a tone's, so a theme can give Achievement its
	--// own glyph without every Accent notice inheriting it
	if not spec.Icon and not spec.Image then
		spec.Icon = theme.Icon[spec.Kind] or theme.Icon[spec.Tone]
	end

	local panel, refs = Render.Build(Flare, notice)

	notice.Panel = panel
	notice.Refs = refs

	--// laid out before it joins the stack, so the stack steps by its real
	--// height rather than by zero and drops the next notice on top of it
	panel:refreshNow()

	if not spec.Attach then
		stackFor(spec.Anchor):add(panel)
	end

	panel:open()

	--// hovering holds it, so a toast cannot vanish as you reach for its button
	if spec.Pausable then
		local instance = panel.instance

		panel.scope:add(instance.MouseEnter:Connect(function()
			notice.Paused = true
		end))

		panel.scope:add(instance.MouseLeave:Connect(function()
			notice.Paused = false
		end))
	end

	local duration = spec.Duration

	if duration == nil and Flare.Transient(spec.Kind) then
		duration = defaults.Durations[spec.Kind] or theme.Duration[spec.Kind] or defaults.Duration
	end

	if duration and duration > 0 then
		notice.Expires = os.clock() + duration
	end

	play(spec.Sound or theme.Sound[spec.Kind] or theme.Sound[spec.Tone] or defaults.DefaultSound)

	for _, handler in notice.ShowHandlers do
		task.spawn(handler)
	end

	ensureStepping()
end

--- Takes a notice's panel off screen and lets the rest of the stack close up.
function Flare.Unmount(notice: Notice)
	local panel = notice.Panel

	if not panel or panel.dead then
		return
	end

	panel:close()

	local stack = stacks[notice.Spec.Anchor]

	if stack then
		stack:remove(panel)
	end

	notice.Panel = nil
	notice.Refs = {}

	--// destroyed after the exit animation, or it vanishes rather than fading
	task.delay(0.4, function()
		if not panel.dead then
			panel:destroy()
		end
	end)
end

--- Takes a finished notice off screen and promotes whatever was waiting.
function Flare.Release(_: any, notice: Notice)
	local queue = queues[notice.Spec.Anchor]

	Flare.Unmount(notice)

	if not queue then
		return
	end

	local promoted = queue:Remove(notice)

	if promoted then
		Flare.Mount(promoted)
	end
end

--- Repaints a live notice's content.
function Flare.Paint(_: any, notice: Notice)
	if notice.Panel then
		Render.Paint(Flare, notice)
	end
end

--- Rebuilds a notice whose structure changed — an action added after showing.
function Flare.Rebuild(_: any, notice: Notice)
	if not notice.Panel then
		return
	end

	Flare.Unmount(notice)
	Flare.Mount(notice)
end

--// kinds ------------------------------------------------------------------------
local function make(kind: Kind, body: string?): Notice
	return NoticeClass.new(Flare, kind, body)
end

--- A transient notice in a corner. The default, and the one to reach for when
--- you are not sure.
function Flare.Toast(body: string?): Notice
	return make("Toast", body)
end

--- A bar across an edge, for something that affects the whole session.
function Flare.Banner(body: string?): Notice
	return make("Banner", body):At("top")
end

--- Stays until dismissed — the kind for something they must have seen.
function Flare.Alert(body: string?): Notice
	return make("Alert", body)
end

--- A toast with one action: the shape of "Deleted. **Undo**".
function Flare.Snackbar(body: string?, actionText: string?, run: ((Notice) -> boolean?)?): Notice
	local notice = make("Snackbar", body):At("bottom")

	if actionText then
		notice:Action(actionText, run)
	end

	return notice
end

--- Asks a yes or no question. `:Await()` returns the answer.
function Flare.Confirm(body: string?): Notice
	local notice = make("Confirm", body)

	notice:Action("Confirm", function(handle)
		handle:Resolve({ Kind = "Accepted", Value = true })

		return false
	end)

	notice:Action("Cancel", function(handle)
		handle:Resolve({ Kind = "Cancelled", Value = false })

		return false
	end)

	return notice
end

--- Asks for a line of text.
function Flare.Prompt(body: string?): Notice
	local notice = make("Prompt", body)

	notice:Action("Cancel", function(handle)
		handle:Resolve({ Kind = "Cancelled" })

		return false
	end)

	return notice
end

--- Asks for a colour. Resolves with the `Color3` itself.
---
--- ```lua
--- local answer = Flare.Color("Trail colour", Color3.fromRGB(126, 170, 255)):Await()
---
--- if answer.Kind == "Value" then
---     trail.Color = ColorSequence.new(answer.Value)
--- end
--- ```
---
--- Watch the drag rather than only the answer by reading `notice.Spec.Color`
--- from an `OnShow` handler, or by passing a handler to `Flare.Color` — the
--- picker writes every change back to the spec.
function Flare.Color(body: string?, initial: Color3?): Notice
	local notice = make("Color", body)

	if initial then
		notice:Color(initial)
	end

	notice:Action("Pick", function(handle)
		handle:Resolve({ Kind = "Value", Value = handle.Spec.Color })

		return false
	end)

	notice:Action("Cancel", function(handle)
		handle:Resolve({ Kind = "Cancelled" })

		return false
	end)

	return notice
end

--- Asks for a number. Resolves with it.
---
--- ```lua
--- local answer = Flare.Number("How many?", 1):Range(1, 99):Await()
---
--- if answer.Kind == "Value" then
---     buy(answer.Value)
--- end
--- ```
---
--- A stepper rather than a text field, because a quantity has a floor, a
--- ceiling and a step, and none of those survive being typed.
function Flare.Number(body: string?, initial: number?): Notice
	local notice = make("Number", body)

	if initial then
		notice:Number(initial)
	end

	notice:Action("Confirm", function(handle)
		handle:Resolve({ Kind = "Value", Value = handle.Spec.Number })

		return false
	end)

	notice:Action("Cancel", function(handle)
		handle:Resolve({ Kind = "Cancelled" })

		return false
	end)

	return notice
end

--- Asks for a score out of five. Resolves the moment a star is clicked —
--- there is no sensible second step after picking four stars.
---
--- ```lua
--- local answer = Flare.Rate("How was that round?"):Await()
--- ```
function Flare.Rate(body: string?, maximum: number?): Notice
	local notice = make("Rating", body)

	if maximum then
		notice.Spec.Maximum = maximum
	end

	notice:Action("Not now", function(handle)
		handle:Resolve({ Kind = "Cancelled" })

		return false
	end)

	return notice
end

--- Asks them to pick from a dropdown. For a list too long to lay out — twenty
--- countries rather than three teams.
---
--- ```lua
--- local answer = Flare.Dropdown("Spawn where?", { "Base", "Arena", "Docks" }):Await()
--- ```
function Flare.Dropdown(body: string?, options: { ChoiceLike }?, initial: string?): Notice
	local notice = make("Dropdown", body)

	if options then
		notice:Options(options)
	end

	if initial then
		notice.Spec.Default = initial
	end

	notice:Action("Confirm", function(handle)
		if not handle.Spec.Default then
			--// nothing chosen yet: keep it open rather than resolving with nil
			return false
		end

		handle:Resolve({ Kind = "Value", Value = handle.Spec.Default })

		return false
	end)

	notice:Action("Cancel", function(handle)
		handle:Resolve({ Kind = "Cancelled" })

		return false
	end)

	return notice
end

--- Asks them to pick with every option visible at once. For a few options with
--- consequences, which want to be read side by side.
---
--- ```lua
--- local answer = Flare.Radio("Which team?", {
---     { Id = "red", Text = "Red", Description = "Attackers" },
---     { Id = "blue", Text = "Blue", Description = "Defenders" },
--- }):Await()
--- ```
function Flare.Radio(body: string?, options: { ChoiceLike }?, initial: string?): Notice
	local notice = make("Radio", body)

	if options then
		notice:Options(options)
	end

	if initial then
		notice.Spec.Default = initial
	end

	notice:Action("Confirm", function(handle)
		if not handle.Spec.Default then
			return false
		end

		handle:Resolve({ Kind = "Value", Value = handle.Spec.Default })

		return false
	end)

	notice:Action("Cancel", function(handle)
		handle:Resolve({ Kind = "Cancelled" })

		return false
	end)

	return notice
end

--- Asks them to pick one of several.
function Flare.Choice(body: string?, options: { ChoiceLike }?): Notice
	local notice = make("Choice", body)

	if options then
		notice:Choices(options)
	end

	return notice
end

--- A bar you fill and then resolve.
function Flare.Progress(body: string?): Notice
	return make("Progress", body):Progress(0):Sticky()
end

--- An indeterminate spinner, for work of unknown length.
function Flare.Loading(body: string?): Notice
	return make("Loading", body):Indeterminate(true):Sticky()
end

--- Counts down to a deadline and expires when it arrives.
function Flare.Countdown(body: string?, seconds: number?): Notice
	local notice = make("Countdown", body)

	if seconds then
		notice:Duration(seconds):Until(os.clock() + seconds)
	end

	return notice
end

--- Big and celebratory. The one kind allowed to interrupt.
function Flare.Achievement(title: string?, body: string?): Notice
	local notice = make("Achievement", body):At("top"):Accent()

	if title then
		notice:Title(title)
	end

	return notice
end

--- An achievement with an amount, for currency and drops.
function Flare.Reward(title: string?, body: string?): Notice
	local notice = make("Reward", body):At("top"):Ok()

	if title then
		notice:Title(title)
	end

	return notice
end

--- Pinned to a GuiObject rather than a screen corner, so it points at the
--- thing it is talking about.
function Flare.Hint(body: string?, target: GuiObject?, side: Side?): Notice
	local notice = make("Hint", body)

	if target then
		notice:Attach(target, side)
	end

	return notice
end

--// control ----------------------------------------------------------------------
--- Dismisses everything, or everything at one anchor.
function Flare.Clear(anchor: Anchor?)
	for name, queue in queues do
		if anchor and name ~= anchor then
			continue
		end

		for _, notice in queue:Clear() do
			notice:Resolve({ Kind = "Dismissed" })
		end
	end
end

--- How many notices are on screen, and how many are waiting for a slot.
function Flare.Count(): (number, number)
	local live, waiting = 0, 0

	for _, queue in queues do
		live += queue:Count()
		waiting += queue:Waiting()
	end

	return live, waiting
end

--- Every live notice, newest queue first. Handy for a "dismiss all" button.
function Flare.Live(): { Notice }
	local out: { Notice } = {}

	for _, queue in queues do
		for _, notice in queue.Live do
			table.insert(out, notice)
		end
	end

	return out
end

--- Switches theme. Returns false if the name is not registered — new notices
--- pick it up, and live ones repaint.
function Flare.SetTheme(name: string): boolean
	local resolved = Themes.Resolve(name)

	if string.lower(resolved.Name) ~= string.lower(name) then
		return false
	end

	Flare.Theme = resolved

	if Flare.App then
		Flare.Start({ Theme = name })
	end

	for _, notice in Flare.Live() do
		Flare.Rebuild(Flare, notice)
	end

	return true
end

--- Registers a theme. Overrides are deep-merged over the theme it extends, so
--- one colour is a one-line theme.
---
--- ```lua
--- Flare.DefineTheme("Mine", { Color = { Ok = Color3.fromHex("#7dcfff") } })
--- ```
function Flare.DefineTheme(name: string, tokens: ThemeOverride, extends: string?): Theme
	return Themes.Register(name, tokens, extends)
end

--- Tears everything down: notices, stepper, app.
function Flare.Destroy()
	Flare.Clear()

	if stepping then
		stepping:Disconnect()

		stepping = nil
	end

	if Flare.App then
		Flare.App:destroy()
	end

	--// left dangling, Render would keep drawing into a destroyed app
	Flare.App = nil

	table.clear(queues)
	table.clear(stacks)
end

export type Api = typeof(Flare)

return Flare
