#include <stdio.h>
#include <sys/stat.h>
#include <string.h>
#ifdef LINUX

#include <linux/limits.h> 
#include <unistd.h>
#include <strings.h>
#define stricmp strcasecmp
#include <sys/sysinfo.h>
#endif
#ifdef MAC
#include <unistd.h>
#include <strings.h>
#include <spawn.h>
#define stricmp strcasecmp

#include <mach-o/dyld.h>
#endif

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

#ifdef WIN32
#include <windows.h>
#define S_ISDIR(flag) (_S_IFDIR &(flag))
#endif
#include <thread>
#include <string>
#include <queue>
#include <mutex>
#include <list>
#include "threadmsg.h"

void getfilepath(char* path)
{
	char* plasts = 0;
	for (; *path; ++path)
	{
		if (*path == '/'||*path=='\\')
			plasts = path;
	}
	if (plasts)
		*plasts = 0;
}

void sleepms(int ms)
{
#ifdef WIN32
	::Sleep(ms);
#else
	std::chrono::milliseconds dura(ms);
	std::this_thread::sleep_for(dura);
#endif
}

int luaapi_getfilepath(lua_State* L)
{
	const char* sPath = lua_tostring(L, 1);
	if (!sPath)
		return 0;
	//printf("path is %s", sPath);
	char buf[1024] = { 0 };
	sprintf(buf, "%s", sPath);

	getfilepath(buf);
	//printf("after path is %s", sPath);
	lua_pushstring(L, buf);
	return 1;
}

int luaapi_getpathtype(lua_State* L)
{
	const char* sPath = lua_tostring(L, 1);
	struct stat buf;
	if (stat(sPath, &buf) != 0)
		return 0;
	if (S_ISDIR(buf.st_mode))
	{
		lua_pushstring(L, "dir");
		lua_pushinteger(L, buf.st_nlink);
		return 2;
	}
	else
	{
		lua_pushstring(L, "file");
		lua_pushinteger(L, buf.st_size);
	}
	return 2;
}

int luaapi_getfiledate(lua_State* L)
{
	const char* sPath = lua_tostring(L, 1);
	struct stat buf;
	if (stat(sPath, &buf) != 0)
		return 0;
	lua_pushinteger(L, buf.st_mtime);
	lua_pushinteger(L, buf.st_ctime);
	lua_pushinteger(L, buf.st_atime);
	return 3;
}
#if defined(MAC) || defined(WIN32)

int luaapi_sys_execmd(lua_State* L);
#endif

int luaapi_gettime_ms(lua_State* L)
{
#ifdef LINUX
	timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);
	lua_pushinteger(L, now.tv_sec * 1000ull + now.tv_nsec / 1000000);
#elif defined(MAC)
	timeval tv;
	gettimeofday(&tv, NULL);
	lua_pushinteger(L, tv.tv_sec * 1000ull + tv.tv_nsec / 1000);
#else
	long long curCounter;
	long long freq;
	QueryPerformanceFrequency((LARGE_INTEGER*)&freq);
	QueryPerformanceCounter((LARGE_INTEGER*)&curCounter);
	freq /= 1000;
	lua_pushinteger(L, curCounter / freq);
#endif
	return 1;
}

//
//int luaapi_getprocesscount(lua_State* L)
//{
//#ifdef WIN32
//
//	SYSTEM_INFO systeminfo;
//	GetSystemInfo(&systeminfo);
//	//return (int)systeminfo.dwNumberOfProcessors;
//	lua_pushinteger(L, systeminfo.dwNumberOfProcessors);
//	return 1;
//#else
//	lua_pushinteger(L, get_nprocs());
//
//	return 1;
//#endif
//}

//struct 

//std::queue<std::pair<bool, std::string>> results;


int luaapi_standardpath(lua_State* L)
{
	size_t l = 0;
	const char* sPath = lua_tolstring(L, 1, &l);
	char* standardp = (char*)malloc(l);
	memcpy(standardp, sPath, l);
	for (int i = 0; i < l; i++)
	{
#ifdef WIN32
		if (standardp[i] == '/')
			standardp[i] = '\\';
#else
		if (standardp[i] == '\\')
			standardp[i] = '/';
#endif
	}
	lua_pushlstring(L, standardp, l);
	free(standardp);
	return 1;
}
char dir[4096] = { 0 };

