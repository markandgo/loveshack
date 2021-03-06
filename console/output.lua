if not (common and common.class and common.instance) then
	class_commons = true
	local path    = (...):match('^.+[%.\\/]') or ''
	require(path..'class')
end
local path = (...):match('^.+[%.\\/]') or ''
require(path..'utf8')

local string_lines = function(self)
	local index = 1
	local len   = #self
	return function()
		if index > len then return end
		local i,j,line = self:find( '([^\r\n]*)\r?\n?', index )
		index = j+1
		return line
	end
end

local output = common.class( 'Output', {} )

function output:init(chars_width,max_lines)
	self.lines       = {}
	self.max_lines   = max_lines or 100
	self.chars_width = chars_width or math.huge
end

function output:resize(chars_width)
	chars_width = chars_width or self.chars_width
	if chars_width == self.chars_width then return end
	self.lines      = {}
	local str_cache = {}
	for index,line in ipairs(self.lines) do
		local nextline = self.lines[index+1]
		if nextline and nextline.wrapped or line.wrapped then
			table.insert(str_cache,line)
		else
			if next(str_cache) then
				local str = table.concat(str_cache)
				str_cache = {} 
				output.write(self,str)
			end
			output.write(self,line)
		end
	end
end

function output:onWrite(str)
	
end

function output:write(str)
	for line in string_lines(str) do
		local count = 1
		for newline in line:utf8gensub(self.chars_width) do
			if count == 2 then newline = {str = newline,wrapped = true} end
			table.insert(self.lines,newline)
			count = count + 1
		end
	end
	
	-- hack for empty string
	if str == '' then table.insert(self.lines,str) end
	
	local lines = #self.lines
	while lines > self.max_lines do
		lines = lines - 1
		table.remove(self.lines,1)
	end
	
	if self.onWrite then self:onWrite(str) end
end

function output:iterate(reverseOrder)
	local lines     = self.lines
	local next_index= reverseOrder and #lines or 1
	local delta     = reverseOrder and -1 or 1
	return function()
		local index = next_index
		local line  = lines[index]
		if not line then return end
		next_index  = next_index + delta
		line        = line and line.str or line
		return index,line,line and line.wrapped
	end
end

return function(...) return common.instance(output,...) end