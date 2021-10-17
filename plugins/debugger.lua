-- mod-version:2 -- lite-xl 2.0

local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local DocView = require "core.docview"
local Doc = require "core.doc"
local common = require "core.common"
local style  = require "core.style"
local config  = require "core.config"
local View = require "core.view"

local draw_line_gutter = DocView.draw_line_gutter
local on_mouse_moved = DocView.on_mouse_moved
local on_mouse_pressed = DocView.on_mouse_pressed

-- General debugger framework.
local debugger = {}
style.debugger_breakpoint = { common.color "#ca3434" }
style.debugger_execution_point = { common.color "#3434ca" }

-- Config variables.
debugger.step_refresh_watches = true
debugger.interval = 0.1
debugger.drawer_size = 100

-- Internals.
debugger.breakpoints = { }
debugger.execution_point = nil
debugger.backends = { }
debugger.drawer_visible = false
debugger.state = nil
debugger.output = function(line)
  core.log(line)
end
debugger.active_debugger = nil
setmetatable(debugger, { 
  __index = function(self, key)
    local active = rawget(debugger, "active_debugger")
    local loc = rawget(debugger, key)
    if loc or not active then
      return loc
    end
    local val = active[key]
    if type(val) == "function" then
      return function(...)
        return val(active, ...)
      end
    end
    return val
  end
})

function debugger.run(path)
  for k,v in pairs(debugger.backends) do
    if v.should_engage(path) then
      debugger.active_debugger = v
      v:run(path)
      break
    end
  end
end

function debugger.toggle_drawer(show)
  if show == nil then
    show = not debugger.drawer_visible
  end
  debugger.drawer_visible = show
end

function debugger.has_breakpoint(file, line)
  return debugger.breakpoints[file] and debugger.breakpoints[file][line] ~= nil
end

function debugger.add_breakpoint(file, line)
  debugger.breakpoints[file] = debugger.breakpoints[file] or { }
  debugger.breakpoints[file][line] = true
  if debugger.active_debugger then
    debugger.active_debugger:add_breakpoint(file, line)
  end
end

function debugger.remove_breakpoint(file, line)
  if debugger.active_debugger then
    debugger.active_debugger:remove_breakpoint(file, line)
  end
  if debugger.breakpoints[file] ~= nil then
    debugger.breakpoints[file][line] = nil
  end
end

function debugger.toggle_breakpoint(file, line)
  if debugger.has_breakpoint(file, line) then
    debugger.remove_breakpoint(file, line)
  else
    debugger.add_breakpoint(file, line)
  end
end

local function jump_to_file(file, line)
  if not core.active_view or not core.active_view.doc or core.active_view.doc.abs_filename ~= file then
    -- Check to see if the file is in the project. If it is, open it, and go to the line.
    for i = 1, #core.project_directories do
      if common.path_belongs_to(file, core.project_dir) then
        local view = core.root_view:open_doc(core.open_doc(file))
        if line then
          view:scroll_to_line(math.max(1, line - 20), true)
          view.doc:set_selection(line, 1, line, 1)
        end
        break
      end
    end
  end
end

function debugger.set_execution_point(file, line)
  if file then
    debugger.execution_point = { file, line }
    debugger.output("Setting execution point to " .. file .. (line and (":" .. line) or ""))
    jump_to_file(file, line)
  else
    debugger.execution_point = nil
  end
end

function debugger.set_state(state, transition, hint)
  if state ~= debugger.state then
    debugger.output("Setting debugger state to " .. state)
    if transition == nil or transition then
      if state == "running" then
        debugger.set_execution_point(nil)
        debugger.toggle_drawer(false)
      elseif state == "stopped" then
        if debugger.step_refresh_watches then
          debugger.watch_result_view:refresh()
        end
        if debugger.stack_view.stack and hint and hint.frame and 
          #debugger.stack_view.stack > 0 and debugger.stack_view.stack[1][1] and
          hint.frame[1] == debugger.stack_view.stack[1][1] and 
          hint.frame[2] == debugger.stack_view.stack[1][3]
        then
          debugger.stack_view.stack[1][4] = hint.frame[3]
          debugger.set_execution_point(hint.frame[2], hint.frame[3])
        else
          debugger.stack_view:refresh(function(backtrace) 
            debugger.set_execution_point(backtrace[1][3], backtrace[1][4])
          end)
        end
        debugger.toggle_drawer(true)
      end
    elseif state == "done" then
      debugger.stack_view.set_stack({ })
      debugger.watch_result_view.refresh()
      debugger.toggle_drawer(false)
    end
    debugger.state = state
  end