static int require_loader(lua_State* L)
{
	char path[4096] = { 0 };

	size_t sl;
	const char* pfilename = lua_tolstring(L, 1, &sl);
	if (pfilename == NULL)
		return 0;
	printf("require file:%s\n", pfilename);

	if(sl>4 && stricmp(pfilename+sl-3,"lua")==0)
		sprintf(path, "%s/%s", dir, pfilename);
	else
		sprintf(path, "%s/%s.lua", dir, pfilename);


	FILE* fp = fopen(path, "rb");
	if (fp == NULL)
	{
		printf("require file not found!%s\n", path);
		return 0;
	}
	fseek(fp, 0, SEEK_END);
	size_t len = ftell(fp);
	char* pdata = (char*)malloc(len+1);
	fseek(fp, 0, SEEK_SET);

	fread(pdata, 1, len, fp);
	fclose(fp);
	pdata[len] = 0;

	int r = luaL_loadbuffer(L, pdata, len, pfilename);
	free(pdata);
	if (r == 0)
		return 1;
	else
	{
		const char* sErr = lua_tostring(L, -1);
		lua_error(L);
		return 0;
	}
}

int lua_crc32(lua_State* L);

int lua_stringbuilder(lua_State* L);
int lua_checksum(lua_State* L);
int lua_open_threadmsg(lua_State* L);
int lua_chdir(lua_State* L);

static std::mutex* g_pLuaPOpenLock;

int main(int argc, char** argv)
{
	printf("luamake version:10\n");
	g_pLuaPOpenLock = new std::mutex();
	lua_State* L = luaL_newstate();
	luaL_openlibs(L);

	//lua_getglobal(L, "package");
	//lua_pushstring(L, "searchers");
	//lua_rawget(L,-2);

	luaL_loadstring(L, "return function(f) package.searchers[#package.searchers+1] = f print('require_loader add') end");

	if (lua_pcall(L,0,1,0))
	{
		const char* pErr = lua_tostring(L, -1);
		printf("err:%s", pErr);
		return -1;
	}
	lua_pushcfunction(L, require_loader);
	if (lua_pcall(L, 1, 0, 0))
	{
		const char* pErr = lua_tostring(L, -1);
		printf("err:%s", pErr);
		return -1;
	}

#if defined(LINUX)
	
	int n = readlink("/proc/self/exe", dir, 4096);
	//printf("PATH_MAX: %d\n", 4096);
	printf("readlink return: %d\n", n);
	printf("dir: %s\n", dir);
#elif defined(MAC)
 
    uint32_t size = sizeof(dir);
    int res = _NSGetExecutablePath(dir,&size);

#else
	
	GetModuleFileName(NULL, dir, sizeof(dir));

#endif
	char path[4096] = {0};
	getfilepath(dir);
	sprintf(path, "%s/main.lua", dir);

	lua_pushstring(L, dir);
	lua_setglobal(L, "luamakeroot");

	lua_pushcfunction(L, luaapi_getfiledate);
	lua_setglobal(L, "getfiledate");
	lua_pushcfunction(L, luaapi_getpathtype);
	lua_setglobal(L, "getpathtype");
	lua_pushcfunction(L, luaapi_getfilepath);
	lua_setglobal(L, "getfilepath");
	lua_pushcfunction(L, luaapi_standardpath);
	lua_setglobal(L, "standardpath");

	lua_pushcfunction(L, luaapi_gettime_ms);
	lua_setglobal(L, "gettimems");

#if defined(MAC) || defined(WIN32)
	lua_pushcfunction(L, luaapi_sys_execmd);
	lua_setglobal(L, "sys_execmd");
#endif

	lua_pushcfunction(L, lua_chdir);
	lua_setglobal(L, "chdir");

	printf("path is %s\n", path);


	lua_open_threadmsg(L);

	lua_pushcfunction(L, lua_crc32);
	lua_setglobal(L, "crc32");

	lua_pushcfunction(L, lua_stringbuilder);
	lua_setglobal(L, "stringbuilder");

	lua_pushcfunction(L, lua_checksum);
	lua_setglobal(L, "checksum");

#ifdef WIN32
	lua_pushstring(L, "windows");
#elif defined(LINUX)
	lua_pushstring(L, "linux");
#elif defined(MAC)
    lua_pushstring(L, "mac");
#endif
	lua_setglobal(L, "build_platform");

	lua_getglobal(L,"debug");
	lua_getfield(L, -1, "traceback");
	lua_remove(L, 1);
	if (lua_gettop(L) != 1)
	{
		printf("gettop error! %d\n", lua_gettop(L));
		return 1;
	}
	int r = luaL_loadfile(L, path);
	if (r != 0)
	{
		printf("error:\n%s\n", lua_tostring(L, -1));
		return r;
	}
	int argnum = 0;

	lua_newtable(L);

	
	for (int i = 1; i < argc; i++)
	{
		lua_pushstring(L, argv[i]);
		lua_rawseti(L, -2, i);
		argnum++;
	}
	lua_setglobal(L, "arg");
	r = lua_pcall(L, 0, 0, 1);
	delete g_pLuaPOpenLock;
	if (r != 0)
	{
#ifdef WIN32
		Sleep(1000);
#endif
		printf("error[%d]:\n%s\n",r, lua_tostring(L, -1));
		return r;
	}
	lua_close(L);

	return 0;
}


