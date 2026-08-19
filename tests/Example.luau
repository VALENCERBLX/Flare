--!nocheck

--- Runs the shipped examples end to end. Compiling an example proves nothing:
--- `:Sticky()` compiled fine while doing the opposite of what it said, and only
--- running it made that visible.

local process = require("@lune/process")

local Shim = require("./Shim")

local Flare = Shim.load("./src", "Flare")

local failed = 0

--// an example that waits on an answer would sit there forever, so play the
--// part of the user: anything asking a question gets one after a beat
local function answer()
	for _, notice in Flare.Live() do
		if notice.Shown and not notice.Resolved then
			local kind = notice.Spec.Kind

			if kind == "Confirm" or kind == "Prompt" or kind == "Choice" or kind == "Color" or kind == "Number" then
				notice:Resolve({ Kind = "Dismissed" })
			end
		end
	end
end

local function run(path: string, name: string)
	Flare.Destroy()
	table.clear(Shim.warnings)

	--// compiled out here: reading the file is async in Lune, and a yield for
	--// a file read inside the thread is one nothing can resume
	local chunk = Shim.compile(path, name)
	local thread = coroutine.create(chunk)

	local ok, err = coroutine.resume(thread)

	if not ok then
		failed += 1

		print(`  FAIL  {name} — {err}`)

		return
	end

	for _ = 1, 30000 do
		Shim.step(1 / 30)
		answer()

		if coroutine.status(thread) == "dead" then
			break
		end
	end

	if coroutine.status(thread) ~= "dead" then
		failed += 1

		print(`  FAIL  {name} never finished`)

		return
	end

	local complaints = {}

	for _, warning in Shim.warnings do
		--// an example is allowed to demonstrate a warning on purpose; nothing
		--// currently does, so treat every one as a regression
		table.insert(complaints, warning)
	end

	if #complaints > 0 then
		failed += 1

		print(`  FAIL  {name} warned: {table.concat(complaints, " | ")}`)

		return
	end

	print(`  ok    {name}`)
end

run("./examples/EveryKind.client.luau", "EveryKind")
run("./examples/Showcase.client.luau", "Showcase")

if failed > 0 then
	print(`Examples: {failed} failed`)

	process.exit(1)
end

print("Examples: all clean")
