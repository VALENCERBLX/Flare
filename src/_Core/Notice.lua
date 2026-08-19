--!strict

--- A notice: the chained builder you configure, and the live handle you keep.
---
--- The same object plays both parts on purpose. Before `:Show()` the setters
--- describe what you want; after it they still work, so `:Update("…")` on a
--- progress bar or `:Tone("Danger")` on a countdown mutates something already
--- on screen. A builder that becomes inert the moment it is shown is the wrong
--- shape for notifications, half of which are alive.
---
--- Every setter returns the notice, so everything chains and every step of the
--- chain is typed:
---
--- ```lua
--- Flare.Toast("Saved"):Ok():Duration(4):Show()
--- ```
--- @section Core

local Types = require(script.Parent.Parent.Types)

type Spec = Types.Spec
type Result = Types.Result
type Tone = Types.Tone

local Notice = {}
Notice.__index = Notice

--- Runtime state. Every one of these is a declared field rather than something
--- smuggled in through an `any` cast, so the type checker sees them.
---
--- **No field name here may match a method name.** An instance field shadows
--- its metatable, so a field called `OnShow` would make `notice:OnShow(f)` fail
--- with *attempt to call a table value* — which is why the two handler lists
--- are `ResolveHandlers` and `ShowHandlers`.
export type Fields = {
	Spec: Spec,
	--- The Flare singleton this notice belongs to.
	Flare: any,

	--// live state, all empty until shown
	Panel: any,
	Refs: { [string]: any },
	Shown: boolean,
	Done: boolean,
	Result: Result?,

	Expires: number?,
	Paused: boolean,
	--- How many notices have collapsed into this one, counting itself.
	Count: number,
	--- Last whole-second countdown reading painted, so a clock repaints on the
	--- second rather than every frame.
	Ticked: number?,
	--- Arrival number, stamped on show. Ties in priority fall back to it, so a
	--- burst of equal notices keeps the order it arrived in.
	Order: number,

	ResolveHandlers: { (Result) -> () },
	ShowHandlers: { () -> () },
	Waiters: { thread },
}

export type Notice = typeof(setmetatable({} :: Fields, Notice))

--// public api ------------------------------------------------------------------
function Notice.new(flare: any, kind: Types.Kind, body: string?): Notice
	local defaults = flare.Defaults

	local self: Fields = {
		Spec = {
			Kind = kind,

			Title = nil,
			Body = body,
			Icon = nil,
			Image = nil,
			Tone = "Neutral",

			Anchor = defaults.Anchor,
			Duration = nil,
			Priority = 0,
			Group = nil,

			Actions = {},
			Choices = {},

			Dismissible = defaults.Dismissible,
			Markup = defaults.Markup,
			Pausable = defaults.Pause,
			Draggable = defaults.Draggable,
			Shadow = nil,
			Sound = nil,
			Width = nil,
			Layer = nil,

			Progress = nil,
			Indeterminate = nil,
			Deadline = nil,

			Placeholder = nil,
			Default = nil,
			Color = nil,
			Number = nil,
			Minimum = nil,
			Maximum = nil,
			Step = nil,
			UserId = nil,
			Builder = nil,
			Attach = nil,
			Side = nil,

			Meta = nil,
		},
		Flare = flare,

		Panel = nil,
		Refs = {},
		Shown = false,
		Done = false,
		Result = nil,

		Expires = nil,
		Paused = false,
		Count = 1,
		Ticked = nil,
		Order = 0,

		ResolveHandlers = {},
		ShowHandlers = {},
		Waiters = {},
	}

	return setmetatable(self, Notice)
end

--// content ---------------------------------------------------------------------
--- A heading above the body.
function Notice.Title(self: Notice, text: string): Notice
	self.Spec.Title = text

	return Notice.Refresh(self)
end

function Notice.Body(self: Notice, text: string): Notice
	self.Spec.Body = text

	return Notice.Refresh(self)
end

--- Replaces the body. The name every other notification library uses, and the
--- one people reach for on a live handle.
function Notice.Update(self: Notice, text: string): Notice
	return Notice.Body(self, text)
end

function Notice.Icon(self: Notice, asset: string): Notice
	self.Spec.Icon = asset

	return Notice.Refresh(self)
end

