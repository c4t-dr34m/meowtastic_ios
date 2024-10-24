import Combine
import FirebaseAnalytics
import Foundation
import MapKit
import OSLog
import SwiftProtobuf
import SwiftUI

struct AppSettings: View {
	@Environment(\.managedObjectContext)
	private var context
	@State
	private var isPresentingCoreDataResetConfirm = false
	@State
	private var isPresentingDeleteMapTilesConfirm = false
	@State
	private var lowBatteryNotifications = UserDefaults.lowBatteryNotifications
	@State
	private var channelMessageNotifications = UserDefaults.channelMessageNotifications
	@State
	private var newNodeNotifications = UserDefaults.newNodeNotifications
	@State
	private var bcgNotification = UserDefaults.bcgNotification
	@State
	private var moreColors = UserDefaults.moreColors

	var body: some View {
		Form {
			Section(header: Text("Notifications")) {
				Toggle(isOn: $lowBatteryNotifications) {
					Text("Low Battery")
				}
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))
				.onChange(of: lowBatteryNotifications) {
					UserDefaults.lowBatteryNotifications = lowBatteryNotifications
				}

				Toggle(isOn: $channelMessageNotifications) {
					Text("New Channel Message")
				}
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))
				.onChange(of: channelMessageNotifications) {
					UserDefaults.channelMessageNotifications = channelMessageNotifications
				}

				Toggle(isOn: $newNodeNotifications) {
					Text("Node Discovered")
				}
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))
				.onChange(of: newNodeNotifications) {
					UserDefaults.newNodeNotifications = newNodeNotifications
				}

				VStack(alignment: .leading, spacing: 8) {
					Toggle(isOn: $bcgNotification) {
						Text("Background Update Summary")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					.onChange(of: bcgNotification) {
						UserDefaults.bcgNotification = bcgNotification
					}

					Text("Show number of visible nodes when background update finishes. Not very useful, but hey... you can have it.")
						.font(.callout)
						.foregroundColor(.gray)
				}
			}

			Section(header: Text("Look & Feel")) {
				Toggle(isOn: $moreColors) {
					Text("More Colors")
				}
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))
				.onChange(of: moreColors) {
					UserDefaults.moreColors = moreColors
				}
			}

			Section(header: Text("Settings")) {
				Button("Open Settings", systemImage: "gear") {
					if let url = URL(string: UIApplication.openSettingsURLString) {
						UIApplication.shared.open(url)
					}
				}
			}
		}
		.navigationTitle("App Settings")
		.navigationBarItems(
			trailing: ConnectionInfo()
		)
		.onAppear {
			Analytics.logEvent(AnalyticEvents.optionsAppSettings.id, parameters: nil)
		}
	}
}
