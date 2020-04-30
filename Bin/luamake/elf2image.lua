BaseFirmwareImage ={};

local function stringappend(s,a,n)
	for i=1,n do
		s = s .. a
	end
	return s
end

local function align_file_position(f, size)
   -- """ Align the position in the file to the next block of specified size """
   local pos = f:seek();
    local align = (size - 1) - (pos % size)
    f:seek("cur",align)

end

local checksum_fun = checksum

local BaseFirmwareImage = BaseFirmwareImage

function BaseFirmwareImage:init(... )
	self.segments = {};
   	self.entrypoint = 0
end

local ESP_CHECKSUM_MAGIC = 0xef
local ESP_IMAGE_MAGIC = 0xe9
local ESP_FLASH_SECTOR = 0x1000

function BaseFirmwareImage:add_segment(addr, data, pad_to )
	pad_to = pad_to or 4
	local l = #data;
	local pad_add = 0
	if l%pad_to~=0 then
		pad_add  =  (pad_to - (l % pad_to))
		data = stringappend(data, "\0", pad_add);
		--data = stringappend(data,'\0', pad_add)
	end
	if l>0 then
		self.segments[#self.segments+1]={offset=addr,size=#data, data=data}
	end
end

function BaseFirmwareImage:modify_segment(addr, data_offset, data)
	local segment;
	for k,v in ipairs(self.segments) do

		if v.offset == addr then
			segment = v;
			break;

		end
	end
	assert(segment, "segment not found!"..addr);
	assert(data_offset<#segment.data,"offset " .. data_offset .. ">" .. #segment.data)
	local prevdata =  string.sub(segment.data, 1, data_offset);
	print("len1", #prevdata)
	print("len2", #data)
	prevdata = prevdata .. data;
	prevdata = prevdata .. string.sub(segment.data, data_offset+1+#data,#segment.data);
	print(#prevdata,#segment.data)
	assert(#prevdata==#segment.data);
	segment.data = prevdata;
end

function BaseFirmwareImage:save_segment(f, segment, checksum)
    --""" Save the next segment to the image file, return next checksum value if provided """
    --(offset, size, data) = segment
    local data;
    if f then

    	f:write(string.pack('<II', segment.offset, segment.size))
    	f:write(segment.data)
    else
    	data = string.pack('<II', segment.offset, segment.size)..segment.data
	end

    if checksum then
    	--print("check sum1 ", checksum)
        checksum = checksum_fun(segment.data, checksum)
		--print("check sum2 ", checksum)
		return checksum,data
    end

end


function BaseFirmwareImage:append_checksum(f, checksum)
    --""" Append ESPROM checksum to the just-written image """
    align_file_position(f, 16)
    print("check sum", checksum)
    f:write(string.pack('B', checksum))

 end

function BaseFirmwareImage:write_v1_header(f, segments)
	print(string.format("segments:%d, flashmode:%d, flashsizefreq:%d, entrypoint:%x", #segments, self.flash_mode, self.flash_size_freq, self.entrypoint))
	--print( ESP_IMAGE_MAGIC, #segments, self.flash_mode, self.flash_size_freq, self.entrypoin)
    local data = 	string.pack('<BBBBI', ESP_IMAGE_MAGIC, #segments, self.flash_mode, self.flash_size_freq, self.entrypoint)

    if f then
    	f:write(data)
    end
    return data;
	--f:write("fuck!")
end

BaseFirmwareImage.__index = BaseFirmwareImage

ESPFirmwareImage = {};
local ESPFirmwareImage = ESPFirmwareImage

function ESPFirmwareImage:dumpdata()
	 local data = self:write_v1_header(nil, self.segments);
	local checksum = ESP_CHECKSUM_MAGIC
	local sectordata;
    for k,segment in  ipairs(self.segments) do
        checksum,sectordata = self:save_segment(nil, segment, checksum)
        data = data .. sectordata;
    end
    local n = 16 - ((#data+1)%16);
    print("need fill", n)
    local aligndata="";
    if(n<16) and n >0 then
    	for i=1,n do
    		aligndata = aligndata .. "\xFF";
    	end
    
    	data = data .. aligndata;
    end
    data = data .. string.pack("B", checksum)
    return data;
    --self:append_checksum(f, checksum)
end

function  ESPFirmwareImage:save(filename)
   -- with open(filename, 'wb') as f:
   local f = io.open(filename,"wb");

    self:write_v1_header(f, self.segments)
    local checksum = ESP_CHECKSUM_MAGIC
    for k,segment in  ipairs(self.segments) do
        checksum = self:save_segment(f, segment, checksum)
    end
    self:append_checksum(f, checksum)
    f:close()
end
ESPFirmwareImage.__index = ESPFirmwareImage
setmetatable(ESPFirmwareImage,BaseFirmwareImage)
function ESPFirmwareImage.New()
	local t = {};
	setmetatable(t,ESPFirmwareImage)
	t:init();
	return t;
end

OTAFirmwareImage={};

local OTAFirmwareImage = OTAFirmwareImage;
OTAFirmwareImage.__index = OTAFirmwareImage;
setmetatable(OTAFirmwareImage,BaseFirmwareImage)
local IMAGE_V2_MAGIC = 0xea
local IMAGE_V2_SEGMENT = 4

function OTAFirmwareImage.New()
	local t = {};
	setmetatable(t,OTAFirmwareImage)
	t:init();
	return t;
end

function OTAFirmwareImage:save( filename )
	local f = io.open(filename,"wb");
	-- # Save first header for irom0 segment
    f:write(string.pack('<BBBBI', IMAGE_V2_MAGIC, IMAGE_V2_SEGMENT,
                                self.flash_mode, self.flash_size_freq, self.entrypoint));
    --# irom0 segment identified by load address zero
    local irom_segment ;--= [segment for segment in self.segments if segment[0] == 0]
    local normal_segments = {};
    for k,v in ipairs(self.segments) do
    	if v.offset == 0 then
    		assert(irom_segment==nil,string.format('Found more segments that could be irom0. Bad ELF file?'))
    		irom_segment = v;
    	else
    		normal_segments[#normal_segments+1] = v;
    	end
    end	
    assert(irom_segment);
    self:save_segment(f, irom_segment)
    self:write_v1_header(f, normal_segments)
    print("normal segments",#normal_segments)
    local checksum = ESP_CHECKSUM_MAGIC

    for k,segment in ipairs(normal_segments) do
        checksum = self:save_segment(f, segment, checksum)
    end
    self:append_checksum(f, checksum)
    print("check sum is", checksum)
end




ELFFile = {};
local ELFFile = ELFFile;
ELFFile.__index = ELFFile
function ELFFile.New(path)
	local tb={path=path};
	setmetatable(tb,ELFFile)
	return tb
end

function ELFFile:get_entry_point(  )
	-- body
	if self.entrypoint then return self.entrypoint end
	
	local cmd;
	if esp32_config then
		cmd	= esp_efl_tool_path .."xtensa-esp32-elf-readelf.exe -h " .. self.path
	else
		cmd	= esp_efl_tool_path .."/xtensa-lx106-elf-readelf.exe -h " .. self.path
	end
	local code, msg =syscmd(cmd)
	assert(code==0,msg)
	print(msg)

	string.gsub(msg,"Entry point address:%s+0x([%a%d%g]+)", function (address)
		--print("entry point is", address)
		self.entrypoint = tonumber(address,16);
	end)

	return self.entrypoint;
	--print(msg)
end

function ELFFile:get_symbol_addr( sym)
	if self.symbos then
		return self.symbos[sym];
	end
	local cmd
	if esp32_config then
		cmd	= esp_efl_tool_path .."xtensa-esp32-elf-nm.exe " .. self.path ;
	else
		cmd	= esp_efl_tool_path .."/xtensa-lx106-elf-nm.exe " .. self.path ;
	end
	local code, msg =syscmd(cmd)
	assert(code==0,msg)
	local symbos ={}
	string.gsub(msg,"(%g+)%s(%g)%s(%g+)", function (address, type, name )
		--print(address, type, name)
		assert(type~="U","undefined symbo:"..name)
		symbos[name] = tonumber(address,16)
	end)
	self.symbos = symbos
	local f = io.open("smybos.txt","wb");
	f:write(msg);
	f:close()
	return symbos[sym]
	--print(msg)
end


function ELFFile:load_section( section)
	if self.sections and self.sections[section] then
		return self.sections[section]
	end

	local tempsection = "secion"..section..".bin"
	local cmd
	if esp32_config then
	cmd	= esp_efl_tool_path .."/xtensa-esp32-elf-objcopy.exe --only-section " .. section .. " -Obinary " ..self.path .. " " .. tempsection;
	else
		cmd	= esp_efl_tool_path .."/xtensa-lx106-elf-objcopy.exe --only-section " .. section .. " -Obinary " ..self.path .. " " .. tempsection;
	end
	local code, msg =syscmd(cmd)
	assert(code==0,msg)
	local f = io.open(tempsection, "rb");
	local data = f:read("a")
	f:close();
	deletepath(tempsection)
	self.sections = self.sections or {};
	self.sections[section] = data;

	print("section load", section, #data)
	return data;
end

local function list_fs_filelist(dir, filelist)
	local ok,msg = syscmd("ls "..dir)

	string.gsub(msg,"./fs/([%w%p]+)\n", function (file)
		
		local fullpath = "../fs/"..file;
		if getpathtype(fullpath) == "dir" then
			list_fs_filelist(fullpath.."/", filelist)
		else
			print("file:", file);
			local f = io.open(fullpath,"rb");
			local data = f:read("a");
			f:close();
			filelist[#filelist+1] = {path = file, data = data};
		end
	end)
end

local function write_resource_file( ... )
	local filelist = {};
	list_fs_filelist("../fs/", filelist);

	local sb = stringbuilder();
	local offset = 0;
	sb:append(string.pack("<I", #filelist))
	for k,v in ipairs(filelist) do


		local namelen =  128;--math.floor(#v.path/4+1)*4;
		assert(#v.path<namelen,"path to long!" .. v.path)
		
		sb:append(v.path);
		if #v.path < namelen then
			sb:append("\0", namelen-#v.path);
		end

		sb:append(string.pack("<I", #v.data));

		sb:append(string.pack("<I", offset));
		offset = offset + math.floor(#v.data/4+1)*4;
	end

	for k,v in ipairs(filelist) do
		sb:append(v.data);
		local  datasize = math.floor(#v.data/4+1)*4;
		if(datasize>#v.data) then
			sb:append("\0", datasize-#v.data);
		end

	end

	return sb:tostring();
end 


function elf2image( version , elfpath,flash_mode, flash_size ,flash_freq)
	local e = ELFFile.New(elfpath)
	
	local image


	if version == 1 then
		image = ESPFirmwareImage.New();
	else
		image = OTAFirmwareImage.New()
		local  irom_data = e:load_section('.irom0.text')
		assert(#irom_data>0, ".irom0.text section not found in ELF file - can't create V2 image.")
		image:add_segment(0, irom_data, 16)
	end
	image.entrypoint = e:get_entry_point();
	print("entrypoint is", string.format("0x%x", image.entrypoint))
	for k,v in ipairs({{".text", "_text_start"}, {".data", "_data_start"}, {".rodata", "_rodata_start"}}) do
		local section = v[1];
		local start = v[2];
		local data = e:load_section(section)
        image:add_segment(e:get_symbol_addr(start), data)
	end

	image.flash_mode = ({
	['qio']=0, ['qout']=1, ['dio']=2, ['dout']=3
	})
	[flash_mode]

    image.flash_size_freq = 
    ({['4m']=0x00, ['2m']=0x10, ['8m']=0x20, ['16m']=0x30,
     ['32m']=0x40, ['16m-c1']= 0x50, ['32m-c1']=0x60, 
     ['32m-c2']=0x70, ['64m']=0x80, ['128m']=0x90})[flash_size]
    image.flash_size_freq = image.flash_size_freq + ({['40m']=0, ['26m']=1, ['20m']=2, ['80m']= 0xf})[flash_freq]
    local irom_offs = e:get_symbol_addr("_irom0_text_start") - 0x40200000
    print(string.format("irom_offs:%x", irom_offs))
    if version==1 then
    	--image:save("0x00000.bin")
    	--do
    	--	local f = io.open("0x00001.bin","wb");

    	--	f:write(image:dumpdata())
    	--	f:close();
    	--end
    	local irondata = e:load_section(".irom0.text")
    	assert(irom_offs>=0, 'Address of symbol _irom0_text_start in ELF is located before flash mapping address. Bad linker script?')
    	if (irom_offs & 0xFFF) ~= 0 then
    		print(string.format("WARNING: irom0 section offset is 0x%08x. ELF is probably linked for 'elf2image --version=2'" ,irom_offs))
    	end
    	--local iromfilename = string.format("0x%05x.bin",irom_offs);
    	--local f = io.open(iromfilename,"wb");
    	--f:write(irondata);
    	--f:close();
    	
    	--do
    	local resource_data = write_resource_file()
    	--end

    	local rodatastart = e:get_symbol_addr("_rodata_start");
    	print("rodata start", rodatastart)

    	local totalsize = irom_offs+#irondata;
    	print("data offset is", totalsize)
    	image:modify_segment(rodatastart, e:get_symbol_addr("FS_START_OFFSET")-rodatastart, string.pack("<I",totalsize))
    	--local src = io.open("0x00000.bin","rb");
    	local data = image:dumpdata();

    	print("ram used:", #data)
    	----local data = src:read("a");
    	--src:close();
    	f = io.open("app.bin","wb");
    	f:write(data);
    	local fillfflen = irom_offs - #data;
    	while fillfflen > 0 do
    		if fillfflen>=4 then
    			f:write("\xff\xff\xff\xff")
    			fillfflen = fillfflen -4
    		elseif fillfflen>=3 then
    			f:write("\xff\xff\xff")
    			fillfflen = fillfflen -3
			elseif fillfflen>=2 then
				f:write("\xff\xff")
				fillfflen = fillfflen -2
			else
				f:write("\xff")
				fillfflen = fillfflen -1
    		end
    	end

    	f:write(irondata);
    	f:write(resource_data)
    	f:close()

    else
    	image:save(string.format("app-0x%06x.bin",irom_offs & ~(ESP_FLASH_SECTOR - 1 )));
    end

    --print("efl flash start pos", e:get_symbol_addr("FS_START_OFFSET")-0x3ffe8000)
    --print("efl flash start pos", e:get_symbol_addr("_get_file_count"))
    local filelist = {};
    list_fs_filelist("../fs/",filelist)
    print("done!")
end