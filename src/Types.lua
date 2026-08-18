--!strict

--- Every public type in Flare.
--- @section Overview

--// what a notice is
export type Kind =
	"Toast"
	| "Banner"
	| "Alert"
	| "Snackbar"
	| "Confirm"
	| "Prompt"
	| "Choice"
	| "Progress"
	| "Loading"
	| "Countdown"
	| "Achievement"
	| "Reward"
	| "Hint"

--- Semantic colour, not a literal one. A theme decides what `danger` looks
--- like; a caller only says that this is bad news.
export type Tone = "Neutral" | "Info" | "Ok" | "Warn" | "Danger" | "Accent"

export type Anchor =
	"top"
	| "topLeft"
	| "topRight"
	| "bottom"
	| "bottomLeft"
	| "bottomRight"
	| "left"
	| "right"
	| "center"

export type Action = {
	Text: string,
	Tone: Tone?,
	--- Returning true (or nothing) dismisses the notice. Return false to keep
	--- it open — useful for an action that fails and wants to say so.
	Run: ((handle: any) -> boolean?)?,
	Primary: boolean?,
}

export type Choice = {
	Id: string,
	Text: string,
	Icon: string?,
	Description: string?,
}

--- What `:await()` gives back, and what the resolve callbacks receive.
export type Result = {
	Kind: "Accepted" | "Cancelled" | "Dismissed" | "Expired" | "Action" | "Value" | "Grouped",
	Value: any?,
	Action: string?,
}

--// the spec a notice is built from
export type Spec = {
	Kind: Kind,

	Title: string?,
	Body: string?,
	Icon: string?,
	Image: string?,
	Tone: Tone,

	Anchor: Anchor,
	Duration: number?,
	Priority: number,
	Group: string?,

	Actions: { Action },
	Choices: { Choice },

	Dismissible: boolean,
	Markup: boolean,
	Pausable: boolean,
	Sound: string?,
	Width: number?,

	Progress: number?,
	Indeterminate: boolean?,
	Deadline: number?,

	Placeholder: string?,
	Default: string?,
	Attach: GuiObject?,
	Side: string?,

	Meta: { [string]: any }?,
}

--// runtime
export type Handle = any

export type QueueOptions = {
	Max: number?,
	Gap: number?,
	Group: boolean?,
	Pause: boolean?,
}

export type FlareOptions = {
	Theme: string?,
	Gui: LayerCollector?,
	DisplayOrder: number?,
	App: any?,

	--- Per-anchor stack cap. Four by default.
	Max: number?,
	--- Seconds before a notice with no explicit duration expires.
	Duration: number?,
	--- Collapse identical notices into one with a count.
	Group: boolean?,
	--- Freeze the countdown while the pointer is over a notice.
	Pause: boolean?,
	--- Parse markup in bodies by default.
	Markup: boolean?,
	--- Play `Spec.Sound` when a notice appears.
	Sound: boolean?,
	Width: number?,
}

return {}
