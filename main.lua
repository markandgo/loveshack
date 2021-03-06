local console = require 'console'
local input   = console.input()
local output  = console.output(114)
local display = console.display(114,43)
local shell   = console.shell(input,output,display)

function love.keypressed(k,unicode)
	if k == 'escape' then love.event.push 'quit' end
	if k == 'insert' then shell:keypressed(k,math.random(0x009f+1,254))
	else shell:keypressed(k,unicode) end
end

function love.update(dt)
	shell:update(dt)
end

function love.draw()
	shell:draw()
	love.graphics.print(love.timer.getFPS(),750,0)
end