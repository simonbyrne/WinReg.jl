#-----------------------------------------------------------
#-----------------------------------------------------------
# Define function to access windows registry
# -- part of WinReg Module --
#----------------------------------------------------------
#----------------------------------------------------------


"""
    regread(key::AbstractString, valuename::AbstractString)

Read a value with `valuename` into `key`. 
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').
Return type in Julia is based onto value type stored in registry; returns `nothing` (type is `Void`) if key not found"""
function regread(key::AbstractString, valuename::AbstractString)
	root = getroothkey(key)
	if root == 0
		return nothing
	end
	subkey = getsubkey(key)
	hk::HKEY = 0
	len = Ref{DWORD}(0)
	typ = Ref{DWORD}(0)
	
	buf = nothing
	try
		hk = regopenkeyex(root, subkey, REG_SAM.KEY_READ)
		#get buffer dim
		res = ccall((:RegQueryValueExW, advapi), stdcall,
		  LONG,
		  (HKEY, Cwstring, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
		  hk, valuename, C_NULL, typ, C_NULL, len )
		if res == ERROR_SUCCESS
			buf = Vector{UInt8}(len[])
			len = Ref{DWORD}(length(buf))
			
			res = ccall((:RegQueryValueExW, advapi), stdcall,
			  LONG,
			  (HKEY, Cwstring, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
			  hk, valuename, C_NULL, typ, pointer(buf), len )
			
			regclosekey(hk)
			
			if res != ERROR_SUCCESS
				return nothing
			end
		else
			regclosekey(hk)
			
			error("error getting value length")
		end
	finally
		regclosekey(hk)
	end
	if hk == 0
		return nothing
	end
	
	if typ[] == REG_TYPE.REG_SZ || typ[] == REG_TYPE.REG_EXPAND_SZ || typ[] == REG_TYPE.REG_LINK
		wbuf = reinterpret(Cwchar_t, buf)
		l = len[]
		if buf[l] == 0 && buf[l-1] == 0
			return transcode(String, wbuf[1:div(l-2,2)])
		else
			return transcode(String, wbuf[1:div(l,2)])
		end
	elseif typ[] == REG_TYPE.REG_MULTI_SZ
		wbuf = reinterpret(Cwchar_t, buf)
		l = len[]
		if buf[l] == 0 && buf[l-1] == 0
			s = transcode(String, wbuf[1:div(l-2,2)])
		else
			s = transcode(String, wbuf[1:div(l,2)])
		end
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

"""
    regdelete(key::AbstractString, view64::Bool = false)

Delete specified `key`. 
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
`view64` specifies if key is 64 or 32 bit view (default); see https://msdn.microsoft.com/en-us/library/aa384129.aspx   
Cannot delete key with subkeys.  
If operation has success is returned `true`, `false` otherwise"""
function regdelete(key::AbstractString, view64::Bool = false)
	root = getroothkey(key)
	if root == 0
		return false
	end
	skey = split(getsubkey(key), '\\')
	subkey = join(skey[1:(end-1)], "\\")
	delkey = String(skey[end])
	
	hk = regopenkeyex(root, subkey, REG_SAM.KEY_WRITE)
	if hk == 0
		return false
	else
		res = ccall((:RegDeleteKeyExW, advapi), stdcall,
		  LONG,
		  (HKEY, Cwstring, REGSAM, DWORD),
		  hk, delkey, (view64 ? REG_SAM.KEY_WOW64_64KEY : REG_SAM.KEY_WOW64_32KEY), 0 )
		
		regclosekey(hk)
		
		return (res == ERROR_SUCCESS)
	end
end

"""
    regdelete(key::AbstractString, valuename::AbstractString)

Delete specified `valuename` under specified `key`.  
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
If operation has success is returned `true`, `false` otherwise"""
function regdelete(key::AbstractString, valuename::AbstractString)
	root = getroothkey(key)
	if root == 0
		return false
	end
	subkey = getsubkey(key)
	
	hk = regopenkeyex(root, subkey, REG_SAM.KEY_WRITE)
	if hk == 0
		return false
	else
		res = ccall((:RegDeleteValueW, advapi), stdcall,
		  LONG,
		  (HKEY, Cwstring),
		  hk, valuename )
		
		regclosekey(hk)
		
		return (res == ERROR_SUCCESS)
	end
end


function preparedata(value::AbstractString)
	typ = REG_TYPE.REG_SZ
	data = string2wchar(value)
	
	return typ, data
end

function preparedata(value::Vector{String})
	typ = REG_TYPE.REG_MULTI_SZ
	len = 0
	for idx in 1:length(value)
		len += length(value[idx])
	end
	data = Vector{UInt8}(len*2+length(value)*2+2)
	pos = 1
	for idx in 1:length(value)
		dt = string2wchar(value[idx])
		copy!(data, pos, dt, 1, length(dt))
		pos += length(dt)
	end
	data[end] = 0
	
	return typ, data
end

function preparedata(value::Int32)
	typ = REG_TYPE.REG_DWORD
	buf = IOBuffer()
	write(buf, htol(value))
	data = buf.data
	
	return typ, data
end

function preparedata(value::UInt32)
	return preparedata(Int32(value))
end

function preparedata(value::Int64)
	typ = REG_TYPE.REG_DWORD
	buf = IOBuffer()
	write(buf, htol(value))
	data = buf.data
	
	return typ, data
end

function preparedata(value::UInt64)
	return preparedata(Int64(value))
end

function preparedata(value::Vector{UInt8})
	typ = REG_TYPE.REG_BINARY
	data = value
	
	return typ, data
end

"""
    regwrite(key::AbstractString, valuename::AbstractString, value::Any)

Write `value` to `valuename` under specified `key`.  
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
Return `true` if successful, `false` otherwise"""
function regwrite(key::AbstractString, valuename::AbstractString, value::Any)
	root = getroothkey(key)
	if root == 0
		return false
	end
	subkey = getsubkey(key)
	typ, data = preparedata(value)
	
	hk = regopenkeyex(root, subkey, REG_SAM.KEY_WRITE)
	if hk == 0
		return false
	end
	res = ccall((:RegSetKeyValueW, advapi), stdcall,
	  LONG,
	  (HKEY, LPCWSTR, Cwstring, DWORD, LPBYTE, DWORD ),
	  hk, C_NULL, valuename, typ, pointer(data), length(data) )
	
	return (res == ERROR_SUCCESS)
end

"""
    regcreatekey(key::AbstractString)

Recursively create specified key. 
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
Return 0 if key is existent, 1 if successful, -1 otherwise"""
function regcreatekey(key::AbstractString)
	root = getroothkey(key)
	if root == 0
		return -1
	end
	subkey = getsubkey(key)
	
	creating = false
	hk::HKEY = 0
	#check existent key
	regpath = split(subkey, '\\')
	lastexistent = 0
	idx = 0
	for idx in 1:length(regpath)
		currsubkey = join(regpath[1:idx], "\\")
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
	newhk = Ref{HKEY}(0)
	for i in (lastexistent+1):length(regpath)
		currsubkey = join(regpath[1:(i-1)], "\\")
		hk = regopenkeyex(root, currsubkey, REG_SAM.KEY_WRITE)
		if hk == 0
			return -1
		end
		subreg = String(regpath[i])
		res = ccall((:RegCreateKeyExW, advapi), stdcall,
		  LONG,
		  (HKEY, Cwstring, DWORD, LPCWSTR, DWORD, REGSAM, LPSECURITY_ATTRIBUTES, PHKEY, LPDWORD),
		  hk, subreg, 0, C_NULL, REG_OPTION.NON_VOLATILE, REG_SAM.KEY_WRITE, C_NULL, newhk, C_NULL )
		if res != ERROR_SUCCESS
			regclosekey(hk)
			return -1
		end
		regclosekey(newhk[])
		regclosekey(hk)
	end
	
	return 1
end

"""
    regkeylist(key::AbstractString)

Return all subkeys of specified `key` as string array. 
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
If operation fails is returned `nothing` (type is `Void`)"""
function regkeylist(key::AbstractString)
	root = getroothkey(key)
	if root == 0
		return nothing
	end
	subkey = getsubkey(key)
	hk::HKEY = 0
	
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
			for idx = 1:numSubKeys[]
				len = Ref{DWORD}(length(buf))
				ccall((:RegEnumKeyExW, advapi), stdcall,
				  LONG,
				  (HKEY, DWORD, LPCWSTR, LPDWORD, LPDWORD, LPCWSTR, LPDWORD, PFILETIME ),
				  hk, idx-1, pointer(buf), len, C_NULL, C_NULL, C_NULL, C_NULL )
				if res != ERROR_SUCCESS
					regclosekey(hk)
					return nothing
				end
				
				wbuf = reinterpret(Cwchar_t, buf)
				keys[idx] = transcode(String, wbuf[1:len[]])
			end
		end
	end
	
	regclosekey(hk)
	
	return keys
end

"""
    regvaluelist(key::AbstractString)

Return all value names of specified `key` as tuple array (name, Julia-type).  
`key` can be specified using abbreviated form (e.g. 'HKEY_LOCAL_MACHINE' -> 'HKLM').  
Return array of tuple (<valuename>, <vlauetype>); otherwise `nothing` is returned (type is `Void`)"""
function regvaluelist(key::AbstractString)
	root = getroothkey(key)
	if root == 0
		return nothing
	end
	subkey = getsubkey(key)
	hk::HKEY = 0
	
	hk = regopenkeyex(root, subkey, REG_SAM.KEY_READ)
	if hk == 0
		return nothing
	else
		numValNames = Ref{DWORD}(0)
		maxValName = Ref{DWORD}(0)
		
		res = ccall((:RegQueryInfoKeyW, advapi), stdcall,
		  LONG,
		  (HKEY, LPCSTR, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, LPDWORD, PFILETIME),
		  hk, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, numValNames, maxValName, C_NULL, C_NULL, C_NULL )
		
		if res != ERROR_SUCCESS
			regclosekey(hk)
			return nothing
		else
			valnames = Vector{Tuple{AbstractString, DataType}}(numValNames[])
			buf = Vector{UInt8}((maxValName[] + 1) * 2) #2-byte Unicode characters + 0-termination
			typ = Ref{DWORD}(0)
			idx::DWORD = 0
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
				
				wbuf = reinterpret(Cwchar_t, buf)
				entry = ( transcode(String, wbuf[1:len[]]) , gettype(typ[]) )
				valnames[idx+1] = entry
			end
		end
	end
	
	regclosekey(hk)
	
	return valnames
end
