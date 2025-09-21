local insert = table.insert
--- #Usage
---```lua
---local flag = require("flag")
--- -- Mutate `arg` or create your own one
--- flag:Init( arg, "This is the explanation of the command" )
--- -- flag:Unnamed("file", "list", {}, "This is the explanation of `file`")
--- flag:Number("n", 123, "This is the explanation of `-n` flag")
--- -- ...
--- local flags = flag:Parse() -- `os.exit()` on error happend or 0-args
--- -- flags.unnamed or flags.file is array or {}
--- -- flags.n is `number` or 123
---```
local flag = {
	_decl = {
		unnamed = { alias = "unnamed", type = "list", default = {}, help = "" },
		h = { type = "boolean", default = false, alias = "help", help = "print help message (shorthand)" },
	},
	_alias = {},
	_ers = {},
	_flag = {},
}
---@alias Flag.types 'list'|'number'|'boolean'|'string'

--- Set `arg` and optional helpdoc
---@param args string[] `arg` arg[0] treat as command name
---@param help string?
function flag:Init(args, help)
	self.args = { command = args[0], args = args, help = help }
end
--- Declare value/s without flags
---NOTE: unexpected values NOT push to that
---NOTE: `default` is UNCHECKED
---@param alias string MUST be UNIQUE because treated as parsed key. Default: "unnamed"
---@param type Flag.types? to replace. Default: "list"
---@param default any? UNCHECKED MUST be EQUAL to `type`
---@param help string? you found it at `--help`
function flag:Unnamed(alias, type, default, help)
	self._decl.unnamed =
		{ alias = alias or "unnamed", type = type or "list", default = default or {}, help = help or "" }
end
--- Declare number value also [16, 8, 2]-base string
---NOTE: `default` is UNCHECKED
---@param name string `-name`
---@param default number? UNCHECKED NOW ONLY 10-base number. Default: 0. TODO: make [16, 8, 2]-base string possible
---@param alias string? `--alias`
---@param help string? you found it at `--help`
function flag:Number(name, default, alias, help)
	self._decl[name] = { type = "number", default = default or 0, alias = alias, help = help or "" }
	if alias then
		self._alias[alias] = name
	end
end
--- Declare boolean NOW `true` or `false` string or `-name` without value only
---NOTE: `default` is UNCHECKED
---@param name string `-name`
---@param default boolean? Default: false.
---@param alias string? `--alias`
---@param help string? you found it at `--help`
function flag:Bool(name, default, alias, help)
	self._decl[name] = { type = "boolean", default = default or false, alias = alias, help = help or "" }
	if alias then
		self._alias[alias] = name
	end
end
--- Declare boolean NOW `true` or `false` string or `-name` without value only
---NOTE: `default` is UNCHECKED
---@param name string `-name`
---@param default string? UNCHECKED
---@param alias string? `--alias`
---@param help string? you found it at `--help`
function flag:String(name, default, alias, help)
	self._decl[name] = { type = "string", default = default or "", alias = alias, help = help or "" }
	if alias then
		self._alias[alias] = name
	end
end
--- Declare list that absorbs all `arg` to the new flag
---NOTE: `default` is UNCHECKED
---@param name string `-name`
---@param default table? UNCHECKED
---@param alias string? `--alias`
---@param help string? you found it at `--help`
function flag:List(name, default, alias, help)
	self._decl[name] = { type = "list", default = default or {}, alias = alias, help = help or "" }
	if alias then
		self._alias[alias] = name
	end
end
local function list2string(list)
	local str = "{" .. (list[1] and (" " .. list[1]) or "")
	for i = 2, #list do
		str = str .. ", " .. (type(list[i]) == "string" and ("'" .. list[i] .. "'") or list[i])
	end
	return " }"
end
local function value2string(type, value)
	return type == "list" and list2string(value)
		or type == "boolean" and (value and "true" or "false")
		or type == "string" and ("'" .. value .. "'")
		or value
