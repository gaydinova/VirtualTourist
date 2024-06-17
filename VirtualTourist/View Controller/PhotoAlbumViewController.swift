//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Gunel Aydinova on 6/6/24.
//

import UIKit
import MapKit
import CoreData

class PhotoCollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, NSFetchedResultsControllerDelegate, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var newCollectionButton: UIButton!
    
    var selectedPin: CLLocationCoordinate2D?
    var annotation: MKAnnotation!
    var dataController: DataController!
    var pinLocation: PinLocation!
    var photoArray: [PhotoAlbum] = []
    var page: Int = 0
    var fetchedResultsController: NSFetchedResultsController<PhotoAlbum>!
    
    let flickrAPI = FlickrAPI()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Configure the flow layout
        flowLayoutSet()
        
        // Fetch existing data from Core Data
        fetchResultFromCoreData()
        
        // Fetch photos from the Flickr API
        getPhotos()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.reloadData()
        getHeaderMap(latitude: pinLocation.latitude, longitude: pinLocation.longitude)
        
    }
    
    func getHeaderMap(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate.latitude = latitude
        annotation.coordinate.longitude = longitude
        let span = MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        let region = MKCoordinateRegion(center: annotation.coordinate, span: span)
        mapView.addAnnotation(annotation)
        self.mapView.setRegion(region, animated: false)
        self.mapView.setCenter(annotation.coordinate, animated: false)
        self.mapView.regionThatFits(region)
    }
    
    fileprivate func fetchResultFromCoreData() {
        let fetchRequest: NSFetchRequest<PhotoAlbum> = PhotoAlbum.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", self.pinLocation)
        fetchRequest.predicate = predicate
        let sortDescriptor = NSSortDescriptor(key: "coreURL", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
            if let fetchedObjects = fetchedResultsController.fetchedObjects {
                photoArray = fetchedObjects
            }
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    fileprivate func flowLayoutSet() {
        let space: CGFloat = 3.0
        let dimension = (view.frame.size.width - (2 * space)) / 3.0
        let _ = (view.frame.size.height - (2 * space)) / 3.0
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        flowLayout.itemSize = CGSize(width: dimension, height: dimension)
        collectionView.collectionViewLayout = UICollectionViewFlowLayout()
    }
    
    
    @IBAction func newCollectionButtonClicked(_ sender: Any) {
        
        newCollectionButton.isEnabled = false

        // Clear existing images from Core Data
        if let fetchedObjects = fetchedResultsController.fetchedObjects {
            for image in fetchedObjects {
                dataController.viewContext.delete(image)
            }
            try? dataController.viewContext.save()
        }

        // Clear the photo array and update the collection view
        photoArray.removeAll()
        collectionView.reloadData()
        
        fetchedResultsController = nil
        setupFetchedResultsController()

        // Fetch new images from the API
        getPhotos()
    }
    
    fileprivate func setupFetchedResultsController() {
        let fetchRequest: NSFetchRequest<PhotoAlbum> = PhotoAlbum.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", self.pinLocation)
        fetchRequest.predicate = predicate
        let sortDescriptor = NSSortDescriptor(key: "coreURL", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
            if let fetchedObjects = fetchedResultsController.fetchedObjects {
                photoArray = fetchedObjects
            }
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        fetchResultFromCoreData()
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCollectionViewCell
        let cellImage = fetchedResultsController.fetchedObjects![indexPath.row]
        
        // Set the placeholder image and start the activity indicator
        cell.imageView.image = UIImage(systemName: "photo")
        cell.activityIndicator.startAnimating()
        
        // Check if the image is already cached
        if let corePhoto = cellImage.corePhoto {
            // Image is cached, update the image view on the main thread
            DispatchQueue.main.async {
                cell.imageView.image = UIImage(data: corePhoto)
                cell.activityIndicator.stopAnimating()
            }
        } else {
            // Image is not cached, fetch it from the URL
            if let urlString = cellImage.coreURL, let url = URL(string: urlString) {
                downloadImage(imagePath: url.absoluteString) { (data, error) in
                    if let data = data {
                        DispatchQueue.main.async {
                            // Update the image view with the downloaded image
                            cell.imageView.image = UIImage(data: data)
                            cell.activityIndicator.stopAnimating()
                        }
                        // Cache the image data
                        cellImage.corePhoto = data
                        try? self.dataController.viewContext.save()
                    } else {
                        // Handle error or show placeholder image if download fails
                        DispatchQueue.main.async {
                            cell.activityIndicator.stopAnimating()
                            cell.imageView.image = UIImage(systemName: "photo")
                        }
                    }
                }
            } else {
                // Handle invalid URL
                DispatchQueue.main.async {
                    cell.activityIndicator.stopAnimating()
                    cell.imageView.image = UIImage(systemName: "photo")
                }
            }
        }
        
        return cell
    }
    
    func downloadImage(imagePath: String, completionHandler: @escaping (_ imageData: Data?, _ errorString: String?) -> Void) {
        let session = URLSession.shared
        if let imgURL = URL(string: imagePath) {
            let request = URLRequest(url: imgURL)
            
            let task = session.dataTask(with: request) { data, response, downloadError in
                if let error = downloadError {
                    print("Download error: \(error.localizedDescription)")
                    completionHandler(nil, "Could not download image \(imagePath): \(error.localizedDescription)")
                } else {
                    print("Image data received for URL: \(imagePath)")
                    completionHandler(data, nil)
                }
            }
            task.resume()
        } else {
            print("Invalid URL: \(imagePath)")
            completionHandler(nil, "Invalid URL")
        }
    }
    
    func getPhotos() {
        newCollectionButton.isEnabled = false
        if let fetchedObjects = fetchedResultsController.fetchedObjects, !fetchedObjects.isEmpty {
            photoArray = fetchedObjects
            self.collectionView.reloadData()
            newCollectionButton.isEnabled = true
        } else {
            flickrAPI.searchPhotos(latitude: pinLocation?.latitude ?? 0.0, longitude: pinLocation?.longitude ?? 0.0, page: page) { [weak self] (response, error) in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let response = response, !response.photos.photo.isEmpty {
                        // Handle new photos
                        response.photos.photo.forEach { photo in
                            let newPhoto = PhotoAlbum(context: self.dataController.viewContext)
                            newPhoto.pin = self.pinLocation
                            newPhoto.coreURL = self.flickrAPI.getPhotoURL(server: photo.server, id: photo.id, secret: photo.secret)
                            self.photoArray.append(newPhoto)
                        }
                        try? self.dataController.viewContext.save()
                    } else {
                        self.showNoImagesLabel() // Handle the no images scenario
                    }
                    self.collectionView.reloadData()
                    self.newCollectionButton.isEnabled = true
                }
            }
        }
    }
    
    private func showNoImagesLabel() {
        let noImagesLabel = UILabel(frame: CGRect(x: 0, y: 0, width: collectionView.bounds.width, height: 40))
        noImagesLabel.text = "No Images"
        noImagesLabel.textAlignment = .center
        noImagesLabel.center = collectionView.center
        collectionView.backgroundView = noImagesLabel
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.tintColor = .red
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        print("map view displayed")
        return pinView
    }
    
    func showErrorAlert(title: String, message: String) {
        let alertViewController = UIAlertController (title: title,  message: message, preferredStyle: .alert)
        alertViewController.addAction(UIAlertAction(title: "Error", style: .default, handler: nil))
        self.present(alertViewController, animated: true, completion: nil)
    }
    
}
