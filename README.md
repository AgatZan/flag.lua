# flag.lua
## Usage
```lua
local flag = require("flag")
-- Mutate `arg` or create your own one
flag:Init( arg, "This is the explanation of the command" )
-- flag:Unnamed( "file", "list", {}, "This is the explanation of `file`" )
flag:Number( "n", 123, "number", "This is the explanation of `-n` flag" )
-- ...
local flags = flag:Parse() -- `os.exit()` on error happened or 0-args
-- flags.unnamed or flags.file is array or {}
-- flags.n is `number` or 123
```
- Predefined flags: `unnamed`, `h`
- `flag:Unnamed` `alias` MUST not overlap with flag names
- ALL default values is UNCHECKED

## Credit
- [tsoding/flag.h](https://github.com/tsoding/flag.h)
- [flag.go](https://pkg.go.dev/flag)
