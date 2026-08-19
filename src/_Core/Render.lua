--!strict

--- Draws a notice. One panel per notice, one builder per kind.
---
--- Every kind is the same Lume panel with different children, the way every
--- Lume preset is the same panel with different numbers. What actually differs
--- between a toast and an achievement is the size, the anchor, and what goes
--- inside — not the machinery.
---
--- The accent bar down the left is shared by all of them, because tone has to
--- survive being glanced at.
--- @section Core

local Types = require(script.Parent.Parent.Types)
local Markup = require(script.Parent.Parent.Markup)
local Lume = require(script.Parent.Parent._Packages.Lume)

type Notice = any

local Render = {}

--// locals ---------------------------------------------------------------------
local function toneColour(theme: any, tone: Types.Tone): Color3
	return theme.Color[tone] or theme.Color.Neutral
end

--- Body text, markup-compiled or escaped, but never raw.
local function bodyText(theme: any, notice: Notice): string
	local spec = notice.Spec
	local text = spec.Body or ""

	if spec.Markup then
		return Markup.parse(text, theme.Rich)
	end

	return Markup.escape(text)
end

--- `Saved ×3` — grouping is invisible unless it is shown.
local function withCount(text: string, count: number, theme: any): string
	if count <= 1 then
		return text
	end

	return `{text}  <font color="{theme.Rich.ghost}">×{count}</font>`
end

--- Kinds that put a control on the notice. Anything here, or anything given a
--- widget through `Custom`, stops the notice being one big dismiss button.
local CONTROLS: { [string]: boolean } = {
	Prompt = true,
	Choice = true,
	Color = true,
	Number = true,
	Rating = true,
	Dropdown = true,
	Radio = true,
}

local function panelFor(flare: any, notice: Notice): any
	local theme = flare.Theme
	local spec = notice.Spec

	local panel = flare.App:panel("card")

	panel:setAnchor(spec.Anchor)
	panel:setInset(theme.Spacing.Inset)
	panel:setPadding(theme.Spacing.PaddingX, theme.Spacing.PaddingY)
	panel:setGap(theme.Spacing.Gap)
	panel:setRadius(theme.Radius.Notice)
	panel:setColor(theme.Color.Background)
	panel:setTransparency(theme.Transparency.Panel)
	panel:setBorder(false)
	panel:setLayer(spec.Layer or "toast")
	panel:setWidth(spec.Width or theme.Size.Width)

	--// per notice first, then the theme. Lume's shadow is sized for a console
	--// window; Flare restyles it tight on Start, so this is a contact shadow
	--// rather than the haze a stack of them would otherwise sit in
	local shadow = if spec.Shadow ~= nil then spec.Shadow else theme.Shadow.Enabled

	panel:setShadow(shadow)

	if spec.Draggable then
		panel:setDraggable(true, { smooth = true, bounds = true })
	else
		panel:setDraggable(false)
	end

	--// A notice whose whole surface is a dismiss button cannot also hold a
	--// control. A slider or a colour square handles raw input rather than
	--// consuming a click the way a Button does, so the drag that moved it
	--// reached the panel underneath and dismissed the notice out from under
	--// the pointer.
	local interactive = #spec.Actions > 0
		or #spec.Choices > 0
		or #spec.Options > 0
		or #spec.Builders > 0
		or CONTROLS[spec.Kind] == true

	if spec.Dismissible and not interactive then
		panel:setActivatable(true)
		panel:onActivated(function()
			notice:Resolve({ Kind = "Dismissed" })
		end)
	end

	--- A notice that fades does not need an ×; one that waits does.
	local fades = spec.Duration ~= nil and spec.Duration > 0 or flare.Transient(spec.Kind)

	if spec.Dismissible and not fades then
		panel:setCloseButton(true)

		--// Lume's own close button only hides the panel. Left at that, the
		--// notice would sit in the queue holding a slot forever.
		panel.scope:add(panel.refs.close.Activated:Connect(function()
			notice:Resolve({ Kind = "Dismissed" })
		end))
	else
		panel:setCloseButton(false)
	end

	return panel
end

