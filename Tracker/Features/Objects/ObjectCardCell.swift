import UIKit
import CoreData

@MainActor
protocol ObjectCardCellDelegate: AnyObject {
    func objectCardCellDidRequestEdit(_ cell: ObjectCardCell)
    func objectCardCellDidRequestDelete(_ cell: ObjectCardCell)
}

final class ObjectCardCell: UICollectionViewCell {

    weak var delegate: ObjectCardCellDelegate?

    let cardView = ObjectCardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.06

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.delegate = self
        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    func configure(with objectID: NSManagedObjectID, in context: NSManagedObjectContext) {
        guard let object = try? context.existingObject(with: objectID) as? TrackedObject else { return }
        cardView.configure(
            title: object.name ?? "",
            iconName: object.displayIconName,
            color: object.displayColor
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(
            roundedRect: cardView.frame,
            cornerRadius: ObjectCardView.cornerRadius
        ).cgPath
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardView.prepareForReuse()
    }
}

// MARK: - ObjectCardViewDelegate

extension ObjectCardCell: ObjectCardViewDelegate {

    func objectCardViewDidRequestEdit(_ cardView: ObjectCardView) {
        delegate?.objectCardCellDidRequestEdit(self)
    }

    func objectCardViewDidRequestDelete(_ cardView: ObjectCardView) {
        delegate?.objectCardCellDidRequestDelete(self)
    }
}

// MARK: - ObjectCardView

@MainActor
protocol ObjectCardViewDelegate: AnyObject {
    func objectCardViewDidRequestEdit(_ cardView: ObjectCardView)
    func objectCardViewDidRequestDelete(_ cardView: ObjectCardView)
}

final class ObjectCardView: UIView {

    static let cornerRadius: CGFloat = 32

    weak var delegate: ObjectCardViewDelegate?

    private let iconContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 18, weight: .semibold
        )
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.textColor = .label
        label.textAlignment = .natural
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupContextMenu()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .systemBackground
        layer.cornerRadius = Self.cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor
        clipsToBounds = true

        iconContainer.addSubview(iconImageView)
        addSubview(iconContainer)
        addSubview(titleLabel)

        let iconSize: CGFloat = 44
        let iconInnerSize: CGFloat = 22

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconContainer.widthAnchor.constraint(equalToConstant: iconSize),
            iconContainer.heightAnchor.constraint(equalToConstant: iconSize),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: iconInnerSize),
            iconImageView.heightAnchor.constraint(equalToConstant: iconInnerSize),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
    }

    private func setupContextMenu() {
        let interaction = UIContextMenuInteraction(delegate: self)
        addInteraction(interaction)
    }

    func configure(title: String, iconName: String, color: UIColor?) {
        titleLabel.text = title

        let tintColor = color ?? .systemGray
        iconContainer.backgroundColor = tintColor.withAlphaComponent(0.15)
        iconImageView.tintColor = tintColor
        iconImageView.image = UIImage(systemName: iconName)
            ?? UIImage(systemName: "cube.fill")
    }

    func prepareForReuse() {
        titleLabel.text = nil
        iconImageView.image = nil
        iconContainer.backgroundColor = nil
    }
}

// MARK: - Context Menu

extension ObjectCardView: UIContextMenuInteractionDelegate {

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let editAction = UIAction(
                title: "Edit Object",
                image: UIImage(systemName: "pencil")
            ) { _ in
                guard let self else { return }
                self.delegate?.objectCardViewDidRequestEdit(self)
            }

            let deleteAction = UIAction(
                title: "Delete Object",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                guard let self else { return }
                self.delegate?.objectCardViewDidRequestDelete(self)
            }

            return UIMenu(children: [editAction, deleteAction])
        }
    }
}
