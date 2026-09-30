#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Créer un mutex pour garantir une seule instance de l'application
  HANDLE hMutex = CreateMutex(NULL, TRUE, L"PharmaGestSingleInstanceMutex");
  
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    // Une instance est déjà en cours d'exécution
    // Trouver et activer la fenêtre existante
    HWND hwnd = FindWindow(NULL, L"PharmaGest");
    if (hwnd != NULL) {
      // Restaurer la fenêtre si elle est minimisée
      if (IsIconic(hwnd)) {
        ShowWindow(hwnd, SW_RESTORE);
      }
      // Mettre la fenêtre au premier plan
      SetForegroundWindow(hwnd);
    }
    
    // Fermer cette instance
    if (hMutex) {
      ReleaseMutex(hMutex);
      CloseHandle(hMutex);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"PharmaGest", origin, size)) {
    // Libérer le mutex en cas d'échec
    if (hMutex) {
      ReleaseMutex(hMutex);
      CloseHandle(hMutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // Libérer le mutex à la fermeture
  if (hMutex) {
    ReleaseMutex(hMutex);
    CloseHandle(hMutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}

