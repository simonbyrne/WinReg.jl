using WinReg
using Test


regkey = WinReg.openkey(WinReg.HKEY_LOCAL_MACHINE,"System\\CurrentControlSet\\Control\\Session Manager")
@test sprint(show, regkey) isa String

@test "Environment" in WinReg.subkeys(regkey)
@test "Environment" in collect(WinReg.subkeys(regkey))

subkey = WinReg.openkey(regkey, "Environment")
@test sprint(show, subkey) isa String

@test haskey(subkey, "OS")
@test "OS" in keys(subkey)
@test subkey["OS"] == "Windows_NT"
@test get(subkey, "OS", nothing) == "Windows_NT"

@test !haskey(subkey, "XOS")
@test !("XOS" in keys(subkey))
@test get(subkey, "XOS", nothing) === nothing

d = Dict(subkey)
@test d isa Dict
@test d["OS"] == "Windows_NT"

@test sprint(show, WinReg.RegKey()) == "WinReg.RegKey()"

@test querykey(WinReg.HKEY_LOCAL_MACHINE,"System\\CurrentControlSet\\Control\\Session Manager\\Environment","OS") == "Windows_NT"
