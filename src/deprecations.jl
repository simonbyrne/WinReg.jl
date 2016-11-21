
const HKEY_CLASSES_ROOT = 0x80000000
const HKEY_CURRENT_CONFIG = 0x80000005
const HKEY_CURRENT_USER = 0x80000001
const HKEY_LOCAL_MACHINE = 0x80000002
const HKEY_USERS = 0x80000003
const HKEY_PERFORMANCE_DATA = 0x80000004
const HKEY_PERFORMANCE_TEXT = 0x80000050
const HKEY_PERFORMANCE_NLSTEXT = 0x80000060
const HKEY_DYN_DATA = 0x80000006


function querykey(base::UInt32, path::AbstractString, valuename::AbstractString)
	local b = ""
    if base == HKEY_CLASSES_ROOT
		b = "HKEY_CLASSES_ROOT"
	elseif base == HKEY_CURRENT_CONFIG
		b = "HKEY_CURRENT_CONFIG"
	elseif base == HKEY_CURRENT_USER
		b = "HKEY_CURRENT_USER"
	elseif base == HKEY_LOCAL_MACHINE
		b = "HKEY_LOCAL_MACHINE"
	elseif base == HKEY_USERS
		b = "HKEY_USERS"
	elseif base == HKEY_PERFORMANCE_DATA
		b = "HKEY_PERFORMANCE_DATA"
	elseif base == HKEY_PERFORMANCE_TEXT
		b = "HKEY_PERFORMANCE_TEXT"
	elseif base == HKEY_PERFORMANCE_NLSTEXT
		b = "HKEY_PERFORMANCE_NLSTEXT"
	elseif base == HKEY_DYN_DATA
		b = "HKEY_DYN_DATA"
	end
	
	local key = b * "\\" * path
	
	return regread(key, valuename)
end

@deprecate querykey regread