static const unsigned long crcTable[256] = {
	0x00000000,0x77073096,0xEE0E612C,0x990951BA,0x076DC419,0x706AF48F,0xE963A535,
	0x9E6495A3,0x0EDB8832,0x79DCB8A4,0xE0D5E91E,0x97D2D988,0x09B64C2B,0x7EB17CBD,
	0xE7B82D07,0x90BF1D91,0x1DB71064,0x6AB020F2,0xF3B97148,0x84BE41DE,0x1ADAD47D,
	0x6DDDE4EB,0xF4D4B551,0x83D385C7,0x136C9856,0x646BA8C0,0xFD62F97A,0x8A65C9EC,
	0x14015C4F,0x63066CD9,0xFA0F3D63,0x8D080DF5,0x3B6E20C8,0x4C69105E,0xD56041E4,
	0xA2677172,0x3C03E4D1,0x4B04D447,0xD20D85FD,0xA50AB56B,0x35B5A8FA,0x42B2986C,
	0xDBBBC9D6,0xACBCF940,0x32D86CE3,0x45DF5C75,0xDCD60DCF,0xABD13D59,0x26D930AC,
	0x51DE003A,0xC8D75180,0xBFD06116,0x21B4F4B5,0x56B3C423,0xCFBA9599,0xB8BDA50F,
	0x2802B89E,0x5F058808,0xC60CD9B2,0xB10BE924,0x2F6F7C87,0x58684C11,0xC1611DAB,
	0xB6662D3D,0x76DC4190,0x01DB7106,0x98D220BC,0xEFD5102A,0x71B18589,0x06B6B51F,
	0x9FBFE4A5,0xE8B8D433,0x7807C9A2,0x0F00F934,0x9609A88E,0xE10E9818,0x7F6A0DBB,
	0x086D3D2D,0x91646C97,0xE6635C01,0x6B6B51F4,0x1C6C6162,0x856530D8,0xF262004E,
	0x6C0695ED,0x1B01A57B,0x8208F4C1,0xF50FC457,0x65B0D9C6,0x12B7E950,0x8BBEB8EA,
	0xFCB9887C,0x62DD1DDF,0x15DA2D49,0x8CD37CF3,0xFBD44C65,0x4DB26158,0x3AB551CE,
	0xA3BC0074,0xD4BB30E2,0x4ADFA541,0x3DD895D7,0xA4D1C46D,0xD3D6F4FB,0x4369E96A,
	0x346ED9FC,0xAD678846,0xDA60B8D0,0x44042D73,0x33031DE5,0xAA0A4C5F,0xDD0D7CC9,
	0x5005713C,0x270241AA,0xBE0B1010,0xC90C2086,0x5768B525,0x206F85B3,0xB966D409,
	0xCE61E49F,0x5EDEF90E,0x29D9C998,0xB0D09822,0xC7D7A8B4,0x59B33D17,0x2EB40D81,
	0xB7BD5C3B,0xC0BA6CAD,0xEDB88320,0x9ABFB3B6,0x03B6E20C,0x74B1D29A,0xEAD54739,
	0x9DD277AF,0x04DB2615,0x73DC1683,0xE3630B12,0x94643B84,0x0D6D6A3E,0x7A6A5AA8,
	0xE40ECF0B,0x9309FF9D,0x0A00AE27,0x7D079EB1,0xF00F9344,0x8708A3D2,0x1E01F268,
	0x6906C2FE,0xF762575D,0x806567CB,0x196C3671,0x6E6B06E7,0xFED41B76,0x89D32BE0,
	0x10DA7A5A,0x67DD4ACC,0xF9B9DF6F,0x8EBEEFF9,0x17B7BE43,0x60B08ED5,0xD6D6A3E8,
	0xA1D1937E,0x38D8C2C4,0x4FDFF252,0xD1BB67F1,0xA6BC5767,0x3FB506DD,0x48B2364B,
	0xD80D2BDA,0xAF0A1B4C,0x36034AF6,0x41047A60,0xDF60EFC3,0xA867DF55,0x316E8EEF,
	0x4669BE79,0xCB61B38C,0xBC66831A,0x256FD2A0,0x5268E236,0xCC0C7795,0xBB0B4703,
	0x220216B9,0x5505262F,0xC5BA3BBE,0xB2BD0B28,0x2BB45A92,0x5CB36A04,0xC2D7FFA7,
	0xB5D0CF31,0x2CD99E8B,0x5BDEAE1D,0x9B64C2B0,0xEC63F226,0x756AA39C,0x026D930A,
	0x9C0906A9,0xEB0E363F,0x72076785,0x05005713,0x95BF4A82,0xE2B87A14,0x7BB12BAE,
	0x0CB61B38,0x92D28E9B,0xE5D5BE0D,0x7CDCEFB7,0x0BDBDF21,0x86D3D2D4,0xF1D4E242,
	0x68DDB3F8,0x1FDA836E,0x81BE16CD,0xF6B9265B,0x6FB077E1,0x18B74777,0x88085AE6,
	0xFF0F6A70,0x66063BCA,0x11010B5C,0x8F659EFF,0xF862AE69,0x616BFFD3,0x166CCF45,
	0xA00AE278,0xD70DD2EE,0x4E048354,0x3903B3C2,0xA7672661,0xD06016F7,0x4969474D,
	0x3E6E77DB,0xAED16A4A,0xD9D65ADC,0x40DF0B66,0x37D83BF0,0xA9BCAE53,0xDEBB9EC5,
	0x47B2CF7F,0x30B5FFE9,0xBDBDF21C,0xCABAC28A,0x53B39330,0x24B4A3A6,0xBAD03605,
	0xCDD70693,0x54DE5729,0x23D967BF,0xB3667A2E,0xC4614AB8,0x5D681B02,0x2A6F2B94,
	0xB40BBE37,0xC30C8EA1,0x5A05DF1B,0x2D02EF8D
};

