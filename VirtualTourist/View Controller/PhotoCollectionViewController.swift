//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Gunel Aydinova on 6/6/24.
//

import UIKit
import MapKit
import CoreData

class PhotoCollectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    
    var dataController: DataController!
    var pinLocation: PinLocation!
    var photoArray: [PhotoAlbum] = []
    var page: Int = 0
    var fetchedResultsController: NSFetchedResultsController<PhotoAlbum>!
    
    let flickrAPI = FlickrAPI()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        mapView.delegate = self
        
        setupCollectionViewLayout()
        checkCoreDataForPhotos()
        setupFetchedResultsController()
        fetchPhotosFromCoreData()
        if photoArray.isEmpty {
            getPhotos()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.reloadData()
        centerMapOnCoordinates(latitude: pinLocation.latitude, longitude: pinLocation.longitude)
    }
    
    // MARK: - Core Data Fetching Methods
    func fetchPhotosFromCoreData() {
        let predicate = NSPredicate(format: "pin == %@", self.pinLocation)
        let sortDescriptor = NSSortDescriptor(key: "url", ascending: true)
        fetchResults(entityName: "PhotoAlbum", predicate: predicate, sortDescriptors: [sortDescriptor]) { (fetchedObjects: [PhotoAlbum]?, error) in
            if let fetchedObjects = fetchedObjects {
                self.photoArray = fetchedObjects
                self.collectionView.reloadData()
            } else if let error = error {
                self.showErrorAlert(title: "Fetch Error", message: "Unable to fetch photos from Core Data: \(error.localizedDescription)")
            }
        }
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
    
    @IBAction func newCollectionButtonClicked(_ sender: Any) {
        print("New Collection button clicked.")
        newCollectionButton.isEnabled = false

        // Delete existing photos from Core Data
        if let fetchedObjects = fetchedResultsController.fetchedObjects {
            for image in fetchedObjects {
                dataController.viewContext.delete(image)
            }
            do {
                try dataController.viewContext.save()
                print("Existing photos deleted from Core Data.")
            } catch {
                print("Failed to delete existing photos from Core Data: \(error.localizedDescription)")
            }
        }

        // Clear local photo array and reload collection view
        photoArray.removeAll()
        collectionView.reloadData()
        print("Collection view reloaded after removing all photos.")

        // Setup fetched results controller again to clear out existing data
        setupFetchedResultsController()
        print("Fetched results controller re-setup.")

        // Fetch new photos from Flickr API
        getPhotos()
        print("Called getPhotos to fetch new collection.")
    }
    
    func checkCoreDataForPhotos() {
        let fetchRequest: NSFetchRequest<PhotoAlbum> = PhotoAlbum.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", self.pinLocation)
        fetchRequest.predicate = predicate
        let sortDescriptor = NSSortDescriptor(key: "url", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]

        do {
            let fetchedObjects = try dataController.viewContext.fetch(fetchRequest)
            if !fetchedObjects.isEmpty {
                print("Core Data contains \(fetchedObjects.count) photos.")
                fetchedObjects.forEach { photo in
                    print("Photo URL: \(photo.url ?? "No URL"), Photo Data: \(photo.photo != nil ? "Exists" : "No Data")")
                }
            } else {
                print("Core Data does not contain any photos.")
            }
        } catch {
            print("Failed to fetch objects from Core Data: \(error.localizedDescription)")
        }
    }
    
    func setupFetchedResultsController() {
        let fetchRequest: NSFetchRequest<PhotoAlbum> = PhotoAlbum.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", self.pinLocation)
        fetchRequest.predicate = predicate
        let sortDescriptor = NSSortDescriptor(key: "url", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
            if let fetchedObjects = fetchedResultsController.fetchedObjects {
                print("Fetched \(fetchedObjects.count) objects from Core Data.")
            } else {
                print("No objects fetched from Core Data.")
            }
        } catch {
            print("Failed to fetch objects from Core Data: \(error.localizedDescription)")
        }
    }
    // MARK: - UICollectionView Methods
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        let sections = fetchedResultsController.sections?.count ?? 0
        print("Number of sections in collection view: \(sections)")
        return sections
    }

    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
          let numberOfItems = fetchedResultsController.sections?[section].numberOfObjects ?? 0
          print("Number of items in section \(section): \(numberOfItems)")
          return numberOfItems
      }

    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
           let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCollectionViewCell
           let cellImage = fetchedResultsController.fetchedObjects![indexPath.row]

           print("Configuring cell for item at indexPath: \(indexPath.row)")

           cell.imageView.image = UIImage(systemName: "photo")

           if let photo = cellImage.photo {
               DispatchQueue.main.async {
                   print("Loading cached image for item at indexPath: \(indexPath.row)")
                   cell.imageView.image = UIImage(data: photo)
               }
           } else {
               if let urlString = cellImage.url, let url = URL(string: urlString) {
                   fetchImageData(from: url.absoluteString) { (data, error) in
                       if let data = data {
                           DispatchQueue.main.async {
                               print("Loaded image from URL for item at indexPath: \(indexPath.row)")
                               cell.imageView.image = UIImage(data: data)
                           }
                           cellImage.photo = data
                           do {
                               try self.dataController.viewContext.save()
                               print("Saved image data to Core Data.")
                           } catch {
                               print("Failed to save image data to Core Data: \(error.localizedDescription)")
                           }
                       } else {
                           DispatchQueue.main.async {
                               cell.imageView.image = UIImage(systemName: "photo")
                           }
                       }
                   }
               } else {
                   DispatchQueue.main.async {
                       cell.imageView.image = UIImage(systemName: "photo")
                   }
               }
           }

           return cell
       }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photoToDelete = fetchedResultsController.object(at: indexPath)
        
        // Delete the photo from Core Data
        dataController.viewContext.delete(photoToDelete)
        
        do {
            try dataController.viewContext.save()
            print("Photo deleted from Core Data.")
            
            // Remove the photo from the local array
            photoArray.remove(at: indexPath.row)
            
            // Reload the collection view
            setupFetchedResultsController()
            collectionView.reloadData()
        } catch {
            print("Failed to delete photo from Core Data: \(error.localizedDescription)")
            showErrorAlert(title: "Delete Error", message: "Unable to delete photo: \(error.localizedDescription)")
        }
    }
    
    // MARK: - MKMapViewDelegate Methods
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
    
    // MARK: - Image fetching
    func fetchImageData(from imagePath: String, completion: @escaping (_ imageData: Data?, _ errorString: String?) -> Void) {
        let session = URLSession.shared
        
        guard let imgURL = URL(string: imagePath) else {
            print("Invalid URL provided: \(imagePath)")
            DispatchQueue.main.async {
                completion(nil, "Invalid URL provided: \(imagePath)")
            }
            return
        }
        
        let request = URLRequest(url: imgURL)
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, "Could not fetch image from URL: \(imagePath), error: \(error.localizedDescription)")
                }
            } else {
                print("Successfully received image data from URL: \(imagePath)")
                DispatchQueue.main.async {
                    completion(data, nil)
                }
            }
        }
        
        task.resume()
    }
    
    func getPhotos() {
        let randomPage = Int.random(in: 1...10)
        print("Fetching photos from random page: \(randomPage)")
       
        newCollectionButton.isEnabled = false
        print("Fetching photos from Flickr API.")
        
        flickrAPI.searchPhotos(latitude: pinLocation?.latitude ?? 0.0, longitude: pinLocation?.longitude ?? 0.0, page: randomPage) { [weak self] (response: PhotoSearchResponse?, error: Error?) in
            guard let self = self else {
                print("Self is nil, exiting closure.")
                return
            }
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching photos from Flickr API: \(error.localizedDescription)")
                } else if let response = response, !response.photos.photoList.isEmpty {
                    print("Fetched \(response.photos.photoList.count) photos from Flickr API.")
                    response.photos.photoList.forEach { photo in
                        let newPhoto = PhotoAlbum(context: self.dataController.viewContext)
                        newPhoto.pin = self.pinLocation
                        newPhoto.url = self.flickrAPI.getPhotoURL(server: photo.serverId, id: photo.identifier, secret: photo.secretKey)
                        self.photoArray.append(newPhoto)
                    }
                    do {
                        try self.dataController.viewContext.save()
                        print("Saved photos to Core Data.")
                        
                        // Re-setup fetched results controller to fetch the newly saved data
                        self.setupFetchedResultsController()
                        self.collectionView.reloadData()
                    } catch {
                        print("Failed to save photos to Core Data: \(error.localizedDescription)")
                    }
                } else {
                    print("No photos found in Flickr API response.")
                    self.showNoImagesLabel()
                }
                self.newCollectionButton.isEnabled = true
            }
        }
    }


    
    // MARK: - Helper Methods
    private func showNoImagesLabel() {
        let noImagesLabel = UILabel(frame: CGRect(x: 0, y: 0, width: collectionView.bounds.width, height: 40))
        noImagesLabel.text = "No Images Available"
        noImagesLabel.textAlignment = .center
        noImagesLabel.center = collectionView.center
        collectionView.backgroundView = noImagesLabel
    }
    
    private func setupCollectionViewLayout() {
        let space: CGFloat = 3.0
        let dimension = (view.frame.size.width - (2 * space)) / 3.0
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        flowLayout.itemSize = CGSize(width: dimension, height: dimension)
        collectionView.collectionViewLayout = UICollectionViewFlowLayout()
    }
    
    private func showErrorAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}
