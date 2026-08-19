--!nocheck

--- A small Roblox stand-in for Lune, so Flare's own code can be run rather
--- than merely compiled. Every bug worth catching in this library so far has
--- been invisible to a syntax check and obvious the moment something ran.
---
--- What it provides: instances with a real parent/child tree and events,
--- the datatypes Lume touches, an auto-vivifying `Enum`, and a driven clock —
--- `Shim.step(dt)` advances time, fires `Heartbeat`, and resumes whatever
--- `task.wait` was owed. Nothing here runs in Roblox; it exists to run tests.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Shim = {}

--// clock -------------------------------------------------------------------
local now = 0
local timers: { { at: number, thread: thread, resume: { any } } } = {}

--// signals -----------------------------------------------------------------
local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	self.live = false

	local index = table.find(self.signal.handlers, self)

	if index then
		table.remove(self.signal.handlers, index)
	end
end

Connection.disconnect = Connection.Disconnect

local Signal = {}
Signal.__index = Signal
Signal.__type = "RBXScriptSignal"

local function signal()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(handler)
	local connection = setmetatable({ signal = self, handler = handler, live = true, once = false }, Connection)

	table.insert(self.handlers, connection)

	return connection
end

function Signal:Once(handler)
	local connection = self:Connect(handler)

	connection.once = true

	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection

	connection = self:Once(function(...)
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

--// Roblox runs every handler on a thread of its own, which is why a
--// connection can call something blocking — `:Await()`, `task.wait` — without
--// stopping whatever fired the event. Calling handlers inline instead meant a
--// blocking handler yielded the *firer*, and on the main thread that ends the
--// script mid-run with nothing printed and a clean exit code.
function Signal:Fire(...)
	for _, connection in table.clone(self.handlers) do
		if connection.live then
			if connection.once then
				connection:Disconnect()
			end

			local thread = coroutine.create(connection.handler)
			local ok, err = coroutine.resume(thread, ...)

			if not ok then
				error(err, 0)
			end
		end
	end
end

Shim.signal = signal

--// datatypes ---------------------------------------------------------------
local function datatype(name: string, fields: { string })
	local class = {}

	class.__index = class
	class.__type = name

	function class.__eq(a, b)
		for _, field in fields do
			if a[field] ~= b[field] then
				return false
			end
		end

		return true
	end

	function class.__tostring(self)
		local parts = {}

		for _, field in fields do
			table.insert(parts, tostring(self[field]))
		end

		return `{name}({table.concat(parts, ", ")})`
	end

	return class
end

local Color3Class = datatype("Color3", { "R", "G", "B" })
local UDimClass = datatype("UDim", { "Scale", "Offset" })
local UDim2Class = datatype("UDim2", { "X", "Y" })
local Vector2Class = datatype("Vector2", { "X", "Y" })
local Vector3Class = datatype("Vector3", { "X", "Y", "Z" })
local RectClass = datatype("Rect", { "Min", "Max" })
local TweenInfoClass = datatype("TweenInfo", { "Time" })

local function color3(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3Class)
end

local Color3Lib = {
	new = color3,
	fromRGB = function(r, g, b)
		return color3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
	fromHSV = function(h, s, v)
		local sector = (h % 1) * 6
		local index = math.floor(sector)
		local offset = sector - index

		local p = v * (1 - s)
		local q = v * (1 - s * offset)
		local t = v * (1 - s * (1 - offset))

		if index == 0 then
			return color3(v, t, p)
		elseif index == 1 then
			return color3(q, v, p)
		elseif index == 2 then
			return color3(p, v, t)
		elseif index == 3 then
			return color3(p, q, v)
		elseif index == 4 then
			return color3(t, p, v)
		end

		return color3(v, p, q)
	end,
	fromHex = function(hex)
		hex = hex:gsub("#", "")

		return color3(
			tonumber(hex:sub(1, 2), 16) / 255,
			tonumber(hex:sub(3, 4), 16) / 255,
			tonumber(hex:sub(5, 6), 16) / 255
		)
	end,
}

function Color3Class.__index.Lerp(self, other, alpha)
	return color3(
		self.R + (other.R - self.R) * alpha,
		self.G + (other.G - self.G) * alpha,
		self.B + (other.B - self.B) * alpha
	)
end

--- Roblox's own conversion, near enough for tests: hue in sixths, saturation
--- and value from the extremes of the three channels.
function Color3Class.__index.ToHSV(self)
	local max = math.max(self.R, self.G, self.B)
	local min = math.min(self.R, self.G, self.B)
	local delta = max - min

	local hue = 0

	if delta > 0 then
		if max == self.R then
			hue = ((self.G - self.B) / delta) % 6
		elseif max == self.G then
			hue = (self.B - self.R) / delta + 2
		else
			hue = (self.R - self.G) / delta + 4
		end

		hue /= 6
	end

	return hue, (if max == 0 then 0 else delta / max), max
end

function Color3Class.__index.ToHex(self)
	return string.format(
		"%02x%02x%02x",
		math.floor(self.R * 255 + 0.5),
		math.floor(self.G * 255 + 0.5),
		math.floor(self.B * 255 + 0.5)
	)
end

local function udim(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDimClass)
end

local function vector2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0, Magnitude = math.sqrt((x or 0) ^ 2 + (y or 0) ^ 2) }, Vector2Class)
end

