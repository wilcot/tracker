import UIKit
import CoreData
import os

final class ObjectsViewController: UIViewController {

    private static let logger = Logger(subsystem: Log.subsystem, category: "persistence")

    let context: NSManagedObjectContext
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<String, NSManagedObjectID>!
    private var fetchedResultsController: NSFetchedResultsController<TrackedObject>!
    private var fabButton: UIButton!

    init(context: NSManagedObjectContext) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
        title = "Objects"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupCollectionView()
        setupDataSource()
        setupFAB()
        setupFetchedResultsController()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if let selected = collectionView.indexPathsForSelectedItems?.first {
            collectionView.deselectItem(at: selected, animated: animated)
        }
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, environment in
            _ = self
            let width = environment.container.effectiveContentSize.width
            let columns: Int
            switch width {
            case ..<400: columns = 1
            case ..<700: columns = 2
            case ..<1000: columns = 3
            default: columns = 4
            }

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(120)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            return section
        }
    }

    // MARK: - Collection View

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.delegate = self
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Data Source

    private func setupDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<ObjectCardCell, NSManagedObjectID> {
            [weak self] cell, _, objectID in
            guard let self else { return }
            cell.configure(with: objectID, in: context)
        }

        dataSource = UICollectionViewDiffableDataSource<String, NSManagedObjectID>(
            collectionView: collectionView
        ) { collectionView, indexPath, objectID in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: objectID
            )
        }
    }

    // MARK: - FAB

    private func setupFAB() {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.image = UIImage(
            systemName: "plus",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        )

        fabButton = UIButton(configuration: config)
        fabButton.translatesAutoresizingMaskIntoConstraints = false
        fabButton.layer.shadowColor = UIColor.black.cgColor
        fabButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        fabButton.layer.shadowRadius = 8
        fabButton.layer.shadowOpacity = 0.2
        fabButton.addTarget(self, action: #selector(fabTapped), for: .touchUpInside)

        view.addSubview(fabButton)
        NSLayoutConstraint.activate([
            fabButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            fabButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            fabButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            fabButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
        ])
    }

    @objc private func fabTapped() {
        let createVC = CreateObjectViewController(context: context)
        let nav = UINavigationController(rootViewController: createVC)

        if let sheet = nav.sheetPresentationController {
            let smallDetent = UISheetPresentationController.Detent.custom(
                identifier: .init("small")
            ) { _ in 250 }
            sheet.detents = [smallDetent]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }

        present(nav, animated: true)
    }

    // MARK: - Fetched Results Controller

    private func setupFetchedResultsController() {
        let request = TrackedObject.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrackedObject.sortOrder, ascending: true)]
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
            Self.logger.error("FRC fetch failed op=objectsList error=\(error, privacy: .private)")
        }
        setNeedsUpdateContentUnavailableConfiguration()
    }

    // MARK: - Reorder persistence

    private func persistReorder(ids: [NSManagedObjectID]) {
        fetchedResultsController.delegate = nil
        for (index, id) in ids.enumerated() {
            (try? context.existingObject(with: id) as? TrackedObject)?.sortOrder = String(format: "%010d", index)
        }
        CoreDataStack.shared.save()
        fetchedResultsController.delegate = self
    }

    // MARK: - Empty State

    override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
        if fetchedResultsController?.fetchedObjects?.isEmpty ?? true {
            var config = UIContentUnavailableConfiguration.empty()
            config.image = UIImage(systemName: "square.stack.3d.up")
            config.text = "No Objects"
            config.secondaryText = "Tap + to create your first object."
            contentUnavailableConfiguration = config
        } else {
            contentUnavailableConfiguration = nil
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ObjectsViewController: @preconcurrency NSFetchedResultsControllerDelegate {
    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChangeContentWith snapshotReference: NSDiffableDataSourceSnapshotReference
    ) {
        let snapshot = snapshotReference as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
        dataSource.apply(snapshot, animatingDifferences: view.window != nil)
        setNeedsUpdateContentUnavailableConfiguration()
    }
}

// MARK: - UICollectionViewDelegate

extension ObjectsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let objectID = dataSource.itemIdentifier(for: indexPath) else { return }
        let detailVC = ObjectDetailViewController(objectID: objectID, context: context)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - UICollectionViewDragDelegate

extension ObjectsViewController: UICollectionViewDragDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: any UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        guard let objectID = dataSource.itemIdentifier(for: indexPath) else { return [] }
        let item = UIDragItem(itemProvider: NSItemProvider(object: objectID.uriRepresentation() as NSURL))
        item.localObject = objectID
        return [item]
    }
}

// MARK: - UICollectionViewDropDelegate

extension ObjectsViewController: UICollectionViewDropDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: any UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        guard session.localDragSession != nil else {
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: any UICollectionViewDropCoordinator
    ) {
        for item in coordinator.items {
            guard let sourceIndexPath = item.sourceIndexPath,
                  let objectID = item.dragItem.localObject as? NSManagedObjectID else { continue }

            var ids = dataSource.snapshot().itemIdentifiers
            ids.remove(at: sourceIndexPath.item)
            let insertAt = coordinator.destinationIndexPath.map { min($0.item, ids.count) } ?? ids.count
            ids.insert(objectID, at: insertAt)

            var newSnapshot = NSDiffableDataSourceSnapshot<String, NSManagedObjectID>()
            let section = dataSource.snapshot().sectionIdentifiers.first ?? ""
            newSnapshot.appendSections([section])
            newSnapshot.appendItems(ids, toSection: section)

            dataSource.apply(newSnapshot, animatingDifferences: false)
            persistReorder(ids: ids)

            if let dest = coordinator.destinationIndexPath {
                coordinator.drop(item.dragItem, toItemAt: dest)
            }
        }
    }
}