--- Title over body, the shape almost every kind wants.
local function textBlock(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	local theme = flare.Theme
	local spec = notice.Spec

	if spec.Title then
		local title = panel:label(Markup.escape(spec.Title))

		title:setFont(theme.Font.Title)
		title:setTextSize(theme.TextSize.Title)
		title:setColor(theme.Color.TextPrimary)
		title:setFill(true)
		title:setWrapped(true)

		refs.Title = title
	end

	if spec.Body then
		local body = panel:label(withCount(bodyText(theme, notice), notice.Count, theme))

		body:setRich(true)
		body:setFont(theme.Font.Body)
		body:setTextSize(theme.TextSize.Body)
		body:setColor(if spec.Title then theme.Color.TextMuted else theme.Color.TextPrimary)
		body:setFill(true)
		body:setWrapped(true)

		refs.Body = body
	end
end

local function actionRow(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	local spec = notice.Spec

	if #spec.Actions == 0 then
		return
	end

	local theme = flare.Theme
	local row = panel:group("horizontal")
	local buttons: { any } = {}

	row:setFill(true)
	row:setGap(theme.Spacing.Gap)
	row:setAlign(Enum.HorizontalAlignment.Right)

	for _, action in spec.Actions do
		local button = row:button(action.Text)

		button:setVariant(if action.Primary then "soft" else "ghost")
		--// buttons sit inside the notice, so they round a little tighter — but
		--// a theme with square corners must not end up with a negative one
		button:setRadius(math.max(theme.Radius.Notice - 4, 0))

		if action.Tone then
			button:setColor(toneColour(theme, action.Tone))
		end

		table.insert(buttons, button)

		button:onClicked(function()
			local keep = false

			if action.Run then
				local ok, result = pcall(action.Run, notice)

				if not ok then
					warn(`[Flare] action '{action.Text}' errored: {result}`)
				else
					--// returning false keeps it open, for an action that
					--// failed and wants to say why
					keep = result == false
				end
			end

			if not keep then
				notice:Resolve({ Kind = "Action", Action = action.Text })
			end
		end)
	end

	refs.Actions = row
	--// kept so a live notice can retext or disable its own buttons
	refs.Buttons = buttons
end

--// kinds -----------------------------------------------------------------------
local Kinds = {}

--- The accent bar plus a text block. Toast, Alert, Snackbar and Banner all
--- share it; they differ in width, anchor and lifetime, not in shape.
function Kinds.Simple(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	local theme = flare.Theme
	local spec = notice.Spec

	local row = panel:group("horizontal")

	row:setFill(true)
	row:setGap(theme.Spacing.Gap + 2)
	row:setAlign(Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)

	local bar = row:icon("")

	bar:setIconSize(theme.Size.Bar)
	bar:setProps({
		BackgroundColor3 = toneColour(theme, spec.Tone),
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(theme.Size.Bar, theme.Size.Icon),
	})

	refs.Bar = bar

	--// a face beats a glyph: if the notice is about a player, that is what the
	--// eye should land on
	if spec.UserId then
		local avatar = row:avatar(spec.UserId)

		avatar:setDiameter(theme.Size.Icon + 10)

		if spec.Meta and spec.Meta.AvatarName then
			avatar:setName(spec.Meta.AvatarName)
		end

		refs.Avatar = avatar
	elseif spec.Icon then
		local icon = row:icon(spec.Icon)

		icon:setIconSize(theme.Size.Icon)
		icon:setColor(toneColour(theme, spec.Tone))
		icon:setProps({ ImageTransparency = theme.Transparency.Icon })

		refs.Icon = icon
	end

	local column = row:group("vertical")

	column:setGrow(true)
	column:setFill(false)
	column:setGap(2)

	textBlock(column, flare, notice, refs)

	refs.Column = column

	--// a countdown that never counts is just a toast
	if spec.Deadline then
		local timer = row:label("")

		timer:setFont(theme.Font.Title)
		timer:setTextSize(theme.TextSize.Body)
		timer:setColor(toneColour(theme, spec.Tone))
		timer:setAlign(Enum.TextXAlignment.Right)

		refs.Timer = timer
	end
end

function Kinds.Progress(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	Kinds.Simple(panel, flare, notice, refs)

	local theme = flare.Theme
	local spec = notice.Spec

	local bar = panel:progress()

	bar:setFill(true)
	bar:setThickness(theme.Size.Rail)
	bar:setColor(toneColour(theme, spec.Tone))

	if spec.Indeterminate then
		bar:setIndeterminate(true)
	else
		bar:setValue(spec.Progress or 0)
	end

	refs.Progress = bar
end

function Kinds.Choice(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	Kinds.Simple(panel, flare, notice, refs)

	local list = panel:list()
	local items = {}

	--// Flare capitalises its fields, Lume's list does not
	for _, choice in notice.Spec.Choices do
		table.insert(items, {
			id = choice.Id,
			text = choice.Text,
			icon = choice.Icon,
			description = choice.Description,
		})
	end

	--// a description is a sentence, not a keybind, so it gets its own line
	--// under the option rather than trailing it and clipping at the edge
	local described = false

	for _, choice in notice.Spec.Choices do
		if choice.Description and choice.Description ~= "" then
			described = true

			break
		end
	end

	list:setItems(items :: any)
	list:setStacked(described)
	list:setMaxRows(6)
	list:setSelectable(true)
	list:onActivated(function(item)
		notice:Resolve({ Kind = "Value", Value = item.id })
	end)

	refs.List = list
end

function Kinds.Prompt(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	Kinds.Simple(panel, flare, notice, refs)

	local spec = notice.Spec
	local field = panel:field(spec.Placeholder or "")

	field:setFill(true)

	if spec.Default then
		field:setText(spec.Default)
	end

	field:onSubmitted(function(text)
		notice:Resolve({ Kind = "Value", Value = text })
	end)

	refs.Field = field
end

--- A colour picker in a notice. Resolves with the `Color3`, not a hex string —
--- the caller almost always wants to assign it to something.
function Kinds.Color(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	Kinds.Simple(panel, flare, notice, refs)

	local spec = notice.Spec
	local picker = panel:colorPicker()

	picker:setFill(true)

	if spec.Color then
		picker:setSilent(spec.Color)
	end

	--// the notice carries the live colour, so a caller watching the handle sees
	--// the drag rather than only the answer
	picker:onChanged(function(color)
		spec.Color = color
	end)

	refs.Picker = picker
end

--- A stepper in a notice, for asking how many.
function Kinds.Number(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	Kinds.Simple(panel, flare, notice, refs)

	local spec = notice.Spec
	local stepper = panel:stepper()

	stepper:setFill(true)
	stepper:setRange(spec.Minimum or 0, spec.Maximum or 99)

	if spec.Step then
		stepper:setStep(spec.Step)
	end

	if spec.Number then
		stepper:setValue(spec.Number)
	end

	--// the spec carries the live number, so a caller watching the handle sees
	--// it move rather than only the answer
	stepper:onChanged(function(value)
		spec.Number = value
	end)

	spec.Number = stepper:value()

	refs.Stepper = stepper
end

--- A dropdown in a notice, for picking one of a list too long to lay out.
function Kinds.Dropdown(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	Kinds.Simple(panel, flare, notice, refs)

	local spec = notice.Spec
	local select = panel:select()

	select:setFill(true)
	select:setPlaceholder("Choose…")

	--// Flare capitalises its fields and Lume's select does not
	local options = {}

	for _, option in spec.Options do
		table.insert(options, {
			id = option.Id,
			text = option.Text,
			icon = option.Icon,
			description = option.Description,
		})
	end

	select:setOptions(options)

	--// a dropdown is a two-step control — open, then pick — so unlike a rating
	--// it does not resolve itself. The buttons underneath do that
	select:onChanged(function(id)
		spec.Default = id
	end)

	refs.Select = select
end

--- A radio group in a notice: every option visible at once.
function Kinds.Radio(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	Kinds.Simple(panel, flare, notice, refs)

	local spec = notice.Spec
	local radio = panel:radio()

	radio:setFill(true)

	local options = {}

	for _, option in spec.Options do
		table.insert(options, {
			id = option.Id,
			text = option.Text,
			icon = option.Icon,
			description = option.Description,
		})
	end

	radio:setOptions(options)

	if spec.Default then
		radio:setValue(spec.Default)
	end

	radio:onChanged(function(id)
		spec.Default = id
	end)

	refs.Radio = radio
end

--- Stars in a notice, for asking how it went.
function Kinds.Rating(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	Kinds.Simple(panel, flare, notice, refs)

	local spec = notice.Spec
	local rating = panel:rating()

	rating:setStarSize(flare.Theme.TextSize.Big)

	if spec.Maximum then
		rating:setMaximum(spec.Maximum)
	end

	if spec.Number then
		rating:setValue(spec.Number)
	end

	--// a rating answers itself: there is no sensible second step after
	--// picking four stars, so picking resolves the notice
	rating:onChanged(function(score)
		spec.Number = score

		if score > 0 then
			notice:Resolve({ Kind = "Value", Value = score })
		end
	end)

	refs.Rating = rating
end

--- Big, centred, and celebratory. The one kind that is allowed to interrupt.
function Kinds.Achievement(panel: any, flare: any, notice: Notice, refs: { [string]: any })
	local theme = flare.Theme
	local spec = notice.Spec

	panel:setPadding(theme.Spacing.PaddingX + 6, theme.Spacing.PaddingY + 6)

	local row = panel:group("horizontal")

	row:setFill(true)
	row:setGap(theme.Spacing.Gap + 6)

	if spec.Image or spec.Icon then
		local icon = row:icon((spec.Image or spec.Icon) :: string)

		icon:setIconSize(theme.Size.BigIcon)
		icon:setProps({ ImageTransparency = theme.Transparency.Icon })

		--// a large image is artwork, so it is painted white rather than left
		--// alone: Lume's icons are chrome and default to the muted text
		--// colour, which would drain a piece of art to grey
		if spec.Image then
			icon:setColor(Color3.new(1, 1, 1))
		else
			icon:setColor(toneColour(theme, spec.Tone))
		end

		refs.Icon = icon
	end

	local column = row:group("vertical")

	column:setGrow(true)
	column:setFill(false)
	column:setGap(2)

	if spec.Title then
		local title = column:label(Markup.escape(spec.Title))

		title:setFont(theme.Font.Title)
		title:setTextSize(theme.TextSize.Big)
		title:setColor(toneColour(theme, spec.Tone))
		title:setFill(true)

		refs.Title = title
	end

	if spec.Body then
		local body = column:label(withCount(bodyText(theme, notice), notice.Count, theme))

		body:setRich(true)
		body:setTextSize(theme.TextSize.Body)
		body:setColor(theme.Color.TextMuted)
		body:setFill(true)
		body:setWrapped(true)

		refs.Body = body
	end
end

local BUILDERS: { [string]: (any, any, any, any) -> () } = {
	Toast = Kinds.Simple,
	Banner = Kinds.Simple,
	Alert = Kinds.Simple,
	Snackbar = Kinds.Simple,
	Confirm = Kinds.Simple,
	Hint = Kinds.Simple,
	Countdown = Kinds.Simple,
	Loading = Kinds.Progress,
	Progress = Kinds.Progress,
	Choice = Kinds.Choice,
	Prompt = Kinds.Prompt,
	Color = Kinds.Color,
	Number = Kinds.Number,
	Rating = Kinds.Rating,
	Dropdown = Kinds.Dropdown,
	Radio = Kinds.Radio,
	Achievement = Kinds.Achievement,
	Reward = Kinds.Achievement,
}

--// public api ------------------------------------------------------------------
--- Builds the panel for a notice and returns it with its refs.
function Render.Build(flare: any, notice: Notice): (any, { [string]: any })
	local theme = flare.Theme
	local spec = notice.Spec

	local panel = panelFor(flare, notice)
	local refs: { [string]: any } = {}

	--// handed over before the build rather than after it, because a Custom
	--// builder writing `notice.Refs.Chart` would otherwise write into the
	--// table this one is about to replace
	notice.Refs = refs

	local build = BUILDERS[spec.Kind] or Kinds.Simple

	build(panel, flare, notice, refs)

	--// the escape hatch, run between the body and the buttons: whatever Lume
	--// has, a notice can hold. They run in the order they were added, so a
	--// chart above a meter is written that way round
	for _, builder in spec.Builders do
		local ok, err = pcall(builder, panel, notice)

		if not ok then
			warn(`[Flare] a Custom builder errored: {err}`)
		end
	end

	actionRow(panel, flare, notice, refs)

	--// a banner spans its edge rather than sitting in a corner
	if spec.Kind == "Banner" then
		panel:setWidth(spec.Width or math.max(theme.Size.Width, flare.App:viewport().X - theme.Spacing.Inset * 2))
	end

	if spec.Attach then
		panel:attachTo(spec.Attach, spec.Side :: any, theme.Spacing.Gap)
	end

	return panel, refs
end

--- `1:05`, or `12s` under a minute.
function Render.Clock(seconds: number): string
	local left = math.max(0, math.ceil(seconds))

	if left < 60 then
		return `{left}s`
	end

	return string.format("%d:%02d", left // 60, left % 60)
end

--- Repaints without rebuilding, for content that changed on a live notice.
function Render.Paint(flare: any, notice: Notice)
	local theme = flare.Theme
	local spec = notice.Spec
	local refs = notice.Refs

	if refs.Title and spec.Title then
		refs.Title:setText(Markup.escape(spec.Title))
	end

	if refs.Body then
		refs.Body:setText(withCount(bodyText(theme, notice), notice.Count, theme))
	end

	if refs.Bar then
		refs.Bar:setProps({ BackgroundColor3 = toneColour(theme, spec.Tone) })
	end

	if refs.Timer and spec.Deadline then
		refs.Timer:setText(Render.Clock(spec.Deadline - os.clock()))
		refs.Timer:setColor(toneColour(theme, spec.Tone))
	end

	if refs.Icon and (spec.Icon or spec.Image) then
		refs.Icon:setImage((spec.Image or spec.Icon) :: string)
		refs.Icon:setProps({ ImageTransparency = theme.Transparency.Icon })

		if spec.Image then
			refs.Icon:setColor(Color3.new(1, 1, 1))
		else
			refs.Icon:setColor(toneColour(theme, spec.Tone))
		end
	end

	if refs.Progress then
		refs.Progress:setColor(toneColour(theme, spec.Tone))

		if spec.Indeterminate then
			refs.Progress:setIndeterminate(true)
		else
			refs.Progress:setIndeterminate(false)
			refs.Progress:setValue(spec.Progress or 0)
		end
	end
end

return Render
