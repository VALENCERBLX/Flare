--!strict

--- **Flare** — notifications for Roblox.
---
--- Thirteen kinds on one queue, every one of them the same chained builder:
---
--- ```lua
--- local Flare = require(ReplicatedStorage.Flare)
---
--- Flare.toast("Saved"):ok():show()
---
--- Flare.confirm("Delete everything?")
---     :danger()
---     :onAccept(wipe)
---     :show()
---
--- local job = Flare.progress("Uploading"):show()
--- job:progress(0.4)
--- job:finish("Uploaded")
--- ```
---
--- The builder and the live handle are the same object, so a setter works
--- before and after `:show()`. Half of these notices are alive — a progress
--- bar, a countdown, a prompt — and a builder that goes inert on show is the
--- wrong shape for them.
---
--- Part of Valence Libs, by Valence.
--- @section Overview

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Types = require(script.Types)
local Markup = require(script.Markup)
local Themes = require(script._Themes)

local Notice = require(script._Core.Notice)
local Queue = require(script._Core.Queue)
local Render = require(script._Core.Render)

local Lume = require(script._Packages.Lume)

--// types
export type Notice = any
export type Result = Types.Result
export type Spec = Types.Spec
export type Tone = Types.Tone
export type Kind = Types.Kind
export type Anchor = Types.Anchor
export type FlareOptions = Types.FlareOptions

--// state -----------------------------------------------------------------------
local Flare = {}

Flare.Version = "0.1.0"
Flare.App = nil :: any
Flare.Markup = Markup
Flare.Themes = Themes

local app: any = nil
local theme: any = Themes.Default
local queues: { [string]: any } = {}
local stacks: { [string]: any } = {}
local stepping: RBXScriptConnection? = nil
local sequence = 0

local defaults = {
	Anchor = "bottomRight" :: Types.Anchor,
	Max = 4,
	Duration = 5,
	Group = true,
	Pause = true,
	Markup = true,
	Sound = true,
	Width = nil :: number?,
}

Flare.Defaults = defaults

--// locals ----------------------------------------------------------------------
local function queueFor(anchor: string): any
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

	local created = app:stack(anchor :: any)

	created:setGap(theme.Spacing.Stack)

	stacks[anchor] = created

	return created
end

--- One stepper for every queue, started on the first notice and stopped when
--- the last one goes, so an idle game pays nothing for having Flare installed.
local function ensureStepping()
	if stepping then
		return
	end

	local signal = if RunService:IsClient() then RunService.RenderStepped else RunService.Heartbeat

	stepping = signal:Connect(function(delta)
		local now = os.clock()
		local live = 0

		for _, queue in queues do
			--// a countdown is repainted only when its whole-second reading
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
				expired:resolve({ Kind = "Expired" })
			end

			live += queue:Count() + queue:Waiting()
		end

		if live == 0 and stepping then
			stepping:Disconnect()

			stepping = nil
		end
	end)
end

