-- mod-version:2 -- lite-xl 2.0
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local config = require "core.config"
local common = require "core.common"
local style = require "core.style"
local View = require "core.view"
local DocView = require "core.docview"
local StatusView = require "core.statusview"
local TreeView = require "plugins.treeview"

local build = {
  targets = { },
  current_target = 1,
  running_program = nil,
  -- Config variables
  threads = 8,
  error_pattern = "^%s*([^:]+):(%d+):(%d+): (%w+): (.+)",
  interval = 0.1,
  drawer_size = 100
}

style.error_line = { common.color "#8c2a2b" }


local function jump_to_file(file, line, col)
  if not core.active_view or not core.active_view.doc or core.active_view.doc.abs_filename ~= file then
    -- Check to see if the file is in the project. If it is, open it, and go to the line.
    for i = 1, #core.project_directories do
      if common.path_belongs_to(file, core.project_dir) then
        local view = core.root_view:open_doc(core.open_doc(file))
        if line then
          view:scroll_to_line(math.max(1, line - 20), true)
          view.doc:set_selection(line, col or 1, line, col or 1)
        end
        break
      end
    end
  end
end

local function run_command(cmd, on_line, on_done)
  core.add_thread(function()
    build.running_program = process.start(cmd, { ["stderr"] = process.REDIRECT_STDOUT })
    local result = ""
    while build.running_program:running() do
      result = build.running_program:read_stdout()
      if result ~= nil then
        local offset = 1
        while offset < #result do
          local newline = result:find("\n", offset) or #result
          if on_line then
            on_line(result:sub(offset, newline-1))
          end
          offset = newline + 1
        end
        coroutine.yield(build.interval)
      end
    end
    if on_done then
      on_done()
    end
  end)
end

function build.set_targets(targets)
  build.targets = targets
  config.target_binary = build.targets[1].binary
end

function build.output(line)
  core.log(line)
end

local function grep(t, cond)
  local nt = {} for i,v in ipairs(t) do if cond(v, i) then table.insert(nt, v) end end return nt
end

