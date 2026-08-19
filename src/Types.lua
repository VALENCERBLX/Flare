--!strict

--- Every public type in Flare.
---
--- Exported through the main module too, so `Flare.Notice` and friends are
--- reachable without requiring this file directly:
---
--- ```lua
--- local Flare = require(ReplicatedStorage.Flare)
---
--- local function announce(text: string): Flare.Notice
---     return Flare.Toast(text):Ok():Show()
--- end
--- ```
--- @section Overview

--// what a notice is -------------------------------------------------------------
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
	| "Color"
	| "Number"
	| "Rating"
	| "Dropdown"
	| "Radio"
	| "Achievement"
	| "Reward"
	| "Hint"

--- Semantic colour, not a literal one. A theme decides what `Danger` looks
--- like; a caller only says that this is bad news.
export type Tone = "Neutral" | "Info" | "Ok" | "Warn" | "Danger" | "Accent"

--- Lume's nine anchors. Notices stack away from whichever edge they are on.
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

export type Side = "top" | "bottom" | "left" | "right"

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

--- What a choice can be written as: a bare string, where the text is also the
--- id, or the full table.
export type ChoiceLike = string | {
	Id: string?,
	Text: string?,
	Icon: string?,
	Description: string?,
}

export type ResultKind = "Accepted" | "Cancelled" | "Dismissed" | "Expired" | "Action" | "Value" | "Grouped"

--- What `:Await()` gives back, and what the resolve callbacks receive.
export type Result = {
	Kind: ResultKind,
	--- The answer: `true`/`false` for a confirm, the typed text for a prompt,
	--- the chosen id for a choice, the notice it merged into for a group.
	Value: any?,
	--- Which button was pressed, when `Kind` is `Action`.
	Action: string?,
}

--// the spec a notice is built from ------------------------------------------------
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
	Draggable: boolean,
	Shadow: boolean?,
	Sound: string?,
	Width: number?,
	Layer: string?,

	Progress: number?,
	Indeterminate: boolean?,
	Deadline: number?,

	Placeholder: string?,
	Default: string?,
	--- The colour a `Color` notice opens on.
	Color: Color3?,
	--- What a `Number` notice opens on, and the range it may move in.
	Number: number?,
	Minimum: number?,
	Maximum: number?,
	Step: number?,
	--- A player whose headshot goes on the notice.
	UserId: number?,
	--- Called in order with the Lume panel while the notice is being built, so
	--- any Lume element at all can go in a notice. See `Notice:Custom`.
	Builders: { (panel: any, notice: any) -> () },
	--- What a `Dropdown` or `Radio` notice offers.
	Options: { Choice },
	Attach: GuiObject?,
	Side: Side?,

	--- Anything you want to carry along. Flare never reads it.
	Meta: { [string]: any }?,
}

--- What `Notice:Meter` takes beyond the value itself.
export type MeterOptions = {
	Label: string?,
	Minimum: number?,
	Maximum: number?,
	--- The thresholds the colour turns on.
	Low: number?,
	High: number?,
	--- `"high"` means high readings are healthy — ammunition, battery. `"low"`
	--- means low ones are — memory, ping.
	Optimum: ("high" | "low")?,
	Format: ((number, number) -> string)?,
}

--- What `Notice:Graph` takes beyond the samples.
export type GraphOptions = {
	Label: string?,
	Unit: string?,
	--- The line a sample is unwelcome past, and the one it fails past.
	Warn: number?,
	Fail: number?,
	--- `"low"` means low samples are healthy — frame time, ping.
	Optimum: ("high" | "low")?,
	Window: number?,
	Minimum: number?,
	Maximum: number?,
	Height: number?,
}

--// theme tokens -------------------------------------------------------------------
export type ColorTokens = {
	Background: Color3,
	Surface: Color3,
	Border: Color3,

	TextPrimary: Color3,
	TextMuted: Color3,
	TextGhost: Color3,

	Neutral: Color3,
	Info: Color3,
	Ok: Color3,
	Warn: Color3,
	Danger: Color3,
	Accent: Color3,

	Overlay: Color3,
}

--- Hex mirrors of the palette. Markup resolves `[ok]…[/ok]` against these, so
--- a themed tone and a themed markup tag are the same colour by construction.
export type RichTokens = {
	text: string,
	muted: string,
	ghost: string,
	code: string,
	neutral: string,
	info: string,
	ok: string,
	warn: string,
	danger: string,
	accent: string,
}

export type FontTokens = {
	Title: Enum.Font,
	Body: Enum.Font,
	Mono: Enum.Font,
}

export type TextSizeTokens = {
	Title: number,
	Body: number,
	Small: number,
	Big: number,
}

export type SpacingTokens = {
	PaddingX: number,
	PaddingY: number,
	Gap: number,
	--- Between notices in a stack.
	Stack: number,
	--- Between the stack and the edge of the screen.
	Inset: number,
}

export type RadiusTokens = {
	Notice: number,
	Pill: number,
	Bar: number,
}

export type SizeTokens = {
	Width: number,
	BannerHeight: number,
	Icon: number,
	BigIcon: number,
	--- The tone bar down the left of a notice.
	Bar: number,
	--- The progress rail.
	Rail: number,
	Action: number,
}