static unsigned long Crc32_ComputeBuf(unsigned long inCrc32, const void *buf, size_t bufLen) {
	
	unsigned long crc32;
	unsigned char *byteBuf;
	size_t i;

	/** accumulate crc32 for buffer **/
	crc32 = inCrc32 ^ 0xFFFFFFFF;
	byteBuf = (unsigned char*)buf;
	for (i = 0; i < bufLen; i++) {
		crc32 = (crc32 >> 8) ^ crcTable[(crc32 ^ byteBuf[i]) & 0xFF];
	}
	return crc32 ^ 0xFFFFFFFF;
}

int lua_crc32(lua_State* L)
{
	unsigned long inCrc32 = 0;

	unsigned long crc32;
	size_t bufLen;
	if (lua_gettop(L) == 2)
	{
		inCrc32 = (lua_Unsigned)lua_tointegerx(L, 2, NULL);
	}
	auto byteBuf = lua_tolstring(L, 1, &bufLen);
	
	
	
	crc32 = inCrc32 ^ 0xFFFFFFFF;
	for (int i = 0; i < bufLen; i++) {
		crc32 = (crc32 >> 8) ^ crcTable[(crc32 ^ byteBuf[i]) & 0xFF];
	}
	lua_pushinteger(L, crc32 ^ 0xFFFFFFFF);
	return 1;
}

unsigned char check_sum_state = 0;
int lua_checksum(lua_State* L)
{
	size_t bufLen;
	auto byteBuf = lua_tolstring(L, 1, &bufLen);

	if (lua_gettop(L) == 2 && lua_isinteger(L, 2))
	{
		check_sum_state = lua_tointeger(L,2);
	}
	for (size_t i = 0; i < bufLen; i++)
	{
		check_sum_state ^= byteBuf[i];
	}

	lua_pushinteger(L, check_sum_state);

	return 1;
}


int stringbuildermeta = 0;

