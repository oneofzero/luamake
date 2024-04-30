

local ndkpath = os.getenv("ANDROID_NDK_ROOT") or os.getenv("NDK_ROOT") or os.getenv("NDKROOT")


assert(ndkpath, "ANDROID_NDK_ROOT MUST SET!");
print("ndkpath:", ndkpath);
assert(getfiledate(ndkpath), "ANDROID_NDK_ROOT:'"..ndkpath.."' not exist!")

local f = io.open(ndkpath.."/source.properties")

local ndk_version
if f then
	local all = f:read("a")
	f:close()
	ndk_version = string.gmatch(all, "Pkg.Revision = (%g+)")
	if ndk_version then
		ndk_version = ndk_version()
		if ndk_version then
			local s = splitstring(ndk_version,".")
			if #s==3 then
				ndk_version ={
					main = tonumber(s[1]),
					sub = tonumber(s[2]),
					build = tonumber(s[3])
				}
				local subv={"b","c","d","e","f","g"}
				setmetatable(ndk_version,
				{
				__tostring = function (tb)
					return "r"..tb.main.. tostring(subv[tb.sub] or "");
				end
				})
			else
				ndk_version = nil
			end
		end
	end
	f=nil
end

print("ndk version", ndk_version or "unknown")

local function getcorrectpath(path)
	if path:find(" ") then
		return '"'..path..'"'
	else
		return path
	end
