import UIKit
import CoreData
import os

final class PropertyHistoryViewController: UIViewController {

    private static let logger = Logger(subsystem: Log.subsystem, category: "persistence")

    private let propertyName: String
    private let objectID: NSManagedObjectID
    private let context: NSManagedObjectContext
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<String, NSManagedObjectID>!
    private var fetchedResultsController: NSFetchedResultsController<Property>!

    init(propertyName: String, objectID: NSManagedObjectID, context: NSManagedObjectContext) {
        self.propertyName = propertyName
        self.objectID = objectID
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "History"
        view.backgroundColor = .systemGroupedBackground
        setupCollectionView()
        setupDataSource()
        setupFetchedResultsController()
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, NSManagedObjectID> {
            [weak self] cell, _, entryID in
            guard let self,
                  let entry = try? context.existingObject(with: entryID) as? Property else { return }

            var content = UIListContentConfiguration.subtitleCell()
            content.text = entry.displayValue ?? "No value"
            content.secondaryText = entry.formattedUserTimestamp
            content.prefersSideBySideTextAndSecondaryText = true
            cell.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource<String, NSManagedObjectID>(
            collectionView: collectionView
        ) { collectionView, indexPath, entryID in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: entryID)
        }
    }

    private func setupFetchedResultsController() {
        guard let object = try? context.existingObject(with: objectID) as? TrackedObject else { return }

        let request = Property.fetchRequest()
        request.predicate = NSPredicate(format: "object == %@ AND name == %@", object, propertyName)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Property.userTimestamp, ascending: false)]
        request.fetchBatchSize = 50

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
        } catch {
            Self.logger.error("FRC fetch failed op=propertyHistory error=\(error, privacy: .private)")
        }
        setNeedsUpdateContentUnavailableConfiguration()
    }

    // MARK: - Empty State

    override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
        if fetchedResultsController?.fetchedObjects?.isEmpty ?? true {
            var config = UIContentUnavailableConfiguration.empty()
            config.image = UIImage(systemName: "clock.arrow.circlepath")
            config.text = "No History"
            config.secondaryText = "Changes to this property will appear here."
            contentUnavailableConfiguration = config
        } else {
            contentUnavailableConfiguration = nil
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension PropertyHistoryViewController: @preconcurrency NSFetchedResultsControllerDelegate {
    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChangeContentWith snapshotReference: NSDiffableDataSourceSnapshotReference
    ) {
        let snapshot = snapshotReference as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
        dataSource.apply(snapshot, animatingDifferences: view.window != nil)
        setNeedsUpdateContentUnavailableConfiguration()
    }
}
