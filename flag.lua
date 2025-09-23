local insert = table.insert
local function typesafe(typ, value)
	return type(value) == typ
		or typ == "number" and (tonumber(value) or tonumber(value, 2) or tonumber(value, 8) or tonumber(value, 16))
end
local function list2string(list)
	local str = "{" .. (list[1] and (" " .. list[1]) or "")
	for i = 2, #list do
		str = str .. ", " .. (type(list[i]) == "string" and ("'" .. list[i] .. "'") or list[i])
	end
	if list[2] then
		str = str .. " "
	end
	return str .. "}"
end
local function value2string(type, value)
	return type == "list" and list2string(value)
		or type == "boolean" and (value and "true" or "false")
		or type == "string" and ("'" .. value .. "'")
		or value
end
---@alias Flag.types 'table'|'number'|'boolean'|'string'

---@class Flag.declaration
---@field alias string?
---@field type Flag.types
---@field default any
---@field help string?

--- #Usage
---```lua
--- local flag = require("flag")
--- -- Mutate `arg` or create your own one
--- -- # STEP 1. Declare
--- flag:Init( arg, "This is the explanation of the command" )
--- -- flag:Unnamed("file", "list", {}, "This is the explanation of `file`")
--- flag:Number("n", 123, "This is the explanation of `-n` flag")
--- -- ...
--- -- # STEP 2. Parse
--- local flags, ers = flag:Parse()
--- if ers[1] then
---		print(flag:Help())
---		os.exit(1)
--- end
--- -- # STEP 3. Use
--- -- flags.unnamed -- or flags.file is array or {}
--- -- flags.n 		 -- is `number` or 123
---```
local flag = {
	---@type {[string]: Flag.declaration}
	_decl = {
		unnamed = { alias = "unnamed", type = "table", default = {}, help = "" },
		h = { type = "boolean", default = false, alias = "help", help = "print help message" },
	},
	---@type {[string]: string}
	_alias = { help = "h" },
	---@type string[]
	_ers = {},
	---@type {[string]: `Flag.types`}
	_flag = { unnamed = {} },
}

--- Set `arg` and optional helpdoc
---@param args string[] `arg` args[0] treat as command name
---@param help string?
function flag:Init(args, help)
	self.args = { command = args[0], args = args, help = help }
end
--- Declare value/s without flags
---NOTE: unexpected values NOT push to that
---@param alias string? MUST be UNIQUE, treated as parsed key. Default: "unnamed"
---@param type Flag.types? to replace. Default: "list"
---@param default any? MUST be EQUAL to `type`
---@param help string? you found it at `--help`
function flag:Unnamed(alias, type, default, help)
	assert(typesafe(type, default))
	assert(self._decl[alias] == nil)

	self._decl.unnamed =
		{ alias = alias or "unnamed", type = type or "table", default = default or {}, help = help or "" }
end
--- Declare number value also [16, 8, 2]-base string
---@param name string `-name` MUST be UNIQUE, treated as parsed key
---@param default (number|string)? Default: 0.
---@param alias string? `--alias` MUST be UNIQUE
---@param help string? you found it at `--help`
function flag:Number(name, default, alias, help)
	assert(typesafe(type, default))
	assert(self._decl.unnamed.alias ~= name and self._decl[name] == nil)

	self._decl[name] = {
		type = "number",
		-- stylua: ignore
		default = type(default) ~= "string" and default
			or tonumber(default)
			or tonumber(default, 2)
			or tonumber(default, 8)
			or tonumber(default, 16)
			or 0,
		alias = alias,
		help = help or "",
	}
	if alias then
		assert(self._alias[alias] == nil)
		self._alias[alias] = name
	end
end
--- Declare boolean NOW `true` or `false` string or `-name` without value only
---@param name string `-name` MUST be UNIQUE, treated as parsed key
---@param default boolean? Default: false.
---@param alias string? `--alias` MUST be UNIQUE
---@param help string? you found it at `--help`
function flag:Bool(name, default, alias, help)
	assert(typesafe(type, default))
	assert(self._decl.unnamed.alias ~= name and self._decl[name] == nil)

	self._decl[name] = { type = "boolean", default = default or false, alias = alias, help = help or "" }
	if alias then
		assert(self._alias[alias] == nil)
		self._alias[alias] = name
	end
