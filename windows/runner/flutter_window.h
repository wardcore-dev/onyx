#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // MethodChannel for performance actions (Windows)
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> performance_channel_;

  // MethodChannel for notification popups
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> notification_channel_;

  // MethodChannel for clipboard image access
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> clipboard_channel_;

  // Reads file paths from Windows clipboard (CF_HDROP, i.e. Explorer Ctrl+C)
  std::vector<std::string> GetClipboardFilePaths();

  // Reads PNG image bytes from Windows clipboard, returns empty vector if not available
  std::vector<uint8_t> GetClipboardImageBytes();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
