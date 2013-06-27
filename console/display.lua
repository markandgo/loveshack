-- #####################################
-- PRIVATE
-- #####################################
local lg       = love.graphics
local path     = (...):match('^.+[%.\\/]') or ''
local fontpath = path:gsub('%.','/')..'/DejaVuSansMono.ttf'

require(path..'utf8')

local monoFont = lg.newFont(fontpath,12)

local DEFAULT_TAB_SIZE = 4

if not (common and common.class and common.instance) then
	class_commons = true
	require(path..'class')
end

local has_canvas_support = lg.isSupported 'canvas'

local default_text_color = {255,255,255,255}
local default_bg_color   = {64,64,64,192}

local color_cache = setmetatable({},{__mode = 'v'})

local drawChars = function(self,x,y)
	local old_font = lg.getFont()
	lg.setFont(self.font)
	local font_width = self.font_width
	local font_height = self.font_height
	x,y = x or 0,y or 0
	
	for col = 1,self.chars_width do
		local t = self.chars_matrix[col]
		local ox = (col-1)*font_width
		for row = 1,self.chars_height do
			local data = t and t[row]
			local char,text_color,bg_color
			if data then
				char       = data.char
				text_color = data.text_color
				bg_color   = data.bg_color
			end
			local oy = (row-1)*font_height
			lg.setColor(bg_color or self.bg_color)
			lg.rectangle('fill',x+ox,y+oy,font_width,font_height)
			if char then
				lg.setColor(text_color or self.text_color)
				lg.print(char,x,y,nil,nil,nil,-ox,-oy)
			end
		end
	end
	
	lg.setColor(255,255,255,255)
	if old_font then lg.setFont(old_font) end
end

local redrawChars = function(self)
	local old_font = lg.getFont()
	lg.setFont(self.font)
	lg.setCanvas(self.canvas)
	local sx,sy,sw,sh = lg.getScissor()
	
		local fw,fh = self.font_width,self.font_height
	
		for data in pairs(self.redraw_list) do
			local col,row = data.x,data.y
			
			local text_color = data.text_color
			local bg_color   = data.bg_color
			
			local x,y = (col-1)*fw, (row-1)*fh
			
			-- have to set canvas before scissor else weird offset
			lg.setScissor(x,y,fw,fh)
			self.canvas:clear()
			lg.setColor(bg_color or self.bg_color)
			lg.rectangle('fill',x,y,fw,fh)
			lg.setScissor()
			
			if data.char then
				lg.setColor(text_color or self.text_color)
				lg.print(data.char,x,y)
			end
			self.redraw_list[data] = nil
		end
		
	lg.setCanvas()
	if old_font then lg.setFont(old_font) end
	if sx then lg.setScissor(sx,sy,sw,sh) end
	lg.setColor(255,255,255,255)
end

local assertBounds = function(x,y,cw,ch)
	if not (x > 0 and y > 0) then error 'Bounds must be greater than zero!' end
	if not (x <= cw and y <= ch) then error 'Bounds must be less than or equal to width/height!' end
end

local getColor = function(rgba)
	local r,g,b,a = rgba[1],rgba[2],rgba[3],rgba[4] or 255
	if not (r and g and b) then error 'Missing rgb value(s)!' end
	local color_index = r..','..g..','..b..','..a
	local color = color_cache[color_index]
	if not color then color = {r,g,b,a}; color_cache[color_index] = color end
	return color
end

local copyColor = function(rgba,t)
	if t then
		for i = 1,4 do
			t[i] = rgba[i] or 255
		end
		return
	end
	return {rgba[1] or 255,rgba[2] or 255,rgba[3] or 255,rgba[4] or 255}
end

local writeDataAddRedraw = function(self, curr_x,curr_y, data, char,text_color,bg_color)
	data.char       = char 
	data.text_color = text_color and getColor(text_color) or nil
	data.bg_color   = bg_color and getColor(bg_color) or nil
	data.x,data.y   = curr_x,curr_y
	
	if self.canvas then self.redraw_list[data] = data end
end

-- #####################################
-- CLASS
-- #####################################

local display = common.class( 'Display', {} )

function display:init(chars_width,chars_height, font, text_color,bg_color)
	assert(chars_width > 0 and chars_height > 0, 'Display must have width & height greater than 0!')
	
	local t = self
	t.chars_height= chars_height
	t.chars_width = chars_width
	t.font        = font or monoFont
	t.text_color  = copyColor(text_color or default_text_color)
	t.bg_color    = copyColor(bg_color or default_bg_color)
	t.chars_matrix= {}
	t.font_width  = t.font:getWidth 'a'
	t.font_height = t.font:getHeight()
	t.canvas      = nil
	t.redraw_list = {}
	t.redraw_all  = true
	t.tab_size    = DEFAULT_TAB_SIZE
end

-- #####################################
-- GETTERS
-- #####################################

function display:getCell(x,y)
	local data = self.chars_matrix[x] and self.chars_matrix[x][y]
	if data then 
		return data.char,
			data.text_color or self.text_color,
			data.bg_color or self.bg_color
	end
	return nil,self.text_color,self.bg_color
end

function display:getSize()
	return self.chars_width,self.chars_height
end

function display:getTabSize()
	return self.tab_size
end