function build.build(target)
  if build.running_program and build.running_program:running() then return false end
  build.message_view:clear_messages()
  build.message_view.visible = true
  local target = build.current_target
  local command = build.targets[target].cmd or "make"
  run_command({ command, build.targets[target].name, "-j", build.threads }, function(line)
    local _, _, file, line_number, column, type, message = line:find(build.error_pattern)
    if file and (type == "warning" or type == "error") then
      build.message_view:add_message({ type, file, line_number, column, message })
    else
      build.message_view:add_message(line)
    end
  end, function()
    build.message_view.messages = grep(build.message_view.messages, function(v) return type(v) == 'table' end)
    build.message_view.visible = #build.message_view.messages > 0
    build.output("Completed building " .. (build.targets[target].binary or "target") .. ". " .. #build.message_view.messages .. " Errors/Warnings.")
  end)
end

function build.clean()
  if build.running_program and build.running_program:running() then return false end
  build.message_view:clear_messages()
  build.output("Started clean " .. (build.targets[build.current_target].binary or "target") .. ".")
  run_command({ "make", "clean" }, function() end, function()
    build.output("Completed cleaning " .. (build.targets[build.current_target].binary or "target") .. ".")
  end)
end

function build.terminate()
  if build.running_program:running() then
    build.running_program:terminate()
    build.message_view:clear_messages()
    build.output("Killed running build.")
  else
    build.output("No build running.")
  end
end


------------------ UI Elements
local status_view_get_items = StatusView.get_items
function StatusView:get_items()
  local left, right = status_view_get_items(self)
  if #build.targets > 0 then
    table.insert(right, 1, self.separator2)
    table.insert(right, 1, "target: " .. build.targets[build.current_target].name)
  end
  return left, right
end

local doc_view_draw_line_gutter = DocView.draw_line_gutter
function DocView:draw_line_gutter(idx, x, y, width)
  if self.doc.abs_filename == build.message_view.active_file
    and build.message_view.active_message
    and idx == build.message_view.active_line
  then
    renderer.draw_rect(x, y, self:get_gutter_width(), self:get_line_height(), style.error_line)
  end
  doc_view_draw_line_gutter(self, idx, x, y, width)
end

local BuildMessageView = View:extend()
function BuildMessageView:new()
  BuildMessageView.super.new(self)
  self.messages = { }
  self.target_size = build.drawer_size
  self.scrollable = true
  self.init_size = true
  self.hovered_message = nil
  self.visible = false
  self.active_message = nil
  self.active_file = nil
  self.active_line = nil
end

function BuildMessageView:update()
  local dest = self.visible and self.target_size or 0
  if self.init_size then
    self.size.y = dest
    self.init_size = false
  else
    self:move_towards(self.size, "y", dest)
  end
  BuildMessageView.super.update(self)
end

function BuildMessageView:set_target_size(axis, value)
  if axis == "y" then
    self.target_size = value
    return true
  end
end

function BuildMessageView:clear_messages()
  self.messages = {}
  self.hovered_message = nil
  self.active_message = nil
  self.active_file = nil
  self.active_line = nil
end

function BuildMessageView:add_message(message)
  local should_scroll = self:get_scrollable_size() <= self.size.y or self.scroll.to.y == self:get_scrollable_size() - self.size.y
  table.insert(self.messages, message)
  if should_scroll then
    self.scroll.to.y = self:get_scrollable_size() - self.size.y
  end
end

function BuildMessageView:get_item_height()
  return style.code_font:get_height() + style.padding.y*2
end

function BuildMessageView:get_scrollable_size()
  return #self.messages and self:get_item_height() * (#self.messages + 1)
end

function BuildMessageView:on_mouse_moved(px, py, ...)
  BuildMessageView.super.on_mouse_moved(self, px, py, ...)
  if self.dragging_scrollbar then return end
  local ox, oy = self:get_content_offset()
  local offset = math.floor((py - oy) / self:get_item_height())
  self.hovered_message = offset >= 1 and offset <= #self.messages and offset
end

function BuildMessageView:on_mouse_pressed(button, x, y, clicks)
  if BuildMessageView.super.on_mouse_pressed(self, button, x, y, clicks) then
    return true
  elseif self.hovered_message and type(self.messages[self.hovered_message]) == "table" then
    self.active_message = self.hovered_message
    self.active_file = system.absolute_path(common.home_expand(self.messages[self.hovered_message][2]))
    self.active_line = tonumber(self.messages[self.hovered_message][3])
    jump_to_file(self.active_file, tonumber(self.messages[self.hovered_message][3]), tonumber(self.messages[self.hovered_message][4]))
    return true
  end
  return false
end

function BuildMessageView:draw()
  self:draw_background(style.background3)
  local h = style.code_font:get_height()
  local item_height = self:get_item_height()
  local ox, oy = self:get_content_offset()
  common.draw_text(style.code_font, style.text, "Build Messages", "left", ox + style.padding.x, oy + style.padding.y, 0, h)
  for i,v in ipairs(self.messages) do
    local yoffset = style.padding.y + (i - 1)*item_height + style.padding.y + h
    if self.hovered_message == i or self.active_message == i then
      renderer.draw_rect(ox, oy + yoffset - style.padding.y * 0.5, self.size.x, h + style.padding.y, style.line_highlight)
    end
    if type(v) == "table" then
      common.draw_text(style.code_font, style.text, v[2] .. ":" .. v[3] .. " [" .. v[1] .. "]: " .. v[5], "left", ox + style.padding.x, oy + yoffset, 0, h)
    else
      common.draw_text(style.code_font, style.text, v, "left", ox + style.padding.x, oy + yoffset, 0, h)
    end
  end
  self:draw_scrollbar()
end

build.message_view = BuildMessageView()
local node = core.root_view:get_active_node()
local message_view_node = node:split("down", build.message_view, { y = true }, true)

command.add(nil, {
  ["build:build"] = function()
    if #build.targets > 0 then
      build.build(build.targets[build.current_target].name)
    end
  end,
  ["build:clean"] = function()
    build.clean()
  end,
  ["build:terminate"] = function()
    build.terminate()
  end,
  ["build:next-target"] = function()
    if #build.targets > 0 then
      build.current_target = (build.current_target + 1) % #build.targets
    end
  end,
  ["build:next-target"] = function()
    if #build.targets > 0 then
      build.current_target = (build.current_target + 1) % #build.targets
      config.target_binary = build.targets[build.current_target].binary
    end
  end,
  ["build:toggle-drawer"] = function()
    build.message_view.visible = not build.message_view.visible
  end
})

keymap.add {
  ["ctrl+b"]             = "build:build",
  ["ctrl+t"]             = "build:next-target",
  ["ctrl+shift+b"]       = "build:clean",
  ["ctrl+alt+b"]         = "build:terminate",
  ["f6"]                 = "build:toggle-drawer"
}

return build