function Vector2Class.__add(a, b)
	return vector2(a.X + b.X, a.Y + b.Y)
end

function Vector2Class.__sub(a, b)
	return vector2(a.X - b.X, a.Y - b.Y)
end

function Vector2Class.__mul(a, b)
	if type(b) == "number" then
		return vector2(a.X * b, a.Y * b)
	end

	return vector2(a.X * b.X, a.Y * b.Y)
end

local function udim2(sx, ox, sy, oy)
	if type(sx) == "table" then
		return setmetatable({ X = sx, Y = ox }, UDim2Class)
	end

	return setmetatable({ X = udim(sx, ox), Y = udim(sy, oy) }, UDim2Class)
end

local Vector2Lib = {
	new = vector2,
	zero = vector2(0, 0),
	one = vector2(1, 1),
}

--// enums -------------------------------------------------------------------
--// every `Enum.Whatever.Item` resolves to a stable singleton, so equality and
--// `.Name` behave without anyone maintaining a list
local enums = setmetatable({}, {
	__index = function(self, enumName)
		local items = setmetatable({}, {
			__index = function(inner, itemName)
				local item = setmetatable({ Name = itemName, Value = 0, EnumType = enumName }, {
					__type = "EnumItem",
					__tostring = function()
						return `Enum.{enumName}.{itemName}`
					end,
				})

				rawset(inner, itemName, item)

				return item
			end,
		})

		rawset(self, enumName, items)

		return items
	end,
})

--// instances ---------------------------------------------------------------
local EVENTS = {
	"Activated",
	"MouseButton1Click",
	"MouseButton1Down",
	"MouseButton1Up",
	"MouseEnter",
	"MouseLeave",
	"MouseMoved",
	"InputBegan",
	"InputChanged",
	"InputEnded",
	"Changed",
	"Ended",
	"Played",
	"Destroying",
	"ChildAdded",
	"ChildRemoved",
	"AncestryChanged",
	"FocusLost",
	"Focused",
	"Touched",
}

local DEFAULTS = {
	Name = "Instance",
	Visible = true,
	Active = false,
	AutoButtonColor = false,
	Text = "",
	Image = "",
	SoundId = "",
	TextTransparency = 0,
	ImageTransparency = 0,
	BackgroundTransparency = 0,
	ZIndex = 1,
	LayoutOrder = 0,
	Transparency = 0,
	Volume = 0.5,
	IsPlaying = false,

	--// GUI properties read before anything sets them. Roblox hands back a
	--// zero value here; the shim used to hand back nil, which turns an
	--// ordinary `.Y` into a crash that says nothing about the code under test
	CanvasPosition = vector2(0, 0),
	AbsoluteContentSize = vector2(0, 0),
	AnchorPoint = vector2(0, 0),
	TextBounds = vector2(0, 0),
	Size = udim2(0, 0, 0, 0),
	Position = udim2(0, 0, 0, 0),
	CanvasSize = udim2(0, 0, 0, 0),
}

local Instance3 = {}

