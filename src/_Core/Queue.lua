--!strict

--- One queue per anchor, and the rules that decide what is on screen.
---
--- Four behaviours, in the order they matter:
---
--- * **Priority.** Higher sorts nearer the front and outlives the cap. A
---   `danger` notice should not be pushed off by three `saved` toasts.
--- * **Grouping.** Notices sharing a group key collapse into one carrying a
---   count, rather than stacking three identical lines.
--- * **Cap and overflow.** Past the cap, waiting notices sit in a backlog and
---   are shown as slots free up, so nothing is silently lost.
--- * **Pause.** The countdown freezes while the pointer is over a notice,
---   because a toast that vanishes as you reach for its button is worse than
---   no toast.
---
--- The queue owns none of the drawing. It decides membership and order, hands
--- that to the renderer, and is testable without a DataModel.
--- @section Core

local Types = require(script.Parent.Parent.Types)

local Queue = {}
Queue.__index = Queue

export type Fields = {
	Anchor: Types.Anchor,
	Max: number,
	Live: { any },
	Backlog: { any },
	Group: boolean,
}

export type Queue = typeof(setmetatable({} :: Fields, Queue))

--// locals ---------------------------------------------------------------------
--- Higher priority first; equal priority keeps arrival order, so a burst does
--- not shuffle itself while you read it.
local function byPriority(left: any, right: any): boolean
	if left.Spec.Priority == right.Spec.Priority then
		return left.Order < right.Order
	end

	return left.Spec.Priority > right.Spec.Priority
end

--- What makes two notices "the same" for grouping.
---
--- An explicit group key wins. Without one, notices are grouped by kind, tone
--- and body — which catches the common case of the same event firing three
--- times without asking the caller to think about it.
local function identity(notice: any): string?
	local spec = notice.Spec

	if spec.Group then
		return spec.Group
	end

	if not spec.Body then
		return nil
	end

	return `{spec.Kind}|{spec.Tone}|{spec.Body}`
end

--// public api ------------------------------------------------------------------
function Queue.new(anchor: Types.Anchor, max: number, group: boolean): Queue
	local self: Fields = {
		Anchor = anchor,
		Max = max,
		Live = {},
		Backlog = {},
		Group = group,
	}

	return setmetatable(self, Queue)
end

--- Finds a live notice this one should collapse into.
function Queue.Match(self: Queue, notice: any): any
	if not self.Group then
		return nil
	end

	local key = identity(notice)

	if not key then
		return nil
	end

	for _, live in self.Live do
		if not live.Done and identity(live) == key then
			return live
		end
	end

	return nil
end

--- Adds a notice. Returns `"grouped"` with the notice it merged into,
--- `"shown"` if it goes on screen now, or `"queued"` if it is waiting.
function Queue.Add(self: Queue, notice: any): (string, any?)
	local match = Queue.Match(self, notice)

	if match then
		match.Count += 1

		return "grouped", match
	end

	if #self.Live < self.Max then
		table.insert(self.Live, notice)
		table.sort(self.Live, byPriority)

		return "shown", nil
	end

	--// full. A higher-priority arrival displaces the least important thing on
	--// screen rather than waiting behind it
	local lowest: any = nil
	local lowestIndex = 0

	for index, live in self.Live do
		if not lowest or byPriority(lowest, live) then
			lowest = live
			lowestIndex = index
		end
	end

	if lowest and notice.Spec.Priority > lowest.Spec.Priority then
		table.remove(self.Live, lowestIndex)
		table.insert(self.Backlog, 1, lowest)

		table.insert(self.Live, notice)
		table.sort(self.Live, byPriority)

		return "shown", lowest
	end

	table.insert(self.Backlog, notice)
	table.sort(self.Backlog, byPriority)

	return "queued", nil
end

--- Removes a notice and promotes the next from the backlog, if any.
function Queue.Remove(self: Queue, notice: any): any?
	local index = table.find(self.Live, notice)

	if index then
		table.remove(self.Live, index)
	else
		local waiting = table.find(self.Backlog, notice)

		if waiting then
			table.remove(self.Backlog, waiting)
		end

		return nil
	end

	if #self.Backlog == 0 then
		return nil
	end

	local next = table.remove(self.Backlog, 1)

	if next then
		table.insert(self.Live, next)
		table.sort(self.Live, byPriority)
	end

	return next
end

--- How many are waiting for a slot.
function Queue.Waiting(self: Queue): number
	return #self.Backlog
end

function Queue.Count(self: Queue): number
	return #self.Live
end

--- Expires anything whose time is up. Returns them, so the caller can resolve
--- each one and let the renderer animate it out.
---
--- A paused notice — the pointer is over it — has its deadline pushed forward
--- instead of firing, so hovering holds it rather than merely delaying the
--- inevitable by one frame.
function Queue.Tick(self: Queue, now: number, delta: number): { any }
	local expired = {}

	for _, notice in table.clone(self.Live) do
		if notice.Done or not notice.Expires then
			continue
		end

		if notice.Paused then
			notice.Expires += delta

			continue
		end

		if now >= notice.Expires then
			table.insert(expired, notice)
		end
	end

	return expired
end

function Queue.Clear(self: Queue): { any }
	local all = {}

	for _, notice in self.Live do
		table.insert(all, notice)
	end

	for _, notice in self.Backlog do
		table.insert(all, notice)
	end

	table.clear(self.Live)
	table.clear(self.Backlog)

	return all
end

return Queue
