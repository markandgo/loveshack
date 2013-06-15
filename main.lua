local console = require 'console'
local input   = console.input()
local output  = console.output(80)
local display = console.display(80,25)
local shell   = console.shell(input,output,display)

function love.keypressed(k,unicode)
	if k == 'escape' then love.event.push 'quit' end
	shell:keypressed(k,unicode)
end

function love.update(dt)
	shell:update(dt)
end

function love.draw()
	shell:draw()
	love.graphics.print(love.timer.getFPS(),750,0)
end