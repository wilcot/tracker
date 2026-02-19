import CoreData
import os

@MainActor
final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// `true` once persistent stores have finished loading successfully.
    private(set) var isReady = false

    /// If store loading failed, this is set instead of fatalError so callers can present an error.
    private(set) var loadError: Error?

    /// Callbacks invoked when stores have finished loading (on main). If already ready, runs immediately.
    /// On load failure, handlers are still invoked so callers can check `loadError`.
    func whenReady(_ handler: @escaping () -> Void) {
        if isReady || loadError != nil {
            handler()
            return
        }
        readyHandlers.append(handler)
    }

    /// Suspends until persistent stores have finished loading (success or failure). Call from MainActor.
    func awaitReady() async {
        if isReady || loadError != nil { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            readyHandlers.append { continuation.resume() }
        }
    }

    private var readyHandlers: [() -> Void] = []

    private static let logger = Logger(subsystem: Log.subsystem, category: "persistence")

    private init() {
        container = NSPersistentCloudKitContainer(name: "Tracker")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }

        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.willfulapps.Tracker"
        )
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        container.loadPersistentStores { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.loadError = error
                    Self.logger.error("Failed to load persistent stores error=\(error, privacy: .private)")
                    for handler in self.readyHandlers {
                        handler()
                    }
                    self.readyHandlers = []
                    return
                }
                self.isReady = true
                for handler in self.readyHandlers {
                    handler()
                }
                self.readyHandlers = []
            }
        }
    }

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Self.logger.error("Save failed op=save error=\(error, privacy: .private)")
        }
    }
}
