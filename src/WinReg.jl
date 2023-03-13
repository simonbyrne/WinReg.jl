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


struct WinAPIError <: Exception
    code::LSTATUS
end



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
        status = ccall((:RegCloseKey, "advapi32"),
                    stdcall, LSTATUS,
                    (HKEY,),
                    key)
        status != ERROR_SUCCESS && throw(WinAPIError(status))
        key.handle = zero(HKEY)
    end
    return nothing
end

"""
    WinReg.openkey(basekey::RegKey, path::AbstractString, accessmask::UInt32=KEY_READ)

Open a registry key at `path` relative to `basekey`. `accessmask` is a bitfield.
"""
function openkey(base::RegKey, path::AbstractString, accessmask::UInt32=KEY_READ)
    # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regopenkeyexw
    key = RegKey()
    status = ccall((:RegOpenKeyExW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, LPCWSTR, DWORD, REGSAM, PHKEY),
                base, path, 0, accessmask, key)
    status != ERROR_SUCCESS && throw(WinAPIError(status))
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

An iterator over the names of the subkeys of `key`.
"""
subkeys(key::RegKey) = SubKeyIterator(key)

function Base.iterate(iter::SubKeyIterator, idx=0)
    buf = Array{UInt16}(undef, MAX_KEY_LENGTH)
    # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regenumkeyw
    status = ccall((:RegEnumKeyW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, DWORD, Ptr{UInt16}, DWORD),
                iter.key, idx, buf, MAX_KEY_LENGTH)
    if status == ERROR_NO_MORE_ITEMS
        return nothing
    end
    status != ERROR_SUCCESS && throw(WinAPIError(status))
    n = findfirst(==(0), buf)
    resize!(buf, n-1)
    str = transcode(String, buf)
    return str, idx+1
end

"""
    WinReg.extract_data(dwDataType::DWORD, data_buf::Vector{UInt8})

Convert the data in `data_buf` to the appropriate type, based on the data type
`dwDataType`.
"""
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
    if iszero(key.handle)
        return nothing
    end
    name_buf = Array{UInt16}(undef, MAX_VALUE_LENGTH + 1)
    nchars = Ref{DWORD}(length(name_buf))
    dwSize = Ref{DWORD}(0)
    dwDataType = Ref{DWORD}(0)
    # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regenumvaluew
    status = ccall((:RegEnumValueW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, DWORD, Ptr{UInt16}, LPDWORD, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
                key, idx, name_buf, nchars, C_NULL, C_NULL, C_NULL, dwSize)
    if status == ERROR_NO_MORE_ITEMS
        return nothing
    end
    status != ERROR_SUCCESS && throw(WinAPIError(status))

    nchars[] = length(name_buf) # reset
    data_buf = Array{UInt8}(undef,dwSize[])
    status = ccall((:RegEnumValueW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, DWORD, Ptr{UInt16}, LPDWORD, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
                key, idx, name_buf, nchars, C_NULL, dwDataType, data_buf, dwSize)
    status != ERROR_SUCCESS && throw(WinAPIError(status))
    
    n = nchars[]
    resize!(name_buf, n)
    name = transcode(String, name_buf)
    data = extract_data(dwDataType[], data_buf)
    return (name => data), idx+1
end


function Base.getindex(key::RegKey, valuename::AbstractString)
    # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regqueryvalueexw
    dwSize = Ref{DWORD}()
    dwDataType = Ref{DWORD}()

    status = ccall((:RegQueryValueExW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
                key, valuename, C_NULL, dwDataType, C_NULL, dwSize)
    status == ERROR_FILE_NOT_FOUND && throw(KeyError(valuename))
    status != ERROR_SUCCESS && throw(WinAPIError(status))

    data_buf = Array{UInt8}(undef,dwSize[])
    status = ccall((:RegQueryValueExW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
                key, valuename, C_NULL, C_NULL, data_buf, dwSize)
    status != ERROR_SUCCESS && throw(WinAPIError(status))

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
