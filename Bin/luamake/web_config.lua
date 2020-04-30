
local emsdkpath = os.getenv("EMSDK");
assert(emsdkpath, "run emsdk_env set env!");
print("emsdk path ", emsdkpath)
return function (proj)

	proj:AddLibPath("../../../web/");
	proj.mid_path = ("../../../web/bt/" .. proj.name.."/");
	proj.compiler = "emcc";
	proj.cxx_compiler = "emcc";
	proj.ar = "emar r";
	proj:AddFlag("-Wc++11-extensions");
	proj:AddCXXFlag("-std=c++11");
	proj.base(proj);
	proj:SetTargetType("a");
	proj:RemoveDefine("LINUX")
	--proj:RemoveFlag("-O3");

end

