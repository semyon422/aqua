local ffi = require("ffi")

local fftw3 = ffi.os == "Windows" and ffi.load("libfftw3-3") or ffi.load("fftw3")

ffi.cdef[[
	typedef double fftw_complex[2];
	typedef struct fftw_plan_s *fftw_plan;
	extern void fftw_execute(const fftw_plan p);
	extern fftw_plan fftw_plan_dft_1d(int n, fftw_complex *in, fftw_complex *out, int sign, unsigned flags);
	extern void fftw_destroy_plan(fftw_plan p);
]]

---@class util.Fftw
---@operator call: util.Fftw
---@field buffer_in {[integer]: number}
---@field buffer_out {[integer]: number}
---@field plan any
local Fftw = {}
Fftw.__index = Fftw

function Fftw:execute()
	assert(not self.destroyed, "plan is destroyed")
	fftw3.fftw_execute(self.plan)
end

function Fftw:destroy()
	fftw3.fftw_destroy_plan(self.plan)
	self.destroyed = true
end

local fftw = {}

---@param size integer
---@param dir "forward"|"backward"
---@return util.Fftw
function fftw.new(size, dir)
	local f = {}

	f.buffer_in = ffi.new("complex[?]", size)
	f.buffer_out = ffi.new("complex[?]", size)

	local sign = dir == "forward" and -1 or 1

	---@type any
	f.plan = fftw3.fftw_plan_dft_1d(size, f.buffer_in, f.buffer_out, sign, 64)

	return setmetatable(f, Fftw)
end

return fftw
