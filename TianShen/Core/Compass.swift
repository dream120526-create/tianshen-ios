import CoreLocation
import Combine
import Foundation

/// 磁方位角，只用于 HUD 显示和雷达朝向。
final class Compass: NSObject, ObservableObject {
    @Published private(set) var heading: Double = 0
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 2
    }

    func start() {
        guard CLLocationManager.headingAvailable() else { return }
        manager.startUpdatingHeading()
    }

    func stop() {
        manager.stopUpdatingHeading()
    }
}

extension Compass: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.magneticHeading
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { false }
}
