//
//  DistanceText.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 8/19/22.
//

import SwiftUI
import CoreLocation
import MapKit

struct DistanceText: View {

	var meters: CLLocationDistance

	var body: some View {

		let distanceFormatter = MKDistanceFormatter()
		Text("\(distanceFormatter.string(fromDistance: Double(meters))) away")
	}
}
struct DistanceText_Previews: PreviewProvider {
	static var previews: some View {

		VStack {
			DistanceText(meters: 100)
			DistanceText(meters: 1000)
			DistanceText(meters: 10000)
			DistanceText(meters: 100000)
			DistanceText(meters: 1000000)
		}
	}
}
