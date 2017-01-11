#-----------------------------------------------------------
#-----------------------------------------------------------
# Define function to access windows registry
#----------------------------------------------------------
#----------------------------------------------------------

__precompile__(true)
module WinReg


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
