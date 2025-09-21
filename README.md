# flag.lua
## Usage
```lua
local flag = require("flag")
-- Mutate `arg` or create your own one
flag:Init( arg, "This is an explanation of the command" )
-- flag:Unnamed( "file", "list", {}, "This is an explanation of `file`" )
flag:Number( "n", 123, "number", "This is an explanation of `-n` flag" )
-- ...
local flags, ers = flag:Parse()
if ers[1] then
    print(flag:Help())
    os.exit(1)
end
-- flags.unnamed or flags.file is array or {}
-- flags.n is `number` or 123
```
- Predefined flags: `unnamed`, `h`
- `flag:Unnamed` `alias` MUST not overlap with flag names
- ALL default values is UNCHECKED

## Credit
- [tsoding/flag.h](https://github.com/tsoding/flag.h)
- [flag.go](https://pkg.go.dev/flag)
