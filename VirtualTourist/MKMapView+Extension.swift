//
//  MKMapView+Extension.swift
//  VirtualTourist
//
//  Created by Gunel Aydinova on 6/16/24.
//

import MapKit

extension MKMapView {
    
    func addPin(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
         let annotation = MKPointAnnotation()
         annotation.coordinate = coordinate
         annotation.title = title
         annotation.subtitle = subtitle
         self.addAnnotation(annotation)
     }
     
     func addPins(pinLocations: [PinLocation]) {
         self.removeAnnotations(self.annotations)
         var annotations = [MKPointAnnotation]()
         for pin in pinLocations {
             let latitude = CLLocationDegrees(pin.latitude)
             let longitude = CLLocationDegrees(pin.longitude)
             let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
             let annotation = MKPointAnnotation()
             annotation.coordinate = coordinate
             annotations.append(annotation)
         }
         self.addAnnotations(annotations)
     }
}
