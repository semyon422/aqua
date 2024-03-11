local ffi = require("ffi")

-- https://learn.microsoft.com/ru-ru/windows/win32/winprog/windows-data-types
ffi.cdef[[
	typedef int BOOL;
	typedef unsigned int UINT;
	typedef unsigned long DWORD;
	typedef const char * LPCCH;  // ?
	typedef wchar_t WCHAR;
	typedef WCHAR *LPWSTR;
	typedef wchar_t * LPCWCH;  // ?
	typedef char CHAR;
	typedef CHAR * LPSTR;
	typedef char * LPCCH;  // ?
	typedef BOOL * LPBOOL;
	typedef void * HANDLE;  // ?
	typedef long LONG;  // ?
	typedef __int64 LONGLONG;  // ?
	typedef void * LPVOID;
	typedef const WCHAR * LPCWSTR;

	int MultiByteToWideChar(
		UINT CodePage,
		DWORD dwFlags,
		LPCCH lpMultiByteStr,
		int cbMultiByte,
		LPWSTR lpWideCharStr,
		int cchWideChar
	);
	int WideCharToMultiByte(
		UINT CodePage,
		DWORD dwFlags,
		LPCWCH lpWideCharStr,
		int cchWideChar,
		LPSTR lpMultiByteStr,
		int cbMultiByte,
		LPCCH lpDefaultChar,
		LPBOOL lpUsedDefaultChar
	);

	int _wgetenv_s(
		size_t *pReturnValue,
		wchar_t *buffer,
		size_t numberOfElements,
		const wchar_t *varname
	);
	int _wputenv_s(const wchar_t *varname, const wchar_t *value_string);
	int _wchdir(const wchar_t *dirname);
	wchar_t *_wgetcwd(wchar_t *buffer, int maxlen);
	int _wfreopen_s(void **stream, const wchar_t *fileName, const wchar_t *mode, void *oldStream);

	typedef union _LARGE_INTEGER {
		struct {
			DWORD LowPart;
			LONG  HighPart;
		} DUMMYSTRUCTNAME;
		struct {
			DWORD LowPart;
			LONG  HighPart;
		} u;
		LONGLONG QuadPart;
	} LARGE_INTEGER;

	typedef struct _SECURITY_ATTRIBUTES {
		DWORD  nLength;
		LPVOID lpSecurityDescriptor;
		BOOL   bInheritHandle;
	} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;

	// https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-createwaitabletimerexw
	HANDLE CreateWaitableTimerExW(
		LPSECURITY_ATTRIBUTES lpTimerAttributes,
		LPCWSTR               lpTimerName,
		DWORD                 dwFlags,
		DWORD                 dwDesiredAccess
	);

	typedef void (*PTIMERAPCROUTINE)(
		LPVOID lpArgToCompletionRoutine,
		DWORD dwTimerLowValue,
		DWORD dwTimerHighValue
	);

	BOOL SetWaitableTimer(
		HANDLE              hTimer,
		const LARGE_INTEGER *lpDueTime,
		LONG                lPeriod,
		PTIMERAPCROUTINE    pfnCompletionRoutine,
		LPVOID              lpArgToCompletionRoutine,
		BOOL                fResume
	);

	DWORD WaitForSingleObject(
		HANDLE hHandle,
		DWORD  dwMilliseconds
	);

	BOOL CloseHandle(
		HANDLE hObject
	);
]]

local winapi = {}

-- https://docs.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-multibytetowidechar

---@param s string
---@return ffi.cdata*
function winapi.to_wchar_t(s)
	local size = ffi.C.MultiByteToWideChar(65001, 0x8, s, #s, nil, 0)
	assert(size > 0, "conversion error")

	local buf = ffi.new("wchar_t[?]", size + 1)
	assert(ffi.C.MultiByteToWideChar(65001, 0x8, s, #s, buf, size) ~= 0, "conversion error")

	return buf
end

-- https://docs.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-widechartomultibyte

---@param w ffi.cdata*
---@return string
function winapi.to_string(w)
	local size = ffi.C.WideCharToMultiByte(65001, 0x80, w, -1, nil, 0, nil, nil)
	assert(size > 0, "conversion error")

	local buf = ffi.new("char[?]", size)
	assert(ffi.C.WideCharToMultiByte(65001, 0x80, w, -1, buf, size, nil, nil) ~= 0, "conversion error")

	return ffi.string(buf, size - 1)
end

-- https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/getenv-s-wgetenv-s?view=msvc-170

---@param name string
---@return string?
function winapi.getenv(name)
	local wname = winapi.to_wchar_t(name)

	local size_ptr = ffi.new("size_t[1]")

	assert(ffi.C._wgetenv_s(size_ptr, nil, 0, wname) == 0)
	if size_ptr[0] == 0 then
		return
	end

	local buf = ffi.new("wchar_t[?]", size_ptr[0])
	assert(ffi.C._wgetenv_s(size_ptr, buf, size_ptr[0], wname) == 0)

	return winapi.to_string(buf)
end

-- https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/putenv-s-wputenv-s?view=msvc-170

---@param name string
---@param value string
function winapi.putenv(name, value)
	assert(ffi.C._wputenv_s(winapi.to_wchar_t(name), winapi.to_wchar_t(value)) == 0)
end

-- https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/chdir-wchdir?view=msvc-170

---@param dir string
function winapi.chdir(dir)
	assert(ffi.C._wchdir(winapi.to_wchar_t(dir)) == 0)
end

-- https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/getcwd-wgetcwd?view=msvc-170

---@return string
function winapi.getcwd()
	local buf = ffi.C._wgetcwd(nil, 0)
	assert(buf ~= 0)
	return winapi.to_string(buf)
end

-- https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/getcwd-wgetcwd?view=msvc-170

---@param path string
---@param mode string?
---@return file*?
---@return string?
---@return number?
function winapi.open(path, mode)
	local file = assert(io.open("nul"))
	local stream = ffi.new("void*[1]")
	local err = ffi.C._wfreopen_s(stream, winapi.to_wchar_t(path), winapi.to_wchar_t(mode or "r"), file)
	if err ~= 0 then
		return nil, ("%s: %s"):format(path, select(2, file:close())), err
	end
	return file
end

local sleep_timer
local li_p = ffi.new("LARGE_INTEGER[1]")

---@param s number
function winapi.sleep(s)
	if not sleep_timer then
		-- CREATE_WAITABLE_TIMER_MANUAL_RESET | CREATE_WAITABLE_TIMER_HIGH_RESOLUTION
		-- TIMER_ALL_ACCESS (0x1F0003)
		sleep_timer = ffi.C.CreateWaitableTimerExW(nil, nil, 0x00000001 + 0x00000002, 0x1F0003)
		if sleep_timer == nil then
			print("error in CreateWaitableTimerW")
		end
		return
	end

	li_p[0].QuadPart = -s * 1e7  -- in 100ns
	if ffi.C.SetWaitableTimer(sleep_timer, li_p, 0, nil, nil, false) == 0 then
		return
	end
	ffi.C.WaitForSingleObject(sleep_timer, 4294967295)
end

return winapi
