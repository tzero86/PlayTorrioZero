#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shobjidl.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

namespace {

// Reads the saved renderer backend ("skia" or "impeller") from the
// shared_preferences JSON file written by the Dart side
// (lib/services/diagnostics/renderer_backend.dart). The Windows
// shared_preferences plugin stores
// `%APPDATA%\<CompanyName>\<ProductName>\shared_preferences.json`
// (Runner.rc: CompanyName "tzero86"; ProductName "zplay"; the executable
// name is the fallback), with keys prefixed `flutter.`. The candidate paths
// below mirror that layout.
// Anything missing or unparseable falls back to "skia": measured A/B on
// this machine felt faster on Skia, and the Impeller run coincided with
// an NVIDIA driver crash notice.
std::string ReadSavedRendererBackend() {
  wchar_t* appdata = nullptr;
  size_t count = 0;
  if (_wdupenv_s(&appdata, &count, L"APPDATA") != 0 || appdata == nullptr) {
    return "skia";
  }
  std::wstring base(appdata);
  free(appdata);
  const wchar_t* candidates[] = {
      L"tzero86\\zplay\\shared_preferences.json",
      L"zplay\\shared_preferences.json",
  };
  for (const wchar_t* candidate : candidates) {
    std::ifstream file(base + L"\\" + candidate);
    if (!file.is_open()) {
      continue;
    }
    std::stringstream buffer;
    buffer << file.rdbuf();
    const std::string content = buffer.str();
    const std::string key = "\"flutter.renderer_backend\"";
    size_t pos = content.find(key);
    if (pos == std::string::npos) {
      continue;
    }
    pos = content.find(':', pos + key.size());
    if (pos == std::string::npos) {
      continue;
    }
    pos = content.find('"', pos + 1);
    if (pos == std::string::npos) {
      continue;
    }
    std::string value;
    for (size_t i = pos + 1; i < content.size() && content[i] != '"'; ++i) {
      if (content[i] == '\\' && i + 1 < content.size()) {
        value += content[++i];
      } else {
        value += content[i];
      }
    }
    if (value == "skia" || value == "impeller") {
      return value;
    }
  }
  return "skia";
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Give this process its own shell identity.
  //
  // ZPlay used to inherit upstream's CompanyName/ProductName version-info
  // identity verbatim, and this explicit AppUserModelID was added because a
  // binary advertising that same identity could be grouped by the shell with an
  // installed copy of the upstream app. The inherited identity is gone: Runner.rc
  // now reports tzero86\zplay, so both the version info and the
  // %APPDATA%\Roaming data directory are the fork's own. The explicit AUMID is
  // kept regardless - the shell does not derive its grouping key from the
  // version-info identity at all. Without an explicit AppUserModelID a Win32
  // process is grouped by an implicit identity derived from its shortcut/executable
  // path, so the separation would then depend on where each app happens to be
  // installed; setting one makes the identity explicit and stable across installs.
  ::SetCurrentProcessExplicitAppUserModelID(L"io.github.tzero86.zplay");

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Persistent renderer backend (default Skia on Windows): the release exe
  // bakes the platform default (Impeller), so the saved choice is applied
  // here, before the engine starts, via DartProject::set_impeller_switch.
  // See lib/services/diagnostics/renderer_backend.dart.
  bool use_skia = ReadSavedRendererBackend() != "impeller";
  for (const auto& arg : command_line_arguments) {
    if (arg == "--impeller" || arg == "--renderer=impeller") {
      use_skia = false;
    } else if (arg == "--skia" || arg == "--renderer=skia") {
      use_skia = true;
    }
  }
  project.set_impeller_switch(use_skia ? flutter::ImpellerSwitch::Disabled
                                       : flutter::ImpellerSwitch::Enabled);
  if (use_skia) {
    std::cout << "[Renderer] backend=skia (Skia, Impeller disabled)"
              << std::endl;
    OutputDebugStringA("[Renderer] backend=skia (Skia, Impeller disabled)");
  } else {
    std::cout << "[Renderer] backend=impeller (Impeller enabled)"
              << std::endl;
    OutputDebugStringA("[Renderer] backend=impeller (Impeller enabled)");
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Get screen dimensions
  int screen_width = GetSystemMetrics(SM_CXSCREEN);
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  // Set preferred size, but cap it to 90% of the screen size if the screen is smaller
  int window_width = 1440;
  int window_height = 900;

  if (window_width > screen_width * 0.9) {
    window_width = static_cast<int>(screen_width * 0.9);
  }
  if (window_height > screen_height * 0.9) {
    window_height = static_cast<int>(screen_height * 0.9);
  }

  // Center the window on screen
  int origin_x = (screen_width - window_width) / 2;
  int origin_y = (screen_height - window_height) / 2;

  Win32Window::Point origin(origin_x, origin_y);
  Win32Window::Size size(window_width, window_height);
  if (!window.Create(L"ZPlay", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
