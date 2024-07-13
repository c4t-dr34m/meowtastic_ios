//
//  PositionPopover.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 9/17/23.
//

import SwiftUI
import MapKit

struct PositionPopover: View {
	let distanceFormatter = MKDistanceFormatter()

	var position: PositionEntity
	var popover: Bool = true
	var delay: Double = 0

	@ObservedObject
	var locationsHandler = LocationsHandler.shared
	@Environment(\.managedObjectContext)
	var context
	@EnvironmentObject
	var bleManager: BLEManager

	@Environment(\.dismiss)
	private var dismiss
	@State
	private var scale: CGFloat = 0.5

	var body: some View {
		// Node Color from node.num
		let nodeColor = UIColor(hex: UInt32(position.nodePosition?.num ?? 0))

		VStack {
			HStack {
				ZStack {
					if position.nodePosition?.isOnline ?? false {
						Circle()
							.fill(
								Color(nodeColor.lighter())
									.opacity(0.4)
									.shadow(.drop(color: Color(nodeColor).isLight() ? .black : .white, radius: 5))
							)
							.foregroundStyle(Color(nodeColor.lighter()).opacity(0.3))
							.scaleEffect(scale)
							.animation(
								Animation.easeInOut(duration: 0.6)
									.repeatForever().delay(delay), value: scale
							)
							.onAppear {
								self.scale = 1
							}
							.frame(width: 90, height: 90)
					}

					Avatar(
						position.nodePosition?.user?.shortName ?? "?",
						background: Color(nodeColor),
						size: 65
					)
				}

				Text(position.nodePosition?.user?.longName ?? "Unknown")
					.font(.largeTitle)
			}

			Divider()

			HStack(alignment: .center) {
				VStack(alignment: .leading) {
					/// Time
					Label {
						Text("heard".localized + ":")
						LastHeardText(lastHeard: position.time)
							.foregroundColor(.primary)
					} icon: {
						Image(
							systemName: position.nodePosition?.isOnline ?? false ? "checkmark.circle.fill" : "moon.circle.fill"
						)
						.symbolRenderingMode(.hierarchical)
						.foregroundColor(position.nodePosition?.isOnline ?? false ? .green : .orange)
						.frame(width: 35)
					}
					.padding(.bottom, 5)

					/// Coordinate
					Label {
						Text("\(String(format: "%.6f", position.coordinate.latitude)), \(String(format: "%.6f", position.coordinate.longitude))")
							.textSelection(.enabled)
							.foregroundColor(.primary)
					} icon: {
						Image(systemName: "mappin.and.ellipse")
							.symbolRenderingMode(.hierarchical)
							.frame(width: 35)
					}
					.padding(.bottom, 5)

					/// Altitude
					Label {
						Text("Altitude: \(distanceFormatter.string(fromDistance: Double(position.altitude)))")
							.foregroundColor(.primary)
					} icon: {
						Image(systemName: "mountain.2.fill")
							.symbolRenderingMode(.hierarchical)
							.frame(width: 35)
					}
					.padding(.bottom, 5)

					/// Sats in view
					let pf = PositionFlags(rawValue: Int(position.nodePosition?.metadata?.positionFlags ?? 3))

					if pf.contains(.Satsinview) {
						Label {
							Text("Sats in view: \(String(position.satsInView))")
								.foregroundColor(.primary)
						} icon: {
							Image(systemName: "sparkles")
								.symbolRenderingMode(.hierarchical)
								.frame(width: 35)
						}
						.padding(.bottom, 5)
					}

					/// Sequence Number
					if pf.contains(.SeqNo) {
						Label {
							Text("Sequence: \(String(position.seqNo))")
								.foregroundColor(.primary)
						} icon: {
							Image(systemName: "number")
								.symbolRenderingMode(.hierarchical)
								.frame(width: 35)
						}
						.padding(.bottom, 5)
					}

					/// Heading
					let degrees = Angle.degrees(Double(position.heading))

					Label {
						let heading = Measurement(value: degrees.degrees, unit: UnitAngle.degrees)
						Text("Heading: \(heading.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))))")
					} icon: {
						Image(systemName: "location.north")
							.symbolRenderingMode(.hierarchical)
							.frame(width: 35)
							.rotationEffect(degrees)
					}
					.padding(.bottom, 5)

					/// Speed
					let speed = Measurement(value: Double(position.speed), unit: UnitSpeed.kilometersPerHour)

					Label {
						Text("Speed: \(speed.formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0)))))")
							.foregroundColor(.primary)
					} icon: {
						Image(systemName: "gauge.with.dots.needle.33percent")
							.symbolRenderingMode(.hierarchical)
							.frame(width: 35)
					}
					.padding(.bottom, 5)

					if position.nodePosition?.viaMqtt ?? false {
						Label {
							Text("MQTT")
						} icon: {
							Image(systemName: "network")
								.symbolRenderingMode(.hierarchical)
								.frame(width: 35)
								.rotationEffect(degrees)
						}
						.padding(.bottom, 5)
					}

					if let lastLocation = locationsHandler.locationsArray.last {
						/// Distance
						if lastLocation.distance(from: CLLocation(latitude: LocationsHandler.DefaultLocation.latitude, longitude: LocationsHandler.DefaultLocation.longitude)) > 0.0 {
							let metersAway = position.coordinate.distance(from: CLLocationCoordinate2D(latitude: lastLocation.coordinate.latitude, longitude: lastLocation.coordinate.longitude))

							Label {
								Text("distance".localized + ": \(distanceFormatter.string(fromDistance: Double(metersAway)))")
									.foregroundColor(.primary)
							} icon: {
								Image(systemName: "lines.measurement.horizontal")
									.symbolRenderingMode(.hierarchical)
									.frame(width: 35)
							}
						}
					}

					Spacer()
				}

				Spacer()

				VStack(alignment: .center) {
					if position.nodePosition != nil {
						if position.nodePosition?.favorite ?? false {
							Image(systemName: "star.fill")
								.foregroundColor(.yellow)
								.symbolRenderingMode(.hierarchical)
								.font(.largeTitle)
								.padding(.bottom, 5)
						}

						if position.nodePosition?.hasEnvironmentMetrics ?? false {
							Image(systemName: "cloud.sun.rain")
								.foregroundColor(.accentColor)
								.symbolRenderingMode(.multicolor)
								.font(.largeTitle)
								.padding(.bottom)
						}

						if position.nodePosition?.hasDetectionSensorMetrics ?? false {
							Image(systemName: "sensor.fill")
								.symbolEffect(.variableColor.reversing.cumulative, options: .repeat(20).speed(3))
								.symbolRenderingMode(.hierarchical)
								.foregroundColor(.accentColor)
								.font(.largeTitle)
								.padding(.bottom)
						}
					}

					BatteryGaugeView(node: position.nodePosition!)
				}

				LoRaSignalMeterView(
					snr: position.nodePosition?.snr ?? 0.0,
					rssi: position.nodePosition?.rssi ?? 0,
					preset: ModemPresets(rawValue: UserDefaults.modemPreset) ?? ModemPresets.longFast,
					compact: false
				)

				Spacer()
			}
		}
		.padding(.top)
		.presentationDetents([.fraction(0.65), .fraction(0.75), .fraction(0.85)])
		.presentationDragIndicator(.visible)
	}
}
