#include <string>
#include <algorithm>
#include <Windows.h>
#include <vector>
int WinRunCmd(const char* cmd, std::string& sOutput)
{
	if (strcmp(cmd, "cd") == 0)
	{
		char buf[4096];
		GetCurrentDirectory(sizeof(buf), buf);
		sOutput = buf;
		sOutput += "\n";
		return 0;
	}
	SECURITY_ATTRIBUTES sa = { sizeof(SECURITY_ATTRIBUTES) };
	sa.bInheritHandle = TRUE;
	HANDLE hRead, hWrite;
	HANDLE hStdInRead, hStdInWrite;
	DWORD buffSize = 1024 * 1024;
	CreatePipe(&hRead, &hWrite, &sa, buffSize);
	CreatePipe(&hStdInRead, &hStdInWrite, &sa, buffSize);
	STARTUPINFO si;
	ZeroMemory(&si, sizeof(si));
	si.cb = sizeof(si);
	si.wShowWindow = SW_SHOW;
	si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;// | STARTF_USECOUNTCHARS;
	si.wShowWindow = SW_HIDE;

	si.hStdOutput = hWrite;
	si.hStdError = hWrite;
	si.hStdInput = hStdInRead;

	HANDLE hJob = CreateJobObject(NULL, NULL);
	DWORD flags = 0;
	PROCESS_INFORMATION processInfo;
	std::string sCmd = cmd;
	//for (int i = 0; i < sCmd.size(); i++)
	//{
	//	if (sCmd[i] == '/')
	//	{
	//		sCmd[i] = '\\';
	//	}
	//}

	if (!CreateProcess(NULL, (LPSTR)sCmd.data(), NULL, NULL, TRUE, flags, NULL, NULL, &si, &processInfo))
	{
		sCmd = std::string("C:\\Windows\\System32\\cmd /c ") + sCmd;
		if (!CreateProcess(NULL, (LPSTR)sCmd.data(), NULL, NULL, TRUE, flags, NULL, NULL, &si, &processInfo))
		{
			CloseHandle(hRead);
			CloseHandle(hWrite);
			return -1;

		}
		
	}

	if (!AssignProcessToJobObject(hJob, processInfo.hProcess))
	{
		printf("ProcessToJob Error!\r\n");
	}
	else
	{
		JOBOBJECT_EXTENDED_LIMIT_INFORMATION limit_info;
		memset(&limit_info, 0x0, sizeof(limit_info));
		limit_info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
		// job句柄回收时，所有加入job的进程都会强制结束。
		if (!SetInformationJobObject(
			hJob,
			JobObjectExtendedLimitInformation,
			&limit_info,
			sizeof(limit_info)))
		{
			printf("SetInformationJobObject Error!\r\n");
		}
	}
	std::vector<char> tempBuff(1024*64);
	DWORD exitCode = 0;

	auto readpipe = [&]()
	{
		DWORD totalBytesAvail;
		DWORD bytesLeftThisMessage;

		if (!PeekNamedPipe(hRead, NULL, 0, NULL, &totalBytesAvail, &bytesLeftThisMessage))
		{
			::Sleep(1);
			return;
		}
		auto readcount = std::min<DWORD>(tempBuff.size(), totalBytesAvail);
		if (readcount == 0)
		{
			::Sleep(1);
			return;
		}
		DWORD readedCount;
		ReadFile(hRead, tempBuff.data(), readcount, &readedCount, NULL);
		if (readedCount)
			sOutput.append(tempBuff.data(), readedCount);
	};

	do
	{
		readpipe();
		//return readedCount;
	} while (::GetExitCodeProcess(processInfo.hProcess, &exitCode) && exitCode == STILL_ACTIVE);
	readpipe();
	if (hJob)
	{
		CloseHandle(hJob);
	}
	CloseHandle(processInfo.hProcess);
	CloseHandle(hRead);
	CloseHandle(hWrite);
	return exitCode;
}