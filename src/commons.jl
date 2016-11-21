#-----------------------------------------------------------
#-----------------------------------------------------------
# Define types and base functions to access windows registry
# -- part of WinReg Module --
#
#File: commons.jl
#Author: Leonardo Cocco
#Creation Date: 11-04-2016
#Last update 21-11-2016
#ver: 0.12
#----------------------------------------------------------
#----------------------------------------------------------


typealias HKEY UInt32 #DWORD also on 64-bit platforms
typealias PHKEY Ptr{HKEY}
typealias REGSAM UInt32 #-> ACCESS_MASK -> DWORD

const advapi = "advapi32.dll"

baremodule ROOT_HKEY
	const HKEY_CLASSES_ROOT = 0x80000000
	const HKEY_CURRENT_CONFIG = 0x80000005
	const HKEY_CURRENT_USER = 0x80000001
	const HKEY_LOCAL_MACHINE = 0x80000002
	const HKEY_USERS = 0x80000003
	const HKEY_PERFORMANCE_DATA = 0x80000004
	const HKEY_PERFORMANCE_TEXT = 0x80000050
	const HKEY_PERFORMANCE_NLSTEXT = 0x80000060
	const HKEY_CURRENT_CONFIG = 0x80000005
	const HKEY_DYN_DATA = 0x80000006
end

baremodule REG_TYPE
	const REG_NONE = 0x00
	const REG_SZ = 0x01
	const REG_EXPAND_SZ = 0x02
	const REG_BINARY = 0x03
	const REG_DWORD = 0x04
	const REG_DWORD_LITTLE_ENDIAN = 0x04
	const REG_DWORD_BIG_ENDIAN = 0x05
	const REG_LINK = 0x06
	const REG_MULTI_SZ = 0x07
	const REG_RESOURCE_LIST = 0x08
	const REG_FULL_RESOURCE_DESCRIPTOR = 0x09
	const REG_RESOURCE_REQUIREMENTS_LIST = 0x0a
	const REG_QWORD = 0x0b
	const REG_QWORD_LITTLE_ENDIAN = 0x0b
end

baremodule REG_SAM
	using Base #for bitwise OPs
	using ..SAM #for other SAM
	
	const KEY_QUERY_VALUE = 0x0001
	const KEY_SET_VALUE = 0x0002
	const KEY_CREATE_SUB_KEY = 0x0004
	const KEY_ENUMERATE_SUB_KEYS = 0x0008
	const KEY_NOTIFY = 0x0010
	const KEY_CREATE_LINK = 0x0020
	const KEY_WOW64_64KEY = 0x0100
	const KEY_WOW64_32KEY = 0x0200
	const KEY_WOW64_RES = 0x0300
	
	const KEY_READ = ((SAM.STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY) & (~SAM.SYNCHRONIZE))
	const KEY_WRITE = ((SAM.STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY) & (~SAM.SYNCHRONIZE))
	const KEY_EXECUTE = ((KEY_READ) & (~SAM.SYNCHRONIZE))
	const KEY_ALL_ACCESS = ((SAM.STANDARD_RIGHTS_ALL | KEY_QUERY_VALUE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY | KEY_CREATE_LINK) & (~SAM.SYNCHRONIZE))
	const REG_OPTION_RESERVED = 0x00000000
end

baremodule REG_OPTION
	const BACKUP_RESTORE = 0x00000004
	const CREATE_LINK = 0x00000002
	const NON_VOLATILE = 0x00000000
	const VOLATILE = 0x00000001
end

const REG_CREATED_NEW_KEY = 0x00000001
const REG_OPENED_EXISTING_KEY = 0x00000002