--- A large image, for a reward or an achievement.
function Notice.Image(self: Notice, asset: string): Notice
	self.Spec.Image = asset

	return Notice.Refresh(self)
end

--- Anything you want to carry along. Flare never reads it — it is there so a
--- resolve handler can tell which notice it is looking at.
function Notice.Meta(self: Notice, data: { [string]: any }): Notice
	self.Spec.Meta = data

	return self
end

--// appearance -------------------------------------------------------------------
function Notice.Tone(self: Notice, tone: string): Notice
	--// accepts "ok" or "Ok", because nobody wants to remember which
	self.Spec.Tone = (string.upper(string.sub(tone, 1, 1)) .. string.sub(tone, 2)) :: Tone

	return Notice.Refresh(self)
end

function Notice.Info(self: Notice): Notice
	return Notice.Tone(self, "Info")
end

function Notice.Ok(self: Notice): Notice
	return Notice.Tone(self, "Ok")
end

function Notice.Warn(self: Notice): Notice
	return Notice.Tone(self, "Warn")
end

function Notice.Danger(self: Notice): Notice
	return Notice.Tone(self, "Danger")
end

function Notice.Accent(self: Notice): Notice
	return Notice.Tone(self, "Accent")
end

--- Which corner (or edge) it appears at. Each anchor has its own queue, so a
--- full corner never blocks a banner.
function Notice.At(self: Notice, anchor: Types.Anchor): Notice
	self.Spec.Anchor = anchor

	return self
end

function Notice.Width(self: Notice, pixels: number): Notice
	self.Spec.Width = pixels

	return self
end

--- Draws this one on a different Lume layer, for a notice that has to sit
--- above or below the rest.
function Notice.Layer(self: Notice, layer: string): Notice
	self.Spec.Layer = layer

	return self
end

function Notice.Shadow(self: Notice, enabled: boolean): Notice
	self.Spec.Shadow = enabled ~= false

	return self
end

--- Turns markup parsing off for this notice, when the body is text somebody
--- else wrote and should never be interpreted.
function Notice.Literal(self: Notice): Notice
	self.Spec.Markup = false

	return Notice.Refresh(self)
end

--// lifetime ---------------------------------------------------------------------
--- Seconds on screen. Zero means it stays until something dismisses it.
---
--- `nil` is not the same as zero: it means *unset*, and an unset duration on a
--- kind that fades falls back to the theme's default for that kind. Zero is how
--- you say "no, really, stay".
function Notice.Duration(self: Notice, seconds: number?): Notice
	self.Spec.Duration = seconds

	if self.Shown then
		self.Expires = if seconds and seconds > 0 then os.clock() + seconds else nil
	end

	return self
end

--- Stays until dismissed or resolved, whatever kind it is.
function Notice.Sticky(self: Notice): Notice
	return Notice.Duration(self, 0)
end

--- Higher sorts nearer the front, and displaces the least important notice on
--- screen rather than queueing behind it.
function Notice.Priority(self: Notice, value: number): Notice
	self.Spec.Priority = value

	return self
end

--- Notices sharing a group key collapse into one with a count, instead of
--- three identical toasts stacking up.
function Notice.Group(self: Notice, key: string): Notice
	self.Spec.Group = key

	return self
end

function Notice.Dismissible(self: Notice, enabled: boolean): Notice
	self.Spec.Dismissible = enabled ~= false

	return self
end

function Notice.Pausable(self: Notice, enabled: boolean): Notice
	self.Spec.Pausable = enabled ~= false

	return self
end

function Notice.Draggable(self: Notice, enabled: boolean): Notice
	self.Spec.Draggable = enabled ~= false

	return self
end

function Notice.Sound(self: Notice, asset: string): Notice
	self.Spec.Sound = asset

	return self
end

--// actions ----------------------------------------------------------------------
--- Adds a button. Its callback receives this handle, so it can update or
--- dismiss the notice it came from. Returning `false` keeps the notice open.
function Notice.Action(self: Notice, text: string, run: ((Notice) -> boolean?)?, tone: string?): Notice
	table.insert(self.Spec.Actions, {
		Text = text,
		Run = run :: any,
		Tone = tone :: any,
		Primary = #self.Spec.Actions == 0,
	})

	return Notice.Rebuild(self)
end

