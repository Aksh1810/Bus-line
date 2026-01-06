
import ActivityKit
import Foundation

struct BusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var arrivalTime: Int
    }

    var busId: String
}
