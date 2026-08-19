--!nocheck

--- Runs every suite in `tests/`. One command, non-zero exit on the first
--- failure, so it drops into CI or a pre-push hook without ceremony.
---
--- ```sh
--- lune run scripts/test
--- ```

local fs = require("@lune/fs")
local process = require("@lune/process")

local suites = {}

for _, entry in fs.readDir("tests") do
	--// Shim is the harness, not a suite
	if entry:match("%.luau$") and entry ~= "Shim.luau" then
		table.insert(suites, entry)
	end
end

table.sort(suites)

local failed = 0

for _, suite in suites do
	local result = process.exec("lune", { "run", `tests/{suite}` }, { stdio = "inherit" })

	if not result.ok then
		failed += 1
	end
end

if failed > 0 then
	print(`\n{failed} of {#suites} suites failed`)

	process.exit(1)
end

print(`\n{#suites} suites passed`)
