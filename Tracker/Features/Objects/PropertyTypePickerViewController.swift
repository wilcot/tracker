import UIKit
import CoreData
import os

final class PropertyTypePickerViewController: UIViewController {

    private static let sectionTypes = "types"
    private static let sectionTip = "tip"
    private static let tipItemID = "__pro_tip__"

    private let object: TrackedObject
    private let context: NSManagedObjectContext
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<String, String>!
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    init(object: TrackedObject, context: NSManagedObjectContext) {
        self.object = object
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0xF1/255, green: 0xF5/255, blue: 0xF9/255, alpha: 1)
        setupNavBar()
        setupCollectionView()
        setupDataSource()
        applySnapshot()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        haptic.prepare()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateCardsIn()
    }

    // MARK: - Navigation

    private func setupNavBar() {
        let titleLabel = UILabel()
        titleLabel.text = "Add Property"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = UIColor(red: 0x0F/255, green: 0x17/255, blue: 0x2A/255, alpha: 1)
        navigationItem.titleView = titleLabel

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - Collection View

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            if sectionIndex == 0 {
                return Self.makeCardSection(environment: environment)
            } else {
                return Self.makeTipSection(environment: environment)
            }
        }
    }

    private static func makeCardSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(76))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(76))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24)
        return section
    }

    private static func makeTipSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(120))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 24, trailing: 24)
        return section
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Data Source

    private func setupDataSource() {
        let cardRegistration = UICollectionView.CellRegistration<PropertyTypeCardCell, String> { cell, _, rawValue in
            guard let propertyType = PropertyType(rawValue: rawValue) else { return }
            cell.configure(with: propertyType)
        }

        let tipRegistration = UICollectionView.CellRegistration<ProTipCell, String> { cell, _, _ in
            cell.configure()
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) {
            collectionView, indexPath, item in
            if indexPath.section == 0 {
                return collectionView.dequeueConfiguredReusableCell(using: cardRegistration, for: indexPath, item: item)
            } else {
                return collectionView.dequeueConfiguredReusableCell(using: tipRegistration, for: indexPath, item: item)
            }
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<String, String>()
        snapshot.appendSections([Self.sectionTypes, Self.sectionTip])
        snapshot.appendItems(PropertyType.allCases.map(\.rawValue), toSection: Self.sectionTypes)
        snapshot.appendItems([Self.tipItemID], toSection: Self.sectionTip)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Animations

    private func animateCardsIn() {
        let visibleCells = collectionView.visibleCells
        for cell in visibleCells {
            cell.alpha = 0
            cell.transform = CGAffineTransform(translationX: 0, y: 30)
        }

        for (index, cell) in visibleCells.enumerated() {
            let delay = Double(index) * 0.08
            UIView.animate(
                withDuration: 0.5,
                delay: delay,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0,
                options: [.curveEaseOut],
                animations: {
                    cell.alpha = 1
                    cell.transform = .identity
                }
            )
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        context.rollback()
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDelegate

extension PropertyTypePickerViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section == 0,
              let rawValue = dataSource.itemIdentifier(for: indexPath),
              let propertyType = PropertyType(rawValue: rawValue) else { return }

        haptic.impactOccurred()

        if let cell = collectionView.cellForItem(at: indexPath) as? PropertyTypeCardCell {
            cell.flashSelection {
                let formVC = AddPropertyFormViewController(
                    object: self.object,
                    context: self.context,
                    propertyType: propertyType
                )
                self.navigationController?.pushViewController(formVC, animated: true)
            }
        } else {
            let formVC = AddPropertyFormViewController(
                object: object,
                context: context,
                propertyType: propertyType
            )
            navigationController?.pushViewController(formVC, animated: true)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard indexPath.section == 0,
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut) {
            cell.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard indexPath.section == 0,
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut) {
            cell.transform = .identity
        }
    }
}

// MARK: - PropertyTypeCardCell

private final class PropertyTypeCardCell: UICollectionViewCell {

    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var currentType: PropertyType?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 24
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.3).cgColor

        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.04
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 8

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.layer.cornerRadius = 16

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        iconContainer.addSubview(iconImageView)

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIColor(red: 0x0F/255, green: 0x17/255, blue: 0x2A/255, alpha: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 0x64/255, green: 0x74/255, blue: 0x8B/255, alpha: 1)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconContainer)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 56),
            iconContainer.heightAnchor.constraint(equalToConstant: 56),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 76),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func configure(with type: PropertyType) {
        currentType = type
        iconContainer.backgroundColor = type.backgroundColor
        iconImageView.tintColor = type.accentColor
        iconImageView.image = UIImage(systemName: type.systemImage)
        titleLabel.text = type.displayName
        subtitleLabel.text = type.subtitle
    }

    func flashSelection(completion: @escaping () -> Void) {
        guard let type = currentType else {
            completion()
            return
        }
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut, animations: {
            self.iconContainer.backgroundColor = type.accentColor
            self.iconImageView.tintColor = .white
        }, completion: { _ in
            completion()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIView.animate(withDuration: 0.2) {
                    self.iconContainer.backgroundColor = type.backgroundColor
                    self.iconImageView.tintColor = type.accentColor
                }
            }
        })
    }
}

// MARK: - ProTipCell

private final class ProTipCell: UICollectionViewCell {

    private let sparkleIcon = UIImageView()
    private let headingLabel = UILabel()
    private let bodyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let indigo = UIColor(red: 0x4F/255, green: 0x46/255, blue: 0xE5/255, alpha: 1)
        contentView.backgroundColor = indigo
        contentView.layer.cornerRadius = 28

        sparkleIcon.image = UIImage(systemName: "sparkles")
        sparkleIcon.tintColor = UIColor(red: 0xA5/255, green: 0xB4/255, blue: 0xFC/255, alpha: 1)
        sparkleIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        sparkleIcon.translatesAutoresizingMaskIntoConstraints = false

        headingLabel.text = "Pro Tip"
        headingLabel.font = .systemFont(ofSize: 16, weight: .bold)
        headingLabel.textColor = .white
        headingLabel.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = UIStackView(arrangedSubviews: [sparkleIcon, headingLabel])
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        bodyLabel.text = "Properties help you filter and organize your items later. You can always change the name of a property after adding it!"
        bodyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        bodyLabel.textColor = UIColor(red: 0xC7/255, green: 0xD2/255, blue: 0xFE/255, alpha: 1)
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headerStack)
        contentView.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),

            bodyLabel.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            bodyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            bodyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            bodyLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])

        isUserInteractionEnabled = false
    }

    func configure() {}
}
