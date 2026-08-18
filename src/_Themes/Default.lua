--!strict

--- The default token set.
---
--- Shares its surface treatment with Lume's console look — pure black at
--- partial transparency, separation from transparency rather than from
--- lightening — so a Flare notice sitting next to an Astrix console does not
--- look like it came from a different program.
--- @section Themes

local rgb = Color3.fromRGB

return {
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
}
