--!strict

--- A notice: the chained builder you configure, and the live handle you keep.
---
--- The same object plays both parts on purpose. Before `:show()` the setters
--- describe what you want; after it they still work, so `:update("…")` on a
--- progress bar or `:tone("danger")` on a countdown mutates something already
--- on screen. A builder that becomes inert the moment it is shown is the wrong
--- shape for notifications, half of which are alive.
--- @section Core

local Types = require(script.Parent.Parent.Types)

type Spec = Types.Spec
type Result = Types.Result

local Notice = {}
Notice.__index = Notice

export type Fields = {
	Spec: Spec,
	Flare: any,

	--// live state, all nil until shown
	Panel: any,
	Refs: { [string]: any },
	Shown: boolean,
	Done: boolean,
	Result: Result?,

	Expires: number?,
	Paused: boolean,
	Count: number,
	--- Last whole-second countdown reading painted, so a clock repaints on the
	--- second rather than every frame.
	Ticked: number?,
	--- Arrival number, stamped on show. Ties in priority fall back to it, so a
	--- burst of equal notices keeps the order it arrived in.
	Order: number,

	OnResolve: { (Result) -> () },
	OnShow: { () -> () },
	Waiters: { thread },
}

export type Notice = typeof(setmetatable({} :: Fields, Notice))