--- `autoSignal` makes any unknown property read return a signal instead of
--- nil. Services are full of events nobody has needed yet — declaring each one
--- by hand is a losing game, so services opt in and GuiObjects do not.
local function newInstance(className: string, autoSignal: boolean?)
	local instance
	local props: { [string]: any } = {
		ClassName = className,
		Name = className,
		Parent = nil,
	}
	local children = {}
	local events = {}
	local changed = {}

	for _, name in EVENTS do
		events[name] = signal()
	end

	local methods = {}

	function methods.Destroy(self)
		self:SetParent(nil)

		props.Parent = nil
		self.Destroyed = true

		events.Destroying:Fire()

		for _, child in table.clone(children) do
			child:Destroy()
		end
	end

	function methods.SetParent(self, parent)
		local old = rawget(props, "Parent")

		if old then
			local index = table.find(old:GetChildren(), self)

			if index then
				table.remove(old:GetChildren(), index)
			end
		end

		rawset(props, "Parent", parent)

		if parent then
			table.insert(parent:GetChildren(), self)
		end
	end

	function methods.GetChildren()
		return children
	end

	function methods.GetDescendants(self)
		local out = {}

		for _, child in children do
			table.insert(out, child)

			for _, deep in child:GetDescendants() do
				table.insert(out, deep)
			end
		end

		return out
	end

	function methods.FindFirstChild(self, name)
		for _, child in children do
			if child.Name == name then
				return child
			end
		end

		return nil
	end

	methods.WaitForChild = methods.FindFirstChild

	function methods.FindFirstChildOfClass(self, class)
		for _, child in children do
			if child.ClassName == class then
				return child
			end
		end

		return nil
	end

	function methods.FindFirstAncestorOfClass(self, class)
		local parent = rawget(props, "Parent")

		while parent do
			if parent.ClassName == class then
				return parent
			end

			parent = parent.Parent
		end

		return nil
	end

	function methods.IsA(self, class)
		if class == className then
			return true
		end

		--// enough of the hierarchy for the checks Lume actually makes
		local guiObjects = {
			Frame = true,
			TextLabel = true,
			TextButton = true,
			TextBox = true,
			ImageLabel = true,
			ImageButton = true,
			ScrollingFrame = true,
			CanvasGroup = true,
		}

		if class == "GuiObject" or class == "GuiBase2d" then
			return guiObjects[className] == true
		end

		if class == "LayerCollector" then
			return className == "ScreenGui"
		end

		return false
	end

	function methods.GetPropertyChangedSignal(self, name)
		if not changed[name] then
			changed[name] = signal()
		end

		return changed[name]
	end

	function methods.Play(self)
		props.IsPlaying = true

		table.insert(Shim.played, props.SoundId)
	end

	function methods.Stop(self)
		props.IsPlaying = false
	end

	function methods.Clone(self)
		local copy = newInstance(className)

		for key, value in props do
			if key ~= "Parent" and key ~= "ClassName" then
				copy[key] = value
			end
		end

		return copy
	end

	function methods.TweenSize() end
	function methods.TweenPosition() end

	instance = setmetatable({}, {
		__type = "Instance",
		__tostring = function()
			return props.Name
		end,
		__index = function(self, key)
			if events[key] then
				return events[key]
			end

			if methods[key] then
				return methods[key]
			end

			if props[key] ~= nil then
				return props[key]
			end

			if key == "AbsoluteSize" or key == "AbsolutePosition" then
				return vector2(0, 0)
			end

			local child = methods.FindFirstChild(self, key)

			if child then
				return child
			end

			if DEFAULTS[key] ~= nil then
				return DEFAULTS[key]
			end

			if autoSignal and type(key) == "string" and key:match("^%u") then
				local created = signal()

				events[key] = created

				return created
			end

			return nil
		end,
		__newindex = function(self, key, value)
			if key == "Parent" then
				methods.SetParent(self, value)
			else
				rawset(props, key, value)
			end

			if changed[key] then
				changed[key]:Fire(value)
			end

			events.Changed:Fire(key)
		end,
	})

	return instance
end

Instance3.new = newInstance

--// services ----------------------------------------------------------------
local services: { [string]: any } = {}

local function service(name: string, build: ((any) -> ())?)
	local instance = newInstance(name, true)

	if build then
		build(instance)
	end

	services[name] = instance

	return instance
end

local RunService = service("RunService", function(self)
	rawset(self, "IsClientValue", true)
end)

RunService.Heartbeat = signal()
RunService.RenderStepped = signal()
RunService.Stepped = signal()

function RunService.IsClient()
	return true
end

function RunService.IsServer()
	return false
end

function RunService.IsStudio()
	return false
end

function RunService.IsRunning()
	return true
end

--// what `play` did is the whole question in a sound test, so record it
Shim.played = {}

local SoundService = service("SoundService")

function SoundService.PlayLocalSound(self, sound)
	table.insert(Shim.played, sound.SoundId)
end

local TweenService = service("TweenService")

function TweenService.Create()
	local tween = newInstance("Tween")

	function tween.Play() end
	function tween.Cancel() end

	tween.Completed = signal()

	return tween
end

local TextService = service("TextService")

