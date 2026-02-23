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
        title = "Everything"
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
        UICollectionViewCompositionalLayout { _, environment in
            let width = environment.container.effectiveContentSize.width
            let spacing: CGFloat = 16
            let horizontalInsets: CGFloat = 32
            let itemWidth: CGFloat = 160
            let availableWidth = width - horizontalInsets
            let columns = max(2, Int(availableWidth / (itemWidth + spacing)))

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
                heightDimension: .estimated(160)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(160)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
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
            cell.delegate = self
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

        dataSource.reorderingHandlers.canReorderItem = { _ in true }
        dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            guard let self,
                  let sectionTransaction = transaction.sectionTransactions.first else { return }

            let orderedIDs = sectionTransaction.finalSnapshot.items
            let updatedItems = orderedIDs.compactMap { objectID in
                self.context.object(with: objectID) as? TrackedObject
            }

            self.fetchedResultsController.delegate = nil
            FractionalIndex.applyReorder(updatedItems)
            CoreDataStack.shared.save()

            DispatchQueue.main.async {
                try? self.fetchedResultsController.performFetch()
                self.fetchedResultsController.delegate = self
            }
        }
    }

    // MARK: - FAB

    private func setupFAB() {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .systemIndigo
        config.baseForegroundColor = .white
        config.image = UIImage(
            systemName: "plus",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        )

        fabButton = UIButton(configuration: config)
        fabButton.translatesAutoresizingMaskIntoConstraints = false
        fabButton.layer.shadowColor = UIColor.systemIndigo.cgColor
        fabButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        fabButton.layer.shadowRadius = 14
        fabButton.layer.shadowOpacity = 0.35
        fabButton.addTarget(self, action: #selector(fabTapped), for: .touchUpInside)

        view.addSubview(fabButton)
        NSLayoutConstraint.activate([
            fabButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            fabButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            fabButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            fabButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
        ])
    }

    @objc private func fabTapped() {
        presentObjectForm(mode: .create)
    }

    private func presentObjectForm(mode: ObjectFormViewController.Mode) {
        let formVC = ObjectFormViewController(context: context, mode: mode)
        formVC.delegate = self
        let nav = UINavigationController(rootViewController: formVC)
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

    // MARK: - Delete

    private func deleteObject(_ object: TrackedObject) {
        DeleteAlertHelper.presentDeleteConfirmation(
            from: self,
            title: "Delete Object?",
            message: "This will permanently delete \"\(object.name ?? "")\" and all its properties.",
            onConfirm: { [weak self] in
                guard let self else { return }
                self.context.delete(object)
                CoreDataStack.shared.save()
                Self.logger.info("Object deleted objectName=\(object.name ?? "", privacy: .public)")
            }
        )
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
        var snapshot = snapshotReference as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>

        let reloaded = snapshot.itemIdentifiers.filter { snapshot.reloadedItemIdentifiers.contains($0) }
        if !reloaded.isEmpty {
            snapshot.reconfigureItems(reloaded)
        }

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

// MARK: - ObjectCardCellDelegate

extension ObjectsViewController: ObjectCardCellDelegate {

    func objectCardCellDidRequestEdit(_ cell: ObjectCardCell) {
        guard let indexPath = collectionView.indexPath(for: cell),
              let objectID = dataSource.itemIdentifier(for: indexPath),
              let object = try? context.existingObject(with: objectID) as? TrackedObject else {
            return
        }
        presentObjectForm(mode: .edit(object))
    }

    func objectCardCellDidRequestDelete(_ cell: ObjectCardCell) {
        guard let indexPath = collectionView.indexPath(for: cell),
              let objectID = dataSource.itemIdentifier(for: indexPath),
              let object = try? context.existingObject(with: objectID) as? TrackedObject else {
            return
        }
        deleteObject(object)
    }
}

// MARK: - ObjectFormViewControllerDelegate

extension ObjectsViewController: ObjectFormViewControllerDelegate {

    func objectFormViewControllerDidSave(_ controller: ObjectFormViewController) {
        controller.dismiss(animated: true)
    }

    func objectFormViewControllerDidCancel(_ controller: ObjectFormViewController) {
        controller.dismiss(animated: true)
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
        // reorderingHandlers.didReorder handles the reorder
    }
}
