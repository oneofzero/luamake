print("lua maker begin!", luamakeroot);

local string_sub = string.sub;
local build_start_time = gettimems()
local function _table2string(tb, st)
	-- body

	local s = "";
	if st==nil then
		st="";
	else
		st=st.."\t";
	end 
	local tbt =  type(tb);
	if tbt=="table" then
		s = s .. st.."{\r\n";

		for k,v in pairs(tb) do
			--if type(k) ~= "string" then
			--	print(k);
			--	s = s ..st.."\t"..k.."=".._table2string(v,st)..",\r\n";
			--else
				s = s ..st.."\t[ [["..k.."]] ]=".._table2string(v,st)..",\r\n";
			--end
		end
		s = s .. st.."}\r\n";
		return s;
	elseif tbt == "string" then
		return '[['..tb..']]';
	else
		return tostring(tb);
	end
end

table2string = _table2string;


function splitstring(s, spliter)
	local r = {};
	for a in string.gmatch(s, "([^"..spliter .."]+)") do
		r[#r+1] = a;
	end
	return r;
end 

local splitstring = splitstring


if build_platform == "mac" or build_platform == "windows" then
	syscmd = sys_execmd
else
	syscmd = function (cmd)
		local f = io.popen(cmd);
		local rt = f:read("*a");
		local ok,stat,errcode = f:close();
		return errcode,rt;
	end
end


local syscmd = syscmd

local function array_has(tb,_v)
	for k,v in ipairs(tb) do
		if v == _v then
			return k
		end
	end
	
end


function getfilename(path)
	assert(path,"path is nil!");
	local l = string.len(path);
	local f = 0;
	for i = l,1,-1 do
		local c = string_sub(path, i, i);
		if c == "/" then
			f = i;
			break;
		end
	end
	if f==0 then
		return path;
	else
		return string_sub(path,f+1,l);
	end
end
local getfilename = getfilename;
local getfilepath = getfilepath;

if not getfilepath then
	getfilepath = function(path)
		assert(path,"path is nil!");
		local l = string.len(path);
		local f = 0;
		for i = 1,l do
			local c = string_sub(path, i, i);
			if c == "/" then
				f = i;
				break;
			end
		end
		if f==l then
			return path;
		else
			return string_sub(path,1,f);
		end
	end
end

local filedatalist = {}
local getfiledate = function ( f, forceupdate )
	local date = filedatalist[f]
	if date and not forceupdate then return date end

	date = getfiledate(f)
	filedatalist[f] = date;
	return date
end

if not getfiledate then
	print("use lua getfiledate fun")
	getfiledate = function (filepath)
		local errcode,date = syscmd("stat -c%Y ".. filepath)
		--local statret = io.popen("stat -c%Y ".. filepath);
		--local date = statret:read("*a");
		--local ok,desc,errcode = statret:close();
		if errcode~=0 then
			--error(date);
			return;
		end
		return string.sub(date,1,-2);

	end
end

function combine_path(a,b )
	local alast = string.sub(a,#a,-1)
	local bfirst = string.sub(b,1,1)
	if alast == "/" or alast == "\\" then
		a = string.sub(a,1,-2)
	end
	if bfirst == "/" or bfirst == "\\" then
		b = string.sub(b,2,-1)
	end
	return a .. "/" .. b
end


function getfileextname(path)
	assert(path,"path is nil!");
	local l = string.len(path);
	local f = 0;
	for i = l,1,-1 do
		local c = string_sub(path, i, i);
		if c == "." then
			f = i;
			break;
		end
	end
	if f==0 then
		return path;
	else
		return string_sub(path,f+1,l);
	end
end

local getfileextname = getfileextname



if build_platform == "linux" or build_platform == "mac" then
	getcurdir = function()
		local errcode,msg = syscmd("pwd");
		assert(errcode==0 or not errcode,"excutecmd error!");
		return string.sub(msg,1,-2);
	end
elseif build_platform == "windows" then
	getcurdir = function()
		local errcode,msg = syscmd("cd");
		assert(errcode==0 or not errcode,"excutecmd error!" .. tostring(errcode) .. " " .. tostring(msg));
		return string.sub(msg,1,-2);
	end
end
assert(getcurdir, "unknown build platform" .. tostring(build_platform));
local getcurdir = getcurdir

if not root_path then
	--local errcode,msg = syscmd("pwd");
	root_path = getcurdir();
end

function mkdirrecur(path)
	path  = standardpath(path);
	print("mkdir ", path)
	if path == nil or string.len(path) == 0 then
		return true;
	end
	if getfiledate(path) then return true end;
	local err = syscmd("mkdir "..path);
	if err==0 then return true end;
	local parentpath = getfilepath(path);
	if mkdirrecur(parentpath) then
		err = syscmd("mkdir "..path);
		return err == 0;
	end
	return false;

end
local mkdirrecur = mkdirrecur
print("root path:", root_path);









local proj = require("make");


local target_name = arg[1];
local target_op;-- = arg[2];
if not target_name then
	print("require build target:")
	for k,v in pairs(proj.targets) do
		print(k)
	end
	print("options:[singlethread] [showbuildcmd] [forcedebug]")
	error("miss target")
end
local force_sgine_thread
local showbuildcmd
local forcedebug
for i=2,#arg do
	if arg[i] == "clear" then
		target_op = "clear"
	
	elseif arg[i] == "singlethread" then
		force_sgine_thread = true
	elseif arg[i] == "showbuildcmd" then
		showbuildcmd = true
	elseif arg[i] == "forcedebug" then
		forcedebug = true
	end
end


assert(proj.name, "project need a name!");
print("proj name", proj.name)
print("force_sgine_thread", force_sgine_thread)
print("showbuildcmd", showbuildcmd)
print("forcedebug", forcedebug)


proj.targets = proj.targets or {};
proj.libs = proj.libs or {};
proj.defs = proj.defs or {};
proj.include_paths = proj.include_paths or {};
proj.library_paths = proj.library_paths or {};
proj.outpath = proj.name;

proj.flag = proj.flag or "";
proj.cxxflag = proj.cxxflag or "";
proj.linkflag = proj.linkflag or "";
proj.target_type = proj.target_type or "exe"; -- "exe" "lib" "dll"
proj.mid_path = proj.mid_path or "buildtemp";

local proj_meta = {};
function proj_meta:RemoveSrc(srcs)
	srcs = splitstring(srcs,";");
	for k,src in ipairs(srcs) do
		for k,v in ipairs(proj.src_files) do
			if string.find(v,src) then
				table.remove(proj.src_files,k);
				break
			end
		end
	end
end

function proj_meta:AddSrc(srcs)
	srcs = splitstring(srcs,";");
	for k,src in ipairs(srcs) do
		for k,v in ipairs(proj.src_files) do
			if not string.find(v,src) then
				table.insert(proj.src_files,src);
				break
			end
		end
	end
end

function proj_meta:SetOutputPath(outpath)
	-- body
	self.outpath = outpath
end

function proj_meta:AddLib(libs)
	libs = splitstring(libs,";");
	for k,lib in ipairs(libs) do
		if not array_has(self.libs,lib) then 
			self.libs[#self.libs+1] = lib;
		end
	end
end

function proj_meta:RemoveLib(libs)
	libs = splitstring(libs,";");
	for k,lib in pairs(libs) do
		local idx = array_has(self.libs,lib)
		if idx then 
			table.remove(self.libs, idx);
		end
	end
end

function proj_meta:AddDefine(defs)
	defs = splitstring(defs,";");
	for k,def in ipairs(defs) do
		if not array_has(self.defs,def) then 
			self.defs[#self.defs+1] = def;
		end
	end
	--print("defs", table2string(self.defs));
end

function proj_meta:HasDefine(def)
	--print("check has define", def)
	for k,v in ipairs(self.defs) do
		--print("defs:", v)
		if v==def then
			return true
		end
	end
	return false
end

function proj_meta:RemoveDefine(defs)
	defs = splitstring(defs,";");
	for k,def in ipairs(defs) do
		local idx = array_has(self.defs,def)
		if  idx then 
			table.remove(self.defs,idx);
			--self.defs[#self.defs+1] = def;
		end
	end
	--print("defs", table2string(self.defs));
end

function proj_meta:AddLinkFlag(flag)
	local flags = splitstring(self.linkflag," ");
	if array_has(flags,flag) then return end
	self.linkflag = self.linkflag .. " " .. flag;
end

function proj_meta:RemoveLinkFlag(flag)
	local flags = splitstring(self.linkflag," ");
	if not array_has(flags,flag) then return end
	self.linkflag = "";
	for k,v in ipairs(flags) do
		if v~=flag then
			self.linkflag = self.linkflag .. " " .. v;
		end
	end
end

function proj_meta:HaveLinkFlag(flag )
	local flags = splitstring(self.linkflag," ");
	return array_has(flags,flag) 
end

function proj_meta:AddFlag( flag )
	local flags = splitstring(self.flag," ");
	if array_has(flags,flag) then return end
	self.flag = self.flag .. " " .. flag;
end

function proj_meta:AddCXXFlag( flag )
	local flags = splitstring(self.cxxflag," ");
	if array_has(flags,flag) then return end
	self.cxxflag = self.cxxflag .. " " .. flag;
end

function proj_meta:RemoveFlag( flag )
	local flags = splitstring(self.flag," ");
	if not array_has(flags,flag) then return end
	self.flag = "";
	for k,v in ipairs(flags) do
		if v~=flag then
			self.flag = self.flag .. " " .. v;
		end
	end
	
end

function proj_meta:RemoveCXXFlag( flag )
	local flags = splitstring(self.cxxflag," ");
	if not array_has(flags,flag) then return end
	self.cxxflag = "";
	for k,v in ipairs(flags) do
		if v~=flag then
			self.cxxflag = self.cxxflag .. " " .. v;
		end
	end
	
end

function proj_meta:SetTargetType(tp)
	self.target_type = tp;
end

function proj_meta:AddIncludePath(paths)
	paths = splitstring(paths,";");
	--print(table2string(paths));
	for k,path in ipairs(paths) do
		if string.sub(path,1,2) == "./" then
			path = root_path .. string.sub(path, 2,-1);
		end
		if not array_has(self.include_paths,path) then 
			self.include_paths[#self.include_paths+1] = path;
		end
	end
	--print(table2string(self.include_paths));
end

function proj_meta:AddLibPath(paths)
	paths = splitstring(paths,";");

	for k,path in ipairs(paths) do
		if not array_has(self.library_paths,path) then 
			self.library_paths[#self.library_paths+1] = path;
		end
	end
end

proj_meta.__index = proj_meta;

setmetatable(proj,proj_meta);

if  not proj.targets then
	error("target not found!")
end

if not target_name then
	target_name = next(proj.targets);
end
if not target_name then
	error("no targets!");
end

print("build target:", target_name)

proj.mid_path = proj.mid_path .."/"..target_name


if type(proj.src_files) == "function" then
	proj.src_files = proj:src_files();
elseif type(proj.src_files) == "string" then
	--print("src_files", proj.src_files);
	local dirs = splitstring(proj.src_files,";");
	--print("dirs", table2string(dirs));
	
	local tb = {};
	local lscmd = "ls ";
	--local iswindows = build_platform == "windows" 
	--if iswindows then
	--	lscmd = "dir /B ";
	--end

	for k,v in ipairs(dirs) do

		if iswindows then
			v = string.gsub(v, "/", "\\");
		end


		local f = io.popen(lscmd..v, "r");
		for l in f:lines() do 
			tb[#tb+1] = l;
		end
		local ok,st,code = f:close();
		
		assert(code==0 ,lscmd ..v.." err!" .. tostring(code));
	end
	proj.src_files = tb;
elseif not proj.src_files then
	error("no src files!");
end
--print("src files:", table2string(proj.src_files));

local target = proj.targets[target_name];
assert(target, "cant find target ".. target_name);
print("build target", target_name)
proj.target_name = target_name
--if proj.compiler == "g++" then
target(proj);
if forcedebug then
	proj:AddDefine("DEBUG")
end

function is_msvc()
	return proj.compiler == "cl"
end

function is_emcc( ... )
	return proj.compiler == "emcc"
end


local is_msvc = is_msvc

if not is_msvc() then
	if build_platform~="mac" then
		proj:AddLib("m")
	else
		
	end
	if proj.compiler == "gcc" then
		proj:AddLib("stdc++");
		
	end

	if build_platform == "mac" then
		proj:AddDefine("MAC");
	elseif build_platform == "linux" then 
		proj:AddDefine("LINUX");
	end

	if  proj:HasDefine("DEBUG") then
		proj:AddFlag("-g")
		proj:AddLinkFlag("-g")

	else
		proj:AddDefine("NDEBUG");
		proj:AddFlag("-O3");
	end
else
	proj:AddDefine("WIN32");

	if not proj:HasDefine("DEBUG") then
		proj:AddDefine("NDEBUG");
		proj:AddFlag("/O2");
		proj:AddFlag("/Oi");
		proj:AddFlag("/Ot");
		proj:AddFlag("/GL");
	else
		proj:AddFlag("/Od");
		proj:AddFlag("/Zi");
		proj:AddFlag("/FS")
		
		proj:AddFlag(string.format('/Fd"%s/vc141.pdb"', proj.mid_path))
		
		proj:AddLinkFlag("/DEBUG")
		local pdb = string.format('/PDB:"%s.pdb"', proj.outpath)
		proj:AddLinkFlag(pdb)
	end

end
--end


function is_cxx_file(extname)
	return extname == "cpp" or extname == "cxx" or extname == "cc"
end
local is_cxx_file = is_cxx_file


if proj.pre_build then
	if not proj.pre_build() then return end
end


proj.compiler = proj.compiler or "gcc"
proj.cxx_compiler = proj.cxx_compiler or "g++"
proj.linker = proj.linker or proj.compiler
print("cc", proj.compiler)
print("cxx", proj.cxx_compiler)
print("linker", proj.linker)
function deletepath( path )
	path = standardpath(path)
	local apath = path
	if apath:sub(1,1)=='"' then
		apath = apath:sub(2,-2);
		
	end
	--print("delete path is", apath)
	local type = getpathtype(apath)
	if not type then return end

	if build_platform == "windows" then

		
		--local errors = {}
		local errcode,msg
		if type == "dir" then
			errcode,msg = syscmd("rd /S /Q  " .. path);
		else
			errcode,msg = syscmd("del /F " .. path);
		end

		assert(errcode==0,msg);
		
	else
		local errcode,msg = syscmd("rm -rf " .. path);
		assert(errcode==0, msg);

	end
end


if target_op == "clear" then
	local errcode,msg;
	if build_platform == "windows" then
		local errors = {}
		if getpathtype(standardpath(proj.mid_path)) =="dir" then
			errcode,msg = syscmd("rd /S /Q  " .. standardpath(proj.mid_path));
			if errcode ~= 0 then errors[#errors+1] = msg end
		end
		if getpathtype(standardpath(proj.outpath)) =="file" then
			errocde,msg = syscmd("del /F " .. standardpath(proj.outpath));
			if errcode ~= 0 then errors[#errors+1] = msg end
			
		end
		if #errors>0 then
			print("err:")
			for k,v in ipairs(errors) do
				print(v);
			end
			error("error!");
		end
	else
		if getpathtype(proj.mid_path) == "dir" then
			errcode,msg = syscmd("rm -rf " .. proj.mid_path);
			assert(errcode==0, msg);
		end
		if  getpathtype(proj.outpath) == "file" then
			errocde,msg = syscmd("rm -f " .. proj.outpath);
			print("delete ", proj.outpath)
			assert(errcode==0,msg);
		end
	end

	print("clear ok!");
	return ;
end

if not is_msvc() then
	proj:AddFlag("-fPIC");
	if proj.target_type == "dll" or proj.target_type == "so" then
		
		proj:AddLinkFlag("-shared");
		if not is_emcc() and build_platform ~= "mac" then
			proj:AddLinkFlag("-Wl,--no-undefined");
		end
	elseif proj.target_type == "lib" or proj.target_type == "a" then
		proj:AddFlag("-static");
	end
end
--print("cur build proj is", table2string(proj));

local compile_options
local function get_compile_options_cmd( ... )
	if compile_options then return compile_options end
	local buildcmd = ""
	if is_msvc() then
		
		for k,v in ipairs(proj.defs) do
			buildcmd = buildcmd .. " /D" .. v;
		end
		buildcmd = buildcmd .. " " .. proj.flag;

		for k,v in ipairs(proj.include_paths) do
			buildcmd = buildcmd .. " /I" .. v;
		end
	else
		for k,v in ipairs(proj.defs) do
			buildcmd = buildcmd .. " -D" .. v;
		end
		buildcmd = buildcmd .. " " .. proj.flag;

		for k,v in ipairs(proj.include_paths) do
			buildcmd = buildcmd .. " -I" .. v;
		end
	end
	compile_options = buildcmd
	return buildcmd
end


local function getdepsfiles( srcfile )
--	print("get file stamp:", srcfile)
	local includespath = "";
		local cmds
		if not is_msvc() then


			local compiler;
			local extname = getfileextname(srcfile) ;
			if extname == "c" then
				compiler = proj.compiler .. " -std=c99";
			elseif is_cxx_file(extname) then
				compiler = proj.cxx_compiler .. proj.cxxflag;
			else
				compiler = proj.compiler
				
			end
			cmds = compiler .. " -MM " .. srcfile .." " .. get_compile_options_cmd()--includespath .. defines .. flags;
		else
			
			cmds = proj.compiler .. " /showIncludes " .. get_compile_options_cmd();
		end

		
		local cor = coroutine.running();

		local cmd
		if build_platform=="mac" or build_platform=="windows" then
			cmd = [[
				local rcode,deps = sys_execmd(arg)
				if rcode ~= 0 then
					error(arg .. "\n" .. deps);
				end
				return deps;
			]]
		else
			cmd = [[
				local gccrt = io.popen(arg);
				local deps = gccrt:read("*a");
				local isok,r,rcode = gccrt:close();
				if rcode ~= 0 then
					error(arg .. "\n" .. deps);
				end
				return deps;
				
				]]
		end
		--print("get file dep cmd:",cmds)
		newthread(cmd,"chunk", function(ok, ret)
			
			
			local ok, rt = coroutine.resume(cor, ok, ret);
			if not ok then
				error(rt);
			end
		end, cmds )
		local isok, deps = coroutine.yield();
		--local gccrt = io.popen( cmds );
		--local deps = gccrt:read("*a");
		--local isok,r,rcode = gccrt:close();
		if not isok then
			error(cmds .. "\n" .. deps);
		end

		local pos = string.find(deps,":");
		if not pos then
			error("get deps file error! : not found!");
		end	
		deps = string_sub(deps, pos+1);
		
		--print("processed is ", deps);
		local deps_processed = {}
		local i = 1;
		local l = #deps
		local s = 1
		while i < l do
			local c = string_sub(deps, i, i + 5 );
			--print("C:", c)
			if c==" \\\r\n  " then
				deps_processed[#deps_processed+1] = string_sub(deps,s,i-1)
				i = i + 6
				s = i
			--else
				--deps_processed = deps_processed .. c;
			end
			i = i + 1;

		end
		--print("dep:")
		--for k,v in ipairs(deps_processed) do
		--	print(string.format("[%s]",v))
		--end
		return deps_processed
		--return splitstring(deps_processed, "\\\r\n");
	
	--print("include path", includespath);


end

local projstampfilepath = proj.mid_path .. "/filestampinfo.lua";
local filestampinfo;

--print(syscmd("stat -c%Y " .. proj.mid_path))
if getfiledate(proj.mid_path) == nil then
	local ok = mkdirrecur(proj.mid_path);
	print("ok!");
	assert(ok,"mid path create error!"..proj.outpath);

end

pcall(function ( ... )
	filestampinfo = dofile(projstampfilepath);
	--print("file stamp loaded!", projstampfilepath)
end)

if not filestampinfo then
	filestampinfo = {};
end


local function getmidobjfilename(src)
	local pathes = splitstring(src,"/")
	for i,v in ipairs(pathes) do
		if v=='..' then
			pathes[i] = "u"
		elseif v=='.' then
			pathes[i] = ""					
		end
	end


	--local outfilename = proj.mid_path .. "/" ..getfilename(src)..".o";
	local outfilename = proj.mid_path .. "/" ..table.concat(pathes,"_")..".o";
	return outfilename;
end 

local newestfilestampinfo = filestampinfo;


local function get_compile_cmd( src )


	local outfilename = getmidobjfilename(src);
	local compiler = proj.compiler;

	local extname = getfileextname(src) ;
	local buildcmd
	if not is_msvc() then


		if extname == "c" then
			compiler = proj.compiler .. " -std=c99";
		elseif is_cxx_file(extname) then
			compiler = proj.cxx_compiler .. proj.cxxflag;
			
		end

		if proj.use_pch then
			if proj.use_pch == src then
				buildcmd = compiler .. string.format(" -o %s.gch -x c++-header %s %s", src, src, get_compile_options_cmd())
				return buildcmd
			--else
			--	compiler = compiler .. string.format(" -include %s.gch", proj.use_pch)	
			end
				
			
		end
		buildcmd = string.format(compiler.. " %s -o %s -c ", src, outfilename);
		
		
		buildcmd = buildcmd .. get_compile_options_cmd()
	else

		if extname == "c" then
			compiler = proj.compiler
		elseif is_cxx_file(extname) then
			compiler = proj.cxx_compiler .. proj.cxxflag;		
		end
		if proj.use_pch then
			if proj.create_pch == src then
				compiler = compiler .. string.format('/Yc"%s"', proj.use_pch)
				compiler = compiler .. string.format(' /Fp"%s.pch"',  combine_path(proj.mid_path,"pch"))
			elseif not proj.no_pch_list[src] then
				compiler = compiler .. string.format('/Yu"%s"', proj.use_pch)
				compiler = compiler .. string.format(' /Fp"%s.pch"',  combine_path(proj.mid_path,"pch"))
			end
			
		end

		buildcmd = string.format(compiler.. ' %s /Fo"%s" /c', src, outfilename);
		
		buildcmd = buildcmd .. " /nologo /showIncludes " .. get_compile_options_cmd()

	end
	return buildcmd
	
end


local function checkneedupdate(src)

	--local depsfiles = getdepsfiles(src);
	local curstampinfo = filestampinfo[src];

	if not curstampinfo then return true end
	--print("check", src)
	for k,v in pairs(curstampinfo) do
		if k~="__cmd" then
			local oldstamp = v-- curstampinfo[v];
			local nowstamp = getfiledate(k);

			--print("  check",src, v, oldstamp, nowstamp)
			if oldstamp~=nowstamp then
				return true
			end
		end
	end
	local buildcmd = get_compile_cmd(src)
	if curstampinfo.__cmd ~= buildcmd then
		--print("change!")
		--print("old:",curstampinfo.__cmd)
		--print("new:",buildcmd)
		return true
	end


	return false;
	

end 






local function save_stamp( ... )
	local saves = "return " .. table2string(newestfilestampinfo);
	--print("write file ", projstampfilepath)
	local f = io.open(projstampfilepath,"w");
	f:write(saves);
	f:close();
end

if proj.use_pch then
	if is_msvc() then
		assert(proj.create_pch, "msvc must set proj.create_pch file")
	else
		print("build gcc pch")
	end
end

local function compileobj(src, buildcmd)
	-- body
	local newstamps = {};

	if not is_msvc() then
		local depsfiles = getdepsfiles(src)

		for k,v in ipairs(depsfiles) do
			local nowstamp = getfiledate(v,true);
			newstamps[v] = nowstamp;
		end
	end

	--print("compile:",src)
	buildcmd = buildcmd or get_compile_cmd(src)
	if showbuildcmd then
		print(buildcmd);
	end
	
	local runcmd
	if build_platform=="mac" or build_platform=="windows"  then
		runcmd=[[
			local errcode, rt = sys_execmd(arg)
			if errcode~=0 then
				error(rt);
			end
			return rt;
		]]
	else
		runcmd = [[
		local f = io.popen(arg);
		local rt = f:read("*a");
		local ok,stat,errcode = f:close();
		if errcode~=0 then
			error(rt);
		end
		return rt;
		]]
	end
	local cor = coroutine.running();
	newthread(runcmd, "chunk_build", function(ok, ret)
		if not ok then
			if not showbuildcmd then
				print(buildcmd);
			end
			print(ret);
			error(ret);
		end
		local bok, rt = coroutine.resume(cor,ok,ret);
		if not bok then
			if not showbuildcmd then
				print(buildcmd);
			end
			print(rt);
			error(rt);
		end


	end, buildcmd);
	local ok,msg = coroutine.yield();
	if not ok then
		error(msg);
	end

	if is_msvc() then

		--print(msg)
		--local lines = splitstring(msg,"\r\n")
		local lines = string.gmatch(msg, "%S+:%s%S+:%s+([%g%s]+)%c+")
		for l in lines do
			local exclude_check
			for _,e in ipairs(proj.exclude_check_path) do
				local f = string.find(l, e, 1, true)
				--print("search",f, l, e)
				if f then
					exclude_check = true
					--print("exclude", l)
					break
				end
			end
			if not exclude_check then
				newstamps[l] = getfiledate(l,true)
				--print("check", l)
			end
		end
		
		--newstamps["compilecmd"] = buildcmd
	end
	newstamps[src] = getfiledate(src,true)
	newstamps.__cmd = buildcmd
	--local errcode, msg = syscmd(buildcmd)
	--if errcode~=0 then
	--	error(msg);
	--end

	newestfilestampinfo[src] = newstamps;
	--save_stamp();
end 

--checkneedupdate(proj.src_files[1])
local srcschanges = 0;
local srcfilenum = #proj.src_files;

--print(table2string(proj.src_files))
local ok, err = xpcall(function ( ... )
if true then

	local curidx = 1;
	local doneidx = 0;
	local processnum = force_sgine_thread and 1 or getprocesscount();
	local pch_src_idx 
	if proj.use_pch  then
		print("compile pch")
		if is_msvc() then
			for k,v in ipairs(proj.src_files) do
				if v == proj.create_pch then
					pch_src_idx = k
					break
				end
			end
			assert(pch_src_idx,"pch file not found!" .. tostring(proj.create_pch))
		end
		local pchfile = is_msvc() and proj.create_pch or proj.use_pch
		local pchcompile_done 
		local cor = coroutine.create(function ( ... )
			if checkneedupdate(pchfile) then
				compileobj(pchfile);
				srcschanges = srcschanges + 1
			end
			pchcompile_done = true
		end)
		local ok,err = coroutine.resume(cor);
		assert(ok,err);
		while not pchcompile_done do
			dispatchthreadmsg();
		end
		--else
		--	compileobj(proj.use_pch);
		--end
		print("compile pch done")
	end

	--processnum = 1;
	print("use ", processnum, "threads to build")
	for i=1,processnum do
		local cor =	coroutine.create(function()
			while curidx <= srcfilenum do
				local src = proj.src_files[curidx];
				local ispchsrc = pch_src_idx and curidx == pch_src_idx 
				--local idx = curidx;
				curidx = curidx + 1;
				--print("check " , src, ispchsrc)		
					--local depsfiles = checkneedupdate(src) 
				--if pch_src_idx and curidx == pch_src_idx then
				
				if not ispchsrc and checkneedupdate(src) then
					print(src, "need update!");
					compileobj(src);
					srcschanges = srcschanges + 1;
					
					print(string.format("%d%%done",math.floor((doneidx)/srcfilenum*100)));
				else
					print(src, "no changes!");
					--doneidx = doneidx + 1
				end
				doneidx = doneidx + 1
			
			end
			
		end)
		local ok,err = coroutine.resume(cor);
		assert(ok,err and err .. debug.traceback(cor));
	end
	while doneidx < srcfilenum do
		dispatchthreadmsg();
	end
end
end, debug.traceback)
save_stamp()
assert(ok,err);

--if true then return end
--link!-----

local function is_static_lib()
	return proj.target_type == "lib" or proj.target_type == "a" ;
end

local is_static_link = proj:HaveLinkFlag("-static")

local function get_lib_stamp(libdir, lib)
	local lp
	local libstamp
	if is_static_link then
		lp = combine_path(libdir ,"lib"..lib..".a")
		libstamp =  getfiledate(lp) 
	else
		lp = combine_path(libdir ,"lib"..lib..".so")
		libstamp =  getfiledate(lp) 
		if not libstamp then
			lp = combine_path(libdir, "lib"..lib..".a")
			libstamp =  getfiledate(lp) 
		end
	end
	return lp,libstamp
end
print(string.format("targetoutputpath:'%s'", proj.outpath) );
local function getlinkcmd()
	if proj.per_link then
		proj.per_link(proj);
	end
	print("link...");
	--print(getfilepath("asas"),proj.outpath);

	local ok = mkdirrecur(getfilepath(proj.outpath));
	print("ok!");
	assert(ok,"outpath create error!"..proj.outpath);
	local linkcmd;
	if not is_msvc() then
		linkcmd = proj.linker .. " -o " .. proj.outpath;
	else
		linkcmd = proj.linker .. string.format(' /OUT:"%s"' , proj.outpath);
	end
	local isdll = true;
	if is_static_lib() then
		if not is_msvc() then
			print("build static lib ...");
			local ar = proj.ar or "ar";
			if ar == "ar" then
				linkcmd =  ar .. " -r ";
			else
				linkcmd =  ar .. " " ;
			end
			if proj.arflag then
				linkcmd = linkcmd  .. proj.arflag;
			end
			linkcmd = linkcmd .. " "  .. proj.outpath;
			proj.libs = {};
			proj.linkflag = "";
		end
		isdll = false;
	else
		if proj.target_type == "exe" then
			print("build executable ...");
		else
			print("build dynamic lib ...");
			if is_msvc() then
				linkcmd = linkcmd .. " /DLL"
			end
		end
	end
	local objfiles = "";
	for k,src in ipairs(proj.src_files) do
		objfiles = objfiles .. " " .. getmidobjfilename(src) 
	end
	local midlibpath 


	local rspfilepath = proj.mid_path .. "/allobj.rsp";
	local f = io.open(rspfilepath,"w");
	f:write(objfiles);
	f:close();
		
	linkcmd = linkcmd .. " @"..rspfilepath;
	linkcmd = linkcmd .. " " .. proj.linkflag 
	if isdll then
		for k,lib in ipairs(proj.libs) do

			if not is_msvc() then
				linkcmd = linkcmd .. " -l" .. lib;
			else
				if getfileextname(lib)==lib then
					linkcmd = linkcmd .. ' "' .. lib .. '.lib"';
				else
					linkcmd = linkcmd .. ' "' .. lib .. '"';
				end
				
			end


			for _,libdir in ipairs(proj.library_paths) do

				local lp,libstamp = get_lib_stamp(libdir,lib)
				if libstamp then
					newestfilestampinfo[lp] = libstamp
					print("lib stamp:",lp, libstamp)
					break
				end
			end
		end

		for k,v in ipairs(proj.library_paths) do
			if not is_msvc() then
				linkcmd = linkcmd .. " -L" .. v;
			else
				linkcmd = linkcmd .. string.format(' /LIBPATH:"%s"', v);
			end
		end
	end

	if not is_msvc() then
		if isdll then
			linkcmd = linkcmd.. " -Wl,-rpath,./"
		end
	else
		linkcmd = linkcmd .. " /NOLOGO"
	end
	if showbuildcmd then
		print("link cmd is:", linkcmd);
	end
	return linkcmd
end
local function link( linkcmd )
	
	
	local errcode,msg = syscmd(linkcmd);
	if errcode ~= 0 then
		if not showbuildcmd then
			print("link cmd is:", linkcmd);
		end
		error(msg);
	end
	newestfilestampinfo["__linker"] = linkcmd
	print(proj.outpath, "build success!")
end



local function check_lib_update()
	if is_static_lib() then
		return false 
	end
	print("check lib update...")
	
	for k,lib in ipairs(proj.libs) do
		
		for _,libdir in ipairs(proj.library_paths) do
						
			local lp,libstamp = get_lib_stamp(libdir,lib)
			--print("check lib", lp, libstamp, newestfilestampinfo[lp] )
			if libstamp ~= newestfilestampinfo[lp] then
				print("lib change",  lp, libstamp, newestfilestampinfo[lp])
				return true
			end
		end
	end
	return false

end

local targetstamp = getfiledate(proj.outpath)


--print(srcschanges, targetstamp, newestfilestampinfo[proj.outpath]);

--print("src change:",srcschanges>0 )
--print("target change:",targetstamp~= newestfilestampinfo[proj.outpath] or not targetstamp  )
--print("lib change:", check_lib_update())
--print("prject stamp:", proj.outpath, newestfilestampinfo[proj.outpath], targetstamp)
--print("srcschanges", srcschanges , targetstamp~= newestfilestampinfo[proj.outpath] ,targetstamp)

local function check_link_flag_dirty(linkcmd)
	return filestampinfo["__linker"]~=linkcmd
end

local needlink = srcschanges>0 or targetstamp~= newestfilestampinfo[proj.outpath] or not targetstamp or check_lib_update()
local linkcmd = getlinkcmd()
needlink = needlink or check_link_flag_dirty(linkcmd)
if needlink  then
	link(linkcmd);
	targetstamp = getfiledate(proj.outpath,true)
	--print("new stamp", targetstamp)
	newestfilestampinfo[proj.outpath] = targetstamp;
	save_stamp();
else
	print("no changes detected!");
end

if proj.post_build then
	proj.post_build(proj);
end

print("used ", string.format("%.2fs",(gettimems() - build_start_time)/1000) )