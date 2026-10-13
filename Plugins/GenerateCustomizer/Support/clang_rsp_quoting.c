// Windows only. Stands in for clang when Swift links WebAssembly, and runs the real clang, whose
// path is in real-clang.txt next to this program, with --rsp-quoting=windows in front of its own
// arguments. The path is in a file because the build system runs the link with an environment of
// its own.
//
// The Swift driver passes the link's arguments to clang in a response file, with Windows paths, but
// only tells clang to read it with Windows quoting when the target is Windows. For WebAssembly,
// clang reads it with Unix quoting, where a backslash escapes the next character, so every path
// loses its backslashes. clang only looks for --rsp-quoting before it reads the file, so it can't
// be passed through Swift's own options, which end up in the file too.

#include <stdio.h>
#include <windows.h>
#include <wchar.h>

int wmain(void) {
    // real-clang.txt, in this program's directory, holds the real clang's path in UTF-8
    wchar_t configPath[MAX_PATH];
    DWORD length = GetModuleFileNameW(NULL, configPath, MAX_PATH);
    wchar_t *name = wcsrchr(configPath, L'\\');
    if (length == 0 || length >= MAX_PATH || !name || (name - configPath) + 16 >= MAX_PATH) return 1;
    wcscpy_s(name + 1, MAX_PATH - (name + 1 - configPath), L"real-clang.txt");

    char utf8[MAX_PATH * 3] = { 0 };
    FILE *config = NULL;
    _wfopen_s(&config, configPath, L"rb");
    size_t count = config ? fread(utf8, 1, sizeof(utf8) - 1, config) : 0;
    if (config) fclose(config);
    while (count > 0 && (utf8[count - 1] == '\n' || utf8[count - 1] == '\r')) utf8[--count] = 0;

    wchar_t realClang[MAX_PATH];
    if (count == 0 || MultiByteToWideChar(CP_UTF8, 0, utf8, -1, realClang, MAX_PATH) == 0) {
        fwprintf(stderr, L"%ls doesn't name the real clang\n", configPath);
        return 1;
    }

    // Everything after this program's own name in its command line, passed on unchanged
    const wchar_t *arguments = GetCommandLineW();
    if (*arguments == L'"') {
        arguments = wcschr(arguments + 1, L'"');
        arguments = arguments ? arguments + 1 : L"";
    } else {
        while (*arguments && *arguments != L' ' && *arguments != L'\t') arguments++;
    }

    size_t size = wcslen(realClang) + wcslen(arguments) + 64;
    wchar_t *commandLine = HeapAlloc(GetProcessHeap(), 0, size * sizeof(wchar_t));
    if (!commandLine) return 1;
    swprintf(commandLine, size, L"\"%ls\" --rsp-quoting=windows%ls", realClang, arguments);

    STARTUPINFOW startup = { .cb = sizeof(startup) };
    PROCESS_INFORMATION process;
    if (!CreateProcessW(realClang, commandLine, NULL, NULL, TRUE, 0, NULL, NULL, &startup, &process)) {
        fwprintf(stderr, L"Couldn't run %ls (error %lu)\n", realClang, GetLastError());
        return 1;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exitCode = 1;
    GetExitCodeProcess(process.hProcess, &exitCode);
    CloseHandle(process.hProcess);
    CloseHandle(process.hThread);
    return (int)exitCode;
}