function TextService.GetTextSize(self, text, size, font, bounds)
	return vector2(#text * size * 0.5, size)
end

local Players = service("Players")

Players.LocalPlayer = newInstance("Player")
Players.LocalPlayer.Name = "Tester"

local playerGui = newInstance("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = Players.LocalPlayer

local UserInputService = service("UserInputService")

UserInputService.InputBegan = signal()
UserInputService.InputChanged = signal()
UserInputService.InputEnded = signal()

function UserInputService.GetMouseLocation()
	return vector2(0, 0)
end

local Workspace = service("Workspace")

local camera = newInstance("Camera")

camera.Name = "Camera"
camera.ViewportSize = vector2(1920, 1080)
Workspace.CurrentCamera = camera
service("CoreGui")
service("GuiService")
service("ReplicatedStorage")
service("HttpService")

local game = newInstance("DataModel")

function game.GetService(self, name)
	if not services[name] then
		service(name)
	end

	return services[name]
end

game.FindService = game.GetService

--// task --------------------------------------------------------------------
local scheduler = {}

function scheduler.wait(duration: number?)
	local thread = coroutine.running()

	table.insert(timers, { at = now + (duration or 0), thread = thread, resume = {} })

	return coroutine.yield()
end

function scheduler.spawn(callback, ...)
	if type(callback) == "thread" then
		local ok, err = coroutine.resume(callback, ...)

		if not ok then
			error(err, 0)
		end

		return callback
	end

	local thread = coroutine.create(callback)
	local ok, err = coroutine.resume(thread, ...)

	if not ok then
		error(err, 0)
	end

	return thread
end

function scheduler.defer(callback, ...)
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)

	table.insert(timers, { at = now, thread = thread, resume = table.pack(...) })

	return thread
end

function scheduler.delay(duration, callback, ...)
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)

	table.insert(timers, { at = now + (duration or 0), thread = thread, resume = table.pack(...) })

	return thread
end

function scheduler.cancel(thread)
	for index = #timers, 1, -1 do
		if timers[index].thread == thread then
			table.remove(timers, index)
		end
	end
end

function scheduler.wrap(callback)
	return function(...)
		return scheduler.spawn(callback, ...)
	end
end

--- Advances the clock, runs whatever came due, and fires a frame.
function Shim.step(dt: number?)
	now += dt or 1 / 60

	local due = {}

	for index = #timers, 1, -1 do
		if timers[index].at <= now then
			table.insert(due, table.remove(timers, index))
		end
	end

	--// oldest first, so two things owed the same frame run in the order they
	--// were scheduled rather than backwards
	table.sort(due, function(a, b)
		return a.at < b.at
	end)

	for _, timer in due do
		if coroutine.status(timer.thread) == "suspended" then
			local ok, err = coroutine.resume(timer.thread, table.unpack(timer.resume, 1, timer.resume.n or 0))

			if not ok then
				error(err, 0)
			end
		end
	end

	RunService.Heartbeat:Fire(dt or 1 / 60)
	RunService.RenderStepped:Fire(dt or 1 / 60)
end

--- Steps enough frames to cover `seconds`.
function Shim.advance(seconds: number, dt: number?)
	local frame = dt or 1 / 60
	local elapsed = 0

	while elapsed < seconds do
		Shim.step(frame)

		elapsed += frame
	end
end

function Shim.clock()
	return now
end

--// module tree -------------------------------------------------------------
local environment

--// the source is read here rather than at require time on purpose: Lune's
--// `fs` is async, and a read inside a coroutine yields it in a way a plain
--// `coroutine.resume` can never drive. Everything is on disk already, so
--// reading eagerly costs nothing and keeps requires synchronous.
local function moduleFor(path: string, name: string)
	local module = newInstance("ModuleScript")

	module.Name = name
	rawset(module, "SourcePath", path)
	rawset(module, "Source", fs.readFile(path))

	return module
end

--- Builds a fake instance tree out of a source directory, so `require(script.
--- Parent.X)` resolves the way it does in Roblox.
local function build(path: string, name: string)
	local instance

	local initLua = `{path}/init.lua`
	local initLuau = `{path}/init.luau`

	if fs.isFile(initLua) then
		instance = moduleFor(initLua, name)
	elseif fs.isFile(initLuau) then
		instance = moduleFor(initLuau, name)
	else
		instance = newInstance("Folder")
		instance.Name = name
	end

	for _, entry in fs.readDir(path) do
		local full = `{path}/{entry}`

		if fs.isDir(full) then
			local child = build(full, entry)

			child.Parent = instance
		elseif entry ~= "init.lua" and entry ~= "init.luau" then
			local base = entry:match("^(.*)%.luau?$")

			if base then
				local child = moduleFor(full, base)

				child.Parent = instance
			end
		end
	end

	return instance
