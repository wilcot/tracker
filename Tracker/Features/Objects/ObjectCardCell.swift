import UIKit
import CoreData

final class ObjectCardCell: UICollectionViewCell {

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        // Shadow on self.layer
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.08

        // Corner radius on contentView
        contentView.layer.cornerRadius = 14
        contentView.layer.cornerCurve = .continuous
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .secondarySystemGroupedBackground

        contentView.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    func configure(with objectID: NSManagedObjectID, in context: NSManagedObjectContext) {
        guard let object = try? context.existingObject(with: objectID) as? TrackedObject else { return }
        nameLabel.text = object.name ?? ""
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
    }
}
