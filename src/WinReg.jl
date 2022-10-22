module WinReg


# https://learn.microsoft.com/en-us/windows/win32/api/winreg/


export querykey

const LSTATUS = Clong
const HKEY = UInt32
const PHKEY = Ptr{HKEY}
const BYTE = UInt8
const DWORD = UInt32
const QWORD = UInt64
const REGSAM = DWORD
const LPBYTE = Ptr{BYTE}
const LPDWORD = Ptr{DWORD}
const LPCWSTR = Cwstring

const MAX_KEY_LENGTH = 255

const ERROR_SUCCESS = LSTATUS(0)
const ERROR_FILE_NOT_FOUND = LSTATUS(2)
const ERROR_NO_MORE_ITEMS = LSTATUS(259)



mutable struct RegKey <: AbstractDict{String,Any}
    handle::HKEY
end
RegKey() = RegKey(zero(UInt32))

Base.cconvert(::Type{HKEY}, key::RegKey) = key
Base.unsafe_convert(::Type{HKEY}, key::RegKey) = key.handle
Base.unsafe_convert(::Type{PHKEY}, key::RegKey) = convert(Ptr{HKEY}, pointer_from_objref(key))



const HKEY_CLASSES_ROOT     = RegKey(0x8000_0000)
const HKEY_CURRENT_USER     = RegKey(0x8000_0001)
const HKEY_LOCAL_MACHINE    = RegKey(0x8000_0002)
const HKEY_USERS            = RegKey(0x8000_0003)
const HKEY_PERFORMANCE_DATA = RegKey(0x8000_0004)
const HKEY_CURRENT_CONFIG   = RegKey(0x8000_0005)
const HKEY_DYN_DATA         = RegKey(0x8000_0006)



const REG_NONE                    = 0 # no value type
const REG_SZ                      = 1 # null-terminated ASCII string
const REG_EXPAND_SZ               = 2 # Unicode nul terminated string
const REG_BINARY                  = 3 # Free form binary
const REG_DWORD                   = 4 # 32-bit number
const REG_DWORD_LITTLE_ENDIAN     = 4 # 32-bit number (same as REG_DWORD)
const REG_DWORD_BIG_ENDIAN        = 5 # 32-bit number
const REG_LINK                    = 6 # Symbolic Link (unicode)
const REG_MULTI_SZ                = 7 # Multiple Unicode strings
const REG_RESOURCE_LIST           = 8 # Resource list in the resource map
const REG_FULL_RESOURCE_DESCRIPTOR = 9 # Resource list in the hardware description
const REG_RESOURCE_REQUIREMENTS_LIST = 10
const REG_QWORD                   = 11 # 64-bit number
const REG_QWORD_LITTLE_ENDIAN     = 11 # 64-bit number (same as REG_QWORD)


const KEY_ALL_ACCESS          = 0xF003F # Combines the STANDARD_RIGHTS_REQUIRED, KEY_QUERY_VALUE, KEY_SET_VALUE, KEY_CREATE_SUB_KEY, KEY_ENUMERATE_SUB_KEYS, KEY_NOTIFY, and KEY_CREATE_LINK access rights.
const KEY_CREATE_LINK         = 0x00020  # Reserved for system use.
const KEY_CREATE_SUB_KEY      = 0x00004  # Required to create a subkey of a registry key.
const KEY_ENUMERATE_SUB_KEYS  = 0x00008  # Required to enumerate the subkeys of a registry key.
const KEY_EXECUTE             = 0x20019  # Equivalent to KEY_READ.
const KEY_NOTIFY              = 0x00010  # Required to request change notifications for a registry key or for subkeys of a registry key.
const KEY_QUERY_VALUE         = 0x00001  # Required to query the values of a registry key.
const KEY_READ                = 0x20019  # Combines the STANDARD_RIGHTS_READ, KEY_QUERY_VALUE, KEY_ENUMERATE_SUB_KEYS, and KEY_NOTIFY values.
const KEY_SET_VALUE           = 0x00002  # Required to create, delete, or set a registry value.

const KEY_WOW64_32KEY         = 0x00200  # Indicates that an application on 64-bit Windows should operate on the 32-bit registry view. This flag is ignored by 32-bit Windows. For more information, see Accessing an Alternate Registry View.
# This flag must be combined using the OR operator with the other flags in this table that either query or access registry values.
# Windows 2000:  This flag is not supported.
const KEY_WOW64_64KEY         = 0x00100  # Indicates that an application on 64-bit Windows should operate on the 64-bit registry view. This flag is ignored by 32-bit Windows. For more information, see Accessing an Alternate Registry View.
# This flag must be combined using the OR operator with the other flags in this table that either query or access registry values.
# Windows 2000:  This flag is not supported.

const KEY_WRITE               = 0x20006  # Combines the STANDARD_RIGHTS_WRITE, KEY_SET_VALUE, and KEY_CREATE_SUB_KEY access rights.

function Base.close(key::RegKey)
    # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regclosekey
    ret = ccall((:RegCloseKey, "advapi32"),
                stdcall, LSTATUS,
                (HKEY,),
                key)
    ret != ERROR_SUCCESS && error("Could not close key")
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
    return transcode(String, buf[1:n]), idx+1
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

    data = Array{UInt8}(undef,dwSize[])
    ret = ccall((:RegQueryValueExW, "advapi32"),
                stdcall, LSTATUS,
                (HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD),
                key, valuename, C_NULL, C_NULL, data, dwSize)
    ret != ERROR_SUCCESS && error("Could not retrieve registry data")

    if dwDataType[] == REG_SZ || dwDataType[] == REG_EXPAND_SZ
        data_wstr = reinterpret(Cwchar_t,data)
        # string may or may not be null-terminated
        # need to copy, until https://github.com/JuliaLang/julia/pull/27810 is fixed
        if data_wstr[end] == 0
            data_wstr2 = data_wstr[1:end-1]
        else
            data_wstr2 = data_wstr[1:end]
        end        
        return transcode(String, data_wstr2)
    elseif dwDataType[] == REG_DWORD
        return reinterpret(DWORD, data)[]
    elseif dwDataType[] == REG_QWORD
        return reinterpret(QWORD, data)[]
    else
        return data
    end
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