end

local loaded: { [any]: any } = {}

local function requireModule(module)
	if loaded[module] ~= nil then
		return loaded[module]
	end

	local path = rawget(module, "SourcePath")

	if not path then
		error(`[Shim] {tostring(module)} is not a ModuleScript`, 0)
	end

	local chunk = luau.load(rawget(module, "Source"), {
		debugName = path,
		environment = setmetatable({ script = module }, { __index = environment }),
		injectGlobals = false,
	})

	local result = chunk()

	loaded[module] = result

	return result
end

environment = {
	game = game,
	workspace = services.Workspace,
	Instance = Instance3,
	Enum = enums,
	Color3 = Color3Lib,
	UDim = { new = udim },
	UDim2 = {
		new = udim2,
		fromScale = function(x, y)
			return udim2(x, 0, y, 0)
		end,
		fromOffset = function(x, y)
			return udim2(0, x, 0, y)
		end,
	},
	Vector2 = Vector2Lib,
	Vector3 = {
		new = function(x, y, z)
			return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Class)
		end,
	},
	Rect = {
		new = function(a, b, c, d)
			if type(a) == "table" then
				return setmetatable({ Min = a, Max = b }, RectClass)
			end

			return setmetatable({ Min = vector2(a, b), Max = vector2(c, d) }, RectClass)
		end,
	},
	TweenInfo = {
		new = function(time, ...)
			return setmetatable({ Time = time or 1 }, TweenInfoClass)
		end,
	},
	NumberSequence = { new = function(...) return { keypoints = { ... } } end },
	NumberSequenceKeypoint = { new = function(time, value) return { Time = time, Value = value } end },
	ColorSequence = { new = function(...) return { keypoints = { ... } } end },
	ColorSequenceKeypoint = { new = function(time, value) return { Time = time, Value = value } end },
	NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end },
	Font = { new = function(...) return { ... } end },

	task = scheduler,
	require = requireModule,

	print = print,
	warn = function(...)
		table.insert(Shim.warnings, table.concat({ ... }, " "))
	end,
	error = error,
	assert = assert,
	pcall = pcall,
	xpcall = xpcall,
	select = select,
	type = type,
	tostring = tostring,
	tonumber = tonumber,
	ipairs = ipairs,
	pairs = pairs,
	next = next,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	rawlen = rawlen,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	unpack = table.unpack,
	string = string,
	table = table,
	math = math,
	coroutine = coroutine,
	utf8 = utf8,
	buffer = buffer,
	bit32 = bit32,
	os = setmetatable({ clock = Shim.clock, time = Shim.clock }, { __index = os }),
	tick = Shim.clock,
	typeof = function(value)
		local meta = getmetatable(value)

		if type(meta) == "table" and rawget(meta, "__type") then
			return rawget(meta, "__type")
		end

		if type(value) == "table" and meta and rawget(meta, "__index") == nil and rawget(meta, "__type") then
			return rawget(meta, "__type")
		end

		return type(value)
	end,
	newproxy = newproxy,
}

environment._G = {}
environment.shared = {}
environment.getfenv = function()
	return environment
end

Shim.warnings = {}
Shim.timers = timers
Shim.environment = environment
Shim.game = game
Shim.services = services
Shim.RunService = RunService
Shim.SoundService = SoundService
Shim.PlayerGui = playerGui
Shim.Instance = Instance3
Shim.Color3 = Color3Lib
Shim.Vector2 = Vector2Lib
Shim.Enum = enums
Shim.task = scheduler

--- Loads a package's `src` directory and returns its main module. The tree is
--- parented into ReplicatedStorage, so an example script that writes
--- `require(ReplicatedStorage.Flare)` finds it exactly as it would in a place.
function Shim.load(root: string, name: string)
	local tree = build(root, name)

	tree.Parent = services.ReplicatedStorage

	return requireModule(tree), tree
end

--- Compiles a standalone script file — an example, usually — against the shim.
--- Returns the chunk rather than calling it, so a caller can run it inside its
--- own coroutine without a file read yielding underneath.
function Shim.compile(path: string, name: string?)
	local module = moduleFor(path, name or "Script")

	return luau.load(rawget(module, "Source"), {
		debugName = path,
		environment = setmetatable({ script = module }, { __index = environment }),
		injectGlobals = false,
	})
end

--- Compiles and runs a script. Only safe on the main thread; inside a
--- coroutine, use `Shim.compile` and call the result yourself.
function Shim.run(path: string, name: string?)
	return Shim.compile(path, name)()
end

return Shim
