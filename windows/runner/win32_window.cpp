#include "win32_window.h"

#include <flutter_windows.h>
#include "resource.h"

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() {
    UnregisterClassW(kWindowClassName, nullptr);
  }

  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  void Register(WNDPROC wnd_proc) {
    if (registered_) return;
    WNDCLASSEXW window_class{};
    window_class.cbSize = sizeof(WNDCLASSEXW);
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.lpfnWndProc = wnd_proc;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    RegisterClassExW(&window_class);
    registered_ = true;
  }

 private:
  static WindowClassRegistrar* instance_;
  bool registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

}  // namespace

Win32Window::Win32Window() {}

Win32Window::~Win32Window() {
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();
  WindowClassRegistrar::GetInstance()->Register(WndProc);

  HWND window = CreateWindowExW(
      10, kWindowClassName, title.c_str(),
      WS_OVERLAPPEDWINDOW,
      origin.x, origin.y, size.width, size.height,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) return false;
  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

void Win32Window::Destroy() {
  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
}

HWND Win32Window::GetHandle() const {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

RECT Win32Window::GetClientArea() const {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));
    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    that->window_handle_ = window;
  } else if (Win32Window* that = reinterpret_cast<Win32Window*>(
                 GetWindowLongPtr(window, GWLP_USERDATA))) {
    return that->MessageHandler(window, message, wparam, lparam);
  }
  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT Win32Window::MessageHandler(HWND hwnd,
                                    UINT const message,
                                    WPARAM const wparam,
                                    LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;
  }
  return DefWindowProc(window_handle_, message, wparam, lparam);
}

bool Win32Window::OnCreate() {
  return true;
}

void Win32Window::OnDestroy() {}
