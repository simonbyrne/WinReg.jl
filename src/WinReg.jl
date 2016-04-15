module WinReg


type RegKey
    phk::UInt32
end
RegKey() = RegKey(0)


import Base: cconvert
cconvert(::Type{UInt32}, k::RegKey) = k.phk
    

const HKEY_CLASSES_ROOT     = 0x80000000
const HKEY_CURRENT_USER     = 0x80000001
const HKEY_LOCAL_MACHINE    = 0x80000002
const HKEY_USERS            = 0x80000003
const HKEY_PERFORMANCE_DATA = 0x80000004
const HKEY_CURRENT_CONFIG   = 0x80000005
const HKEY_DYN_DATA         = 0x80000006


const REG_SZ                  = 1 # null-terminated ASCII string
const REG_DWORD               = 4 # DWORD in little endian format

const QUERY_VALUE         = 0x00001


function openkey(base::Union{UInt32,RegKey}, path::AbstractString)
    key = RegKey()
    ret = ccall((:RegOpenKeyExW, "advapi32"), 
                Clong, 
                (UInt32, Cwstring, UInt32, UInt32, RegKey),
                base, path, 0, QUERY_VALUE, key)
    if ret != 0
        error("Could not find registry key")
    end
    key
end

function querykey(key::Union{UInt32,RegKey}, name::AbstractString)
    dwSize = Ref{UInt32}()
    dwDataType = Ref{UInt32}()
    
    ret = ccall((:RegQueryValueExW, "advapi32"),
                Clong,
                (UInt32, Cwstring, Ptr{UInt32},
                 Ref{UInt32}, Ptr{UInt8}, Ref{UInt32}),
                key, name, C_NULL,
                dwDataType, C_NULL, dwSize)
    if ret != 0
        error("Could not find registry name")
    end

    if dwDataType[] == REG_SZ
        wstr_data = Array(UInt8, dwSize[])
        ret = ccall((:RegQueryValueExW, "advapi32"), 
                    Clong, 
                    (UInt32, Cwstring, Ptr{UInt32},
                     Ref{UInt32}, Ptr{UInt8}, Ref{UInt32}),                
                    key, name, C_NULL,
                    C_NULL, wstr_data, dwSize)
        if ret != 0
            error("Could not retrieve registry data")
        end
        
        return wstring(wstr_data)
    else
        error("Unknown data type")
    end        
end

function querykey(base::Union{UInt32,RegKey}, path::AbstractString, name::AbstractString)
    key = openkey(base,path)
    val = querykey(key, name)
    closekey(key)
    val
end

function closekey(key::RegKey)
    ret = ccall((:RegQueryValueExW, "advapi32"),
                Clong,
                (UInt32,),
                key)
    if ret != 0
        error("Could not close key")
    end
    nothing
end


end # module
