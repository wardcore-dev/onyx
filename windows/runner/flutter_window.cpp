#include "flutter_window.h"

#include <optional>
#include <shellapi.h>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include "notification_popup.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Setup MethodChannel to receive performance commands from Dart (Windows)
  performance_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.wardcore.onyx/performance",
      &flutter::StandardMethodCodec::GetInstance());

  performance_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();
        if (method == "enableHighPerformanceMode") {
          // Try to boost process/thread priority for smoother rendering
          ::SetPriorityClass(::GetCurrentProcess(), HIGH_PRIORITY_CLASS);
          ::SetThreadPriority(::GetCurrentThread(), THREAD_PRIORITY_HIGHEST);
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });

  // Setup MethodChannel for notification popups
  notification_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.onyx.messenger/notifications",
      &flutter::StandardMethodCodec::GetInstance());

  notification_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();
        
        if (method == "showNotification") {
          try {
            const auto& arguments = std::get<flutter::EncodableMap>(*call.arguments());
            const auto& username      = std::get<std::string>(arguments.at(flutter::EncodableValue("username")));
            const auto& displayName   = std::get<std::string>(arguments.at(flutter::EncodableValue("displayName")));
            const auto& message       = std::get<std::string>(arguments.at(flutter::EncodableValue("message")));
            const auto& displayDurationMs = std::get<int32_t>(arguments.at(flutter::EncodableValue("displayDurationMs")));

            // Helper: extract optional string argument
            auto getString = [&](const char* key, const std::string& def) -> std::string {
              auto i = arguments.find(flutter::EncodableValue(key));
              if (i != arguments.end() && !i->second.IsNull()) {
                return std::get<std::string>(i->second);
              }
              return def;
            };

            std::string surfaceColor          = getString("surfaceColor",          "1c1b1f");
            std::string onSurfaceColor        = getString("onSurfaceColor",        "e6e1e5");
            std::string onSurfaceVariantColor = getString("onSurfaceVariantColor", "cac4d0");
            std::string avatarColor           = getString("avatarColor",           "4a6741");
            std::string avatarLetterColor     = getString("avatarLetterColor",     "ffffff");
            std::string primaryColor          = getString("primaryColor",          "d39aff");
            std::string messageColor          = getString("messageColor",          "cac4d0");
            std::string position              = getString("position",              "bottom_right");

            ShowNotificationPopup(username, displayName, message, displayDurationMs,
                                  surfaceColor, onSurfaceColor, onSurfaceVariantColor,
                                  avatarColor, avatarLetterColor, primaryColor,
                                  messageColor, position);
            result->Success();
          } catch (const std::exception& e) {
            result->Error("NOTIFICATION_ERROR", std::string("Failed to show notification: ") + e.what());
          }
        } else if (method == "updateAvatar") {
          try {
            const auto& arguments = std::get<flutter::EncodableMap>(*call.arguments());
            auto it = arguments.find(flutter::EncodableValue("avatarBytes"));
            if (it != arguments.end() && !it->second.IsNull()) {
              const auto& bytes = std::get<std::vector<uint8_t>>(it->second);
              UpdateNotificationAvatar(bytes);
            }
            result->Success();
          } catch (...) {
            result->Success(); // avatar update is best-effort
          }
        } else if (method == "closeNotification") {
          CloseNotificationPopup();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  // Forward native notification taps back to Dart via the same channel
  SetOnNotificationTapped([this](const std::string& username) {
    try {
      flutter::EncodableMap args;
      args[flutter::EncodableValue("username")] = flutter::EncodableValue(username);
      notification_channel_->InvokeMethod("onNotificationTapped",
                                         std::make_unique<flutter::EncodableValue>(args));
    } catch (...) {
      // swallow errors — tapping the popup shouldn't crash the host
    }
  });

  // Setup MethodChannel for clipboard image reading
  clipboard_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "onyx/clipboard",
      &flutter::StandardMethodCodec::GetInstance());

  clipboard_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getClipboardImage") {
          auto bytes = GetClipboardImageBytes();
          if (!bytes.empty()) {
            result->Success(flutter::EncodableValue(bytes));
          } else {
            result->Success(flutter::EncodableValue());
          }
        } else if (call.method_name() == "getClipboardFilePaths") {
          auto paths = GetClipboardFilePaths();
          flutter::EncodableList list;
          for (const auto& p : paths) {
            list.push_back(flutter::EncodableValue(p));
          }
          result->Success(flutter::EncodableValue(list));
        } else if (call.method_name() == "readContentUri") {
          // Not supported on Windows
          result->Success(flutter::EncodableValue());
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

std::vector<std::string> FlutterWindow::GetClipboardFilePaths() {
  std::vector<std::string> paths;
  if (!::OpenClipboard(nullptr)) return paths;

  // CF_HDROP — files copied in Windows Explorer (Ctrl+C on files/folders)
  HANDLE h_data = ::GetClipboardData(CF_HDROP);
  if (h_data) {
    HDROP h_drop = static_cast<HDROP>(::GlobalLock(h_data));
    if (h_drop) {
      UINT count = ::DragQueryFileW(h_drop, 0xFFFFFFFF, nullptr, 0);
      for (UINT i = 0; i < count; i++) {
        UINT len = ::DragQueryFileW(h_drop, i, nullptr, 0);
        if (len > 0) {
          std::wstring wpath(len + 1, L'\0');
          ::DragQueryFileW(h_drop, i, wpath.data(), static_cast<UINT>(wpath.size()));
          wpath.resize(len);
          int utf8_len = ::WideCharToMultiByte(CP_UTF8, 0, wpath.c_str(), -1,
                                               nullptr, 0, nullptr, nullptr);
          if (utf8_len > 1) {
            std::string utf8(utf8_len - 1, '\0');
            ::WideCharToMultiByte(CP_UTF8, 0, wpath.c_str(), -1,
                                  &utf8[0], utf8_len, nullptr, nullptr);
            paths.push_back(utf8);
          }
        }
      }
      ::GlobalUnlock(h_data);
    }
  }

  ::CloseClipboard();
  return paths;
}

std::vector<uint8_t> FlutterWindow::GetClipboardImageBytes() {
  std::vector<uint8_t> bytes;
  if (!::OpenClipboard(nullptr)) return bytes;

  // Try "PNG" custom format (Chrome, Firefox, and most browsers register this)
  UINT png_format = ::RegisterClipboardFormat(L"PNG");
  HANDLE h_data = ::GetClipboardData(png_format);

  if (h_data) {
    LPVOID ptr = ::GlobalLock(h_data);
    if (ptr) {
      SIZE_T size = ::GlobalSize(h_data);
      const uint8_t* raw = static_cast<const uint8_t*>(ptr);
      bytes.assign(raw, raw + size);
      ::GlobalUnlock(h_data);
    }
  }

  ::CloseClipboard();
  return bytes;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