end
--- Declare boolean NOW `true` or `false` string or `-name` without value only
---@param name string `-name`  MUST be UNIQUE, treated as parsed key
---@param default string?
---@param alias string? `--alias` MUST be UNIQUE
---@param help string? you found it at `--help`
function flag:String(name, default, alias, help)
	assert(typesafe(type, default))
	assert(self._decl.unnamed.alias ~= name and self._decl[name] == nil)

	self._decl[name] = { type = "string", default = default or "", alias = alias, help = help or "" }
	if alias then
		assert(self._alias[alias] == nil)
		self._alias[alias] = name
	end
end
--- Declare list that absorbs all `arg` to the new flag
---@param name string `-name`  MUST be UNIQUE, treated as parsed key
---@param default table?
---@param alias string? `--alias` MUST be UNIQUE
---@param help string? you found it at `--help`
function flag:List(name, default, alias, help)
	assert(typesafe(type, default))
	assert(self._decl.unnamed.alias ~= name and self._decl[name] == nil)

	self._decl[name] = { type = "table", default = default or {}, alias = alias, help = help or "" }
	if alias then
		assert(self._alias[alias] == nil)
		self._alias[alias] = name
	end
	self._flag[name] = default or {}
end

function flag:title()
	local title = "Usage: " .. self.args.command .. " " .. (self._decl.unnamed and self._decl.unnamed.alias or "")
	for name, decl in pairs(self._decl) do
		if name ~= "unnamed" then
			local alias = self._alias[decl.alias] and ("[--" .. decl.alias .. "]") or ""
			title = title .. " -" .. name .. alias .. (decl.type ~= "boolean" and (" <" .. decl.type .. ">") or "")
		end
	end
	return title .. "\n"
end
function flag:Help()
	local help = self:title()
	if self.args.help then
		help = help .. self.args.help .. "\n\n"
	end
	if self._ers[1] then
		help = help .. "Errors:\n"
		for i = 1, #self._ers do
			help = help .. "\t" .. self._ers[i] .. "\n"
		end
	end
	help = help .. "Options:\n"
	local tag = self._decl.unnamed.alias
	local val = value2string(self._decl.unnamed.type, self._flag.unnamed or self._decl.unnamed.default)
	help = help .. "\t" .. tag .. " ( " .. val .. " ) " .. self._decl.unnamed.help .. "\n"
	for name, decl in pairs(self._decl) do
		if name ~= "unnamed" then
			tag = ("-" .. name .. (self._alias[self._decl[name].alias] and ("[--" .. self._decl[name].alias .. "]")))
			val = value2string(self._decl[name].type, self._flag[name] or self._decl[name].default)
			help = help .. "\t" .. tag .. " ( " .. val .. " ) " .. decl.help .. "\n"
		end
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
	local verified, err = verifyValue(typ, tag, value)
	if verified == nil then
		return insert(self._ers, err)
	end
	return is_sciped and self._decl[name].default or verified
end
--- `arg` to verified `table` and error of parsing
---@nodiscard
---@return table, string[]
function flag:Parse()
	local args = self.args.args
	if #args == 0 then
		return {}, {}
	end
	local last_name = "unnamed"
	local is_one_set = true
	local alias, is_sciped, name, tag
	for i = 1, #args do
		local arg = args[i]
		if arg:find("^%-%-?/?") then
			alias, is_sciped, name = arg:match("-(-?)(/?)(%w+)")
			tag = "-" .. name
			-- vim.print(type(alias), name, self._decl[name], self._alias[name], self._decl[self._alias[name]])
			if alias and alias ~= "" then
				tag = "--" .. name
				if not self._alias[name] then
					insert(self._ers, tag .. ": undefine alias")
				end
				name = self._alias[name]
				alias = ""
			end
			if not self._decl[name] and (not alias or alias == "") then
				insert(self._ers, tag .. ": undefine option")
			else
				if self._decl[name].type == "boolean" then
					self._flag[name] = is_sciped ~= "/"
					is_one_set = true
				elseif not is_one_set and self._decl[name] ~= "list" then
					insert(self._ers, tag .. ": given but unset")
				else
					is_one_set = false
				end
				last_name = name
			end
		elseif self._decl[last_name].type == "list" then
			insert(self._flag[last_name], arg)
			is_one_set = true
		else
			local typ = self._decl[last_name]
			if is_one_set and not typ == "boolean" then
				insert(self._ers, tag .. " override setted value: " .. value2string(self._flag[last_name]))
			end
			self._flag[last_name] = self:parseValue(is_sciped == "/", name, arg)
			is_one_set = true
		end
	end

	local parsed = {}
	for n, v in pairs(self._flag) do
		if n == "unnamed" then
			parsed[self._decl.unnamed.alias] = v
		elseif n ~= "h" then
			parsed[n] = v
		end
	end
	return parsed, self._ers
end
return flag
