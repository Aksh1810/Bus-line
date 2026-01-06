import ActivityKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  var currentActivity: Activity<BusActivityAttributes>?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let busChannel = FlutterMethodChannel(
      name: "com.busline/live_activity",
      binaryMessenger: controller.binaryMessenger)

    busChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if #available(iOS 16.1, *) {
        switch call.method {
        case "startActivity":
          guard let args = call.arguments as? [String: Any],
            let busId = args["busId"] as? String,
            let status = args["status"] as? String,
            let arrivalTime = args["arrivalTime"] as? Int
          else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
          }
          self.startActivity(busId: busId, status: status, arrivalTime: arrivalTime, result: result)

        case "updateActivity":
          guard let args = call.arguments as? [String: Any],
            let status = args["status"] as? String,
            let arrivalTime = args["arrivalTime"] as? Int
          else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
          }
          self.updateActivity(status: status, arrivalTime: arrivalTime, result: result)

        case "stopActivity":
          self.stopActivity(result: result)

        default:
          result(FlutterMethodNotImplemented)
        }
      } else {
        result(
          FlutterError(
            code: "UNAVAILABLE", message: "Live Activities not available on this version",
            details: nil))
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @available(iOS 16.1, *)
  private func startActivity(busId: String, status: String, arrivalTime: Int, result: FlutterResult)
  {
    let attributes = BusActivityAttributes(busId: busId)
    let contentState = BusActivityAttributes.ContentState(status: status, arrivalTime: arrivalTime)

    let activityContent = ActivityContent(state: contentState, staleDate: nil)

    do {
      let activity = try Activity.request(
        attributes: attributes, content: activityContent, pushType: nil)
      self.currentActivity = activity
      result(nil)
      print("Live Activity Started: \(activity.id)")
    } catch {
      result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
    }
  }

  @available(iOS 16.1, *)
  private func updateActivity(status: String, arrivalTime: Int, result: FlutterResult) {
    guard let activity = currentActivity else {
      result(FlutterError(code: "NO_ACTIVITY", message: "No active Live Activity", details: nil))
      return
    }

    let contentState = BusActivityAttributes.ContentState(status: status, arrivalTime: arrivalTime)
    let activityContent = ActivityContent(state: contentState, staleDate: nil)

    Task {
      await activity.update(activityContent)
      result(nil)
    }
  }

  @available(iOS 16.1, *)
  private func stopActivity(result: FlutterResult) {
    guard let activity = currentActivity else {
      result(nil)  // No activity to stop is fine
      return
    }

    let contentState = activity.content.state  // Keep last state
    let activityContent = ActivityContent(state: contentState, staleDate: nil)

    Task {
      await activity.end(activityContent, dismissalPolicy: .immediate)
      self.currentActivity = nil
      result(nil)
    }
  }
}
