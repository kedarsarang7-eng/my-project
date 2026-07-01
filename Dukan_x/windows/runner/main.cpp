#define _CRT_SECURE_NO_WARNINGS

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h>
#include <cstdio>
#include <ctime>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

// ============================================================================
// Native crash logger — writes to %APPDATA%\Myvyaparmitra\logs\native_crash.log
// This catches failures that occur BEFORE the Dart VM starts (missing DLLs,
// window creation failures, SEH exceptions, etc.)
// ============================================================================
static void LogNativeEvent(const char* message) {
  char appDataPath[MAX_PATH];
  if (SUCCEEDED(SHGetFolderPathA(nullptr, CSIDL_APPDATA, nullptr, 0, appDataPath))) {
    std::string logDir = std::string(appDataPath) + "\\Myvyaparmitra\\logs";
    CreateDirectoryA((std::string(appDataPath) + "\\Myvyaparmitra").c_str(), nullptr);
    CreateDirectoryA(logDir.c_str(), nullptr);

    std::string logPath = logDir + "\\native_crash.log";
    FILE* f = fopen(logPath.c_str(), "a");
    if (f) {
      time_t now = time(nullptr);
      char timeBuf[64];
      strftime(timeBuf, sizeof(timeBuf), "%Y-%m-%d %H:%M:%S", localtime(&now));
      fprintf(f, "[%s] %s\n", timeBuf, message);
      fflush(f);
      fclose(f);
    }
  }
}

// RunApplication has local variables that require destructor/unwinding.
// Separating it from wWinMain prevents C2712 error when wWinMain uses __try.
static int RunApplication(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                          _In_ wchar_t *command_line, _In_ int show_command) {
  LogNativeEvent("Myvyaparmitra native startup begin");

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  LogNativeEvent("COM initialized");

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));
  LogNativeEvent("DartProject configured, creating window...");

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Myvyaparmitra", origin, size)) {
    LogNativeEvent("FATAL: Window creation failed! Possible causes: "
                   "missing flutter_windows.dll, missing data/ folder, "
                   "missing VC++ runtime, or antivirus blocking.");
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  LogNativeEvent("Window created successfully, entering message loop");

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  LogNativeEvent("Message loop exited normally");
  ::CoUninitialize();
  return EXIT_SUCCESS;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Wrap entire startup in SEH to catch native crashes.
  // Since wWinMain itself has no C++ objects that require destructor unwinding,
  // we can safely use __try and __except here.
  __try {
    return RunApplication(instance, prev, command_line, show_command);
  } __except(EXCEPTION_EXECUTE_HANDLER) {
    // Native structured exception — the process is crashing
    char buf[256];
    snprintf(buf, sizeof(buf),
             "FATAL SEH EXCEPTION: code=0x%08lX. Likely cause: missing DLL, "
             "corrupted binary, or access violation during startup.",
             GetExceptionCode());
    LogNativeEvent(buf);
    return EXIT_FAILURE;
  }
}
