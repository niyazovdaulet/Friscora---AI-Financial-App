//
//  CoreDataStack.swift
//  Friscora
//
//  CoreData persistence layer for the app
//

import CoreData
import Foundation

/// Manages CoreData stack and provides access to managed object context
class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FriscoraModel")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("CoreData failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func save() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
    
    private init() {}
}

