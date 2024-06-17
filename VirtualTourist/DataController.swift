//
//  DataController.swift
//  VirtualTourist
//
//  Created by Gunel Aydinova on 6/5/24.
//

import Foundation
import CoreData

class DataController {
    let persistentContainer: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    init(modelName: String) {
        persistentContainer = NSPersistentContainer(name: modelName)
    }
    
    func load(completion: (() -> Void)? = nil) {
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
          self.autoSaveViewContext(interval: 5)
            completion?()
        }
    }
    
    func save() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving data to Core Data: \(error.localizedDescription)")
        }
    }
}

extension DataController {
    
    func autoSaveViewContext (interval: TimeInterval = 30){
        guard interval > 0 else {
            print("cannot save at negative time interval")
            return
        }
        
        if viewContext.hasChanges {
            try? viewContext.save()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval){
            self.autoSaveViewContext(interval: interval)
        }
    }
}

