#-----------------------------------------------------------
#-----------------------------------------------------------
# Define function to access windows registry
# -- part of WinReg Module --
#
#File: regutils.jl
#Author: Leonardo Cocco
#Creation Date: 11-04-2016
#Last update 21-11-2016
#ver: 0.11
#----------------------------------------------------------
#----------------------------------------------------------


"""Read a value with `valuename` into `key`. 
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').
Return type in Julia is based onto value type stored in registry; returns `nothing` (type is `Void`) if key not found"""
function regread(key::AbstractString, valuename::AbstractString)
	local root = getroothkey(key)
	if root == 0
		return nothing
	end
	local subkey = getsubkey(key)
	local hk::HKEY = 0
	local len = Ref{DWORD}(0)
	local typ = Ref{DWORD}(0)
	
	hk = regopenkeyex(root, subkey, REG_SAM.KEY_READ)
	if hk != 0
		#get buffer dim
		local res = ccall((:RegQueryValueExW, advapi), stdcall,
		  LONG,
		  (HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
		  hk, transcode(Cwchar_t, valuename), C_NULL, typ, C_NULL, len )
		if res == ERROR_SUCCESS
			buf = Vector{UInt8}(len[])
			len = Ref{DWORD}(length(buf))
			
			res = ccall((:RegQueryValueExW, advapi), stdcall,
			  LONG,
			  (HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
			  hk, transcode(Cwchar_t, valuename), C_NULL, typ, pointer(buf), len )
			
			regclosekey(hk)
			
			if res != ERROR_SUCCESS
				return nothing
			end
		else
			regclosekey(hk)
			
			return nothing
		end
	else
		return nothing
	end
	
	if typ[] == REG_TYPE.REG_SZ || typ[] == REG_TYPE.REG_EXPAND_SZ || typ[] == REG_TYPE.REG_LINK
		local wbuf = reinterpret(Cwchar_t, buf)
		return transcode(String, wbuf[1:div((len[]-2),2)])
	elseif typ[] == REG_TYPE.REG_MULTI_SZ
		wbuf = reinterpret(Cwchar_t, buf)
		s = transcode(String, wbuf[1:div((len[]-2),2)])
		v = split(s, '\0')
		return v[1:(end-1)]
	elseif typ[] == REG_TYPE.REG_DWORD_LITTLE_ENDIAN
		return ltoh(reinterpret(DWORD, buf[1:len[]])[1])
	elseif typ[] == REG_TYPE.REG_DWORD_BIG_ENDIAN
		return ntoh(reinterpret(DWORD, buf[1:len[]])[1])
	elseif typ[] == REG_TYPE.REG_QWORD
		return ltoh(reinterpret(QWORD, buf[1:len[]])[1])
	elseif typ[] == REG_TYPE.REG_BINARY
		return buf[1:len[]]
	else
		return nothing
	end
end

"""Delete specified `key`. 
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
`view64` specifies if key is 64 or 32 bit view (default); see https://msdn.microsoft.com/en-us/library/aa384129.aspx   
Cannot delete key with subkeys.  
If operation has success is returned `true`, `false` otherwise"""
function regdelete(key::AbstractString, view64::Bool = false)
	local root = getroothkey(key)
	if root == 0
		return false
	end
	local skey = split(getsubkey(key), '\\')
	local subkey = join(skey[1:(end-1)], "\\")
	local delkey = String(skey[end])
	
	local hk = regopenkeyex(root, subkey, REG_SAM.KEY_WRITE)
	if hk == 0
		return false
	else
		local res = ccall((:RegDeleteKeyExW, advapi), stdcall,
		  LONG,
		  (HKEY, LPCWSTR, REGSAM, DWORD),
		  hk, transcode(Cwchar_t ,delkey), (view64 ? REG_SAM.KEY_WOW64_64KEY : REG_SAM.KEY_WOW64_32KEY), 0 )
		
		regclosekey(hk)
		
		return (res == ERROR_SUCCESS)
	end
end

"""Delete specified `valuename` under specified `key`.  
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
If operation has success is returned `true`, `false` otherwise"""
function regdelete(key::AbstractString, valuename::AbstractString)
	local root = getroothkey(key)
	if root == 0
		return false
	end
	local subkey = getsubkey(key)
	
	local hk = regopenkeyex(root, subkey, REG_SAM.KEY_WRITE)
	if hk == 0
		return false
	else
		local res = ccall((:RegDeleteValueW, advapi), stdcall,
		  LONG,
		  (HKEY, LPCWSTR),
		  hk, transcode(Cwchar_t, valuename) )
		
		regclosekey(hk)
		
		return (res == ERROR_SUCCESS)
	end
end

"""Write `value` to `valuename` under specified `key`.  
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
Return `true` if successful, `false` otherwise"""
function regwrite(key::AbstractString, valuename::AbstractString, value::Any)
	local root = getroothkey(key)
	if root == 0
		return false
	end
	local subkey = getsubkey(key)
	
	local typ::DWORD = 0
	local data::Vector{UInt8} = Vector{UInt8}()
	if typeof(value) <: AbstractString
		typ = REG_TYPE.REG_SZ
		data = string2wchar(value)
	elseif typeof(value) <: Vector && eltype(value) <: AbstractString
		typ = REG_TYPE.REG_MULTI_SZ
		local len = 0
		for idx in 1:length(value)
			len += length(value[idx])
		end
		data = Vector{UInt8}(len*2+length(value)*2+2)
		local pos = 1
		for idx in 1:length(value)
			dt = string2wchar(value[idx])
			copy!(data, pos, dt, 1, length(dt))
			pos += length(dt)
		end
		data[end] = 0
	elseif typeof(value) <: UInt32 || typeof(value) <: Int32
		typ = REG_TYPE.REG_DWORD
		buf = IOBuffer()
		write(buf, htol(value))
		data = buf.data
	elseif typeof(value) <: UInt64 || typeof(value) <: Int64
		typ = REG_TYPE.REG_QWORD
		buf = IOBuffer()
		write(buf, htol(value))
		data = buf.data
	elseif typeof(value) <: Vector{UInt8}
		typ = REG_TYPE.REG_BINARY
		data = value
	else
		return false
	end
	
	local hk = regopenkeyex(root, subkey, REG_SAM.KEY_WRITE)
	if hk == 0
		return false
	end
	local res = ccall((:RegSetKeyValueW, advapi), stdcall,
	  LONG,
	  (HKEY, LPCWSTR, LPCWSTR, DWORD, LPBYTE, DWORD ),
	  hk, C_NULL, transcode(Cwchar_t, valuename), typ, pointer(data), length(data) )
	
	return (res == ERROR_SUCCESS)
end

"""Recursively create specified key. 
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
Return 0 if key is existent, 1 if successful, -1 otherwise"""
function regcreatekey(key::AbstractString)
	local root = getroothkey(key)
	if root == 0
		return -1
	end
	local subkey = getsubkey(key)
	
	local creating = false
	local hk::HKEY = 0
	#check existent key
	local regpath = split(subkey, '\\')
	local lastexistent = 0
	local idx = 0
	for idx in 1:length(regpath)
		local currsubkey = join(regpath[1:idx], "\\")
		hk = regopenkeyex(root, currsubkey, REG_SAM.KEY_READ)
		if hk == 0
			break
		else
			lastexistent = idx
			regclosekey(hk)
		end
	end
	if lastexistent == length(regpath)
		return 0
	end
	
	#create subkeys
	local newhk = Ref{HKEY}(0)
	for i in (lastexistent+1):length(regpath)
		currsubkey = join(regpath[1:(i-1)], "\\")
		hk = regopenkeyex(root, currsubkey, REG_SAM.KEY_WRITE)
		if hk == 0
			return -1
		end
		subreg = String(regpath[i])
		res = ccall((:RegCreateKeyExW, advapi), stdcall,
		  LONG,
		  (HKEY, LPCWSTR, DWORD, LPCWSTR, DWORD, REGSAM, LPSECURITY_ATTRIBUTES, PHKEY, LPDWORD),
		  hk, transcode(Cwchar_t, subreg), 0, C_NULL, REG_OPTION.NON_VOLATILE, REG_SAM.KEY_WRITE, C_NULL, newhk, C_NULL )
		if res != ERROR_SUCCESS
			regclosekey(hk)
			return -1
		end
		regclosekey(newhk[])
		regclosekey(hk)
	end
	
	return 1
end

"""Return all sukbeys of specified `key` as string array. 
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
If operation fails is returned `nothing` (type is `Void`)"""
function regkeylist(key::AbstractString)
	local root = getroothkey(key)
	if root == 0
		return nothing
	end
	local subkey = getsubkey(key)
	local hk::HKEY = 0
	
	hk = regopenkeyex(root, subkey, REG_SAM.KEY_READ)
	if hk == 0
		return nothing
	else
		numSubKeys = Ref{DWORD}(0)
		maxLongSubKey = Ref{DWORD}(0)
		
		res = ccall((:RegQueryInfoKeyW, advapi), stdcall,
		  LONG,
		  (HKEY, LPCSTR, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, PFILETIME),
		  hk, C_NULL, C_NULL, C_NULL, numSubKeys, maxLongSubKey, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL )
		
		if res != ERROR_SUCCESS
			regclosekey(hk)
			return nothing
		else
			keys = Vector{AbstractString}(numSubKeys[])
			buf = Vector{UInt8}((maxLongSubKey[] + 1) * 2) #2-byte Unicode characters + 0-termination
			idx::DWORD = 0
			for idx = 0:(numSubKeys[] - 1)
				len = Ref{DWORD}(length(buf))
				ccall((:RegEnumKeyExW, advapi), stdcall,
				  LONG,
				  (HKEY, DWORD, LPCWSTR, LPDWORD, LPDWORD, LPCWSTR, LPDWORD, PFILETIME ),
				  hk, idx, pointer(buf), len, C_NULL, C_NULL, C_NULL, C_NULL )
				if res != ERROR_SUCCESS
					regclosekey(hk)
					return nothing
				end
				
				local wbuf = reinterpret(Cwchar_t, buf)
				keys[idx+1] = transcode(String, wbuf[1:len[]])
			end
		end
	end
	
	regclosekey(hk)
	
	return keys
end

"""Return all value names of specified `key` as tuple array (name, Julia-type).  
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
Return array of tuple (<valuename>, <vlauetype>); otherwise `nothing` is returned (type is `Void`)"""
function regvaluelist(key::AbstractString)
	local root = getroothkey(key)
	if root == 0
		return nothing
	end
	local subkey = getsubkey(key)
	local hk::HKEY = 0
	
	hk = regopenkeyex(root, subkey, REG_SAM.KEY_READ)
	if hk == 0
		return nothing
	else
		local numValNames = Ref{DWORD}(0)
		local maxValName = Ref{DWORD}(0)
		
		local res = ccall((:RegQueryInfoKeyW, advapi), stdcall,
		  LONG,
		  (HKEY, LPCSTR, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, PFILETIME),
		  hk, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, numValNames, maxValName, C_NULL, C_NULL, C_NULL )
		
		if res != ERROR_SUCCESS
			regclosekey(hk)
			return nothing
		else
			local valnames = Vector{Tuple{AbstractString, DataType}}(numValNames[])
			local buf = Vector{UInt8}((maxValName[] + 1) * 2) #2-byte Unicode characters + 0-termination
			local typ = Ref{DWORD}(0)
			local idx::DWORD = 0
			for idx = 0:(numValNames[] - 1)
				len = Ref{DWORD}(length(buf))
				ccall((:RegEnumValueW, advapi), stdcall,
				  LONG,
				  (HKEY, DWORD, LPCWSTR, LPDWORD, LPDWORD, LPDWORD, LPBYTE, LPDWORD ),
				  hk, idx, pointer(buf), len, C_NULL, typ, C_NULL, C_NULL )
				if res != ERROR_SUCCESS
					regclosekey(hk)
					return nothing
				end
				
				local wbuf = reinterpret(Cwchar_t, buf)
				local entry = ( transcode(String, wbuf[1:len[]]) , gettype(typ[]) )
				valnames[idx+1] = entry
			end
		end
	end
	
	regclosekey(hk)
	
	return valnames
end