int lua_stringbuilder_append(lua_State* L);
int lua_stringbuilder_clear(lua_State* L);
int lua_stringbuilder_tostring(lua_State* L);
int lua_stringbuilder_gc(lua_State* L);

int lua_stringbuilder(lua_State* L)
{
	int resever = 1024;

	if (lua_gettop(L) == 1)
	{
		resever = lua_tointeger(L, 1);
	}

	std::vector<char>* buffer = new( lua_newuserdata(L,sizeof(std::vector<char>))) std::vector<char>();
	buffer->reserve(1024);
	//lua_pushlightuserdata(L, buffer);
	if (!stringbuildermeta)
	{
		lua_createtable(L, 0, 5);
		lua_pushstring(L,"append");
		lua_pushcfunction(L, lua_stringbuilder_append);
		lua_rawset(L, -3);

		lua_pushstring(L, "clear");
		lua_pushcfunction(L, lua_stringbuilder_clear);
		lua_rawset(L, -3);

		lua_pushstring(L, "tostring");
		lua_pushcfunction(L, lua_stringbuilder_tostring);
		lua_rawset(L, -3);

		lua_pushstring(L, "__gc");
		lua_pushcfunction(L, lua_stringbuilder_gc);
		lua_rawset(L, -3);

		lua_pushstring(L, "__index");
		lua_pushvalue(L, -2);
		lua_rawset(L, -3);
		stringbuildermeta = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	lua_rawgeti(L, LUA_REGISTRYINDEX, stringbuildermeta);

	
	lua_setmetatable(L, -2);

	return 1;
}

int lua_stringbuilder_append(lua_State* L)
{

	std::vector<char>* buffer = (std::vector<char>*)lua_touserdata(L, 1);
	size_t len = 0;
	
	int nparmnum = lua_gettop(L)-1;
	if (nparmnum <= 0)
		return 0;
	auto appendoldsize = buffer->size();
	const char* s = lua_tolstring(L, 2, &len);
	int repeatcount = 1;
	if (nparmnum == 2 && lua_isinteger(L, 3))
	{
		repeatcount = lua_tointeger(L, 3);
	}

	if (len)
	{
		if (repeatcount > 1)
		{

			while (repeatcount > 0)
			{
				buffer->reserve(buffer->size() + len);
				buffer->insert(buffer->end(), s, (s + len));
				repeatcount--;
			}
		}
		else
		{
			for (int i = 0; i < nparmnum; i++)
			{
				s = lua_tolstring(L, 2+i, &len);
				buffer->reserve(buffer->size() + len);
				buffer->insert(buffer->end(), s, (s + len));
			}
		}
	}
	lua_pushinteger(L, buffer->size()- appendoldsize);
	return 1;
}
int lua_stringbuilder_clear(lua_State* L)
{
	std::vector<char>* buffer = (std::vector<char>*)lua_touserdata(L, 1);
	buffer->clear();
	return 0;

}
int lua_stringbuilder_tostring(lua_State* L)
{
	std::vector<char>* buffer = (std::vector<char>*)lua_touserdata(L, 1);
	lua_pushlstring(L, &(*buffer)[0], buffer->size());
	return 1;
}
int lua_stringbuilder_gc(lua_State* L)
{
	std::vector<char>* buffer = (std::vector<char>*)lua_touserdata(L, 1);
	//delete buffer;
	buffer->~vector();
	return 0;
}


int lua_chdir(lua_State* L)
{
	if (lua_gettop(L) < 1)
	{
		return 0;
	}
	auto dir = lua_tostring(L, 1);
#if defined(LINUX)||defined(MAC)
	chdir(dir);
#else
	SetCurrentDirectory(dir);
#endif
	
	lua_pushboolean(L, 1);
	return 1;
}




#if defined(MAC) || defined(WIN32)
#ifdef MAC
int MacRunCmd(const char* cmd,std::string& sOutput);
#else
int WinRunCmd(const char* cmd, std::string& sOutput);
#endif
int luaapi_sys_execmd(lua_State* L)
{



	const char* sCMD = lua_tostring(L, 1);

	std::string result;
#ifdef MAC
	auto status = MacRunCmd(sCMD, result);
#else
	auto status = WinRunCmd(sCMD, result);
#endif

	lua_pushinteger(L, status);
	lua_pushlstring(L, result.c_str(), result.length());
	//printf("exe %s:%d\n%s\n", sCMD, status, result.c_str());

    return 2;
}
#endif