end

--------------------------- UI Elements
function DocView:on_mouse_moved(x, y, ...)
  on_mouse_moved(self, x, y, ...)
  local minline, maxline = self:get_visible_line_range()
  local _, docy = self:get_line_screen_position(minline)
  if x > self.position.x and x < self.position.x + self:get_gutter_width() then
    self.cursor = "arrow"
  end
end
function DocView:on_mouse_pressed(button, x, y, clicks)
  on_mouse_pressed(self, button, x, y, clicks)
  local minline, maxline = self:get_visible_line_range()
  local _, docy = self:get_line_screen_position(minline)
  if self.doc and x > self.position.x and x < self.position.x + self:get_gutter_width() and y > docy then
    debugger.toggle_breakpoint(self.doc.abs_filename, minline + math.floor((y - docy) / self:get_line_height()))
  end
end
function DocView:draw_line_gutter(idx, x, y, width)
   if debugger.has_breakpoint(self.doc.abs_filename, idx) then
     renderer.draw_rect(x, y, self:get_gutter_width(), self:get_line_height(), style.debugger_breakpoint)
   end
   if debugger.execution_point and debugger.execution_point[1] == self.doc.abs_filename and idx == debugger.execution_point[2] then
     renderer.draw_rect(x, y+1, self:get_gutter_width(), self:get_line_height()-2, style.debugger_execution_point)
   end
  draw_line_gutter(self, idx, x, y, width)
end

local DebuggerWatchResultView = View:extend()
function DebuggerWatchResultView:new()
  DebuggerWatchResultView.super.new(self)
  self.results = { }
  self.target_size = debugger.drawer_size
  self.init_size = true
end
function DebuggerWatchResultView:update()
  local dest = debugger.drawer_visible and self.target_size or 0
  if self.init_size then
    self.size.y = dest
    self.init_size = false
  else
    self:move_towards(self.size, "y", dest)
  end
  DebuggerWatchResultView.super.update(self)
end
function DebuggerWatchResultView:set_target_size(axis, value)
  if axis == "y" then
    self.target_size = value
    return true
  end
end
function DebuggerWatchResultView:get_item_height() return style.font:get_height() end
function DebuggerWatchResultView:get_scrollable_size() return 0 end
function DebuggerWatchResultView:draw()
  self:draw_background(style.background2)
  local h = style.code_font:get_height()
  local ox, oy = self:get_content_offset()
  common.draw_text(style.font, style.text, "Watch Values", "left", ox + style.padding.x, oy, self.size.x, h)
  for i,v in ipairs(self.results) do
    local yoffset = i * style.font:get_height()
    common.draw_text(style.code_font, style.text, v, "left", ox + style.padding.x, oy + yoffset, 0, h)
  end
end
function DebuggerWatchResultView:refresh(idx)
  if debugger.active_debugger and debugger.is_running() then
    local lines = debugger.watch_variable_view.doc.lines
    local total_lines = lines[1]:find("%S") and #lines or 0
    if idx then
      self.results[idx] = ""
    else
      self.results[total_lines+1] = nil
    end
    for i = 1, #lines do
      if lines[i]:find("%S") and not idx or idx == i then
        debugger.print(lines[i], function(result)
          self.results[i] = result
        end)
      end
    end
  else
    self.results = { }
  end
end


local DebuggerWatchVariableDoc = Doc:extend()
function DebuggerWatchVariableDoc:new()
  DebuggerWatchVariableDoc.super.new(self)