--// public api ------------------------------------------------------------------
function Notice.new(flare: any, kind: Types.Kind, body: string?): Notice
	local self: Fields = {
		Spec = {
			Kind = kind,

			Title = nil,
			Body = body,
			Icon = nil,
			Image = nil,
			Tone = "Neutral",

			Anchor = flare.Defaults.Anchor,
			Duration = nil,
			Priority = 0,
			Group = nil,

			Actions = {},
			Choices = {},

			Dismissible = true,
			Markup = flare.Defaults.Markup,
			Pausable = flare.Defaults.Pause,
			Sound = nil,
			Width = nil,

			Progress = nil,
			Indeterminate = nil,
			Deadline = nil,

			Placeholder = nil,
			Default = nil,
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

		OnResolve = {},
		OnShow = {},
		Waiters = {},
	}

	return setmetatable(self, Notice)
end

--// content ---------------------------------------------------------------------
function Notice.title(self: Notice, text: string): Notice
	self.Spec.Title = text

	return Notice.refresh(self)
end

function Notice.body(self: Notice, text: string): Notice
	self.Spec.Body = text

	return Notice.refresh(self)
end

--- Replaces the body. The name every other notification library uses, and the
--- one people reach for on a live handle.
function Notice.update(self: Notice, text: string): Notice
	return Notice.body(self, text)
end

function Notice.icon(self: Notice, asset: string): Notice
	self.Spec.Icon = asset

	return Notice.refresh(self)
end

function Notice.image(self: Notice, asset: string): Notice
	self.Spec.Image = asset

	return Notice.refresh(self)
end

--// appearance -------------------------------------------------------------------
function Notice.tone(self: Notice, tone: string): Notice
	--// accepts "ok" or "Ok", because nobody wants to remember which
	self.Spec.Tone = (string.upper(string.sub(tone, 1, 1)) .. string.sub(tone, 2)) :: Types.Tone

	return Notice.refresh(self)
end

function Notice.info(self: Notice): Notice
	return Notice.tone(self, "Info")
end

function Notice.ok(self: Notice): Notice
	return Notice.tone(self, "Ok")
end

function Notice.warn(self: Notice): Notice
	return Notice.tone(self, "Warn")
end

function Notice.danger(self: Notice): Notice
	return Notice.tone(self, "Danger")
end

function Notice.accent(self: Notice): Notice
	return Notice.tone(self, "Accent")
end

function Notice.at(self: Notice, anchor: Types.Anchor): Notice
	self.Spec.Anchor = anchor

	return self
end

function Notice.width(self: Notice, pixels: number): Notice
	self.Spec.Width = pixels

	return self
end

--- Turns markup parsing off for this notice, when the body is user-supplied
--- text that should never be interpreted.
function Notice.literal(self: Notice): Notice
	self.Spec.Markup = false

	return Notice.refresh(self)
end

--// lifetime ---------------------------------------------------------------------
--- Seconds on screen. Zero or nil means it stays until dismissed.
function Notice.duration(self: Notice, seconds: number?): Notice
	self.Spec.Duration = seconds

	if self.Shown and seconds then
		self.Expires = os.clock() + seconds
	end

	return self
end

function Notice.sticky(self: Notice): Notice
	return Notice.duration(self, nil)
end

--- Higher sorts nearer the front and survives the cap for longer.
function Notice.priority(self: Notice, value: number): Notice
	self.Spec.Priority = value

	return self
end

--- Notices sharing a group key collapse into one with a count, instead of
--- three identical toasts stacking up.
function Notice.group(self: Notice, key: string): Notice
	self.Spec.Group = key

	return self
end

function Notice.dismissible(self: Notice, enabled: boolean): Notice
	self.Spec.Dismissible = enabled ~= false

	return self
end

function Notice.pausable(self: Notice, enabled: boolean): Notice
	self.Spec.Pausable = enabled ~= false

	return self
end

function Notice.sound(self: Notice, asset: string): Notice
	self.Spec.Sound = asset

	return self
end

--// actions ----------------------------------------------------------------------
--- Adds a button. Its callback receives this handle, so it can update or
--- dismiss the notice it came from.
function Notice.action(self: Notice, text: string, run: ((Notice) -> boolean?)?, tone: string?): Notice
	table.insert(self.Spec.Actions, {
		Text = text,
		Run = run :: any,
		Tone = tone :: any,
		Primary = #self.Spec.Actions == 0,
	})

	return Notice.rebuild(self)
end

function Notice.choices(self: Notice, options: { any }): Notice
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

	return Notice.rebuild(self)
end

--// live state --------------------------------------------------------------------
--- Sets a progress bar, 0 to 1. Values above 1 are read as a percentage.
function Notice.progress(self: Notice, value: number): Notice
	local raw = tonumber(value) or 0

	self.Spec.Progress = math.clamp(if raw > 1 then raw / 100 else raw, 0, 1)
	self.Spec.Indeterminate = false

	return Notice.refresh(self)
end

function Notice.indeterminate(self: Notice, enabled: boolean?): Notice
	self.Spec.Indeterminate = enabled ~= false

	return Notice.refresh(self)
end

--- Counts down to a wall-clock deadline.
function Notice.until_(self: Notice, clock: number): Notice
	self.Spec.Deadline = clock

	return Notice.refresh(self)
end

--// prompts -----------------------------------------------------------------------
function Notice.placeholder(self: Notice, text: string): Notice
	self.Spec.Placeholder = text

	return Notice.refresh(self)
end

function Notice.default(self: Notice, text: string): Notice
	self.Spec.Default = text

	return self
end

--- Pins a notice to a GuiObject rather than to a screen corner.
function Notice.attach(self: Notice, target: GuiObject, side: string?): Notice
	self.Spec.Attach = target
	self.Spec.Side = side or "top"

	return self
end

--// callbacks ---------------------------------------------------------------------
function Notice.onResolve(self: Notice, handler: (Result) -> ()): Notice
	table.insert(self.OnResolve, handler)

	return self
end

function Notice.onAccept(self: Notice, handler: (any) -> ()): Notice
	return Notice.onResolve(self, function(result)
		if result.Kind == "Accepted" or result.Kind == "Value" then
			handler(result.Value)
		end
	end)
end

function Notice.onCancel(self: Notice, handler: () -> ()): Notice
	return Notice.onResolve(self, function(result)
		if result.Kind == "Cancelled" then
			handler()
		end
	end)
end

function Notice.onDismiss(self: Notice, handler: () -> ()): Notice
	return Notice.onResolve(self, function(result)
		if result.Kind == "Dismissed" or result.Kind == "Expired" then
			handler()
		end
	end)
end

function Notice.onShow(self: Notice, handler: () -> ()): Notice
	table.insert(self.OnShow, handler)

	return self
end

--// control -----------------------------------------------------------------------
--- Queues the notice. Returns itself, still live.
function Notice.show(self: Notice): Notice
	self.Flare:Enqueue(self)

	return self
end

--- Dismisses it. `kind` distinguishes a player closing it from it timing out.
function Notice.dismiss(self: Notice, kind: string?): Notice
	return Notice.resolve(self, { Kind = (kind or "Dismissed") :: any })
end

--- Finishes the notice with a result, firing every callback and waking anyone
--- blocked in `await`.
function Notice.resolve(self: Notice, result: Result): Notice
	if self.Done then
		return self
	end

	self.Done = true
	self.Result = result

	self.Flare:Release(self)

	for _, handler in self.OnResolve do
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
--- Shows it first if it has not been shown, so `Flare.confirm(…):await()` is
--- one expression rather than two.
function Notice.await(self: Notice): Result
	if self.Done then
		return self.Result :: Result
	end

	if not self.Shown then
		Notice.show(self)
	end

	table.insert(self.Waiters, coroutine.running())

	return coroutine.yield()
end

--- Marks a progress notice finished and lets it fade.
function Notice.finish(self: Notice, message: string?, tone: string?): Notice
	if message then
		Notice.body(self, message)
	end

	Notice.tone(self, tone or "Ok")
	Notice.progress(self, 1)

	return Notice.duration(self, 2)
end

function Notice.fail(self: Notice, message: string?): Notice
	if message then
		Notice.body(self, message)
	end

	Notice.tone(self, "Danger")
	Notice.indeterminate(self, false)

	return Notice.duration(self, 4)
end

--// internal ----------------------------------------------------------------------
--- Repaints without rebuilding, for a setter that changed only content.
function Notice.refresh(self: Notice): Notice
	if self.Shown and not self.Done then
		self.Flare:Paint(self)
	end

	return self
end

--- Rebuilds the whole body, for a setter that changed its structure.
function Notice.rebuild(self: Notice): Notice
	if self.Shown and not self.Done then
		self.Flare:Rebuild(self)
	end

	return self
end

function Notice.alive(self: Notice): boolean
	return self.Shown and not self.Done
end

return Notice
