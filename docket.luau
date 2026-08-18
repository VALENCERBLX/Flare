-- Flare docs: build with `lune run scripts/Docket`
return {
	Title = "Flare",
	Lead = "Notifications for Roblox — toasts, banners, dialogs, progress and more, on one queue.",
	Theme = "tokyonight",
	Version = "0.2.0",
	License = "MIT",
	Sections = {
		"Guides",
		"Overview",
		"Kinds",
		"Core",
		"Themes",
	},
	Pages = {
		{ file = "pages/GettingStarted.md", section = "Guides" },
		{ file = "pages/Kinds.md", section = "Guides" },
		{ file = "pages/Markup.md", section = "Guides" },
		{ file = "pages/Queue.md", section = "Guides" },
		{ file = "pages/Theming.md", section = "Guides" },
	},
	Ignore = { "_Packages/" },
	Repo = "https://github.com/VALENCERBLX/Flare",
}
