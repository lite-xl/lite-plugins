-- lite-xl 1.16
local syntax = require "core.syntax"

syntax.add {
  files = { "%.sh$" },
  headers = "^#!.*bin.*tcsh\n",
  comment = "#",
  patterns = {
    { pattern = "#.*\n",                  type = "comment"  },
    { pattern = [[\.]],                   type = "normal"   },
    { pattern = { '"', '"', '\\' },       type = "string"   },
    { pattern = { "'", "'", '\\' },       type = "string"   },
    { pattern = { '`', '`', '\\' },       type = "string"   },
    { pattern = "%f[%w_][%d%.]+%f[^%w_]", type = "number"   },
    { pattern = "[!<>|&%[%]=*]",          type = "operator" },
    { pattern = "%f[%S]%-[%w%-_]+",       type = "function" },
    { pattern = "${.-}",                  type = "keyword2" },
    { pattern = "$[%a_@*][%w_]*",         type = "keyword2" },
    { pattern = "[%a_][%w_]*",            type = "symbol"   },
  },
  symbols = {
    ["set"]     = "keyword",
    ["setenv"]     = "keyword",
    ["setpath"]     = "keyword",
    ["unset"]     = "keyword",
    ["alias"]     = "keyword",
    ["if"]       = "keyword",
    ["then"]       = "keyword",
    ["else"]     = "keyword",
    ["endif"]       = "keyword",
    ["switch"]     = "keyword",
    ["case"]     = "keyword",
    ["breaksw"]     = "keyword",
    ["endsw"]     = "keyword",
    ["foreach"]     = "keyword",
    ["while"]     = "keyword",
    ["end"]     = "keyword",
    ["repeat"]     = "keyword",
    ["pushd"]     = "keyword",
    ["popd"]     = "keyword",


    ["echo"]     = "keyword2",
    ["cd"]       = "keyword2",
    ["pwd"]       = "keyword2",
  },
}

