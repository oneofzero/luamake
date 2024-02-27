
local emsdkpath = os.getenv("EMSDK");
assert(emsdkpath, "run emsdk_env set env!");
print("emsdk path ", emsdkpath)
return function (proj)

	proj:AddLibPath("../../../web/");
	proj.mid_path = ("../../../web/bt/" .. proj.name.."/");
	proj.compiler = "emcc";
	proj.cxx_compiler = "em++";
	proj.ar = "emar r";
	proj:AddFlag("-Wc++11-extensions");
	proj:AddFlag("-Wno-inconsistent-missing-override");
	--proj:AddFlag("-sEXCEPTION_CATCHING_ALLOWED=IFExceptionInfo")
	proj:AddFlag("-Wno-undefined-var-template");
	--proj:AddFlag("-sNO_DISABLE_EXCEPTION_CATCHING");
	--proj:AddCXXFlag("-fexceptions");
	proj:AddCXXFlag("-fno-exceptions")
	
	--proj:AddFlag("-pthread");
	proj:AddCXXFlag("-std=c++11");
	proj.base(proj);
	proj:SetTargetType("a");
	proj:RemoveDefine("LINUX")
	proj:AddDefine("IF_DONT_USE_CXX_EXCEPTION")
	--proj:AddFlag("-O3");
	--proj:AddFlag("-Os");
	proj:AddFlag("-Oz");
	--proj:AddFlag("-g0")
	--proj:AddDefine("DEBUG")
	--proj:AddFlag("-g")
	--proj:AddFlag("-fsanitize=undefined")
	--proj:AddCXXFlag("-fno-rtti")

	print("compile flag:",proj.flag)
end

