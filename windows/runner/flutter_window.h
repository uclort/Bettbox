#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

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
  
  // Setup app method channel
  void SetupAppMethodChannel();
  
  // Set window icon
  bool SetWindowIcon(bool use_dark_icon);
  
  // Update desktop and start menu shortcuts icon
  void UpdateShortcutsIcon(bool use_dark_icon);

  // Save icon preference
  void SaveIconPreference(bool use_dark_icon);
  
  // Load icon preference
  bool LoadIconPreference();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
