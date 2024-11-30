local ffi = require("ffi")
local bit = require("bit")

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
	typedef const void *LPCVOID;

	struct HKEY__ { int unused; };
	typedef struct HKEY__ *HKEY;
	typedef const CHAR *LPCSTR, *PCSTR;
	typedef DWORD *LPDWORD;
	typedef void *PVOID;
	typedef LONG LSTATUS;

	typedef void * HMODULE;

	DWORD GetLastError();

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

	LSTATUS RegGetValueW(
		HKEY    hkey,
		LPCWSTR lpSubKey,
		LPCWSTR lpValue,
		DWORD   dwFlags,
		LPDWORD pdwType,
		PVOID   pvData,
		LPDWORD pcbData
	);

	HMODULE LoadLibraryW(
		LPCWSTR lpLibFileName
	);

	DWORD FormatMessageW(
		DWORD   dwFlags,
		LPCVOID lpSource,
		DWORD   dwMessageId,
		DWORD   dwLanguageId,
		LPWSTR  lpBuffer,
		DWORD   nSize,
		va_list *Arguments
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

-- https://learn.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-getlasterror

---@return integer
function winapi.get_last_error()
	return ffi.C.GetLastError()
end

-- https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-formatmessagew

local error_buf_size = 1024
local error_buf = ffi.new("wchar_t[?]", error_buf_size)

---@param msg integer
---@return string
function winapi.format_message_from_system(msg)
	-- FORMAT_MESSAGE_FROM_SYSTEM
	local wchars = ffi.C.FormatMessageW(0x00001000, nil, msg, 0, error_buf, error_buf_size, nil)

	if wchars == 0 then
		return winapi.format_message_from_system(winapi.get_last_error())
	end

	return winapi.to_string(error_buf)
end

-- https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-loadlibraryw

---@param path string
function winapi.load_library(path)
	local h = ffi.C.LoadLibraryW(winapi.to_wchar_t(path))
	if h == nil then
		local err = winapi.get_last_error()
		error(("cannot load module '%s': %s"):format(path, winapi.format_message_from_system(err)))
	end
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

-- https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/freopen-s-wfreopen-s?view=msvc-170

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

-- https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-createwaitabletimerexw

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

-- https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-reggetvaluew

winapi.hkey = {
	HKEY_CLASSES_ROOT = 0x80000000,
	HKEY_CURRENT_USER = 0x80000001,
	HKEY_LOCAL_MACHINE = 0x80000002,
	HKEY_USERS = 0x80000003,
	HKEY_PERFORMANCE_DATA = 0x80000004,
	HKEY_PERFORMANCE_TEXT = 0x80000050,
	HKEY_PERFORMANCE_NLSTEXT = 0x80000060,
	HKEY_CURRENT_CONFIG = 0x80000005,
	HKEY_DYN_DATA = 0x80000006,
	HKEY_CURRENT_USER_LOCAL_SETTINGS = 0x80000007,
}

winapi.rrf = {
	RRF_RT_REG_NONE = 0x00000001,
	RRF_RT_REG_SZ = 0x00000002,
	RRF_RT_REG_EXPAND_SZ = 0x00000004,
	RRF_RT_REG_BINARY = 0x00000008,
	RRF_RT_REG_DWORD = 0x00000010,
	RRF_RT_REG_MULTI_SZ = 0x00000020,
	RRF_RT_REG_QWORD = 0x00000040,
	RRF_RT_DWORD = bit.bor(0x00000008, 0x00000010),
	RRF_RT_QWORD = bit.bor(0x00000008, 0x00000040),
	RRF_RT_ANY = 0x0000ffff,

	RRF_NOEXPAND = 0x10000000,
	RRF_ZEROONFAILURE = 0x20000000,
	RRF_SUBKEY_WOW6464KEY = 0x00010000,
	RRF_SUBKEY_WOW6432KEY = 0x00020000,
	RRF_WOW64_MASK = 0x00030000,
}

---@param hkey integer
---@param sub_key string?
---@param value string?
---@param flags integer
---@return ffi.cdata*?
---@return string|integer?
function winapi.get_reg_value(hkey, sub_key, value, flags)
	local buf_size = ffi.new("DWORD[1]")

	local hkey_p = ffi.cast("void*", hkey)
	local wsub_key = sub_key and winapi.to_wchar_t(sub_key)
	local wvalue = value and winapi.to_wchar_t(value)

	local status = ffi.C.RegGetValueW(hkey_p, wsub_key, wvalue, flags, nil, nil, buf_size)
	if status == 2 then  -- ERROR_FILE_NOT_FOUND
		return nil, "not found"
	end
	assert(status == 0)

	local buf = ffi.new("unsigned char[?]", buf_size[0])

	status = ffi.C.RegGetValueW(hkey_p, wsub_key, wvalue, flags, nil, buf, buf_size)
	assert(status == 0)

	return buf, buf_size[0]
end

---@param hkey integer
---@param sub_key string?
---@param value string?
---@return string?
---@return string?
function winapi.get_reg_value_sz(hkey, sub_key, value)
	local flags = winapi.rrf.RRF_RT_REG_SZ

	local buf, size =  winapi.get_reg_value(hkey, sub_key, value, flags)
	if not buf then
		return nil, size
	end

	if size == 0 then
		return
	end

	return winapi.to_string(ffi.cast("void*", buf))
end

return winapi
