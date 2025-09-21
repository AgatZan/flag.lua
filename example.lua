local function list2string(list)
	local str = "{" .. (list[1] and (" " .. list[1]) or "")
	for i = 2, #list do
		str = str .. ", " .. (type(list[i]) == "string" and ("'" .. list[i] .. "'") or list[i])
	end
	return str .. " }"
end
local flag = require("flag")
-- Mutate `arg` or create your own one
flag:Init(arg, "This is the explanation of the command")
-- flag:Unnamed( "file", "list", {}, "This is the explanation of `file`" )
flag:Number("n", 123, "number", "This is the explanation of `-n` flag")
-- ...
local flags = flag:Parse() -- `os.exit()` on error happened or 0-args

for key, value in pairs(flags) do
	print(key, type(value) == "table" and list2string(value) or value)
end