function getroothkey(key::AbstractString)
	local pos = search(key, '\\')
	if pos == 0
		return convert(HKEY, 0)
	else
		root_key = uppercase(key[1:(pos-1)])
	end
	
	if root_key == "HKEY_CLASSES_ROOT" || root_key == "HKCR"
		return ROOT_HKEY.HKEY_CLASSES_ROOT
	elseif root_key == "HKEY_CURRENT_CONFIG" || root_key == "HKCC"
		return ROOT_HKEY.HKEY_CURRENT_CONFIG
	elseif root_key == "HKEY_CURRENT_USER" || root_key == "HKCU"
		return ROOT_HKEY.HKEY_CURRENT_USER
	elseif root_key == "HKEY_LOCAL_MACHINE" || root_key == "HKLM"
		return ROOT_HKEY.HKEY_LOCAL_MACHINE
	elseif root_key == "HKEY_USERS" || root_key == "HKU"
		return ROOT_HKEY.HKEY_USERS
	elseif root_key == "HKEY_PERFORMANCE_DATA"
		return ROOT_HKEY.HKEY_PERFORMANCE_DATA
	elseif root_key == "HKEY_PERFORMANCE_TEXT"
		return ROOT_HKEY.HKEY_PERFORMANCE_TEXT
	elseif root_key == "HKEY_PERFORMANCE_NLSTEXT"
		return ROOT_HKEY.HKEY_PERFORMANCE_NLSTEXT
	elseif root_key == "HKEY_CURRENT_CONFIG" || root_key == "HKCG"
		return ROOT_HKEY.HKEY_CURRENT_CONFIG
	elseif root_key == "HKEY_DYN_DATA" || root_key == "HKDD"
		return ROOT_HKEY.HKEY_DYN_DATA
	else
		return convert(HKEY, 0)
	end
end

function getsubkey(key::AbstractString)
	local pos = search(key,'\\')
	if pos == 0
		return ""
	else
		return key[(pos+1):end]
	end
end

function gettype(typ::UInt32)
	if typ == REG_TYPE.REG_SZ || typ == REG_TYPE.REG_EXPAND_SZ || typ == REG_TYPE.REG_LINK
		return AbstractString
	elseif typ == REG_TYPE.REG_MULTI_SZ
		return Vector{AbstractString}
	elseif typ == REG_TYPE.REG_DWORD_LITTLE_ENDIAN || typ == REG_TYPE.REG_DWORD_BIG_ENDIAN
		return UInt32
	elseif typ == REG_TYPE.REG_QWORD
		return UInt64
	elseif typ == REG_TYPE.REG_BINARY
		return Vector{UInt8}
	else
		return 0
	end
end

function regopenkeyex(root::HKEY, subkey::AbstractString, sam::REGSAM)
	local hk = Ref{HKEY}(0)
	
	#UNICODE version; xxxExA is ASCII version, but LPCTRSTR = LPCSTR
	res = ccall((:RegOpenKeyExW, advapi), stdcall,
	  LONG,
	  (HKEY, LPCWSTR, DWORD, REGSAM, PHKEY),
	  root, transcode(Cwchar_t, subkey), 0, sam, hk )
	
	if res == ERROR_SUCCESS
		return hk[]
	else
		return 0
	end
end

function regclosekey(key::HKEY)
	if key == ROOT_HKEY.HKEY_CLASSES_ROOT ||
	  key == ROOT_HKEY.HKEY_CURRENT_CONFIG ||
	  key == ROOT_HKEY.HKEY_CURRENT_USER ||
	  key == ROOT_HKEY.HKEY_LOCAL_MACHINE ||
	  key == ROOT_HKEY.HKEY_USERS ||
	  key == ROOT_HKEY.HKEY_PERFORMANCE_DATA ||
	  key == ROOT_HKEY.HKEY_PERFORMANCE_TEXT ||
	  key == ROOT_HKEY.HKEY_PERFORMANCE_NLSTEXT ||
	  key == ROOT_HKEY.HKEY_CURRENT_CONFIG ||
	  key == ROOT_HKEY.HKEY_DYN_DATA
		return 0
	end
	
	ret = ccall((:RegCloseKey, advapi), stdcall,
	  LONG,
	  (HKEY, ),
	  key )
	
	return ret
end

function any2bytes(x)
	local sz = sizeof(x)
	local ba = Vector{UInt8}(sz)
	local src_ptr = convert(Ptr{UInt8}, pointer_from_objref(x))
	unsafe_copy!(pointer(ba), src_ptr, sz)
	
	return ba
end

#return byte-array with NULL-termination
function string2wchar(str::AbstractString)
	local buf = Vector{UInt8}(length(str)*2+2)
	for idx = 1:length(str)
		charbytes = any2bytes(convert(UInt16, str[idx]))
		buf[idx*2-1] = charbytes[1]
		buf[idx*2] = charbytes[2]
	end
	buf[end-1] = 0
	buf[end] = 0
	
	return buf
end
