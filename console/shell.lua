local path   = (...):match('^.+[%.\\/]') or ''
local output = require(path..'output')
local input  = require(path..'input')
local display= require(path..'display')
require(path..'utf8')

if not (common and common.class and common.instance) then
	class_commons = true
	require(path..'class')
end

local shell = common.class( 'Shell', {} )

function shell:init(input,output,display)
	self.prompt           = self.prompt or '>'
	self.input            = input or self.input
	self.output           = output or self.output
	self.display          = display or self.display
	self.cursor_bg_color  = {255,255,255}
	self.cursor_char_color= {0,0,0}
	self.scroll_oy        = 0
	self.redraw_all       = true
	self._previous_chunk  = nil
	self._env             = setmetatable(
		{print = function(...) shell.print(self,...) end,},
		{__index = _G,__newindex = _G})
	
	function self.output.onWrite(output,str)
		self.redraw_all = true
	end
	
	-- setup input callback
	function self.input.onFlush(input,str)
		if self.onFlush then self:onFlush(str) end
	end
	
	function self.input.onKeypressed(input,key,unicode)
		if key == 'pageup' then
			self.scroll_oy = math.min( self.scroll_oy + self.display.chars_height,
				self.output.max_lines-self.display.chars_height)
			self.scroll_oy = math.max(0,self.scroll_oy)
		elseif key == 'pagedown' then 
			self.scroll_oy = math.max(self.scroll_oy - self.display.chars_height,0)
		else 
			self.scroll_oy = 0 
		end	
		self.redraw_all = true
	end
	
	self.output:write 'Welcome to the Love Shack. Type --help to see available commands'
end

function shell:onFlush(str)
	self.output:write(self.prompt..str)
	
	if str:match '^%s*%-%-help' then
		self.output:write 
[[Press up or down to see previous commands.
Press pageup or pagedown to scroll.]]
		return
	end
	
	local func,err
	local chunk = str
	if self._previous_chunk then
		self._previous_chunk = self._previous_chunk..str 
		chunk = self._previous_chunk
	end
	
	chunk      = chunk:gsub('^=','return '):gsub('^return%s+(.*)','print(%1)')
	func,err   = loadstring(chunk)
	
	if func then
		setfenv(func,self._env)
		local ok,err = pcall(func)
		if err then self.output:write(err) end
		self.prompt          = '>'
		self._previous_chunk = nil
	elseif str == '' then
		local ok = pcall(self.output.write,self.output,err)
		if not ok then self.output:write 'Unexpected symbol found for variable name.' end
		self.prompt          = '>'
		self._previous_chunk = nil
	elseif self._previous_chunk then
		return
	else
		self._previous_chunk = str
		self.prompt          = '>>'
	end
end

function shell:print(...)
	local count = select('#',...)
	local list  = {...}
	for i = 1,count do
		list[i] = tostring(list[i])
	end
	local str = table.concat(list,'\t')
	self.output:write(str)
end

function shell:keypressed(key,unicode)
	self.input:keypressed(key,unicode)
end

function shell:update(dt)
	self.input:update(dt)
	if not self.redraw_all then return else self.redraw_all = false end
	local input,output,display = self.input,self.output,self.display
	
	display:clear()
		-- display input
		
		local w,h          = display:getSize()
		local input_str    = (self.prompt or '')..table.concat(input.chars)
		local input_len    = input_str:utf8len()
		local prompt_len   = self.prompt:utf8len()
		
		local cursor_pos   = input.cursor_pos + prompt_len
		if cursor_pos > input_len then input_str = input_str..' '; input_len = input_len + 1 end
		
		local input_height = math.ceil(input_len/w)
		local output_height= #output.lines
		local input_ypos   = h - input_height+1 + self.scroll_oy
		
		-- get the visible string onscreen
		local input_y1  = math.max(1, math.min(input_ypos,h) )
		local input_y2  = math.max(1, math.min(input_ypos-1+input_height,h) )
		local sub_i     = (input_y1-input_ypos)*w+1
		local sub_j     = (input_y2-input_ypos+1)*w
		
		local sub_string= input_str:utf8sub(sub_i,sub_j)
	
	display:write(sub_string,1,input_y1)
	
	local cursor_oy = math.ceil(cursor_pos/w)-1
	local cursor_y  = input_ypos+cursor_oy
	
	-- display cursor
	if cursor_y > 0 and cursor_y <= h then
		local cursor_x = cursor_pos-(cursor_oy*w)
		local char     = display:getCell(cursor_x,cursor_y)
		display:write(char, cursor_x,cursor_y, nil, self.cursor_char_color, self.cursor_bg_color)
	end
	
	-- display output
	output:resize(w)
	local curr_row = input_ypos
	for index,line in output:iterate(true) do
		curr_row   = curr_row-1
		if curr_row > 0 and curr_row <= h then display:write(line,1,curr_row) end
	end
end

function shell:draw(x,y)
	self.display:draw(x,y)
end

return function(...) return common.instance(shell,...) end