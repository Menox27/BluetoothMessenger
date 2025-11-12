import Flutter
import UIKit
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let hotspotChannel = "app.hotspot/configurator"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: hotspotChannel,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "joinChannel",
            let args = call.arguments as? [String: Any],
            let ssid = args["ssid"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }

      let password = args["password"] as? String
      let configuration: NEHotspotConfiguration
      if let password = password, !password.isEmpty {
        configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
      } else {
        configuration = NEHotspotConfiguration(ssid: ssid)
      }
      configuration.joinOnce = false

      NEHotspotConfigurationManager.shared.apply(configuration) { error in
        if let error = error {
          let nsError = error as NSError
          if nsError.domain == NEHotspotConfigurationErrorDomain &&
              nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
            result(true)
          } else {
            result(FlutterError(code: "HOTSPOT_ERROR", message: error.localizedDescription, details: nil))
          }
        } else {
          result(true)
        }
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
