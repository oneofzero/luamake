
local vsversion = os.getenv("VisualStudioVersion")
assert(vsversion,"please run in visual stuido cmd env")
print("vs version",vsversion)
local target = os.getenv("VSCMD_ARG_TGT_ARCH")
print("vs target", target)

WindowsSdkDir = os.getenv("WindowsSdkDir")
VCINSTALLDIR = os.getenv("VCINSTALLDIR")

function win_config(proj)
	proj.compiler =  "cl";
	proj.cxx_compiler = "cl";
	proj.ar = "lib"
	--proj.ar = adroidtoolpath .. "/arm-linux-androideabi-ar.exe";
	proj.linker = "link"
	proj.win_target = target
	proj.mid_path = "buildtemp/"..target .. "/"..proj.target_name;
	proj:AddLib("kernel32.lib;user32.lib;gdi32.lib;shell32.lib;ole32.lib;oleaut32.lib;uuid.lib;odbc32.lib;odbccp32.lib")
	proj.exclude_check_path = {WindowsSdkDir, VCINSTALLDIR}
	if target=="x64" then
		--proj:AddLinkFlag("/MACHINE:X64")		
	end
end