end
function flag:title()
	local title = "Usage: "
		.. self.args.command
		.. (self._decl.unnamed and (self._decl.unnamed.alias .. " <" .. self._decl.unnamed.type .. ">") or "")
	for name, decl in pairs(self._decl) do
		if name ~= "unnamed" then
			local alias = self._alias[decl.alias] and ("[--" .. self._alias[decl.alias] .. "]") or ""
			title = title .. " -" .. name .. alias .. " <" .. decl.type .. ">"
		end
	end
	return title .. "\n"
end
function flag:help()
	local help = self:title()
	if self.args.help then
		help = help .. self.args.help .. "\n"
	end
	if self._ers[1] then
		help = help .. "Errors:\n"
		for i = 1, #self._ers do
			help = "\t" .. self._ers[i] .. "\n"
		end
	end
	help = help .. "Options:\n"
	for name, decl in pairs(self._decl) do
		local tag = name == "unnamed" and self._decl.unnamed[1]
			or ("-" .. name .. (self._alias[self._decl[name].alias] and (" ( --" .. self._decl[name].alias .. " )")))
		local val = value2string(
			self._decl[name].type,
			self._flag[name] and not self._flag[name].isScipped and self._flag[name].val or self._decl[name].default
		)
		help = help .. "\t" .. tag .. ":" .. val .. "  " .. decl.help .. "\n"
	end
	return help
end
local function verifyValue(typ, tag, value)
	local initial = value
	if typ == "number" then
		value = tonumber(value) or tonumber(value, 2) or tonumber(value, 8) or tonumber(value, 16)
		return value, tag .. ": expect number got: " .. initial
	elseif typ == "boolean" then
		value = value == "true" and true or value == "false" and false or nil
		return value, tag .. ": expect true|false got: " .. initial
	end
	return value, ""
end
function flag:parseValue(is_sciped, name, value)
	local alias = self._alias[self._decl[name].alias] and ("[--" .. self._alias[self._decl[name].alias] .. "]") or ""
	local tag = name == "unnamed" and self._decl.unnamed.alias or ("-" .. name .. alias)
	if not self._decl[name] then
		return insert(self._ers, tag .. ": undefine option")
	end
	local typ = self._decl[name].type
	local verifyed, err = verifyValue(typ, tag, value)
	if verifyed == nil then
		return insert(self._ers, err)
	end
	return is_sciped and verifyed or self._decl[name].default
end
--- `arg` to verifyed `table`
---@nodiscard
---@return table
function flag:Parse()
	local args = self.args.args
	if #args == 0 then
		print(self:help())
		os.exit(1)
	end
	local last_name = "unnamed"
	local is_one_set = false
	local alias, is_sciped, name, tag
	for i = 1, #args do
		local arg = args[i]
		if arg:find("^--?/?") then
			alias, is_sciped, name = arg:match("(-?)(/?)(%w+)")
			tag = "-" .. name
			if alias then
				tag = "--" .. name
				if not self._alias[name] then
					insert(self._ers, tag .. ": undefine alias")
				end
				name = self._alias[alias]
			end
			if not self._decl[name] and not alias then
				insert(self._ers, tag .. ": undefine option")
			else
				if self._decl[name].type == "boolean" then
					is_one_set = true
					self._flag[name] = true
				elseif not is_one_set and self._decl[name] ~= "list" then
					insert(self._ers, tag .. ": given but unset")
				end
				last_name = name
			end
		elseif self._decl[last_name].type == "list" then
			insert(self._flag[last_name], arg)
		else
			local typ = self._decl[last_name]
			if is_one_set and not typ == "boolean" then
				insert(self._ers, tag .. " override setted value: " .. value2string(self._flag[last_name]))
			end
			is_one_set = false
			self._flag[last_name] = self:parseValue(is_sciped == "/", name, arg)
		end
	end

	if self._flag["h"] or self._ers[1] then
		print(self:help())
		os.exit(1)
	end

	local parsed = {}
	for n, v in pairs(self._flag) do
		if n ~= "h" then
			parsed[n] = v
		elseif n == "unnamed" then
			parsed[self._decl.unnamed.alias] = v
		end
	end
	return parsed
end
return flag
