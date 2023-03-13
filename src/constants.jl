# type aliases
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


# constants
const MAX_KEY_LENGTH = 255
const MAX_VALUE_LENGTH = 16383

const ERROR_SUCCESS = LSTATUS(0)
const ERROR_FILE_NOT_FOUND = LSTATUS(2)
const ERROR_MORE_DATA = LSTATUS(234)
const ERROR_NO_MORE_ITEMS = LSTATUS(259)

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