export type TransparencyTokens = {
	Panel: number,
	--- Notice icons. Zero — solid — unlike Lume's muted chrome icons.
	Icon: number,
	Overlay: number,
	Muted: number,
	Ghost: number,
	Track: number,
}

--- Named Lume motion specs. Swap a name for a different one — or register your
--- own on the app's theme — to change how notices move without touching Flare.
export type MotionTokens = {
	Enter: string,
	Exit: string,
	Move: string,
	Pulse: string,
	Settle: string,
}

--- Default seconds per kind, for kinds that fade on their own.
export type DurationTokens = { [string]: number }

--- A partial `ShadowTokens`, merged over the theme's. This is what `Shadow`
--- takes when you pass it a table instead of a boolean.
export type ShadowOverride = {
	Enabled: boolean?,
	Image: string?,
	Slice: Rect?,
	Color: Color3?,
	Transparency: number?,
	Spread: number?,
	Offset: Vector2?,
}

--- Lume's shadow is one soft nine-sliced image shared by every surface. A
--- console window wants it broad; a stack of notices wants it tight, or off.
export type ShadowTokens = {
	Enabled: boolean,
	Image: string,
	Slice: Rect,
	Color: Color3,
	Transparency: number,
	--- How far the shadow bleeds past the panel, in pixels.
	Spread: number,
	Offset: Vector2,
}

--- Optional asset ids keyed by tone, applied when a notice sets no icon or
--- sound of its own. Empty by default: shipping guessed asset ids is worse
--- than shipping none.
export type AssetTokens = { [string]: string }

export type Theme = {
	Name: string,

	Color: ColorTokens,
	Rich: RichTokens,
	Font: FontTokens,
	TextSize: TextSizeTokens,
	Spacing: SpacingTokens,
	Radius: RadiusTokens,
	Size: SizeTokens,
	Transparency: TransparencyTokens,
	Motion: MotionTokens,
	Duration: DurationTokens,
	Shadow: ShadowTokens,
	Icon: AssetTokens,
	Sound: AssetTokens,
}

--- A partial theme: everything optional, deep-merged over the theme it
--- extends. This is what `Flare.DefineTheme` takes.
export type ThemeOverride = {
	Name: string?,

	Color: { [string]: Color3 }?,
	Rich: { [string]: string }?,
	Font: { [string]: Enum.Font }?,
	TextSize: { [string]: number }?,
	Spacing: { [string]: number }?,
	Radius: { [string]: number }?,
	Size: { [string]: number }?,
	Transparency: { [string]: number }?,
	Motion: { [string]: string }?,
	Duration: { [string]: number }?,
	Shadow: ShadowOverride?,
	Icon: AssetTokens?,
	Sound: AssetTokens?,
}

--// configuration --------------------------------------------------------------------
export type FlareOptions = {
	--- A registered theme name. `"Default"` unless you register another.
	Theme: string?,
	--- Token overrides applied on top of `Theme`, for one-off tweaks that do
	--- not deserve a whole registered theme.
	Tokens: ThemeOverride?,

	--- Render into a Lume app you already have. Everything else about the app
	--- — its gui, its layer, its own theme — stays yours.
	App: any?,
	--- Render into a `ScreenGui` you own, rather than one Flare creates.
	Gui: LayerCollector?,
	DisplayOrder: number?,

	--- Where notices go when they do not say. `"bottomRight"` by default.
	Anchor: Anchor?,
	--- Per-anchor stack cap. Four by default.
	Max: number?,
	--- Seconds before a notice with no explicit duration expires.
	Duration: number?,
	--- Per-kind duration overrides, for when one number is not enough.
	Durations: { [string]: number }?,
	--- Collapse identical notices into one carrying a count.
	Group: boolean?,
	--- Freeze the countdown while the pointer is over a notice.
	Pause: boolean?,
	--- Parse markup in bodies and titles by default.
	Markup: boolean?,
	--- Play sounds at all. Pass a string instead of `true` to give every
	--- notice that sound unless it names its own, or a table to set them per
	--- tone — the same thing `Sounds` takes, since the two names are one
	--- letter apart and either spelling should work.
	Sound: (boolean | string | { [string]: string })?,
	--- Asset id per tone or kind, played when a notice of that tone appears
	--- and sets no sound of its own. `{ Ok = "rbxassetid://…" }`. A kind wins
	--- over a tone, so `Achievement` can have its own without every `Accent`
	--- notice inheriting it.
	Sounds: { [string]: string }?,
	--- Asset id per tone or kind, shown when a notice sets no icon of its own.
	Icons: { [string]: string }?,
	--- Alias for `Icons`. Both spellings work.
	Icon: { [string]: string }?,
	--- Show a close button, and let a click outside dismiss.
	Dismissible: boolean?,
	--- Let notices be dragged around the screen.
	Draggable: boolean?,
	--- Draw shadows. `false` turns them off everywhere. A table sets the
	--- shadow tokens themselves: `Shadow = { Spread = 50, Transparency = 0.7 }`.
	Shadow: (boolean | ShadowOverride)?,

	Width: number?,
	--- Between notices in a stack.
	Gap: number?,
	--- Between the stack and the edge of the screen.
	Inset: number?,
}

export type QueueOptions = {
	Max: number?,
	Gap: number?,
	Group: boolean?,
	Pause: boolean?,
}

return {}
