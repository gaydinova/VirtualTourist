//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Gunel Aydinova on 6/6/24.
//

import Foundation
import UIKit
import MapKit
import CoreData

class TouristMapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    var dataController: DataController!
    var pinLocation: PinLocation!
    var pinFetchedResultsController: NSFetchedResultsController<PinLocation>?
    private var gestureHandler: LongPressGestureHandler?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        mapView.mapType = .standard
        gestureHandler = LongPressGestureHandler(mapView: mapView, dataController: dataController)
        setupFetchedResultsController()
        fetchPins()
    }
    
    func setupFetchedResultsController() {
        let fetchRequest: NSFetchRequest<PinLocation> = PinLocation.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "latitude", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        pinFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        pinFetchedResultsController?.delegate = self
    }
    
    func fetchPins() {
        guard let pinFetchedResultsController = pinFetchedResultsController else {
            print("Fetched results controller is not set up")
            return
        }
        
        do {
            try pinFetchedResultsController.performFetch()
            if let pins = pinFetchedResultsController.fetchedObjects {
                mapView.addPins(pinLocations: pins)
            }
        } catch {
            displayFetchErrorAlert(error: error)
        }
    }
    
    func displayFetchErrorAlert(error: Error) {
        showErrorAlert(title: "Error", message: "Unable to fetch pin locations from Core Data: \(error.localizedDescription)")
    }
    
    func showErrorAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
    
    func centerMapOnCoordinates(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate.latitude = latitude
        annotation.coordinate.longitude = longitude
        
        let coordinateSpan = MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        let region = MKCoordinateRegion(center: annotation.coordinate, span: coordinateSpan)
        mapView.addAnnotation(annotation)
        self.mapView.setRegion(region, animated: false)
        self.mapView.setCenter(annotation.coordinate, animated: false)
        self.mapView.regionThatFits(region)
    }
    
    func fetchResults<T: NSFetchRequestResult>(entityName: String, predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor], completion: @escaping ([T]?, Error?) -> Void) {
        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
            completion(fetchedResultsController.fetchedObjects, nil)
        } catch {
            completion(nil, error)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "photoAlbum" {
            let vc = segue.destination as? PhotoCollectionViewController
            vc?.pinLocation = self.pinLocation
            vc?.dataController = self.dataController
        }
    }
}

// MARK: - MKMapViewDelegate methods
extension TouristMapViewController {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.tintColor = .red
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        } else {
            pinView!.annotation = annotation
        }
        print("Displaying map pin annotation view.")
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        let annotation = view.annotation
        let latitude = annotation?.coordinate.latitude
        let longitude = annotation?.coordinate.longitude
        
        let fetchRequest: NSFetchRequest<PinLocation> = PinLocation.fetchRequest()
        if let result = try? dataController.viewContext.fetch(fetchRequest) {
            for pin in result {
                if pin.latitude == latitude && pin.longitude == longitude {
                    print("Pin selected at coordinates: \(latitude!), \(longitude!). Preparing to show photos.")
                    self.pinLocation = pin
                    self.performSegue(withIdentifier: "photoAlbum", sender: nil)
                    mapView.deselectAnnotation(view.annotation, animated: true)
                    break
                }
            }
        }
    }
}