end
local exe_ext_name = build_platform == "windows" and ".exe" or ""
function android_config(proj, apilevel, arch, gccversion)
	proj:AddFlag("-DANDROID")
	
	--proj:AddDefine("DEBUG")
	--proj:AddFlag("-mfloat-abi=hard")
	
	
	proj:AddLib("c");
	proj:AddLib("m");
	proj:AddLib("log");
	
	proj:AddLib("dl");
	
	proj:RemoveLib("uuid");

	local platformtoolchains=
	{
		arm = "arm-linux-androideabi",
		x86 = "x86",	
		arm64 = "aarch64-linux-android",
	}

	gccversion = gccversion or "4.9"
	arch = arch or "arm"
	local abi;
	

	local adroidtoolpath = ndkpath .. "/toolchains/".. platformtoolchains[arch] .."-" .. gccversion .. "/prebuilt/"..build_platform.."-x86_64/bin"
	apilevel = apilevel or "android-16"
	local levelnumber = tonumber(splitstring(apilevel,"-")[2])
	print("api level is ", levelnumber)
	proj:AddFlag("-D__ANDROID_API__="..levelnumber)
	if ndk_version and ndk_version.main>=16 and  levelnumber >=21 or ndk_version.main >=19  then --us llvm
		print("use llvm")
		--proj:AddLib("stdc++");
		proj:AddCXXFlag("-std=c++14")
		proj:AddCXXFlag("-stdlib=libc++")
		--proj:AddCXXFlag("-fno-addrsig")
		--proj:AddCXXFlag("-DANDROID_STL=c++_static")
		--proj:AddLinkFlag("-fno-addrsig")
		--
		proj:AddLinkFlag("-static-libstdc++")
		proj:AddLinkFlag("-stdlib=libc++")
		--proj:AddLib("c++");
		--proj:AddLib("z")
		--proj:AddLib("gcc");
		proj:AddLib("android");		
		
		--proj:AddCXXFlag("-stdlib=libstdc++")
		local llvmroot = ndkpath .. "/toolchains/llvm/prebuilt/"..build_platform.."-x86_64/"
		local llvm = llvmroot .. "bin"
		local sysroot = llvmroot .. "sysroot"
		--proj:AddLinkFlag("--sysroot=" .. getcorrectpath(sysroot))

		--proj:AddLinkFlag("-gcc-toolchain " .. llvmroot)
		--proj:AddLinkFlag("-static")
		local clangtarget
		if arch == "arm" then
			abi  = "armeabi-v7a"
			proj:AddFlag("-D_ARM_")
			proj:AddFlag("-march=armv7-a")
			clangtarget = "armv7a-linux-androideabi" .. levelnumber				

			proj.ar = getcorrectpath(llvm .. "/arm-linux-androideabi-ar" .. exe_ext_name);
			--proj.linker =proj.compiler
			--proj:AddLib("gcc")
			--proj:AddLinkFlag("-Wl,-Bdynamic -lgcc_s")
			--proj:AddLinkFlag("-m32")
			--proj:AddLinkFlag("-rtlib=compiler-rt")

		elseif arch=="arm64" then
			abi = "arm64-v8a"
			proj:AddFlag("-D_ARM_")
			proj:AddFlag("-march=armv8-a")
			proj:AddFlag("-D_AARCH64_")
			proj:AddFlag("-D_X64")
			clangtarget = "aarch64-none-linux-android" .. levelnumber	
			proj.ar = getcorrectpath(llvm .. "/aarch64-linux-android-ar".. exe_ext_name);
		elseif arch=="x86" then
			abi = "x86"
			--proj:AddFlag("-march=armv8-a")
			clangtarget = "i686-linux-android" .. levelnumber	
			proj.ar = getcorrectpath(llvm .. "/i686-linux-android-ar"..exe_ext_name);
		else
			error("unsupport arch:"..arch)
		end

		proj.compiler = getcorrectpath(llvm .. "/clang"..exe_ext_name).. " -target " .. clangtarget 
		proj.cxx_compiler = getcorrectpath(llvm .. "/clang++"..exe_ext_name) .. " -target " .. clangtarget
		--proj.ar = adroidtoolpath .. "/arm-linux-androideabi-ar.exe";
		proj.linker = proj.cxx_compiler

		--proj:AddFlag("-DANDROID_ABI="..abi)
	else
		proj:AddCXXFlag("-std=gnu++11")
		proj:AddLib("gcc");
		proj:AddLib("gnustl_static");
		if arch == "arm" then
			abi  = "armeabi-v7a"
			proj:AddFlag("-march=armv7-a")
			proj:AddFlag("-D_ARM_")
			proj.compiler = adroidtoolpath .. "/arm-linux-androideabi-gcc"..exe_ext_name;
			proj.cxx_compiler = adroidtoolpath .. "/arm-linux-androideabi-g++"..exe_ext_name;
			proj.ar = adroidtoolpath .. "/arm-linux-androideabi-ar"..exe_ext_name;
			proj.linker =proj.cxx_compiler
			proj:AddIncludePath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/include/")
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/include/")
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/libs/"..abi.."/include/")

			proj:AddLibPath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/lib/")
			proj:AddLibPath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/libs/"..abi.."/")
			proj:AddLinkFlag("--sysroot=" .. ndkpath .. "/platforms/"..apilevel.."/arch-"..arch)
		elseif arch == "arm64" then
			assert( levelnumber >=21, "arm64 must apilevel>=21")
			abi  = "arm64-v8a"
			proj:AddFlag("-march=armv8-a")
			proj:AddFlag("-D_ARM_")
			proj:AddFlag("-D_AARCH64_")
			proj:AddFlag("-D_X64")
			proj.compiler = adroidtoolpath .. "/aarch64-linux-android-gcc"..exe_ext_name;
			proj.cxx_compiler = adroidtoolpath .. "/aarch64-linux-android-g++"..exe_ext_name;
			proj.ar = adroidtoolpath .. "/aarch64-linux-android-ar"..exe_ext_name;
			proj.linker =proj.cxx_compiler
			proj:AddIncludePath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/include/")
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/include/")
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/libs/"..abi.."/include/")

			proj:AddLibPath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/lib/")
			proj:AddLibPath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/libs/"..abi.."/")
			proj:AddLinkFlag("--sysroot=" .. ndkpath .. "/platforms/"..apilevel.."/arch-"..arch)

		elseif arch == "x86" then
			abi  = "x86"
			proj.compiler = adroidtoolpath .. "/i686-linux-android-gcc"..exe_ext_name;
			proj.cxx_compiler = adroidtoolpath .. "/i686-linux-android-g++"..exe_ext_name;
			proj.ar = adroidtoolpath .. "/i686-linux-android-ar"..exe_ext_name
			proj.linker =proj.cxx_compiler
			proj:AddIncludePath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/include/")
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/include/")
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/libs/x86/include/")

			proj:AddLibPath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/lib/")
			proj:AddLibPath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/libs/x86/")
			proj:AddLinkFlag("--sysroot=" .. ndkpath .. "/platforms/"..apilevel.."/arch-"..arch)
		else
			error("unknown arch:" .. arch);
		end
	end
	proj.abi = abi;
	proj.apilevel = apilevel;
	proj.arch = arch;
	proj.output_dir = proj.output_dir or "../../../android"
	proj:AddLibPath(proj.output_dir ..  "/"..proj.target_name.."/");
	proj.mid_path = (proj.output_dir .. "/bt/"..proj.target_name.."/" .. proj.name.."/");
	proj.arflag = "-r";
	proj:SetOutputPath(proj.output_dir ..  "/"..proj.target_name.."/lib".. proj.name .. "." .. proj.target_type);

end