--- The options for a `Choice`. A bare string is its own id.
function Notice.Choices(self: Notice, options: { Types.ChoiceLike }): Notice
	local out: { Types.Choice } = {}

	for index, entry in options do
		if type(entry) == "string" then
			table.insert(out, { Id = entry, Text = entry })
		else
			table.insert(out, {
				Id = entry.Id or entry.Text or tostring(index),
				Text = entry.Text or tostring(entry.Id),
				Icon = entry.Icon,
				Description = entry.Description,
			})
		end
	end

	self.Spec.Choices = out

	return Notice.Rebuild(self)
end

--// live state --------------------------------------------------------------------
--- Sets a progress bar, 0 to 1. Values above 1 are read as a percentage.
function Notice.Progress(self: Notice, value: number): Notice
	local raw = tonumber(value) or 0

	self.Spec.Progress = math.clamp(if raw > 1 then raw / 100 else raw, 0, 1)
	self.Spec.Indeterminate = false

	return Notice.Refresh(self)
end

--- A bar that sweeps rather than fills, for work of unknown length.
function Notice.Indeterminate(self: Notice, enabled: boolean?): Notice
	self.Spec.Indeterminate = enabled ~= false

	return Notice.Refresh(self)
end

--- Counts down to a wall-clock deadline, in `os.clock` terms.
function Notice.Until(self: Notice, clock: number): Notice
	self.Spec.Deadline = clock

	return Notice.Refresh(self)
end

--// prompts -----------------------------------------------------------------------
function Notice.Placeholder(self: Notice, text: string): Notice
	self.Spec.Placeholder = text

	return Notice.Refresh(self)
end

--- Pre-fills a prompt's field.
function Notice.Default(self: Notice, text: string): Notice
	self.Spec.Default = text

	return Notice.Refresh(self)
end

--- The colour a `Color` notice opens on. Rebuilds rather than refreshes when
--- the notice is already up, because the picker holds its own state once it
--- exists and will not take a new one from underneath it.
function Notice.Color(self: Notice, color: Color3): Notice
	self.Spec.Color = color

	if self.Panel and self.Refs.Picker then
		self.Refs.Picker:setSilent(color)

		return self
	end

	return Notice.Refresh(self)
end

--- What a `Number` notice opens on. Like `Color`, this reaches a live stepper
--- directly rather than rebuilding the panel around it.
function Notice.Number(self: Notice, value: number): Notice
	self.Spec.Number = value

	if self.Panel and self.Refs.Stepper then
		self.Refs.Stepper:setValue(value)

		return self
	end

	return Notice.Refresh(self)
end

--- The range a `Number` notice may move in.
function Notice.Range(self: Notice, minimum: number, maximum: number): Notice
	self.Spec.Minimum = minimum
	self.Spec.Maximum = maximum

	if self.Panel and self.Refs.Stepper then
		self.Refs.Stepper:setRange(minimum, maximum)

		return self
	end

	return Notice.Refresh(self)
end

--- How far one press of the plus moves it.
function Notice.Step(self: Notice, step: number): Notice
	self.Spec.Step = step

	if self.Panel and self.Refs.Stepper then
		self.Refs.Stepper:setStep(step)

		return self
	end

	return Notice.Refresh(self)
end

--- Puts a player's headshot on the notice, in place of an icon.
---
--- Requested through `rbxthumb://`, so nothing yields and nothing has to be
--- fetched before the notice can appear.
function Notice.Avatar(self: Notice, userId: number, name: string?): Notice
	self.Spec.UserId = userId

	if name then
		self.Spec.Meta = self.Spec.Meta or {}
		self.Spec.Meta.AvatarName = name
	end

	return Notice.Rebuild(self)
end

--- Hands you the Lume panel while the notice is being built.
---
--- This is the escape hatch, and it is the answer to "can a notice contain a
--- ...": yes, whatever Lume has. A tree, a table, a sparkline, three of your
--- own elements. The callback runs during the build, after the body and before
--- the buttons, and anything it returns is ignored.
---
--- ```lua
--- Flare.Toast("Server load"):Custom(function(panel)
---     panel:sparkline({ 4, 9, 6, 12, 7 }):setHeight(24)
--- end)
--- ```
---
--- It runs again on every rebuild, so it must build rather than mutate: keep a
--- reference from inside if you need to change what it made.
function Notice.Custom(self: Notice, build: (panel: any, notice: Notice) -> ()): Notice
	self.Spec.Builder = build :: any

	return Notice.Rebuild(self)
