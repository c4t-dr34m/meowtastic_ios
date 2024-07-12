//
//  LocalMBTileOverlay.swift
//  MeshtasticApple
//
//  Copyright(c) Joshua Pirihi 16/01/22.
//

import UIKit
import MapKit
import SQLite
import OSLog

extension MKMapRect {
	init(coordinates: [CLLocationCoordinate2D]) {
		self = MKMapRect()
		var coordinates = coordinates
		if !coordinates.isEmpty {
			let first = coordinates.removeFirst()
			var top = first.latitude
			var bottom = first.latitude
			var left = first.longitude
			var right = first.longitude
			coordinates.forEach { coordinate in
				top = max(top, coordinate.latitude)
				bottom = min(bottom, coordinate.latitude)
				left = min(left, coordinate.longitude)
				right = max(right, coordinate.longitude)
			}
			let topLeft = MKMapPoint(CLLocationCoordinate2D(latitude: top, longitude: left))
			let bottomRight = MKMapPoint(CLLocationCoordinate2D(latitude: bottom, longitude: right))
			self = MKMapRect(x: topLeft.x, y: topLeft.y,
							 width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
		}
	}
}

enum MapTileError: Error {
	case invalidFormat
	case other
}

class LocalMBTileOverlay: MKTileOverlay {

	var path: String!
	var mb: Connection!
	private var _boundingMapRect: MKMapRect!
	override var boundingMapRect: MKMapRect {
		return _boundingMapRect
	}

	init?(mbTilePath path: String) {

		super.init(urlTemplate: nil)
		self.path = path
		do {
			self.mb = try Connection(self.path, readonly: true)
			let metadata = Table("metadata")

			let name = Expression<String>(value: "name")
			let value = Expression<String>(value: "value")

			// make sure it's raster
			let formatQuery = try mb.pluck(metadata.select(value).filter(name == "format"))
			if formatQuery?[value] == nil || (formatQuery![value] != "jpeg" && formatQuery![value] != "jpg" && formatQuery![value] != "png") {
				throw MapTileError.invalidFormat
			}

			let minZQuery = try mb.pluck(metadata.select(value).filter(name == "minzoom"))
			self.minimumZ = Int(minZQuery![value])!

			let maxZQuery = try mb.pluck(metadata.select(value).filter(name == "maxzoom"))
			self.maximumZ = Int(maxZQuery![value])!

			self.isGeometryFlipped = true

			let boundingBoxString = try mb.pluck(metadata.select(value).filter(name == "bounds"))
			let boundCoords = boundingBoxString![value].split(separator: ",")
			let coords = [
				CLLocationCoordinate2D(latitude: Double(boundCoords[1]) ?? 0,
									   longitude: Double(boundCoords[0]) ?? 0),
				CLLocationCoordinate2D(latitude: Double(boundCoords[3]) ?? 0,
									   longitude: Double(boundCoords[2]) ?? 0)
			]
			self._boundingMapRect = MKMapRect(coordinates: coords)

		} catch {
			Logger.services.error("Map tile error: \(error)")
			return nil
		}
	}

//	override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
//
//		let tileX = Int64(path.x)
//		let tileY = Int64(path.y)
//		let tileZ = Int64(path.z)
//		let tileData = Expression<SQLite.Blob>("tile_data")
//		let zoomLevel = Expression<Int64>("zoom_level")
//		let tileColumn = Expression<Int64>("tile_column")
//		let tileRow = Expression<Int64>("tile_row")
//
//		if let dataQuery = try? self.mb.pluck(Table("tiles").select(tileData).filter(zoomLevel == tileZ).filter(tileColumn == tileX).filter(tileRow == tileY)) {
//			let data = Data(bytes: dataQuery[tileData].bytes, count: dataQuery[tileData].bytes.count)// dataQuery![tileData].bytes
//			result(data, nil)
//		} else {
//			Logger.services.error("No tile here: x:\(tileX) y:\(tileY) z:\(tileZ)")
//			let error = NSError(domain: "LocalMBTileOverlay", code: 1, userInfo: ["reason": "no_tile"])
//			result(nil, error)
//		}
//	}
}

// public class CustomMapOverlaySource: MKTileOverlay {
//
//	// requires folder: tiles/{mapName}/z/y/y,{tileType}
//	private var parent: MapViewSwiftUI
//	private let mapName: String
//	private let tileType: String
//	private let defaultTile: DefaultTile?
//
//	public init(
//		parent: MapViewSwiftUI,
//		mapName: String,
//		tileType: String,
//		defaultTile: DefaultTile?
//	) {
//		self.parent = parent
//		self.mapName = mapName
//		self.tileType = tileType
//		self.defaultTile = defaultTile
//		super.init(urlTemplate: "")
//	}
//
//	public override func url(forTilePath path: MKTileOverlayPath) -> URL {
//		if let tileUrl = Bundle.main.url(
//			forResource: "\(path.y)",
//			withExtension: self.tileType,
//			subdirectory: "tiles/\(self.mapName)/\(path.z)/\(path.x)",
//			localization: nil
//		) {
//			return tileUrl
//		} else if let defaultTile = self.defaultTile, let defaultTileUrl = Bundle.main.url(
//			forResource: defaultTile.tileName,
//			withExtension: defaultTile.tileType,
//			subdirectory: "tiles/\(self.mapName)",
//			localization: nil
//		) {
//			return defaultTileUrl
//		} else {
//			let urlstring = self.mapName+"\(path.z)/\(path.x)/\(path.y).png"
//			return URL(string: urlstring)!
//		}
//	}
// }
