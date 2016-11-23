#-----------------------------------------------------------
#-----------------------------------------------------------
# Define function to access windows registry
#----------------------------------------------------------
#----------------------------------------------------------

__precompile__(true)
module WinReg

#Julia 0.4.x compatibility
if VERSION < v"0.5.0"
	include_string("is_windows() = (@windows ? true : false)")
end

if is_windows()
	include("wintypes.jl")
	include("commons.jl")
	
	include("regfunc.jl")
	export regread,
	       regwrite,
	       regcreatekey,
	       regdelete,
	       regkeylist,
	       regvaluelist
	
	include("deprecations.jl")
	export querykey
end #windows_only

end # module