end
function DebuggerWatchVariableDoc:text_input(text)
  if self:has_selection() then
    self:delete_to()
  end
  local newline = text:find("\n")
  if newline then
    local line, col = self:get_selection()
    
    if #text == 1 and col == 1 and #self.lines[line] == 1 then
      if #debugger.watch_result_view.results >= line then
        table.remove(debugger.watch_result_view.results, line)
      end
      if #self.lines > line then
        self:raw_remove(line, 1, line+1, 1, self.undo_stack, system.get_time())
      end
    else
      self:insert(line, col, text:sub(1, newline))
      self:move_to(newline-1)
      debugger.watch_result_view:refresh(line)
    end
    core.set_active_view(core.root_view)
  else
    local line, col = self:get_selection()
    self:insert(line, col, text)
    self:move_to(#text)
  end
end
function DebuggerWatchVariableDoc:delete_to(...)
  local line, col = self:get_selection(true)
  if self:has_selection() then
    self:remove(self:get_selection())
  elseif col > 1 then
    local line2, col2 = self:position_offset(line, col, ...)
    self:remove(line, col, line2, col2)
    line, col = sort_positions(line, col, line2, col2)
  end
  self:set_selection(line, col)
end
function DebuggerWatchVariableDoc:remove(line1, col1, line2, col2)
  if line1 == line2 then
    DebuggerWatchVariableDoc.super.remove(self, line1, col1, line2, col2)
  end
end
function DebuggerWatchVariableDoc:set_selection(line1, col1, line2, col2, swap)
  assert(not line2 == not col2, "expected 2 or 4 arguments")
  if swap then line1, col1, line2, col2 = line2, col2, line1, col1 end
  line1, col1 = self:sanitize_position(line1, col1)
  line2, col2 = self:sanitize_position(line2 or line1, col2 or col1)
  if line2 ~= line1 then
    line2 = line1
    col2 = #self.lines[line1] - 1
  end
  self.selection.a.line, self.selection.a.col = line1, col1
  self.selection.b.line, self.selection.b.col = line2, col2
end
local DebuggerWatchVariableView = DocView:extend()
function DebuggerWatchVariableView:new()
  DebuggerWatchVariableView.super.new(self, DebuggerWatchVariableDoc(self))
  self.target_size = debugger.drawer_size
  self.init_size = true
end
function DebuggerWatchVariableView:set_target_size(axis, value)
  if axis == "y" then
    self.target_size = value
    return true
  end
end
function DebuggerWatchVariableView:try_close(do_close) end
function DebuggerWatchVariableView:get_scrollable_size() return 0 end
function DebuggerWatchVariableView:get_gutter_width() return 0 end
function DebuggerWatchVariableView:draw_line_gutter(idx, x, y) end

--  common.draw_text(style.code_font, style.text, "Watch Values", "left", ox + style.padding.x, oy, self.size.x, h)
function DebuggerWatchVariableView:get_content_offset(...)
  local x, y = DebuggerWatchVariableView.super.get_content_offset(self, ...)
  return x, y + self:get_line_height()
end
function DebuggerWatchVariableView:get_line_screen_position(idx)
  local x, y = self:get_content_offset()
  return x + self:get_gutter_width() + style.padding.x, y + (idx-1)
end
function DebuggerWatchVariableView:draw_line_body(idx, x, y)
  DebuggerWatchVariableView.super.draw_line_body(self, idx, x, y)
  if idx == 1 then
    renderer.draw_rect(x - self:get_gutter_width() - style.padding.x, y, self.size.x, 1, style.divider)  
  end
  renderer.draw_rect(x - self:get_gutter_width() - style.padding.x, y + self:get_line_height(), self.size.x, 1, style.divider)
end
function DebuggerWatchVariableView:draw()
  DebuggerWatchVariableView.super.draw(self)
  local ox, oy = self:get_content_offset()
  common.draw_text(style.font, style.text, "Watch Expressions", "left", ox + style.padding.x, oy - self:get_line_height(), self.size.x, self:get_line_height())
end
function DebuggerWatchVariableView:draw_background(color)
  DebuggerWatchVariableView.super.draw_background(self, style.background3)
end


local DebuggerStackView = View:extend()
function DebuggerStackView:new()
  DebuggerStackView.super.new(self)
  self.stack = { }
  self.target_size = debugger.drawer_size
  self.scrollable = true
  self.init_size = true
  self.hovered_frame = nil
  self.active_frame = nil
end
function DebuggerStackView:update()
  local dest = debugger.drawer_visible and self.target_size or 0
  if self.init_size then
    self.size.y = dest
    self.init_size = false
  else
    self:move_towards(self.size, "y", dest)
  end
  DebuggerStackView.super.update(self)
end
function DebuggerStackView:set_target_size(axis, value)
  if axis == "y" then
    self.target_size = value
    return true
  end
end
function DebuggerStackView:set_stack(stack)
  self.stack = stack
  self.hovered_frame = nil
  self.active_frame = 1
  core.redraw = true
end
function DebuggerStackView:get_item_height()
  return style.code_font:get_height() + style.padding.y*2
end
function DebuggerStackView:get_scrollable_size()
  return #self.stack and self:get_item_height() * (#self.stack + 1)
end
function DebuggerStackView:on_mouse_moved(px, py, ...)
  DebuggerStackView.super.on_mouse_moved(self, px, py, ...)
  if self.dragging_scrollbar then return end
  local ox, oy = self:get_content_offset()
  local offset = math.floor((py - oy) / self:get_item_height())
  self.hovered_frame = offset >= 1 and offset <= #self.stack and offset
end
function DebuggerStackView:on_mouse_pressed(button, x, y, clicks)
  local caught = DebuggerStackView.super.on_mouse_pressed(self, button, x, y, clicks)
  if caught then
    return
  end
  if self.hovered_frame then
    if clicks >= 2 then
      debugger.frame(self.hovered_frame - 1)
      self.active_frame = self.hovered_frame
      debugger.set_execution_point(self.stack[self.hovered_frame][3], self.stack[self.hovered_frame][4])
    end
    jump_to_file(self.stack[self.hovered_frame][3], self.stack[self.hovered_frame][4])
  end
end
function DebuggerStackView:draw()
  self:draw_background(style.background3)
  local h = style.code_font:get_height()
  local item_height = self:get_item_height()
  local ox, oy = self:get_content_offset()
  common.draw_text(style.font, style.text, "Stack Trace", "left", ox + style.padding.x, oy, 0, h)
  for i,v in ipairs(self.stack) do
    local yoffset = style.padding.y + (i - 1)*item_height + style.padding.y + h
    if self.hovered_frame == i or self.active_frame == i then
      renderer.draw_rect(ox, oy + yoffset - style.padding.y, self.size.x, h + style.padding.y*2, style.line_highlight)
    end
    common.draw_text(style.code_font, style.text, "#" .. i .. " " .. v[1] .. " " .. v[2] .. " " .. v[3] .. (v[4] and (" line " .. v[4]) or ""), "left", ox + style.padding.x, oy + yoffset, 0, h)
  end
  self:draw_scrollbar()
end
function DebuggerStackView:refresh(on_finish)
  debugger.backtrace(function(stack)
    self:set_stack(stack)
    if on_finish then
      on_finish(stack)
    end
  end)
end

debugger.stack_view = DebuggerStackView()
debugger.watch_variable_view = DebuggerWatchVariableView()
debugger.watch_result_view = DebuggerWatchResultView()
local node = core.root_view:get_active_node()
local stack_view_node = node:split("down", debugger.stack_view, { y = true }, true)
local watch_variable_view_node = stack_view_node:split("right", debugger.watch_variable_view, { y = true }, true)
local watch_result_view_node = watch_variable_view_node:split("right", debugger.watch_result_view, { y = true }, true)

------------------------------------- GDB
local function gdb_parse_string(str) 
  local offset = 0
  while offset ~= nil do
    offset = str:find('"', offset+1)
    if offset and str:sub(offset - 1, offset - 1) ~= "\\" then
      return str:sub(1, offset - 1):gsub("\\\"", "\""), offset + 1
    end
  end
end

local gdb_parse_status_attributes
local gdb_parse_status_array

local function gdb_parse_status_value(value)
  if value:sub(1, 1) == "{" then
    return gdb_parse_status_attributes(value:sub(2))
  elseif value:sub(1,1) == "[" then
    return gdb_parse_status_array(value:sub(2))
  elseif value:sub(1,1) == "\"" then
    return gdb_parse_string(value:sub(2))
  end
  return nil
end

gdb_parse_status_array = function(values)
  local array = { }
  local offset = 1
  if values:sub(offset, offset) == "]" then
    return array
  end
  while true do
    local value, length = gdb_parse_status_value(values:sub(offset))
    table.insert(array, value)
    offset = offset + length
    if values:sub(offset, offset) == "," then
      offset = offset + 1
    elseif values:sub(offset, offset) == "]" then
      return array, offset+1
    end
  end
end


gdb_parse_status_attributes = function(attributes)
  local obj = { }
  local offset = 1
  while true do
    local equal_idx = attributes:find("=", offset)
    local attr_name = attributes:sub(offset, equal_idx-1)
    local attr_value, length = gdb_parse_status_value(attributes:sub(equal_idx+1))
    if not length then
      return obj, offset + 1
    end
    obj[attr_name] = attr_value
    offset = length + equal_idx + 1
    if attributes:sub(offset, offset) == "," then
      offset = offset + 1
    else
      return obj, offset+1
    end
  end
  return offset
end

local function gdb_parse_status_line(line)
  local idx = line:find(",")
  local type = line:sub(1, 1)
  if idx and type == "*" or type == "=" then
    return type, line:sub(2, idx - 1), gdb_parse_status_attributes(line:sub(idx+1))
  elseif type == "~" then
    return type, gdb_parse_string(line:sub(3))
  elseif type == "^" then
    local quote = line:find('"')
    if idx and (not quote or idx < quote) then
      return type, line:sub(2, idx - 1), gdb_parse_status_attributes(line:sub(idx+1))
    else
      return type, line:sub(2)
    end
  else
    return type
  end
end

debugger.backends.gdb = { 
  running_program = nil,
  command_queue = { },
  breakpoints = { }
}
function debugger.backends.gdb:should_engage(path)
  return true
end
function debugger.backends.gdb:cmd(command, on_finish)
  debugger.output("Running GDB command " .. command .. ".")
  table.insert(self.command_queue, { command, on_finish })
end
function debugger.backends.gdb:step_into()  self:cmd("step") end
function debugger.backends.gdb:step_over()  self:cmd("next") end
function debugger.backends.gdb:step_out()   self:cmd("finish") end
function debugger.backends.gdb:continue()   self:cmd("cont") end
function debugger.backends.gdb:halt()       self.running_program:interrupt() end
function debugger.backends.gdb:is_running() return self.running_program ~= nil end
function debugger.backends.gdb:frame(idx)   self:cmd("f " .. idx) end
function debugger.backends.gdb:print(expr, on_finish) 
  self:cmd("p " .. expr, function(t, category, result)
    if result and type(result) == "table" then
      local equals = result[1] and result[1]:find("=")
      if equals then
        on_finish(result[1]:sub(equals+1))
      else
        on_finish(result[1])
      end
    else
        on_finish(result)    
    end
  end)
end
function debugger.backends.gdb:backtrace(on_finish)
  self:cmd("backtrace", function(type, category, frames)
    local stack = { }
    for i,v in ipairs(frames) do
      local str = string.gsub(v, "[%xx]+ in ", "")
      local s,e = str:find(" at ")
      if not s then
        s,e = str:find(" from ")
      end
      if s then
        local _, _, n, func, args = string.find(str:sub(1, s-1), "#(%d+)%s+(%S+) (.+)")
        local _, _, file, line = string.find(str:sub(e + 1), "([^:]+):?(%d*)")
        table.insert(stack, { func, args, file:gsub("\\n", ""), line and tonumber(line) })
      end
    end
    on_finish(stack)
  end)
end
function debugger.backends.gdb:terminate()
  self:cmd("quit")
  debugger.toggle_drawer(false)
  debugger.set_execution_point(nil)
end
function debugger.backends.gdb:add_breakpoint(file, line)
  if self.running_program then
    self:cmd("b " .. file .. ":" .. line, function(type, category, attributes)
      if attributes["bkpt"] then
        if not self.breakpoints[file] then
          self.breakpoints[file] = { }
        end
        self.breakpoints[file][line] = tonumber(attributes["bkpt"]["number"])
      end
    end)
  end
end

function debugger.backends.gdb:remove_breakpoint(file, line)
  if self.running_program and self.breakpoints[file] and type(self.breakpoints[file][line]) == "number" then
    self:cmd("d " .. self.breakpoints[file][line])
  end
end


function debugger.backends.gdb:run(program)
  debugger.output("Running GDB on " .. program .. ".")
  debugger.toggle_drawer(false)
  debugger.set_state("init")
  core.add_thread(function()
    self.running_program = process.start({ "gdb", "-q", "-nx", "--interpreter=mi", "--args", program })
    local result, accumulator, resume_on_command_completion = "", {}, false
    local waiting_on_result = function(type, category, attributes)
      self:cmd("set filename-display absolute")
      self:cmd("start")
      for file, v in pairs(debugger.breakpoints) do
        for line, v in pairs(debugger.breakpoints[file]) do
          self:add_breakpoint(file, line)
        end
      end
    end
    local saved_result = ""
    while result ~= nil do
      result = self.running_program:read_stdout()
      if result ~= nil and #result > 0 then
        saved_result = saved_result .. result
        while #saved_result > 0 do
          local newline = saved_result:find("\n")
          if not newline then break end
          local type, category, attributes = gdb_parse_status_line(saved_result:sub(1, newline-1))
          saved_result = saved_result:sub(newline + 1)
          if type == "*" then
            if category == "stopped" then
              if attributes.reason == "exited-normally" then
                self:terminate()
              elseif attributes.frame and attributes.bkptno == "1" then
                resume_on_command_completion = true
                debugger.set_state("stopped", false)
              elseif attributes.reason == "end-stepping-range" and attributes.frame and attributes.frame.file and attributes.frame.line then
                debugger.set_state("stopped", true, { frame = {
                  attributes.frame.func,
                  attributes.frame.file,
                  tonumber(attributes.frame.line)
                } })
              else
                if not resume_on_command_completion then
                  debugger.set_state("stopped")
                  accumulator = {}
                else
                  debugger.state = "stopped"
                end
              end
            elseif category == "running" then
              debugger.set_state("running")
            end
          elseif type == "^" then
            if (category == "done" or category == "error") and waiting_on_result then
              waiting_on_result(type, category, category == "error" and attributes["msg"] or accumulator)
            end
            waiting_on_result = nil
            accumulator = {}
          elseif type == "~" then
            table.insert(accumulator, category)
          elseif type == "=" and waiting_on_result then
            waiting_on_result(type, category, attributes)
            waiting_on_result = nil
          end
        end
      end
      if not waiting_on_result and #self.command_queue > 0 then
        if debugger.state == "running" then
          self:halt()
          resume_on_command_completion = true
          debugger.set_state("indeterminate")
        else
          if self.running_program:write(self.command_queue[1][1] .. "\n") then
            if self.command_queue[1][2] then
              waiting_on_result = self.command_queue[1][2]
            end
            table.remove(self.command_queue, 1)
          end
        end
      end
      if not waiting_on_result and debugger.state == "stopped" and #self.command_queue == 0 and resume_on_command_completion then
        self:continue()
        resume_on_command_completion = false
      end
      coroutine.yield(debugger.interval)
    end
    debugger.output("Finished running " .. program .. ".")
    self.running_program = nil
    debugger.set_state("done")
  end)
end

command.add(nil, {
  ["debugger:step-over"] = function() debugger.step_over() end,
  ["debugger:step-into"] = function() debugger.step_into() end,
  ["debugger:step-out"] = function() debugger.step_out() end,
  ["debugger:break"] = function() debugger.halt() end,
  ["debugger:quit"] = function()  debugger.terminate() end,
  ["debugger:toggle-drawer"] = function() debugger.toggle_drawer() end,
  ["debugger:toggle-breakpoint"] = function()
    if core.active_view and core.active_view.doc then
      local line1, col1, line2, col2, swap = core.active_view.doc:get_selection(true)
      if line1 then
        debugger.toggle_breakpoint(core.active_view.doc.abs_filename, line1);
      end
    end
  end,
  ["debugger:start-or-continue"] = function()
    if debugger.active_debugger and debugger.is_running() then    
      debugger.continue()
    elseif config.target_binary then
      debugger.run(config.target_binary)
    else
      core.command_view:enter("Program to Debug", function(text)
        debugger.run(text)
      end)
    end
  end
})

keymap.add { 
  ["f7"]                 = "debugger:step-over",
  ["shift+f7"]           = "debugger:step-into",
  ["ctrl+f7"]            = "debugger:step-out",
  ["f8"]                 = "debugger:start-or-continue", 
  ["ctrl+f8"]            = "debugger:break", 
  ["shift+f8"]           = "debugger:quit",
  ["f9"]                 = "debugger:toggle-breakpoint",
  ["f12"]                = "debugger:toggle-drawer"
}

return debugger
