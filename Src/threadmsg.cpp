#include "threadmsg.h"

#ifdef LINUX
#include <linux/limits.h> 
#include <unistd.h>
#include <strings.h>
#define stricmp strcasecmp
#include <sys/sysinfo.h>
#endif
#ifdef WIN32
#include <windows.h>

#endif
#ifdef MAC
#include <sys/types.h>
#include <sys/sysctl.h>
#endif

#include <thread>
#include <string>
#include <queue>
#include <mutex>
#include <list>
#include <functional>
struct NotifyInfo
{
	NotifyInfo()
	{
		thread = nullptr;
	}
	bool ok;
	std::string output;
	int fun;
	std::thread* thread;

};
std::list<NotifyInfo*> results;
std::mutex result_lock;


class ThreadWrap
{
public:

	ThreadWrap()
	{
		m_exit = false;
		m_fun = nullptr;

		m_thread = new std::thread(std::bind(&ThreadWrap::run, this));
	}

	template<typename FUN>
	void setRunFun(const FUN& t)
	{
		if (m_fun)
			return;
		m_fun = new std::function<void()>(t);
	}
	bool hasWork()
	{
		return !!m_fun;
	}
	void run()
	{
		std::chrono::milliseconds dura(10);

		while (!m_exit)
		{
			if (m_fun)
			{
				(*m_fun)();
				m_fun = NULL;
			}
			std::this_thread::sleep_for(dura);
		}
	}

	std::thread* m_thread;
	std::function<void()>* m_fun;
	bool m_exit;
};

std::list<ThreadWrap*> thread_pool;
template<typename T>
ThreadWrap* get_thread(const T& f)
{
	for (auto tw : thread_pool)
	{
		if (!tw->hasWork())
		{
			tw->setRunFun(f);
			return tw;
		}
	}
	auto pThread = new ThreadWrap();
	pThread->setRunFun(f);
	thread_pool.push_back(pThread);
	return pThread;
}

std::string lua_tostdstring(lua_State* L, int idx)
{
	size_t l;
	auto p = lua_tolstring(L, -1, &l);
	return std::string(p, l);

}

#ifdef MAC
int luaapi_mac_execmd(lua_State* L);
#endif

int luaapi_newthread(lua_State* L)
{
	size_t l;
	const char* s = lua_tolstring(L, 1, &l);
	if (!s)
		return 0;

	NotifyInfo* notifyinfo = new NotifyInfo();
	std::string chunkname;
	int nfunidx = 2;
	if (lua_isstring(L, 2))
	{
		chunkname = lua_tostring(L, 2);
		nfunidx++;
	}
	else
	{
		chunkname = s;
		if (chunkname.length() > 256)
		{
			chunkname.resize(253);
			chunkname += "...";
		}
	}
	if (lua_isfunction(L, nfunidx))
	{
		lua_pushvalue(L, nfunidx);
		notifyinfo->fun = luaL_ref(L, LUA_REGISTRYINDEX);
	}
	else
	{
		notifyinfo->fun = 0;
	}

	std::string param;
	if (lua_isstring(L, nfunidx + 1))
	{
		param = lua_tostdstring(L, nfunidx + 1);
	}

	std::string ss = std::string(s, l);

	get_thread([=]()
	{

		lua_State* newL = luaL_newstate();
		luaL_openlibs(newL);

#ifdef MAC
		lua_pushcfunction(newL, luaapi_mac_execmd);
		lua_setglobal(newL, "mac_execmd");
#endif

		lua_getglobal(newL, "debug");
		lua_getfield(newL, -1, "traceback");
		lua_remove(newL, 1);


		if (luaL_loadbuffer(newL, ss.c_str(), ss.length(), chunkname.c_str()) != 0)
		{
			notifyinfo->ok = false;
			notifyinfo->output = lua_tostring(newL, -1);
			result_lock.lock();
			results.push_back(notifyinfo);
			result_lock.unlock();
			//const char* pErr = lua_tostring(L, -1);
			//printf("err:%s", pErr);
			return 0;
		}

		lua_pushlstring(newL, param.c_str(), param.length());
		lua_setglobal(newL, "arg");
		if (lua_pcall(newL, 0, 1, 1) != 0)
		{
			notifyinfo->ok = false;
			notifyinfo->output = lua_tostring(newL, -1);
			result_lock.lock();
			results.push_back(notifyinfo);
			result_lock.unlock();
			//printf("error:\n%s\n", lua_tostring(L, -1));
			return 0;
		}

		notifyinfo->ok = true;
		if (lua_isstring(newL, -1))
		{
			notifyinfo->output = lua_tostdstring(newL, -1);
		}

		result_lock.lock();
		results.push_back(notifyinfo);
		result_lock.unlock();
		lua_close(newL);

		return 0;
	});



	lua_pushboolean(L, true);


	return 1;

}

int luaapi_dispatch_thread_msg(lua_State* L)
{
	while (results.size() > 0)
	{
		result_lock.lock();
		auto pResult = results.front();
		results.pop_front();
		result_lock.unlock();

		if (pResult->fun)
		{
			lua_rawgeti(L, LUA_REGISTRYINDEX, pResult->fun);
			lua_pushboolean(L, pResult->ok);
			lua_pushlstring(L, pResult->output.c_str(), pResult->output.length());
			lua_call(L, 2, 0);

			luaL_unref(L, LUA_REGISTRYINDEX, pResult->fun);
		}
		if (pResult->thread)
		{
			delete pResult->thread;
		}
		delete pResult;

	}
	std::chrono::milliseconds dura(10);
	
	std::this_thread::sleep_for(dura);

	//sleepms(10);
	return 0;
}

int luaapi_getprocesscount(lua_State* L)
{
#ifdef WIN32

	SYSTEM_INFO systeminfo;
	GetSystemInfo(&systeminfo);
	//return (int)systeminfo.dwNumberOfProcessors;
	lua_pushinteger(L, systeminfo.dwNumberOfProcessors);
	return 1;
#elif defined(MAC)
    int count;
    size_t count_len = sizeof(count);
    sysctlbyname("hw.logicalcpu", &count, &count_len, NULL, 0);
    lua_pushinteger(L,count);
    return 1;
#else
	lua_pushinteger(L, get_nprocs());

	return 1;
#endif
}

int lua_open_threadmsg(lua_State* L)
{
	lua_pushcfunction(L, luaapi_newthread);
	lua_setglobal(L, "newthread");
	lua_pushcfunction(L, luaapi_dispatch_thread_msg);
	lua_setglobal(L, "dispatchthreadmsg");
	lua_pushcfunction(L, luaapi_getprocesscount);
	lua_setglobal(L, "getprocesscount");
	return 0;
}
