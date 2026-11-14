#include <flutter_windows.h>

extern "C" {
__declspec(dllexport) void JustAudioWindowsPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {}
__declspec(dllexport) void PermissionHandlerWindowsPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {}
__declspec(dllexport) void ScreenRetrieverPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {}
__declspec(dllexport) void UrlLauncherWindowsRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {}
__declspec(dllexport) void WindowManagerPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {}
}
