#-----------------------------------------------------------
#-----------------------------------------------------------
# Define useful windows types
# -- part of WinReg Module --
#
#File: wintypes.jl
#Author: Leonardo Cocco
#Creation Date: 11-04-2016
#Last update 22-04-2016
#ver: 0.10
#----------------------------------------------------------
#----------------------------------------------------------


typealias POINTER UInt
typealias LPVOID Ptr{UInt8}
typealias WINBOOL UInt
typealias BOOL UInt
typealias BYTE UInt8
typealias LONG Int32
typealias DWORD UInt32
typealias QWORD UInt64
typealias HANDLE Ptr{Void}
typealias LPDWORD Ptr{DWORD}
typealias LPBYTE Ptr{BYTE}
typealias LPCWSTR Ptr{UInt16}
typealias LPCSTR Ptr{UInt8}
#typealias LPCTSTR Ptr{UInt8}

type FILETIME
	dwLowDateTime::DWORD
	dwHighDateTime::DWORD
end
typealias PFILETIME Ptr{FILETIME}

type SECURITY_ATTRIBUTES
	nLength::DWORD
    lpSecurityDescriptor::LPVOID
    bInheritHandle::WINBOOL
end
typealias LPSECURITY_ATTRIBUTES Ptr{SECURITY_ATTRIBUTES}


const ERROR_SUCCESS = 0x00
const ERROR_MORE_DATA = 234
const ERROR_NO_MORE_ITEMS = 259


baremodule SAM
	const DELETE = 0x00010000
	const READ_CONTROL = 0x00020000
	const WRITE_DAC = 0x00040000
	const WRITE_OWNER = 0x00080000
	const SYNCHRONIZE = 0x00100000
	
	const STANDARD_RIGHTS_REQUIRED = 0x000F0000
	
	const STANDARD_RIGHTS_READ = (READ_CONTROL)
	const STANDARD_RIGHTS_WRITE = (READ_CONTROL)
	const STANDARD_RIGHTS_EXECUTE = (READ_CONTROL)
	
	const STANDARD_RIGHTS_ALL = 0x001F0000
	const SPECIFIC_RIGHTS_ALL = 0x0000FFFF
end
