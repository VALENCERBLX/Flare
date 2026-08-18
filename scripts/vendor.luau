--- Refreshes the vendored copy of Lume under `src/_Packages`.
---
--- Flare ships self-contained, which means Lume is a *copy*. Editing upstream
--- Lume does nothing here until this is run.
---
--- Run with `lune run scripts/vendor`.

local fs = require("@lune/fs")

local SOURCES = { { Name = "Lume", From = "../Lume/src" } }

for _, source in SOURCES do
	local target = `src/_Packages/{source.Name}`

	if not fs.isDir(source.From) then
		print(`skip {source.Name}: {source.From} is not there`)
		continue
	end

	if fs.isDir(target) then
		fs.removeDir(target)
	end

	fs.copy(source.From, target)

	print(`vendored {source.Name}`)
end

print("\nremember to rebuild the installer: lune run scripts/build-installer")
