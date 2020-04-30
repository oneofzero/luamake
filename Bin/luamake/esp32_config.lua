local toolroot = [[D:\esp32\]]
local toolpath = toolroot .. [[xtensa-esp32-elf\bin\]]
esp_efl_tool_path = toolpath
esp32_config = true
local esp32include = toolroot .. [[xtensa-esp32-elf\xtensa-esp32-elf\include\]]
return function (proj)
	
			proj.compiler = toolpath .. "/xtensa-esp32-elf-gcc.exe";
			proj.cxx_compiler = toolpath .. "/xtensa-esp32-elf-g++.exe";
			proj.ar = toolpath .. "/xtensa-esp32-elf-ar.exe";
			proj.linker =proj.compiler
			proj:AddIncludePath(esp32include)
			proj:AddLibPath(toolroot..[[esp-idf-v3.2\lib\]])
			--proj:AddIncludePath(toolroot..[[esp-idf-v3.2\sdkconfig\]])
			--proj:AddFlag("-DESP_PLATFORM -MMD -MP")
			proj:AddFlag("-DESP_PLATFORM -Os -Wpointer-arith -Wundef -Wl,-EL -fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals -ffunction-sections  -fno-jump-tables -fdata-sections -DAT_UPGRADE_SUPPORT -DICACHE_FLASH -DLUA_OPTIMIZE_MEMORY=2")
			proj:AddLinkFlag("-nostdlib -Wl,-EL -Wl,--no-check-sections -Wl,--gc-sections -u call_user_start_cpu0 -Wl,-static -Wl,--no-undefined -fPIC ")
			proj:AddLinkFlag("-T"..toolroot.."esp-idf-v3.2/components/esptool_py/esptool/flasher_stub/rom_32.ld")
			function proj:AddComponent(name) 
				self:AddIncludePath(toolroot.."esp-idf-v3.2/components/"..name.."/include/");
				
			end

end