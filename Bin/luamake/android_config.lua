

local ndkpath = os.getenv("ANDROID_NDK_ROOT") or os.getenv("NDK_ROOT") or os.getenv("NDKROOT")


assert(ndkpath, "ANDROID_NDK_ROOT MUST SET!");
print("ndkpath:", ndkpath);
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
					return "r"..tb.main.. tostring(subv[tb.sub]);
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
	

	local adroidtoolpath = ndkpath .. "/toolchains/".. platformtoolchains[arch] .."-" .. gccversion .. "/prebuilt/windows-x86_64/bin"
	apilevel = apilevel or "android-16"
	local levelnumber = tonumber(splitstring(apilevel,"-")[2])
	print("api level is ", levelnumber)
	proj:AddFlag("-D__ANDROID_API__="..levelnumber)
	if ndk_version and ndk_version.main>=16 and  levelnumber >=21 then --us llvm
		print("use llvm")
		proj:AddLib("stdc++");
		proj:AddLib("c++");
		proj:AddLib("z")
		proj:AddCXXFlag("-std=c++11")
		local llvm = ndkpath .. "/toolchains/llvm/prebuilt/windows-x86_64/bin"
		if arch == "arm" then
			abi  = "armeabi-v7a"
			proj:AddFlag("-march=armv7-a")
			proj:AddFlag("-D_ARM_")
			proj:AddFlag("-no-canonical-prefixes")
			proj:AddFlag("-gcc-toolchain " .. ndkpath .. "/toolchains/arm-linux-androideabi-4.9/prebuilt/windows-x86_64/")

			proj.compiler = llvm .. "/clang.exe -target armv7-none-linux-androideabi";
			proj.cxx_compiler = llvm .. "/clang++.exe -target armv7-none-linux-androideabi";
			proj.ar = adroidtoolpath .. "/arm-linux-androideabi-ar.exe";
			proj.linker =proj.cxx_compiler
			proj:AddIncludePath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/include/")
			proj:AddIncludePath(ndkpath .. "/sysroot/usr/include")
			proj:AddIncludePath(ndkpath .. "/sysroot/usr/include/"..platformtoolchains[arch])
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/llvm-libc++/include")
			--proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/llvm-libstdc++/"..gccversion.."/include/")
			--proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/llvm-libstdc++/"..gccversion.."/libs/"..abi.."/include/")

			proj:AddLibPath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/lib/")
			proj:AddLibPath(ndkpath .. "/sources/cxx-stl/llvm-libc++/libs/"..abi.."/")
			--proj:AddLibPath(ndkpath .. "/toolchains/arm-linux-androideabi-4.9/prebuilt/windows-x86_64/lib/gcc/arm-linux-androideabi/4.9.x")
			--proj:AddLibPath(ndkpath .. "/toolchains/arm-linux-androideabi-4.9/prebuilt/windows-x86_64/arm-linux-androideabi/lib")
			proj:AddLinkFlag("--sysroot=" .. ndkpath .. "/platforms/"..apilevel.."/arch-"..arch)

			proj:AddLinkFlag("-gcc-toolchain " .. ndkpath .. "/toolchains/arm-linux-androideabi-4.9/prebuilt/windows-x86_64/")
			proj:AddLinkFlag("-no-canonical-prefixes")

		elseif arch=="x86" then
			abi  = "x86"

			proj:AddFlag("-no-canonical-prefixes")
			proj:AddFlag("-gcc-toolchain " .. ndkpath .. "/toolchains/x86-4.9/prebuilt/windows-x86_64")

			proj.compiler = llvm .. "/clang.exe -target i686-none-linux-android";
			proj.cxx_compiler = llvm .. "/clang++.exe -target i686-none-linux-android";
			proj.ar = adroidtoolpath .. "/i686-linux-androideabi-ar.exe";
			proj.linker =proj.cxx_compiler
			proj:AddIncludePath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/include/")
			proj:AddIncludePath(ndkpath .. "/sysroot/usr/include")
			proj:AddIncludePath(ndkpath .. "/sysroot/usr/include/i686-linux-android")
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/llvm-libc++/include")
			--proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/llvm-libstdc++/"..gccversion.."/include/")
			--proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/llvm-libstdc++/"..gccversion.."/libs/"..abi.."/include/")

			proj:AddLibPath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/lib/")
			proj:AddLibPath(ndkpath .. "/sources/cxx-stl/llvm-libc++/libs/"..abi.."/")
			--proj:AddLibPath(ndkpath .. "/toolchains/arm-linux-androideabi-4.9/prebuilt/windows-x86_64/lib/gcc/arm-linux-androideabi/4.9.x")
			--proj:AddLibPath(ndkpath .. "/toolchains/arm-linux-androideabi-4.9/prebuilt/windows-x86_64/arm-linux-androideabi/lib")
			proj:AddLinkFlag("--sysroot=" .. ndkpath .. "/platforms/"..apilevel.."/arch-"..arch)

			proj:AddLinkFlag("-gcc-toolchain " .. ndkpath .. "/toolchains/x86-4.9/prebuilt/windows-x86_64")
			proj:AddLinkFlag("-no-canonical-prefixes")
		end
	else
		proj:AddCXXFlag("-std=gnu++11")
		proj:AddLib("gcc");
		proj:AddLib("gnustl_static");
		if arch == "arm" then
			abi  = "armeabi-v7a"
			proj:AddFlag("-march=armv7-a")
			proj:AddFlag("-D_ARM_")
			proj.compiler = adroidtoolpath .. "/arm-linux-androideabi-gcc.exe";
			proj.cxx_compiler = adroidtoolpath .. "/arm-linux-androideabi-g++.exe";
			proj.ar = adroidtoolpath .. "/arm-linux-androideabi-ar.exe";
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
			proj.compiler = adroidtoolpath .. "/aarch64-linux-android-gcc.exe";
			proj.cxx_compiler = adroidtoolpath .. "/aarch64-linux-android-g++.exe";
			proj.ar = adroidtoolpath .. "/aarch64-linux-android-ar.exe";
			proj.linker =proj.cxx_compiler
			proj:AddIncludePath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/include/")
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/include/")
			proj:AddIncludePath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/libs/"..abi.."/include/")

			proj:AddLibPath(ndkpath .. "/platforms/"..apilevel.."/arch-"..arch.."/usr/lib/")
			proj:AddLibPath(ndkpath .. "/sources/cxx-stl/gnu-libstdc++/"..gccversion.."/libs/"..abi.."/")
			proj:AddLinkFlag("--sysroot=" .. ndkpath .. "/platforms/"..apilevel.."/arch-"..arch)

		elseif arch == "x86" then
			abi  = "x86"
			proj.compiler = adroidtoolpath .. "/i686-linux-android-gcc.exe";
			proj.cxx_compiler = adroidtoolpath .. "/i686-linux-android-g++.exe";
			proj.ar = adroidtoolpath .. "/i686-linux-android-ar.exe"
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
	proj:AddLibPath("../../../android/"..proj.target_name.."/");
	proj.mid_path = ("../../../android/bt/"..proj.target_name.."/" .. proj.name.."/");
	proj.arflag = "-r";
	proj:SetOutputPath("../../../android/"..proj.target_name.."/lib".. proj.name .. "." .. proj.target_type);

end
