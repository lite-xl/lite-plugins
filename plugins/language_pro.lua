local syntax = require "core.syntax"

syntax.add {
  files = { "%.pro$" },
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
    ["Group"]    = "keyword",
    ["Function"] = "keyword",
    ["Constraint"] = "keyword",
    ["FunctionSpace"] = "keyword",
    ["Jacobian"]      = "keyword",
    ["Integration"]   = "keyword",
    ["Formulation"]   = "keyword",
    ["Resolution"]    = "keyword",
    ["PostProcessing"] = "keyword",
    ["PostOperation"] = "keyword",

    ["Name"] = "keyword2",
    ["Value"] = "keyword2",
    ["Type"] = "keyword2",
    ["Term"] = "keyword2",
    ["In"] = "keyword2",
    ["Case"] = "keyword2",
    ["Region"] = "keyword2",
  },
}

