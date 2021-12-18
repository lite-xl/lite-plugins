-- mod-version:2 -- lite-xl 2.1
-- Author: Jipok
-- Doesn't work well with scaling mode == "ui"

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local TreeView = require "plugins.treeview"

-- Config
local use_default_dir_icons = false
local use_default_chevrons  = false

local icon_font = renderer.font.load(USERDIR.."/fonts/nonicons.ttf", 15 * SCALE)
local chevron_width = icon_font:get_width("")
local extension_icons = {
  [".lua"] = { "#51a0cf", "" },
  [".md"]  = { "#519aba", "" }, -- Markdown
  [".cpp"] = { "#519aba", "" },
  [".c"]   = { "#599eff", "" },
  [".h"] = { "#599eff", "" },
  [".py"]  = { "#3572A5", "" }, -- Python
  [".pyc"]  = { "#519aba", "" }, [".pyd"]  = { "#519aba", "" },
  [".php"] = { "#a074c4", "" },
  [".cs"] = { "#596706", "" },  -- C#
  [".conf"] = { "#6d8086", "" }, [".cfg"] = { "#6d8086", "" },
  [".toml"] = { "#6d8086", "" },
  [".yaml"] = { "#6d8086", "" }, [".yml"] = { "#6d8086", "" },
  [".json"] = { "#854CC7", "" },
  [".css"] = { "#563d7c", "" },
  [".html"] = { "#e34c26", "" },
  [".js"] = { "#cbcb41", "" },  -- JavaScript
  [".go"] = { "#519aba", "" },
  [".jpg"] = { "#a074c4", "" }, [".png"] = { "#a074c4", "" },
  [".sh"] = { "#4d5a5e", "" },  -- Shell
  [".java"] = { "#cc3e44", "" },
  [".scala"] = { "#cc3e44", "" },
  [".kt"] = { "#F88A02", "" },  -- Kotlin
  [".pl"] = { "#519aba", "" },  -- Perl
  [".r"] = { "#358a5b", "" },
  [".rake"] = { "#701516", "" },
  [".rb"] = { "#701516", "" },  -- Ruby
  [".rs"] = { "#dea584", "" },  -- Rust
  [".rss"] = { "#cc3e44", "" },
  [".sql"] = { "#dad8d8", "" },
  [".swift"] = { "#e37933", "" },
  [".ts"] = { "#519aba", "" },  -- TypeScript
  [".elm"] = { "#519aba", "" },
  [".diff"] = { "#41535b", "" },
  [".ex"] = { "#a074c4", "" }, [".exs"] = { "#a074c4", "" },  -- Elixir
  -- Following without special icon:
  [".awk"] = { "#4d5a5e", "" },
  [".nim"] = { "#F88A02", "" },

}
local known_names_icons = {
  ["changelog"] = { "#657175", "" }, ["changelog.txt"] = { "#4d5a5e", "" },
  ["makefile"] = { "#6d8086", "" },
  ["dockerfile"] = { "#296478", "" },
  ["docker-compose.yml"] = { "#4289a1", "" },
  ["license"] = { "#d0bf41", "" },
  ["cmakelists.txt"] = { "#6d8086", "" },
  ["readme.md"] = { "#72b886", "" }, ["readme"] = { "#72b886", "" },
  ["init.lua"] = { "#2d6496", "" },
  ["setup.py"] = { "#559dd9", "" },
}

-- Preparing colors
for k, v in pairs(extension_icons) do
  v[1] = { common.color(v[1]) }
end
for k, v in pairs(known_names_icons) do
  v[1] = { common.color(v[1]) }
end

-- Override function to define dir and file custom icons if setting is disabled
if not use_default_dir_icons then
  function TreeView:get_item_icon(item, active, hovered)
    local icon = "" -- unicode 61766
    if item.type == "dir" then
      icon = item.expanded and "" or "" -- unicode 61771 and 61772
    end
    return icon, icon_font, style.text
  end
end

-- Override function to change default icons for special extensions and names
local TreeView_get_item_icon = TreeView.get_item_icon
function TreeView:get_item_icon(item, active, hovered)
  local icon, font, color = TreeView_get_item_icon(self, item, active, hovered)
  local custom_icon = known_names_icons[item.name:lower()]
  if custom_icon == nil then
    custom_icon = extension_icons[item.name:match("^.+(%..+)$")]
  end
  if custom_icon ~= nil then
    color = custom_icon[1]
    icon = custom_icon[2]
    font = icon_font
  end
  if active or hovered then
    color = style.accent
  end
  return icon, font, color
end

-- Override function to draw chevrons if setting is disabled
if not use_default_chevrons then
  function TreeView:draw_item_chevron(item, active, hovered, x, y, w, h)
    if item.type == "dir" then
      local chevron_icon = item.expanded and "" or ""
      local chevron_color = hovered and style.accent or style.text
      common.draw_text(icon_font, chevron_color, chevron_icon, nil, x, y, 0, h)
    end
    return chevron_width * 1.25
  end
end

