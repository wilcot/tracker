import UIKit

@MainActor
protocol IconPickerCollectionViewDelegate: AnyObject {
    func iconPickerCollectionView(_ view: IconPickerCollectionView, didSelectIcon iconName: String?)
}

final class IconPickerCollectionView: UIView {

    weak var delegate: IconPickerCollectionViewDelegate?

    var selectedIcon: String? {
        didSet { collectionView.reloadData() }
    }

    var accentColor: UIColor? {
        didSet { collectionView.reloadData() }
    }

    private let icons = ObjectIconCatalog.allIcons

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 48, height: 48)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.register(IconCell.self, forCellWithReuseIdentifier: IconCell.reuseIdentifier)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 240)
    }
}

// MARK: - UICollectionViewDataSource

extension IconPickerCollectionView: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        icons.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: IconCell.reuseIdentifier, for: indexPath
        ) as! IconCell
        let name = icons[indexPath.item]
        let isSelected = selectedIcon == name
        cell.configure(iconName: name, isSelected: isSelected, tintColor: accentColor)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension IconPickerCollectionView: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let name = icons[indexPath.item]
        selectedIcon = (selectedIcon == name) ? nil : name
        delegate?.iconPickerCollectionView(self, didSelectIcon: selectedIcon)
    }
}

// MARK: - IconCell

private final class IconCell: UICollectionViewCell {

    static let reuseIdentifier = "IconCell"

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        contentView.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    func configure(iconName: String, isSelected: Bool, tintColor: UIColor?) {
        let color = tintColor ?? .systemGray
        iconImageView.image = UIImage(systemName: iconName)
        if isSelected {
            contentView.backgroundColor = color.withAlphaComponent(0.15)
            iconImageView.tintColor = color
            contentView.layer.borderWidth = 2
            contentView.layer.borderColor = color.cgColor
        } else {
            contentView.backgroundColor = .secondarySystemGroupedBackground
            iconImageView.tintColor = .secondaryLabel
            contentView.layer.borderWidth = 0
            contentView.layer.borderColor = nil
        }
    }
}
