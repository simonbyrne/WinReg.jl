using WinReg
using Test

@show collect(WinReg.subkeys(WinReg.openkey(WinReg.HKEY_CURRENT_USER, "Software")))


regkey = WinReg.openkey(WinReg.HKEY_LOCAL_MACHINE,"System\\CurrentControlSet\\Control\\Session Manager")

@test "Environment" in WinReg.subkeys(regkey)

@show regkey
@show WinReg.RegKey()

names = collect(WinReg.subkeys(key))
@test "Environment" in names

subkey = WinReg.openkey(key, "Environment")
@test subkey["OS"] == "Windows_NT"

@test querykey(WinReg.HKEY_LOCAL_MACHINE,"System\\CurrentControlSet\\Control\\Session Manager\\Environment","OS") == "Windows_NT"
