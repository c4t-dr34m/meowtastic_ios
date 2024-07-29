import SwiftUI
import Charts

struct BatteryGaugeView: View {
	@ObservedObject
	var node: NodeInfoEntity

	private let withLabels: Bool
	private let minValue = 0.0
	private let maxValue = 100.00
	private let gaugeGradient = Gradient(colors: [.red, .orange, .green])

	var body: some View {
		if let telemetries = node.telemetries {
			let deviceMetrics = telemetries.filtered(
				using: NSPredicate(format: "metricsType == 0")
			)
			let mostRecent = deviceMetrics.lastObject as? TelemetryEntity

			let batteryLevel = mostRecent?.batteryLevel
			let voltage = mostRecent?.voltage

			if let voltage, let batteryLevel, voltage > 0 || batteryLevel > 0 {
				HStack {
					if withLabels {
						if batteryLevel > 100 {
							Image(systemName: "powerplug.fill")
								.font(.footnote)
						}
						else {
							if batteryLevel <= 10 {
								Image(systemName: "battery.0percent")
									.font(.footnote)
							}
							else if batteryLevel <= 35 {
								Image(systemName: "battery.25percent")
									.font(.footnote)
							}
							else if batteryLevel <= 60 {
								Image(systemName: "battery.50percent")
									.font(.footnote)
							}
							else if batteryLevel <= 85 {
								Image(systemName: "battery.75percent")
									.font(.footnote)
							}
							else {
								Image(systemName: "battery.100percent")
									.font(.footnote)
							}
						}
					}

					Gauge(
						value: min(Double(batteryLevel), 100),
						in: minValue...maxValue
					) { }
						.gaugeStyle(.accessoryLinear)
						.tint(gaugeGradient)

					if withLabels {
						if let voltage = mostRecent?.voltage, voltage > 0, voltage <= 100 {
							let voltageFormatted = String(format: "%.1f", voltage) + "V"

							Text(voltageFormatted)
								.font(.footnote)
								.lineLimit(1)
								.minimumScaleFactor(0.5)
								.frame(width: 40)
						}
						else {
							let socFormatted = String(format: "%.0f", batteryLevel) + "%"

							Text(socFormatted)
								.font(.footnote)
								.lineLimit(1)
								.minimumScaleFactor(0.5)
								.frame(width: 40)
						}
					}
				}
			}
		}
		else {
			EmptyView()
		}
	}

	init(
		node: NodeInfoEntity,
		withLabels: Bool = false
	) {
		self.node = node
		self.withLabels = withLabels
	}
}