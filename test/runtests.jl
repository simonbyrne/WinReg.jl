using WinReg
using Base.Test

@test querykey(WinReg.HKEY_LOCAL_MACHINE,"System\\CurrentControlSet\\Control\\Session Manager\\Environment","PROCESSOR_ARCHITECTURE") == ENV["PROCESSOR_ARCHITECTURE"]
