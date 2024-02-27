



function harmony_config(proj, apilevel, arch, gccversion)

	local sdkpath = os.getenv("HARMONY_SDK_ROOT") 


	assert(sdkpath, "HARMONY_SDK_ROOT MUST SET!");
	print("HARMONY_SDK_NATIVE_ROOT:", sdkpath);

	local nativesdkpath = sdkpath.. "/" .. apilevel .. "/native";
	local f = io.open(nativesdkpath .. "/oh-uni-package.json")

	local harmony_sdk_version
	if f then
		local all = f:read("a")
		f:close()
		harmony_sdk_version = string.gmatch(all, [["version": "(%g+)"]])
		if harmony_sdk_version then
			harmony_sdk_version = harmony_sdk_version()

		end
		f=nil
	end

	print("harmony_sdk_version ", harmony_sdk_version or "unknown")

	local function getcorrectpath(path)
		if path:find(" ") then
			return '"'..path..'"'
		else
			return path
		end
	end
	local levelnumber = tonumber(apilevel)
	print("api level is ", levelnumber)
	proj:AddFlag("-DOHOS -DOHOS_PLATFORM_LEVEL=1")
	
	--proj:AddDefine("DEBUG")
	--proj:AddFlag("-mfloat-abi=hard")
	
	
	proj:AddLib("c");
	proj:AddLib("m");
	
	proj:AddLib("dl");
	
	proj:RemoveLib("uuid");

	gccversion = gccversion or "4.9"
	arch = arch or "arm"
	local abi;
	
	
	--proj:AddFlag("-D__ANDROID_API__="..levelnumber)
	
	print("use llvm")
	--proj:AddLib("stdc++");
	proj:AddCXXFlag("-std=c++14")
	proj:AddCXXFlag("-stdlib=libc++")

	--
	proj:AddLinkFlag("-static-libstdc++")
	proj:AddLinkFlag("-stdlib=libc++")
		
	--proj:AddCXXFlag("-stdlib=libstdc++")
	local llvmroot = nativesdkpath .. "/llvm"
	local llvm = llvmroot .. "/bin"
	local sysroot = nativesdkpath .. "/sysroot"

	local clangtarget
	if arch == "arm" then
		abi  = "armeabi-v7a"
		proj:AddFlag("-D_ARM_")
		proj:AddFlag("-march=armv7-a")
		clangtarget = "arm-linux-ohos"				

	elseif arch=="arm64" then
		abi = "arm64-v8a"
		proj:AddFlag("-D_ARM_")
		proj:AddFlag("-march=armv8-a")
		proj:AddFlag("-D_AARCH64_")
		proj:AddFlag("-D_X64")
		clangtarget = "aarch64-linux-ohos"	
	elseif arch=="x86" then
		abi = "x86"
		clangtarget = "x86_64-linux-ohos"	
	else
		error("unsupport arch:"..arch)
	end

	proj.ar =  getcorrectpath(llvm .. "/llvm-ar.exe")
	proj.compiler = getcorrectpath(llvm .. "/clang.exe").. " -target " .. clangtarget 
	proj.cxx_compiler = getcorrectpath(llvm .. "/clang++.exe") .. " -target " .. clangtarget
	proj.linker = proj.cxx_compiler

	
	
	proj.abi = abi;
	proj.apilevel = apilevel;
	proj.arch = arch;
	proj:AddLibPath("../../../harmony/"..proj.target_name.."/");
	proj.mid_path = ("../../../harmony/bt/"..proj.target_name.."/" .. proj.name.."/");
	proj.arflag = "-r";
	proj:SetOutputPath("../../../harmony/"..proj.target_name.."/lib".. proj.name .. "." .. proj.target_type);

end
