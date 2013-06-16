local path   = (...):match('^.+[%.\\/]') or ''
local output = require(path..'output')
local input  = require(path..'input')
local display= require(path..'display')

local class = class
if common and common.class then
	class = function(n)
		return common.class(name,{})
	end
end

local shell = class 'Shell'

function shell:init(input,output,display)
	self.prompt           = self.prompt or '>'
	self.input            = input or self.input
	self.output           = output or self.output
	self.display          = display or self.display
	self.cursor_bg_color  = {255,255,255}
	self.cursor_char_color= {0,0,0}
	self.redraw_all       = true
	self._previous_chunk  = nil
	self._env             = setmetatable(
		{print = function(...) shell.print(self,...) end,},
		{__index = _G,__newindex = _G})
	
	-- setup input callback
	function self.input.onFlush(input,str)
		if self.onFlush then self:onFlush(str) end
	end
	
	function self.input.onKeypressed(key,unicode)
		self.redraw_all = true
	end
end

function shell:onFlush(str)
	self.output:write(self.prompt..str)
	local func,err
	if self._previous_chunk then
		self._previous_chunk = self._previous_chunk..str 

		local chunk= self._previous_chunk
		chunk      = chunk:gsub('^=','return '):gsub('^return%s+(.*)','print(%1)')
		func,err   = loadstring(chunk)
	else
		func,err = loadstring(str)
	end
	
	if func then
		setfenv(func,self._env)
		local ok,err = pcall(func)
		if err then self.output:write(err) end
		self.prompt          = '>'
		self._previous_chunk = nil
	elseif str == '' then
		self.output:write(err)
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
	local str = table.concat(list,(' '):rep(4))
	self.output:write(str)
end

function shell:keypressed(key,unicode)
	self.input:keypressed(key,unicode)
end

function shell:update(dt)
	self.input:update(dt)
	if not self.redraw_all then return else self.redraw_all = false end
	local input,output,display = self.input,self.output,self.display
	
	local w,h       = display:getSize()
	local input_str = (self.prompt or '')..table.concat(input.chars)
	local cursor_pos= input.cursor_pos + #self.prompt
	
	if cursor_pos > #input_str then input_str = input_str..' ' end
	
	local curr_row   = h
	local input_rows = math.max(math.ceil(#input_str/w),1)
	while input_rows > h do
		input_str        = input_str:sub(w+1)
		local input_rows = math.max(math.ceil(#input_str/w),1)
	end
	curr_row = curr_row+1-input_rows
	
	display:clear()
	display:write(input_str,1,curr_row)
	
	local row_offset = math.ceil(cursor_pos/display.chars_width)-1
	local col_pos    = cursor_pos - row_offset*display.chars_width
	local row_pos    = curr_row+row_offset
	
	if row_pos > 0 and row_pos <= h then
		local char,tc,bc = display:getCell(col_pos,row_pos)
		display:write(char, col_pos,row_pos, nil, self.cursor_char_color, self.cursor_bg_color)
	end
	
	output:resize(w)
	for index,line in output:iterate(true) do
		curr_row   = curr_row-1
		if curr_row > 0 then display:write(line,1,curr_row) end
	end
end

function shell:draw(x,y)
	self.display:draw(x,y)
end

return shell