--!strict

--- The default token set.
---
--- Shares its surface treatment with Lume's console look — pure black at
--- partial transparency, separation from transparency rather than from
--- lightening — so a Flare notice sitting next to an Astrix console does not
--- look like it came from a different program.
--- @section Themes

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Default: Types.Theme = {
	Name = "Default",

	Color = {
		Background = rgb(0, 0, 0),
		Surface = rgb(12, 12, 14),
		Border = rgb(0, 0, 0),

		TextPrimary = rgb(255, 255, 255),
		TextMuted = rgb(159, 159, 159),
		TextGhost = rgb(110, 110, 110),

		Neutral = rgb(159, 159, 159),
		Info = rgb(126, 170, 255),
		Ok = rgb(137, 255, 126),
		Warn = rgb(255, 211, 106),
		Danger = rgb(255, 126, 126),
		Accent = rgb(167, 139, 250),

		Overlay = rgb(0, 0, 0),
	},

	--// hex mirrors, and the palette markup resolves `[ok]…[/ok]` against
	Rich = {
		text = "#FFFFFF",
		muted = "#9F9F9F",
		ghost = "#6E6E6E",
		code = "#CFCFCF",
		neutral = "#9F9F9F",
		info = "#7EAAFF",
		ok = "#89FF7E",
		warn = "#FFD36A",
		danger = "#FF7E7E",
		accent = "#A78BFA",
	},

	Font = {
		Title = Enum.Font.BuilderSansBold,
		Body = Enum.Font.BuilderSans,
		Mono = Enum.Font.Code,
	},

	TextSize = {
		Title = 15,
		Body = 13,
		Small = 11,
		Big = 22,
	},

	Spacing = {
		PaddingX = 12,
		PaddingY = 10,
		Gap = 6,
		Stack = 8,
		Inset = 24,
	},

	Radius = {
		Notice = 10,
		Pill = 999,
		Bar = 2,
	},

	Size = {
		Width = 320,
		BannerHeight = 44,
		Icon = 20,
		BigIcon = 40,
		Bar = 3,
		Rail = 4,
		Action = 26,
	},

	Transparency = {
		Panel = 0.25,
		--// Lume's icons default to `transparency.muted` (0.5) because there
		--// they are chrome. A notice's icon is the notice, so Flare paints it
		--// solid unless a theme says otherwise.
		Icon = 0,
		Overlay = 0.45,
		Muted = 0.25,
		Ghost = 0.45,
		Track = 0.85,
	},

	Motion = {
		--// a notice arrives quickly and leaves slowly, so it does not feel
		--// snatched away mid-read
		Enter = "enter",
		Exit = "exit",
		Move = "layout",
		Pulse = "press",
		Settle = "item",
	},

	Duration = {
		Toast = 5,
		Banner = 6,
		Snackbar = 6,
		Achievement = 6,
		Reward = 5,
		Hint = 4,
	},

	--// Lume ships one soft nine-sliced shadow shared by every surface, sized
	--// for a console window: 22px of bleed on all four sides. On a stack of
	--// notices that reads as haze, and neighbouring shadows overlap into a
	--// band, so Flare tightens it to a close contact shadow.
	Shadow = {
		Enabled = true,
		Image = "rbxassetid://1316045217",
		Slice = Rect.new(10, 10, 118, 118),
		Color = rgb(0, 0, 0),
		Transparency = 0.86,
		Spread = 8,
		Offset = Vector2.new(0, 2),
	},

	--// per-tone defaults, applied when a notice sets none of its own. Empty
	--// because a guessed asset id is worse than no asset id — point these at
	--// your own and every `:Ok()` notice picks the icon up.
	Icon = {},
	Sound = {},
}

return Default
