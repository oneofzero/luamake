return {
	--compiler = "g++",

	name = "lua";

	src_files = "./*.c",
	
	c_flag = "",

	mid_path = "buildtemp",

	target_name = "lua",


	targets =
	{
		base = function ( proj )
			proj:AddLib("m")

		end,

		lua = function ( proj )
			proj.targets.base(proj);
			proj:RemoveSrc("luac.c");
			proj:RemoveSrc("luamake.c");
			proj:SetOutputPath("lua53")


		end,

		luamake = function ( proj )
			proj.targets.base(proj);
			proj:RemoveSrc("luac.c");
			proj:RemoveSrc("lua.c");
			proj:AddDefine("LINUX");
			proj:AddDefine("LUA_USE_POSIX");
			proj:SetOutputPath("luamake")
		end,
		nluamake = function ( proj )
			proj.targets.luamake(proj);
			proj:RemoveSrc("luac.c");
			proj:RemoveSrc("lua.c");
			proj:AddDefine("LINUX");
			proj:AddDefine("LUA_USE_POSIX");
			proj:SetOutputPath("nluamake")
		end


	}

}

