//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Gunel Aydinova on 6/5/24.
//

import Foundation

class FlickrAPI {
    
    private var currentDataTask: URLSessionDataTask?

    enum Endpoint {
        static let base = "https://api.flickr.com/services/rest"
        static let apiKey = "2c2d20e5dc0d38291e03aa1ede861e90"
        static let secret = "9dad7d6cc2dd8e97"
        static let baseURL = "https://live.staticflickr.com/"
        
        case searchPhotos(latitude: Double, longitude: Double, page: Int)
        case photoURL(server: String, id: String, secret: String)
        
        var stringValue: String {
            switch self {
            case .searchPhotos(let latitude, let longitude, let page):
                return Endpoint.base + "?method=flickr.photos.search" + "&api_key=\(Endpoint.apiKey)" + "&format=json" + "&lat=\(latitude)" +
                "&lon=\(longitude)" + "&per_page=20" + "&page=\(page)" + "&nojsoncallback=1"
            case .photoURL(let server, let id, let secret):
                return Endpoint.baseURL + "\(server)/\(id)_\(secret).jpg"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    func performGETRequest<ResponseType: Decodable>(url: URL, responseType: ResponseType.Type, completion: @escaping (ResponseType?, Error?) -> Void) -> URLSessionDataTask {
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data else {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                    return
                }
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                    print("Raw JSON response: \(json)")
                }
                let decoder = JSONDecoder()
                do {
                    let responseObject = try decoder.decode(ResponseType.self, from: data)
                    DispatchQueue.main.async {
                        completion(responseObject, nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }
            task.resume()
            return task
        }
    
    func searchPhotos(latitude: Double, longitude: Double, page: Int, completion: @escaping (PhotoSearchResponse?, Error?) -> Void) {
           let url = Endpoint.searchPhotos(latitude: latitude, longitude: longitude, page: page).url
           
           // Cancel any existing task before starting a new one
           currentDataTask?.cancel()
           
           currentDataTask = performGETRequest(url: url, responseType: PhotoSearchResponse.self) { response, error in
               if let response = response {
                   print("Decoded response: \(response)")
                   DispatchQueue.main.async {
                       completion(response, nil)
                   }
               } else {
                   completion(nil, error)
                   print("Error while searching for photos")
               }
           }
       }
   
    func getPhotoURL(server: String, id: String, secret: String) -> String {
        let urlString = Endpoint.photoURL(server: server, id: id, secret: secret).url.absoluteString
        return urlString
    }
}
