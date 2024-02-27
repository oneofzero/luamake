print("lua maker begin!");
local string_sub = string.sub;

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
				s = s ..st.."\t[\""..k.."\"]=".._table2string(v,st)..",\r\n";
			--end
		end
		s = s .. st.."}\r\n";
		return s;
	elseif tbt == "string" then
		return '"'..tb..'"';
	else
		return tostring(tb);
	end
end

table2string = _table2string;


local function splitstring(s, spliter)
	local r = {};
	for a in string.gmatch(s, "([^"..spliter .."]+)") do
		r[#r+1] = a;
	end
	return r;
end 



local function syscmd(cmd)
	local f = io.popen(cmd);
	local rt = f:read("*a");
	local ok,stat,errcode = f:close();
	return errcode,rt;
end

local function array_has(tb,_v)
	for k,v in ipairs(tb) do
		if v == _v then
			return k
		end
	end
	
end

local function getfilename(path)
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

local getfiledate = getfiledate;
if not getfiledate then
	print("use lua getfiledate fun")
	getfiledate = function (filepath)
		local statret = io.popen("stat -c%Y ".. filepath);
		local date = statret:read("*a");
		local ok,desc,errcode = statret:close();
		if errcode~=0 then
			--error(date);
			return;
		end
		return string.sub(date,1,-2);

	end
end


local function getfileextname(path)
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

local getcurdir;

if build_platform == "linux" then
	getcurdir = function()
		local errcode,msg = syscmd("pwd");
		assert(errocde==0 or not errocde,"excutecmd error!");
		return string.sub(msg,1,-2);
	end
elseif build_platform == "windows" then
	getcurdir = function()
		local errcode,msg = syscmd("cd");
		assert(errocde==0 or not errocde,"excutecmd error!" .. tostring(errocde) .. " " .. tostring(msg));
		return string.sub(msg,1,-2);
	end
end
assert(getcurdir, "unknown build platform" .. tostring(build_platform));
 

if not root_path then
	--local errcode,msg = syscmd("pwd");
	root_path = getcurdir();
end

local function mkdirrecur(path)
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

print("root path:", root_path);




local target_name = arg[1];
local target_op = arg[2];

if arg[1] == "clear" then
	target_op = "clear";
	target_name = nil;
end



local proj = require("make");

assert(proj.name, "project need a name!");
print("proj name", proj.name)


proj.targets = proj.targets or {};
proj.libs = proj.libs or {};
proj.defs = proj.defs or {};
proj.include_paths = proj.include_paths or {};
proj.library_paths = proj.library_paths or {};
proj.outpath = proj.name;

proj.flag = proj.flag or "";
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

function proj_meta:AddLinkFlag(flag)
	if array_has(self.linkflag,flag) then return end
	self.linkflag = self.linkflag .. " " .. flag;
end

function proj_meta:AddFlag( flag )
	
	if array_has(self.flag,flag) then return end
	self.flag = self.flag .. " " .. flag;
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
--if proj.compiler == "g++" then
proj:AddLib("stdc++");
--end



proj:AddFlag("-g");

proj:AddLib("m")

--proj:AddFlag("-O0");

proj:AddDefine("LINUX");

target(proj);

proj.compiler = proj.compiler or "gcc"
proj.cxx_compiler = proj.cxx_compiler or "g++"
proj.linker = proj.linker or proj.compiler




if target_op == "clear" then
	local errcode,msg;
	if build_platform == "windows" then
		local errors = {}

		errcode,msg = syscmd("rd /S /Q  " .. standardpath(proj.mid_path));
		if errcode ~= 0 then errors[#errors+1] = msg end
		errocde,msg = syscmd("del /F " .. standardpath(proj.outpath));
		if errcode ~= 0 then errors[#errors+1] = msg end
		if #errors>0 then
			for k,v in ipairs(errors) do
				print(v);
			end
			error("error!");
		end
		
	else
		errcode,msg = syscmd("rm -rf " .. proj.mid_path);
		assert(errcode==0, msg);
		errocde,msg = syscmd("rm -rf " .. proj.outpath);
		assert(errcode==0,msg);
	end

	print("clear ok!");
	return ;
end

if proj.target_type == "dll" or proj.target_type == "so" then
	proj:AddLinkFlag("-shared");
	proj:AddFlag("-fPIC");
	proj:AddLinkFlag("-Wl,--no-undefined");
elseif proj.target_type == "lib" or proj.target_type == "a" then
	proj:AddFlag("-static");
end
--print("cur build proj is", table2string(proj));



local function getdepsfiles( srcfile )

	local includespath = "";

		for k,v in ipairs(proj.include_paths) do
			includespath = includespath .. " -I"..v;
		end

		local defines = "";
		for k,v in ipairs(proj.defs) do
			defines = defines .. " -D" .. v;
		end
		local flags = "";
		for k,v in ipairs(proj.flag) do
			flags = flags .. v;
		end
		local cmds = proj.compiler .. " -MM " .. srcfile .. includespath .. defines .. flags;
		local gccrt = io.popen( cmds );
		local deps = gccrt:read("*a");
		local isok,r,rcode = gccrt:close();
		if rcode ~= 0 then
			error(cmds .. "\n" .. deps);
		end

		local pos = string.find(deps,":");
		if not pos then
			error("get deps file error! : not found!");
		end	
		deps = string_sub(deps, pos+1);
		--print("original is ", deps);
		local deps_processed = "";
		local i = 1;
		local l = string.len(deps);
		while i < l do
			local  c = string_sub(deps,i, i );
			if c == "\\" then
				i = i + 1;
			else
				deps_processed = deps_processed .. c;
			end
			i = i + 1;

		end
		--print("processed is ", deps_processed);
		return splitstring(deps_processed, " ");
	
	--print("include path", includespath);


end

local projstampfilepath = proj.mid_path .. "/filestampinfo.lua";
local filestampinfo;

--print(syscmd("stat -c%Y " .. proj.mid_path))
if getfiledate(proj.mid_path) == nil then
	local errcode, str = syscmd("mkdir " .. standardpath(proj.mid_path));
	if errcode~=0 then
		error(str);
	end
end

pcall(function ( ... )
	filestampinfo = dofile(projstampfilepath);
end)

if not filestampinfo then
	filestampinfo = {};
end
local newestfilestampinfo = filestampinfo;



local function checkneedupdate(src)

	local depsfiles = getdepsfiles(src);
	local curstampinfo = filestampinfo[src];

	if not curstampinfo then return depsfiles end

	for k,v in ipairs(depsfiles) do
		local oldstamp = curstampinfo[v];
		local nowstamp = getfiledate(v);
		if oldstamp~=nowstamp then
			return depsfiles
		end

	end

	return false;
	

end 




local function getmidobjfilename(src)
	local outfilename = proj.mid_path .. "/" ..getfilename(src)..".obj";
	return outfilename;
end 

local function save_stamp( ... )
	local saves = "return " .. table2string(newestfilestampinfo);
	--print("write file ", projstampfilepath)
	local f = io.open(projstampfilepath,"w");
	f:write(saves);
	f:close();
end

local function compileobj(src, depsfiles)
	-- body
	local newstamps = {};
	for k,v in ipairs(depsfiles) do
		local nowstamp = getfiledate(v);
		newstamps[v] = nowstamp;
	end
	local outfilename = getmidobjfilename(src);
	local compiler = proj.compiler;
	--print("ext name is" , getfileextname(src));
	local extname = getfileextname(src) ;
	if extname == "c" then
		compiler = proj.compiler .. " -std=c99";
	elseif extname == "cpp" or extname == "cxx" then
		compiler = proj.cxx_compiler; --"g++";
	end

	local buildcmd = string.format(compiler.. " %s -o %s -c", src, outfilename);
	for k,v in ipairs(proj.defs) do
		buildcmd = buildcmd .. " -D" .. v;
	end
	buildcmd = buildcmd .. " " .. proj.flag;

	for k,v in ipairs(proj.include_paths) do
		buildcmd = buildcmd .. " -I" .. v;
	end

	--print("compile:",src)
	print(buildcmd);
	local errcode, msg = syscmd(buildcmd)
	if errcode~=0 then
		error(msg);
	end

	newestfilestampinfo[src] = newstamps;
	save_stamp();
end 

--checkneedupdate(proj.src_files[1])
local srcschanges = 0;
local srcfilenum = #proj.src_files;

--print(table2string(proj.src_files))


for k,src in ipairs(proj.src_files) do

	local depsfiles = checkneedupdate(src) 
	if depsfiles then
		print(src, "need update!");
		compileobj(src, depsfiles);
		srcschanges = srcschanges + 1;
		print(string.format("%d%%done",math.floor((k-1)/srcfilenum*100)));
	else
		--print(src, "no changes!");
	end


end
--if true then return end
--link!-----

local function link( ... )
	print("link...");
	print(getfilepath("asas"),proj.outpath);

	local ok = mkdirrecur(getfilepath(proj.outpath));
	print("ok!");
	assert(ok,"outpath create error!"..proj.outpath);
	local linkcmd = proj.linker .. " -o " .. proj.outpath;
	local isdll = true;
	if proj.target_type == "lib" or proj.target_type == "a" then
		print("build static lib ...");
		local ar = proj.ar or "ar";
		linkcmd =  ar .. " -r " .. proj.outpath;
		proj.libs = {};
		proj.linkflag = "";
		isdll = false;
	else
		print("build dynamic lib ...");
	end
	for k,src in ipairs(proj.src_files) do
		linkcmd = linkcmd .. " " .. getmidobjfilename(src) 
	end

	if isdll then
		for k,lib in ipairs(proj.libs) do
			linkcmd = linkcmd .. " -l" .. lib;
		end

		for k,v in ipairs(proj.library_paths) do
			linkcmd = linkcmd .. " -L" .. v;
		end
	end
	linkcmd = linkcmd .. " " .. proj.linkflag 
	if isdll then
		linkcmd = linkcmd.. " -Wl,-rpath,./"
	end

	print("link cmd is:", linkcmd);
	local errcode,msg = syscmd(linkcmd);
	if errcode ~= 0 then
		error(msg);
	end
	print(proj.outpath, "build success!")
end

local targetstamp = getfiledate(proj.outpath)
--print(srcschanges, targetstamp, newestfilestampinfo[proj.outpath]);
if srcschanges>0 or targetstamp~= newestfilestampinfo[proj.outpath] or not targetstamp then
	link();
	targetstamp = getfiledate(proj.outpath)
	newestfilestampinfo[proj.outpath] = targetstamp;
	save_stamp();
else
	print("no changes detected!");
end