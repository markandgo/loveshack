local path = ...
require(path..'.class')
return {
	display = require(path..'.display'),
	input   = require(path..'.input'),
	output  = require(path..'.output'),
	shell   = require(path..'.shell'),
}