local function play(asset: string?)
	if not asset or not defaults.Sound or not RunService:IsClient() then
		return
	end

	local sound = Instance.new("Sound")

	sound.SoundId = asset
	sound.Parent = SoundService

	sound:Play()

	sound.Ended:Once(function()
		sound:Destroy()
	end)

	--// a sound that never fires Ended would otherwise leak
	task.delay(10, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

--// engine ----------------------------------------------------------------------
--- Ensures an app exists. Called lazily, so requiring Flare builds no
--- instances until something is actually shown.
function Flare.Ready(): any
	if not app then
		Flare.Start()
	end

	return app
end

--- Configures Flare. Optional — anything not set keeps its default, and the
--- first notice starts it implicitly.
function Flare.Start(options: FlareOptions?)
	local settings = options or {}

	theme = Themes.Resolve(settings.Theme)

	if settings.Max then
		defaults.Max = settings.Max
	end

	if settings.Duration then
		defaults.Duration = settings.Duration
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

	if settings.Sound ~= nil then
		defaults.Sound = settings.Sound
	end

	if settings.Width then
		defaults.Width = settings.Width
	end

	app = settings.App
		or app
		or Lume.app({
			name = "Flare",
			gui = settings.Gui,
			displayOrder = settings.DisplayOrder or 9000,
		})

	Flare.App = app
	Flare.Theme = theme

	return Flare
end

--- Queues a notice. Called by `Notice:show()`.
function Flare.Enqueue(_: any, notice: any)
	if notice.Shown then
		return
	end

	Flare.Ready()

	sequence += 1
	notice.Order = sequence
	notice.Shown = true

	local spec = notice.Spec
	local queue = queueFor(spec.Anchor)

	local outcome, other = queue:Add(notice)

	if outcome == "grouped" then
		--// merged into a live one: repaint its count and restart its clock, so
		--// a repeat event keeps the notice on screen rather than letting the
		--// original expire on the original schedule
		notice.Shown = false

		Render.Paint(Flare, other)

		if other.Expires then
			other.Expires = os.clock() + (other.Spec.Duration or defaults.Duration)
		end

		if other.Panel then
			other.Panel:flash(0.12)
		end

		notice:resolve({ Kind = "Grouped", Value = other })

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
function Flare.Mount(notice: any)
	local spec = notice.Spec

	local panel, refs = Render.Build(Flare, notice)

	notice.Panel = panel
	notice.Refs = refs

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
		duration = theme.Duration[spec.Kind] or defaults.Duration
	end

	if duration and duration > 0 then
		notice.Expires = os.clock() + duration
	end

	play(spec.Sound)

	for _, handler in notice.OnShow do
		task.spawn(handler)
	end

	ensureStepping()
end

--- Whether a kind fades on its own. Anything asking a question does not.
function Flare.Transient(kind: string): boolean
	return kind ~= "Confirm" and kind ~= "Prompt" and kind ~= "Choice" and kind ~= "Alert"
end

function Flare.Unmount(notice: any)
	local panel = notice.Panel

	if not panel or panel.dead then
		return
	end

	panel:close()

	local anchor = notice.Spec.Anchor
	local stack = stacks[anchor]

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
function Flare.Release(_: any, notice: any)
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

function Flare.Paint(_: any, notice: any)
	if notice.Panel then
		Render.Paint(Flare, notice)
	end
end

--- Rebuilds a notice whose structure changed — an action added after showing.
function Flare.Rebuild(_: any, notice: any)
	if not notice.Panel then
		return
	end

	Flare.Unmount(notice)
	Flare.Mount(notice)
end

--// kinds -----------------------------------------------------------------------
local function make(kind: Types.Kind, body: string?): any
	return Notice.new(Flare, kind, body)
end

--- A transient notice in a corner. The default.
function Flare.toast(body: string?): Notice
	return make("Toast", body)
end

--- A bar across an edge, for something that affects the whole session.
function Flare.banner(body: string?): Notice
	return make("Banner", body):at("top")
end

--- Stays until dismissed.
function Flare.alert(body: string?): Notice
	return make("Alert", body)
end

--- A toast with one action, the shape of "Deleted. **Undo**".
function Flare.snackbar(body: string?, actionText: string?, run: ((Notice) -> boolean?)?): Notice
	local notice = make("Snackbar", body):at("bottom")

	if actionText then
		notice:action(actionText, run)
	end

	return notice
end

--- Asks a yes or no question. `:await()` returns the answer.
function Flare.confirm(body: string?): Notice
	local notice = make("Confirm", body)

	notice:action("Confirm", function(handle)
		handle:resolve({ Kind = "Accepted", Value = true })

		return false
	end)

	notice:action("Cancel", function(handle)
		handle:resolve({ Kind = "Cancelled", Value = false })

		return false
	end)

	return notice
end

--- Asks for a line of text.
function Flare.prompt(body: string?): Notice
	local notice = make("Prompt", body)

	notice:action("Cancel", function(handle)
		handle:resolve({ Kind = "Cancelled" })

		return false
	end)

	return notice
end

--- Asks the player to pick one of several.
function Flare.choice(body: string?, options: { any }?): Notice
	local notice = make("Choice", body)

	if options then
		notice:choices(options)
	end

	return notice
end

--- A bar you update and then resolve.
function Flare.progress(body: string?): Notice
	return make("Progress", body):progress(0):sticky()
end

--- An indeterminate spinner for work of unknown length.
function Flare.loading(body: string?): Notice
	return make("Loading", body):indeterminate(true):sticky()
end

--- Counts down to a deadline and expires when it arrives.
function Flare.countdown(body: string?, seconds: number?): Notice
	local notice = make("Countdown", body)

	if seconds then
		notice:duration(seconds):until_(os.clock() + seconds)
	end

	return notice
end

--- Big and celebratory. The one kind allowed to interrupt.
function Flare.achievement(title: string?, body: string?): Notice
	local notice = make("Achievement", body):at("top"):accent()

	if title then
		notice:title(title)
	end

	return notice
end

--- An achievement with an amount, for currency and drops.
function Flare.reward(title: string?, body: string?): Notice
	local notice = make("Reward", body):at("top"):ok()

	if title then
		notice:title(title)
	end

	return notice
end

--- Pinned to a GuiObject rather than a screen corner.
function Flare.hint(body: string?, target: GuiObject?, side: string?): Notice
	local notice = make("Hint", body)

	if target then
		notice:attach(target, side)
	end

	return notice
end

--// control ---------------------------------------------------------------------
--- Dismisses everything, everywhere.
function Flare.clear(anchor: Types.Anchor?)
	for name, queue in queues do
		if anchor and name ~= anchor then
			continue
		end

		for _, notice in queue:Clear() do
			notice:resolve({ Kind = "Dismissed" })
		end
	end
end

--- How many notices are on screen, or waiting.
function Flare.count(): (number, number)
	local live, waiting = 0, 0

	for _, queue in queues do
		live += queue:Count()
		waiting += queue:Waiting()
	end

	return live, waiting
end

function Flare.setTheme(name: string): boolean
	local resolved = Themes.Resolve(name)

	if string.lower(resolved.Name) ~= string.lower(name) then
		return false
	end

	theme = resolved
	Flare.Theme = resolved

	return true
end

function Flare.defineTheme(name: string, tokens: { [string]: any }, extends: string?)
	return Themes.Register(name, tokens, extends)
end

function Flare.destroy()
	Flare.clear()

	if stepping then
		stepping:Disconnect()

		stepping = nil
	end

	if app then
		app:destroy()

		app = nil
	end

	--// left dangling, Render would keep drawing into a destroyed app
	Flare.App = nil

	table.clear(queues)
	table.clear(stacks)
end

Flare.Theme = theme

export type Api = typeof(Flare)

return Flare