function display:getFont()
	return self.font,self.font_width,self.font_height
end

function display:getDefaultColors()
	return self.text_color,self.bg_color
end

function display:iterate(x,y,x2,y2)
	local cw  = self.chars_width
	local ch  = self.chars_height
	x,y       = x or 1,y or 1
	x2,y2     = x2 or cw,y2 or ch
	
	assertBounds(x,y,cw,ch)
	assertBounds(x2,y2,cw,ch)
	
	local xi,yi  = x-1,y
	return function(self,_)
		while true do
			xi = xi+1
			if xi > x2 then yi = yi + 1; xi = x end
			if yi > y2 then return end
			
			return xi,yi,display.getCell(self,xi,yi)
		end
	end,self,nil
end

-- #####################################
-- SETTERS
-- #####################################

function display:setSize(width,height)
	self.chars_width,self.chars_height = width,height
	self.canvas = nil
end

function display:setFont(font)
	self.font = font 
	self.font_height = font:getHeight()
	self.font_width  = font:getWidth 'a'
	self.canvas = nil
end

function display:setDefaultColors(text_color,bg_color)
	copyColor(text_color or default_text_color, self.text_color)
	copyColor(bg_color or default_bg_color, self.bg_color)
	self.redraw_all = true
end

function display:setTabSize(tab_size)
	self.tab_size = tab_size or DEFAULT_TAB_SIZE
end

-- #####################################
-- MAIN
-- #####################################
function display:write(str,x,y, reverse, text_color,bg_color)
	x,y = x or 1,y or 1
	
	assertBounds(x,y,self.chars_width,self.chars_height)
	local curr_x,curr_y= x,y
	local len          = str and str:utf8len() or 1
	local curr_index   = 1
	
	if reverse and str then
		local offset = (y-1)*self.chars_width + x - len
		if offset < 0 then curr_index = curr_index - offset end
		local start   = offset < 0 and 1 or offset+1
		curr_x,curr_y = 0,1
		local remain  = start
		while true do
			remain = remain - self.chars_width
			if remain < 1 then 
				curr_x = remain + self.chars_width 
				break
			end
			curr_y = curr_y + 1
		end
	end
	
	local matrix = self.chars_matrix
	local getChar= str and str:utf8gensub()
	
	while curr_index < len+1 do
		local char = str and getChar()
		
		if char == '\t' then 
			curr_x = curr_x + self.tab_size - 1
			if curr_x > self.chars_width then
				curr_x = 1; curr_y = curr_y + 1
			end
		elseif char == '\n' then
			curr_x = 0
			curr_y = curr_y + 1
		else
			matrix[curr_x] = matrix[curr_x] or {}
			
			local data = matrix[curr_x][curr_y]
			if not data then data = {}; matrix[curr_x][curr_y] = data end
			
			writeDataAddRedraw(self, curr_x,curr_y, data, char,text_color,bg_color)
		end
		
		curr_x = curr_x+1
		if curr_x > self.chars_width then 
			curr_y = curr_y+1; curr_x = 1 
		end
		if curr_y > self.chars_height then break end
		curr_index = curr_index + 1
	end	
end

function display:clear(range, char,text_color,bg_color)
	local cw  = self.chars_width
	local ch  = self.chars_height
	
	local x,y,x2,y2
	if not range then x,y,x2,y2 = 1,1,cw,ch
	else x,y,x2,y2 = range[1],range[2],range[3],range[4] end
	
	assertBounds(x,y,cw,ch)
	assertBounds(x2,y2,cw,ch)
	
	if x == 1 and y == 1 and x2 == cw and y2 == ch then
		bg_color   = bg_color or self.bg_color
		text_color = text_color or self.text_color
		local font = display.getFont(self)
		
		local canvas = self.canvas
		display.init(self,cw,ch, font,text_color,bg_color)
		self.canvas  = canvas
		
		if not char then return end
	end
	
	local matrix = self.chars_matrix
	
	for x = x,x2 do
		matrix[x] = matrix[x] or {}
		for y = y,y2 do
			local data = matrix[x][y]
			
			if not data then data = {}; matrix[x][y] = data end
			writeDataAddRedraw(self, x,y, data, char,text_color,bg_color)
		end
	end
end

function display:draw(x,y)
	local r,g,b,a  = lg.getColor()
	lg.setColor(255,255,255,255)
	local old_blend = lg.getBlendMode()
	lg.setBlendMode 'alpha'
	local old_canvas = lg.getCanvas()
	
	if has_canvas_support then
		self.canvas =  self.canvas or lg.newCanvas(self.font_width*self.chars_width, 
						   self.font_height*self.chars_height)
		if self.redraw_all then
			self.canvas:clear()
			love.graphics.setCanvas(self.canvas)
				drawChars(self)
			love.graphics.setCanvas()
			self.redraw_list = {}
			self.redraw_all  = false
		elseif next(self.redraw_list) then
			redrawChars(self)
		end
		lg.setBlendMode 'premultiplied'
		lg.draw(self.canvas,x,y)
	else
		drawChars(self,x,y)
	end
	
	lg.setColor(r,g,b,a)
	lg.setBlendMode(old_blend)
	if old_canvas then lg.setCanvas(old_canvas) end	
end

return function(...) return common.instance(display,...) end