import UIKit
import CoreData
import os

final class EditPropertyValueViewController: UIViewController {

    private static let logger = Logger(subsystem: Log.subsystem, category: "persistence")

    private let propertyID: NSManagedObjectID
    private let context: NSManagedObjectContext
    private var property: Property!
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    private var textField: UITextField?
    private var datePicker: UIDatePicker?
    private var userTimestampPicker: UIDatePicker!
    private var saveButton: UIBarButtonItem!

    init(propertyID: NSManagedObjectID, context: NSManagedObjectContext) {
        self.propertyID = propertyID
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let prop = try? context.existingObject(with: propertyID) as? Property else {
            navigationController?.popViewController(animated: true)
            return
        }
        property = prop
        title = prop.name
        view.backgroundColor = .systemGroupedBackground
        setupNavBar()
        setupContent(property: prop)
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        textField?.becomeFirstResponder()
    }

    // MARK: - Setup

    private func setupNavBar() {
        saveButton = UIBarButtonItem(title: "Save", style: .prominent, target: self, action: #selector(saveTapped))

        let historyButton = UIBarButtonItem(
            image: UIImage(systemName: "clock.arrow.circlepath"),
            style: .plain,
            target: self,
            action: #selector(historyTapped)
        )
        navigationItem.rightBarButtonItems = [saveButton, historyButton]
    }

    private func setupContent(property: Property) {
        guard let type = PropertyType(rawValue: property.type ?? "") else { return }

        let nameLabel = UILabel()
        nameLabel.text = property.name
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        stackView = UIStackView(arrangedSubviews: [nameLabel])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        switch type {
        case .string:
            let field = UITextField()
            field.placeholder = "Value"
            field.borderStyle = .roundedRect
            field.text = property.valueString
            field.autocapitalizationType = .sentences
            field.translatesAutoresizingMaskIntoConstraints = false
            field.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
            stackView.addArrangedSubview(field)
            textField = field

        case .integer:
            let field = UITextField()
            field.placeholder = "Number"
            field.borderStyle = .roundedRect
            field.keyboardType = .numberPad
            if let num = property.valueInteger {
                field.text = "\(num.int64Value)"
            }
            field.translatesAutoresizingMaskIntoConstraints = false
            field.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
            stackView.addArrangedSubview(field)
            textField = field

        case .date:
            let picker = UIDatePicker()
            picker.datePickerMode = .date
            picker.preferredDatePickerStyle = .inline
            if let d = property.valueDate {
                picker.date = d
            }
            picker.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(picker)
            datePicker = picker
        }

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        stackView.addArrangedSubview(separator)

        let timestampRow = UIStackView()
        timestampRow.axis = .horizontal
        timestampRow.spacing = 8
        timestampRow.alignment = .center
        timestampRow.translatesAutoresizingMaskIntoConstraints = false

        let timestampLabel = UILabel()
        timestampLabel.text = "Date"
        timestampLabel.font = .preferredFont(forTextStyle: .body)
        timestampLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        userTimestampPicker = UIDatePicker()
        userTimestampPicker.datePickerMode = .dateAndTime
        userTimestampPicker.preferredDatePickerStyle = .compact
        userTimestampPicker.date = Date()

        timestampRow.addArrangedSubview(timestampLabel)
        timestampRow.addArrangedSubview(userTimestampPicker)
        stackView.addArrangedSubview(timestampRow)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    // MARK: - Actions

    @objc private func textDidChange() {
        saveButton.isEnabled = true
    }

    @objc private func historyTapped() {
        guard let name = property.name, let object = property.object else { return }
        let historyVC = PropertyHistoryViewController(
            propertyName: name,
            objectID: object.objectID,
            context: context
        )
        navigationController?.pushViewController(historyVC, animated: true)
    }

    @objc private func saveTapped() {
        guard let property = property, let type = PropertyType(rawValue: property.type ?? "") else { return }

        let newEntry = Property(context: context)
        newEntry.id = UUID()
        newEntry.name = property.name
        newEntry.type = property.type
        newEntry.sortOrder = property.sortOrder
        newEntry.object = property.object
        newEntry.timestamp = Date()
        newEntry.userTimestamp = userTimestampPicker.date

        switch type {
        case .string:
            let trimmed = textField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            newEntry.setValue(string: trimmed?.isEmpty == true ? nil : trimmed)

        case .integer:
            let text = textField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                newEntry.setValue(integer: nil)
            } else if let i = Int64(text) {
                newEntry.setValue(integer: i)
            } else {
                context.delete(newEntry)
                let alert = UIAlertController(title: "Invalid Number", message: "Please enter a whole number.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }

        case .date:
            newEntry.setValue(date: datePicker?.date)
        }

        do {
            try context.save()
            navigationController?.popViewController(animated: true)
        } catch {
            Self.logger.error("Save failed op=addPropertyEntry error=\(error, privacy: .private)")
            let alert = UIAlertController(title: "Save Failed", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