end

--- Pins the notice to a `GuiObject` instead of a screen corner, so it points
--- at the thing it is talking about.
function Notice.Attach(self: Notice, target: GuiObject, side: Types.Side?): Notice
	self.Spec.Attach = target
	self.Spec.Side = side or "top"

	return self
end

--// callbacks ---------------------------------------------------------------------
--- Fires however the notice finishes.
function Notice.OnResolve(self: Notice, handler: (Result) -> ()): Notice
	table.insert(self.ResolveHandlers, handler)

	return self
end

function Notice.OnAccept(self: Notice, handler: (any) -> ()): Notice
	return Notice.OnResolve(self, function(result)
		if result.Kind == "Accepted" or result.Kind == "Value" then
			handler(result.Value)
		end
	end)
end

function Notice.OnCancel(self: Notice, handler: () -> ()): Notice
	return Notice.OnResolve(self, function(result)
		if result.Kind == "Cancelled" then
			handler()
		end
	end)
end

function Notice.OnDismiss(self: Notice, handler: () -> ()): Notice
	return Notice.OnResolve(self, function(result)
		if result.Kind == "Dismissed" or result.Kind == "Expired" then
			handler()
		end
	end)
end

function Notice.OnShow(self: Notice, handler: () -> ()): Notice
	table.insert(self.ShowHandlers, handler)

	return self
end

--// control -----------------------------------------------------------------------
--- Queues the notice. Returns itself, still live.
function Notice.Show(self: Notice): Notice
	self.Flare:Enqueue(self)

	return self
end

--- Dismisses it. `kind` distinguishes a player closing it from it timing out.
function Notice.Dismiss(self: Notice, kind: Types.ResultKind?): Notice
	return Notice.Resolve(self, { Kind = kind or "Dismissed" })
end

--- Finishes the notice with a result, firing every callback and waking anyone
--- blocked in `Await`.
function Notice.Resolve(self: Notice, result: Result): Notice
	if self.Done then
		return self
	end

	self.Done = true
	self.Result = result

	self.Flare:Release(self)

	for _, handler in self.ResolveHandlers do
		local ok, err = pcall(handler, result)

		if not ok then
			warn(`[Flare] resolve handler errored: {err}`)
		end
	end

	for _, thread in self.Waiters do
		task.spawn(thread, result)
	end

	table.clear(self.Waiters)

	return self
end

--- Blocks until the notice finishes, then returns its result.
---
--- Shows it first if it has not been shown, so `Flare.Confirm(…):Await()` is
--- one expression rather than two.
function Notice.Await(self: Notice): Result
	if self.Done then
		return self.Result :: Result
	end

	if not self.Shown then
		Notice.Show(self)
	end

	table.insert(self.Waiters, coroutine.running())

	return coroutine.yield()
end

--- Marks a progress notice finished and lets it fade.
function Notice.Finish(self: Notice, message: string?, tone: string?): Notice
	if message then
		Notice.Body(self, message)
	end

	Notice.Tone(self, tone or "Ok")
	Notice.Progress(self, 1)

	return Notice.Duration(self, 2)
end

--- Marks it failed. Stays longer than a success, because a failure is the one
--- you actually have to read.
function Notice.Fail(self: Notice, message: string?): Notice
	if message then
		Notice.Body(self, message)
	end

	Notice.Tone(self, "Danger")
	Notice.Indeterminate(self, false)

	return Notice.Duration(self, 4)
end

--// internal ----------------------------------------------------------------------
--- Repaints without rebuilding, for a setter that changed only content.
function Notice.Refresh(self: Notice): Notice
	if self.Shown and not self.Done then
		self.Flare:Paint(self)
	end

	return self
end

--- Rebuilds the whole body, for a setter that changed its structure.
function Notice.Rebuild(self: Notice): Notice
	if self.Shown and not self.Done then
		self.Flare:Rebuild(self)
	end

	return self
end

--- Whether it is on screen and unanswered.
function Notice.Alive(self: Notice): boolean
	return self.Shown and not self.Done
end

return Notice
