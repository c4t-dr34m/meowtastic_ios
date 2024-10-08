import CoreBluetooth
import Foundation

public struct Device: Identifiable, Equatable {
	public var peripheral: CBPeripheral

	public var id: String
	public var num: Int64
	public var name: String
	public var shortName: String
	public var longName: String
	public var firmwareVersion: String
	public var rssi: Int
	public var lastUpdate: Date

	public static func == (lhs: Device, rhs: Device) -> Bool {
		lhs.id == rhs.id
	}

	public func getSignalStrength() -> BLESignalStrength {
		if rssi > -65 {
			return BLESignalStrength.strong
		}
		else if rssi > -85 {
			return BLESignalStrength.normal
		}
		else {
			return BLESignalStrength.weak
		}
	}
}
