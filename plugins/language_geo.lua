local syntax = require "core.syntax"

syntax.add {
  files = { "%.geo$" },
  comment = "//",
  patterns = {
    { pattern = "//.-\n",               type = "comment"  },
    { pattern = { "/%*", "%*/" },       type = "comment"  },
    { pattern = { '"', '"', '\\' },     type = "string"   },
    { pattern = "-?%d+[%d%.eE]*f?",     type = "number"   },
    { pattern = "-?%.?%d+f?",           type = "number"   },
    { pattern = "[%+%-=/%*%^%%<>!~|&]", type = "operator" },
    { pattern = "[%a_][%w_]*%f[(]",     type = "function" },
    { pattern = "[%a_][%w_]*",          type = "symbol"   },
  },
  symbols = {
    ["Macro"]    = "keyword",
    ["Function"] = "keyword",
    ["Return"]   = "keyword",
    ["Call"]     = "keyword",
    ["For"]      = "keyword",
    ["In"]       = "keyword",
    ["EndFor"]   = "keyword",
    ["If"]       = "keyword",
    ["ElseIf"]   = "keyword",
    ["Else"]     = "keyword",
    ["EndIf"]    = "keyword",

    ["Physical"] = "keyword2",
    ["Plane"] = "keyword2",

    ["Loop"]     = "keyword2",
    ["Point"]    = "keyword2",
    ["Line"]     = "keyword2",
    ["Surface"]  = "keyword2",
    ["Volume"]   = "keyword2",
  },
}

