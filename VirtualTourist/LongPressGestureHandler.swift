//
//  LongPressGestureHandler.swift
//  VirtualTourist
//
//  Created by Gunel Aydinova on 6/16/24.
//

import UIKit
import MapKit

class LongPressGestureHandler: NSObject, UIGestureRecognizerDelegate {

    private weak var mapView: MKMapView?
    private weak var dataController: DataController?

    init(mapView: MKMapView, dataController: DataController) {
        self.mapView = mapView
        self.dataController = dataController
        super.init()
        setupLongPressGesture()
    }

    private func setupLongPressGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.delegate = self
        longPressGesture.minimumPressDuration = 2
        mapView?.addGestureRecognizer(longPressGesture)
        mapView?.isScrollEnabled = true
        mapView?.isZoomEnabled = true
        mapView?.showsCompass = true
        mapView?.showsTraffic = true
        print("Long press gesture recognizer added to map view.")
    }

    @objc private func handleLongPress(_ gestureRecognizer: UIGestureRecognizer) {
        guard let mapView = mapView, let dataController = dataController else { return }

        if gestureRecognizer.state != .began {
            return
        }
        let touchPoint = gestureRecognizer.location(in: mapView)
        let touchCoordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        let annotation = MKPointAnnotation()
        annotation.title = "Latitude: \(touchCoordinate.latitude)"
        annotation.subtitle = "Longitude: \(touchCoordinate.longitude)"
        annotation.coordinate = touchCoordinate
        let pinLocation = PinLocation(context: dataController.viewContext)
        pinLocation.latitude = touchCoordinate.latitude
        pinLocation.longitude = touchCoordinate.longitude
        do {
            try dataController.viewContext.save()
            print("New pin saved at coordinates: \(touchCoordinate.latitude), \(touchCoordinate.longitude).")
        } catch {
            print("Failed to save new pin at coordinates: \(touchCoordinate.latitude), \(touchCoordinate.longitude) - Error: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            mapView.addPin(coordinate: touchCoordinate, title: annotation.title, subtitle: annotation.subtitle)
        }
    }
}
