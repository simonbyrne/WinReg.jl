using WinReg
using Base.Test


info("querykey - test #0: compatibility test")
@test querykey(WinReg.HKEY_LOCAL_MACHINE,"System\\CurrentControlSet\\Control\\Session Manager\\Environment","OS") == "Windows_NT"


#set test values
parentkey = "HKCU\\Julia"
subkey1 = "test1"
subkey2 = "test2"
dwName = "dwTest"
dwValue = convert(Int32, 2205)
strName = "strTest"
strValue = "Hello!"
mstrName = "mstrTest"
mstrValue = ["Some", "Vectorized", "Words"]
defaValue = "def"

info("regcreatekey - test #1: recursive creation of keys")
res = regcreatekey(parentkey * "\\" * subkey1)
@test res == 1
res = regcreatekey(parentkey * "\\" * subkey2)
@test res == 1
res = regcreatekey(parentkey * "\\" * subkey1)
@test res == 0

info("regwrite - test #2.1: write values")
res = regwrite(parentkey, dwName, dwValue)
@test res
res = regwrite(parentkey, strName, strValue)
@test res
res = regwrite(parentkey, mstrName, mstrValue)
@test res

info("regwrite - test #2.2: write default value")
res = regwrite(parentkey * "\\" * subkey1, "", defaValue)
@test res

info("... dumping values on file ...")
path = joinpath(Pkg.dir("WinReg"), "test", "regdump.reg")
cmd = `cmd /c regedit /e ""$path"" HKEY_CURRENT_USER\\Julia`
#run(cmd)

info("regread - test #3.1: read existent values")
res = regread(parentkey, dwName)
@test res == dwValue
res = regread(parentkey, strName)
@test res == strValue
res = regread(parentkey, mstrName)
@test length(res) == length(mstrValue)
for w in res
	@test (w in mstrValue)
end

info("regread - test #3.2: read default value")
res = regread(parentkey * "\\" * subkey1, "")
@test res == defaValue

info("regread - test #3.3: read not-existent value")
res = regread(parentkey, "noval")
@test res == nothing

info("regkeylist - test #4.1: list existent subkeys of existent key")
res = regkeylist(parentkey)
@test subkey1 in res
@test subkey2 in res

info("regkeylist - test #4.2: list not-existent subkeys of existent key")
res = regkeylist(parentkey * "\\" * subkey2)
@test length(res) == 0

info("regkeylist - test #4.3: list subkeys of not-existent key")
res = regkeylist(parentkey * "\\nokey")
@test res == nothing

info("regvaluelist - test #5.1: list existent values of existent key")
res = regvaluelist(parentkey)
@test length(res) == 3
@test (dwName, UInt32) in res
@test (strName, AbstractString) in res
@test (mstrName, Vector{AbstractString}) in res

info("regvaluelist - test #5.2: list default value of existent key")
res = regvaluelist(parentkey * "\\" * subkey1)
@test ("", AbstractString) in res

info("regvaluelist - test #5.3: list not-existent values of existent key")
res = regvaluelist(parentkey * "\\" * subkey2)
@test length(res) == 0

info("regvaluelist - test #5.4: list values of not-existent key")
res = regvaluelist(parentkey * "\\nokey")
@test res == nothing

info("regdelete - test #6.1: delete key")
res = regdelete(parentkey * "\\" * subkey2)
@test res

info("regdelete - test #6.2: delete not-existent value")
res = regdelete(parentkey * "\\" * subkey1, dwName)
@test !res

info("regdelete - test #6.3: delete value")
res = regdelete(parentkey, dwName)
@test res

info("regdelete - test #6.4: delete default value")
res = regdelete(parentkey * "\\" * subkey1, "")
@test res

info("regdelete - test #6.5: delete keys recursively (error)")
res = regdelete(parentkey)
@test !res

info("regdelete - test #6.6: delete test subkey")
res = regdelete(parentkey * "\\" * subkey1)
@test res

info("regdelete - test #6.7: delete test key with subvalues")
res = regdelete(parentkey)
@test res
