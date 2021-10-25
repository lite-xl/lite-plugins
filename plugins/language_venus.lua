-- mod-version:2 -- lite-xl 2.0
local syntax = require "core.syntax"

syntax.add {
  files = { "%.venus$", "%.ve$" },
  comment = "--",
  patterns = {
    { pattern = { '"', '"', '\\' },       type = "string"   },
    { pattern = { "'", "'", '\\' },       type = "string"   },
    { pattern = { "%[%[", "%]%]" },       type = "string"   },
    { pattern = { "%-%-%[%[", "%]%]"},    type = "comment"  },
    { pattern = "%-%-.-\n",               type = "comment"  },
    { pattern = "-?0x%x+",                type = "number"   },
    { pattern = "-?%d+[%d%.eE]*",         type = "number"   },
    { pattern = "-?%.?%d+",               type = "number"   },
    { pattern = "%.%.%.?",                type = "operator" },
    { pattern = "[<>~=&|]=",              type = "operator" },
    { pattern = "[%+%-=/%*%^%%#<>]",      type = "operator" },
    --{ pattern = "[%a_][%w_]*%s*%f[(\"{]", type = "function" },
    { pattern = "[%a_][%w_]*",            type = "symbol"   },
    { pattern = {"%{", "%}"}              type = "operator"   }
  },
  symbols = {
    ["if"]          = "keyword",
    ["else"]        = "keyword",
    ["elseif"]      = "keyword",
    ["for"]         = "keyword",
    ["foreach"]     = "keyword",
    ["return"]      = "keyword",
    ["require"]     = "keyword",
    ["local"]       = "keyword",
    ["until"]       = "keyword",
    ["fn"]          = "keyword",
    ["select"]      = "keyword",
    ["break"]       = "keyword",
    ["true"]        = "literal",
    ["false"]       = "literal",
    ["nil"]         = "literal",
  },
}

