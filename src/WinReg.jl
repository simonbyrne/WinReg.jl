module WinReg


# https://learn.microsoft.com/en-us/windows/win32/api/winreg/


export querykey


include("constants.jl")


"""
    RegKey <: AbstractDict{String,Any}

A Windows registry key. The name is slightly misleading, in that it is actually
a Dict-like object which maps "values" (keys) to "data" (values).
"""
mutable struct RegKey <: AbstractDict{String,Any}
    handle::HKEY
end
RegKey() = RegKey(zero(HKEY))

Base.cconvert(::Type{HKEY}, key::RegKey) = key
Base.unsafe_convert(::Type{HKEY}, key::RegKey) = key.handle
Base.unsafe_convert(::Type{PHKEY}, key::RegKey) = convert(Ptr{HKEY}, pointer_from_objref(key))


# pre-defined keys
const HKEY_CLASSES_ROOT     = RegKey(0x8000_0000)
const HKEY_CURRENT_USER     = RegKey(0x8000_0001)
const HKEY_LOCAL_MACHINE    = RegKey(0x8000_0002)
const HKEY_USERS            = RegKey(0x8000_0003)
const HKEY_PERFORMANCE_DATA = RegKey(0x8000_0004)
const HKEY_CURRENT_CONFIG   = RegKey(0x8000_0005)
const HKEY_DYN_DATA         = RegKey(0x8000_0006)


function Base.close(key::RegKey)
    if key.handle != zero(HKEY)
        # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regclosekey
        ret = ccall((:RegCloseKey, "advapi32"),
                    stdcall, LSTATUS,
                    (HKEY,),
                    key)
        ret != ERROR_SUCCESS && error("Could not close key $ret")
        key.handle = zero(HKEY)
    end
    return nothing
end

function openkey(base::RegKey, path::AbstractString, accessmask::UInt32=KEY_READ)
    # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regopenkeyexw
    key = RegKey()
    ret = ccall((:RegOpenKeyExW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, LPCWSTR, DWORD, REGSAM, PHKEY),
                base, path, 0, accessmask, key)
    ret != ERROR_SUCCESS && error("Could not open registry key")
    finalizer(close, key)
    return key
end



struct SubKeyIterator
    key::RegKey
end

Base.IteratorSize(::Type{SubKeyIterator}) = Base.SizeUnknown()
Base.IteratorEltype(::Type{SubKeyIterator}) = Base.HasEltype()
Base.eltype(::Type{SubKeyIterator}) = String


"""
    subkeys(key::RegKey)

An iterator over the subkeys of `key`.
"""
subkeys(key::RegKey) = SubKeyIterator(key)

function Base.iterate(iter::SubKeyIterator, idx=0)
    buf = Array{UInt16}(undef, MAX_KEY_LENGTH)
    # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regenumkeyw
    ret = ccall((:RegEnumKeyW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, DWORD, Ptr{UInt16}, DWORD),
                iter.key, idx, buf, MAX_KEY_LENGTH)
    if ret == ERROR_NO_MORE_ITEMS
        return nothing
    end
    ret != ERROR_SUCCESS && error("Could not access registry key, $ret")
    n = findfirst(==(0),buf)
    str = transcode(String, buf[1:n-1])
    return str, idx+1
end

function extract_data(dwDataType::DWORD, data::Vector{UInt8})
    if dwDataType == REG_SZ || dwDataType == REG_EXPAND_SZ
        data_wstr = reinterpret(Cwchar_t,data)
        # string may or may not be null-terminated
        # need to copy, until https://github.com/JuliaLang/julia/pull/27810 is fixed
        if data_wstr[end] == 0
            data_wstr2 = data_wstr[1:end-1]
        else
            data_wstr2 = data_wstr[1:end]
        end        
        return transcode(String, data_wstr2)
    elseif dwDataType == REG_DWORD
        return reinterpret(DWORD, data)[]
    elseif dwDataType == REG_QWORD
        return reinterpret(QWORD, data)[]
    else
        return data
    end
end


function Base.iterate(key::RegKey, idx=0)
    name_buf = Array{UInt16}(undef, MAX_VALUE_LENGTH + 1)
    nchars = Ref{DWORD}(length(name_buf))
    dwSize = Ref{DWORD}(0)
    dwDataType = Ref{DWORD}(0)
    # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regenumvaluew
    ret = ccall((:RegEnumValueW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, DWORD, Ptr{UInt16}, LPDWORD, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
                key, idx, name_buf, nchars, C_NULL, C_NULL, C_NULL, dwSize)
    if ret == ERROR_NO_MORE_ITEMS
        return nothing
    end
    ret != ERROR_SUCCESS && error("Could not access registry key, $ret")

    nchars[] = length(name_buf) # reset
    data_buf = Array{UInt8}(undef,dwSize[])
    ret = ccall((:RegEnumValueW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, DWORD, Ptr{UInt16}, LPDWORD, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
                key, idx, name_buf, nchars, C_NULL, dwDataType, data_buf, dwSize)
    ret != ERROR_SUCCESS && error("Could not access registry key, $ret")
    
    n = nchars[]
    name = transcode(String, name_buf[1:n])
    data = extract_data(dwDataType[], data_buf)
    return (name => data), idx+1
end


function Base.getindex(key::RegKey, valuename::AbstractString)
    # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regqueryvalueexw
    dwSize = Ref{DWORD}()
    dwDataType = Ref{DWORD}()

    ret = ccall((:RegQueryValueExW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
                key, valuename, C_NULL, dwDataType, C_NULL, dwSize)
    ret == ERROR_FILE_NOT_FOUND && throw(KeyError(valuename))
    ret != ERROR_SUCCESS && error("Could not find registry value name")

    data_buf = Array{UInt8}(undef,dwSize[])
    ret = ccall((:RegQueryValueExW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
                key, valuename, C_NULL, C_NULL, data_buf, dwSize)
    ret != ERROR_SUCCESS && error("Could not retrieve registry data")

    return extract_data(dwDataType[], data_buf)
end



# for compatibility


function querykey(base::RegKey, path::AbstractString, valuename::AbstractString)
    key = openkey(base, path)
    try
        return key[valuename]
    finally
        close(key)
    end
end



end # module
