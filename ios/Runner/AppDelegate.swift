import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 1. Call the dummy method to force Xcode to bundle the Rust C-bindings
    dummy_method_to_enforce_bundling()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 2. The dummy method itself
  func dummy_method_to_enforce_bundling() {
    // This is never actually executed, but it stops Xcode from stripping the FFI symbol
    store_dart_post_cobject(nil)
  }
}