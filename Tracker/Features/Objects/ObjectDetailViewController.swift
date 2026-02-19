import UIKit
import CoreData
import os

final class ObjectDetailViewController: UIViewController {

    private static let logger = Logger(subsystem: Log.subsystem, category: "persistence")

    private let objectID: NSManagedObjectID
    private let context: NSManagedObjectContext
    private var object: TrackedObject!
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<String, NSManagedObjectID>!
    private var fetchedResultsController: NSFetchedResultsController<Property>!

    init(objectID: NSManagedObjectID, context: NSManagedObjectContext) {
        self.objectID = objectID
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let obj = try? context.existingObject(with: objectID) as? TrackedObject else { return }
        object = obj
        title = obj.name
        view.backgroundColor = .systemGroupedBackground
        setupCollectionView()
        setupDataSource()
        setupNavigationBar()
        setupFetchedResultsController()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .add,
            primaryAction: UIAction { [weak self] _ in self?.addPropertyTapped() }
        )
    }

    private func makeLayout() -> UICollectionViewLayout {
        let config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: config)
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
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
            [weak self] cell, _, propertyID in
            guard let self,
                  let property = try? context.existingObject(with: propertyID) as? Property else { return }
            let propType = PropertyType(rawValue: property.type ?? "")
            var content = UIListContentConfiguration.subtitleCell()
            content.text = property.name
            content.secondaryText = property.displayValue ?? "No value"
            content.image = UIImage(systemName: propType?.systemImage ?? "questionmark.circle")
            cell.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource<String, NSManagedObjectID>(
            collectionView: collectionView
        ) { collectionView, indexPath, propertyID in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: propertyID)
        }
    }

    private func setupFetchedResultsController() {
        let request = Property.fetchRequest()
        request.predicate = NSPredicate(format: "object == %@", object)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Property.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Property.timestamp, ascending: false),
        ]
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
            Self.logger.error("FRC fetch failed op=propertyList error=\(error, privacy: .private)")
        }
        rebuildSnapshot()
    }

    private func rebuildSnapshot() {
        guard let allProperties = fetchedResultsController.fetchedObjects else { return }

        var seen = Set<String>()
        var latestPerName: [NSManagedObjectID] = []
        for property in allProperties {
            let name = property.name ?? ""
            if seen.insert(name).inserted {
                latestPerName.append(property.objectID)
            }
        }

        var snapshot = NSDiffableDataSourceSnapshot<String, NSManagedObjectID>()
        snapshot.appendSections(["main"])
        snapshot.appendItems(latestPerName)
        dataSource.apply(snapshot, animatingDifferences: view.window != nil)
        setNeedsUpdateContentUnavailableConfiguration()
    }

    // MARK: - Empty State

    override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
        if fetchedResultsController?.fetchedObjects?.isEmpty ?? true {
            var config = UIContentUnavailableConfiguration.empty()
            config.image = UIImage(systemName: "list.bullet.rectangle")
            config.text = "No Properties"
            config.secondaryText = "Tap + to add a property to track."
            contentUnavailableConfiguration = config
        } else {
            contentUnavailableConfiguration = nil
        }
    }

    // MARK: - Actions

    private func addPropertyTapped() {
        let addVC = AddPropertyViewController(object: object, context: context)
        let nav = UINavigationController(rootViewController: addVC)
        if let sheet = nav.sheetPresentationController {
            let detent = UISheetPresentationController.Detent.custom(identifier: .init("addProperty")) { _ in 520 }
            sheet.detents = [detent]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(nav, animated: true)
    }
}

// MARK: - UICollectionViewDelegate

extension ObjectDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let propertyID = dataSource.itemIdentifier(for: indexPath) else { return }
        let editVC = EditPropertyValueViewController(propertyID: propertyID, context: context)
        navigationController?.pushViewController(editVC, animated: true)
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ObjectDetailViewController: @preconcurrency NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        rebuildSnapshot()
    }
}
