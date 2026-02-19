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
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.08

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.delegate = self
        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func configure(with objectID: NSManagedObjectID, in context: NSManagedObjectContext) {
        guard let object = try? context.existingObject(with: objectID) as? TrackedObject else { return }
        cardView.configure(
            title: object.name ?? "",
            description: object.objectDescription,
            color: object.displayColor
        )
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

    static let cornerRadius: CGFloat = 14

    weak var delegate: ObjectCardViewDelegate?

    private let backgroundColorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let borderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 2
        view.isUserInteractionEnabled = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
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
        layer.cornerRadius = Self.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        addSubview(backgroundColorView)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        addSubview(stackView)

        addSubview(borderView)

        NSLayoutConstraint.activate([
            backgroundColorView.topAnchor.constraint(equalTo: topAnchor),
            backgroundColorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundColorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundColorView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),

            borderView.topAnchor.constraint(equalTo: topAnchor),
            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            borderView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupContextMenu() {
        let interaction = UIContextMenuInteraction(delegate: self)
        addInteraction(interaction)
    }

    func configure(title: String, description: String?, color: UIColor?) {
        titleLabel.text = title

        let trimmedDesc = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedDesc.isEmpty {
            descriptionLabel.text = nil
            descriptionLabel.isHidden = true
        } else {
            descriptionLabel.text = trimmedDesc
            descriptionLabel.isHidden = false
        }

        let bgColor = color?.withAlphaComponent(0.18) ?? .secondarySystemGroupedBackground
        let borderColor = color?.withAlphaComponent(0.7) ?? .separator

        backgroundColorView.backgroundColor = bgColor
        borderView.layer.borderColor = borderColor.cgColor
    }

    func prepareForReuse() {
        titleLabel.text = nil
        descriptionLabel.text = nil
        descriptionLabel.isHidden = true
        backgroundColorView.backgroundColor = .secondarySystemGroupedBackground
        borderView.layer.borderColor = UIColor.separator.cgColor
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
