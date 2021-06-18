-- mod-version:1 -- lite-xl 1.16
local config = require "core.config"
local style = require "core.style"
local DocView = require "core.docview"

local draw_caret = DocView.draw_caret
local draw = DocView.draw

local carets = { }

function DocView:draw_caret(x, y)
  carets[#carets+1] = x
  carets[#carets+1] = y
end

function DocView:draw(...)
  draw(self, ...)

  local ns = ("n"):rep(config.line_limit)
  local ss = self:get_font():subpixel_scale()
  local offset = self:get_font():get_width_subpixel(ns) / ss
  local x = self:get_line_screen_position(1) + offset
  local y = self.position.y
  local w = math.ceil(SCALE * 1)
  local h = self.size.y

  local color = style.guide or style.selection
  renderer.draw_rect(x, y, w, h, color)

  for i = 1, #carets / 2 do
    draw_caret(self, carets[i*2 - 1], carets[i*2])
  end

  carets = { }
end
