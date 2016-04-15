using WinReg
using Base.Test

import WinReg: querykey, HKEY_LOCAL_MACHINE

@test querykey(HKEY_LOCAL_MACHINE,"System\\CurrentControlSet\\Control\\Session Manager\\Environment","PROCESSOR_ARCHITECTURE") == ENV["PROCESSOR_ARCHITECTURE"]
