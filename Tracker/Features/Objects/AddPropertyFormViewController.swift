import UIKit
import CoreData
import os

final class AddPropertyFormViewController: UIViewController {

    private let object: TrackedObject
    private let context: NSManagedObjectContext
    private let propertyType: PropertyType

    private var scrollView: UIScrollView!
    private var nameTextField: UITextField!
    private var saveButton: UIBarButtonItem!

    private var valueTextField: UITextField?
    private var valueTextView: UITextView?
    private var valueDatePicker: UIDatePicker?
    private var valueSwitch: UISwitch?

    init(object: TrackedObject, context: NSManagedObjectContext, propertyType: PropertyType) {
        self.object = object
        self.context = context
        self.propertyType = propertyType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0xF1/255, green: 0xF5/255, blue: 0xF9/255, alpha: 1)
        setupNavBar()
        setupScrollView()
        setupTypeHeader()
        setupNameField()
        setupValueInput()
        finalizeLayout()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        nameTextField.becomeFirstResponder()
    }

    // MARK: - Navigation

    private func setupNavBar() {
        title = propertyType.displayName

        saveButton = UIBarButtonItem(title: "Save", style: .prominent, target: self, action: #selector(saveTapped))
        saveButton.isEnabled = false
        navigationItem.rightBarButtonItem = saveButton
    }

    // MARK: - Layout

    private let contentStack = UIStackView()

    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func setupTypeHeader() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconBadge = UIView()
        iconBadge.backgroundColor = propertyType.backgroundColor
        iconBadge.layer.cornerRadius = 16
        iconBadge.translatesAutoresizingMaskIntoConstraints = false

        let iconImage = UIImageView()
        iconImage.image = UIImage(systemName: propertyType.systemImage)
        iconImage.tintColor = propertyType.accentColor
        iconImage.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(iconImage)

        let typeLabel = UILabel()
        typeLabel.text = propertyType.displayName
        typeLabel.font = .systemFont(ofSize: 22, weight: .bold)
        typeLabel.textColor = propertyType.accentColor
        typeLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = propertyType.subtitle
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 0x64/255, green: 0x74/255, blue: 0x8B/255, alpha: 1)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [typeLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconBadge)
        container.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconBadge.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconBadge.topAnchor.constraint(equalTo: container.topAnchor),
            iconBadge.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            iconBadge.widthAnchor.constraint(equalToConstant: 56),
            iconBadge.heightAnchor.constraint(equalToConstant: 56),

            iconImage.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconBadge.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textStack.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
        ])

        contentStack.addArrangedSubview(container)
    }

    private func setupNameField() {
        let label = makeSectionLabel("Name")
        contentStack.addArrangedSubview(label)

        let field = UITextField()
        field.placeholder = "Property name"
        field.font = .systemFont(ofSize: 17, weight: .regular)
        field.backgroundColor = .white
        field.layer.cornerRadius = 16
        field.autocapitalizationType = .words
        field.returnKeyType = .done
        field.delegate = self

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        field.leftView = paddingView
        field.leftViewMode = .always
        let rightPadding = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        field.rightView = rightPadding
        field.rightViewMode = .always

        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 52).isActive = true

        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.3).cgColor

        contentStack.addArrangedSubview(field)
        nameTextField = field

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nameDidChange),
            name: UITextField.textDidChangeNotification,
            object: field
        )

        contentStack.setCustomSpacing(8, after: label)
    }

    private func setupValueInput() {
        let label = makeSectionLabel("Initial Value (optional)")
        contentStack.addArrangedSubview(label)
        contentStack.setCustomSpacing(8, after: label)

        switch propertyType {
        case .string:
            let field = makeStyledTextField(placeholder: "Text value", keyboard: .default)
            field.autocapitalizationType = .sentences
            contentStack.addArrangedSubview(field)
            valueTextField = field

        case .integer:
            let field = makeStyledTextField(placeholder: "Number", keyboard: .numberPad)
            contentStack.addArrangedSubview(field)
            valueTextField = field

        case .date:
            let picker = UIDatePicker()
            picker.datePickerMode = .date
            picker.preferredDatePickerStyle = .inline
            picker.translatesAutoresizingMaskIntoConstraints = false

            let wrapper = UIView()
            wrapper.backgroundColor = .white
            wrapper.layer.cornerRadius = 16
            wrapper.layer.borderWidth = 1
            wrapper.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.3).cgColor
            wrapper.translatesAutoresizingMaskIntoConstraints = false

            wrapper.addSubview(picker)
            NSLayoutConstraint.activate([
                picker.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
                picker.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 8),
                picker.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -8),
                picker.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -8),
            ])

            contentStack.addArrangedSubview(wrapper)
            valueDatePicker = picker

        case .description:
            let textView = UITextView()
            textView.font = .systemFont(ofSize: 17, weight: .regular)
            textView.backgroundColor = .white
            textView.layer.cornerRadius = 16
            textView.layer.borderWidth = 1
            textView.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.3).cgColor
            textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
            textView.translatesAutoresizingMaskIntoConstraints = false
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
            textView.isScrollEnabled = false
            contentStack.addArrangedSubview(textView)
            valueTextView = textView

        case .boolean:
            let row = UIView()
            row.backgroundColor = .white
            row.layer.cornerRadius = 16
            row.layer.borderWidth = 1
            row.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.3).cgColor
            row.translatesAutoresizingMaskIntoConstraints = false

            let switchLabel = UILabel()
            switchLabel.text = "Default value"
            switchLabel.font = .systemFont(ofSize: 17, weight: .regular)
            switchLabel.textColor = UIColor(red: 0x0F/255, green: 0x17/255, blue: 0x2A/255, alpha: 1)
            switchLabel.translatesAutoresizingMaskIntoConstraints = false

            let toggle = UISwitch()
            toggle.onTintColor = propertyType.accentColor
            toggle.translatesAutoresizingMaskIntoConstraints = false

            row.addSubview(switchLabel)
            row.addSubview(toggle)

            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: 52),
                switchLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
                switchLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
                toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            ])

            contentStack.addArrangedSubview(row)
            valueSwitch = toggle
        }
    }

    private func finalizeLayout() {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(spacer)
    }

    // MARK: - Helpers

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor(red: 0x64/255, green: 0x74/255, blue: 0x8B/255, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeStyledTextField(placeholder: String, keyboard: UIKeyboardType) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 17, weight: .regular)
        field.backgroundColor = .white
        field.layer.cornerRadius = 16
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.3).cgColor
        field.keyboardType = keyboard

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        field.leftView = paddingView
        field.leftViewMode = .always
        let rightPadding = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        field.rightView = rightPadding
        field.rightViewMode = .always

        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return field
    }

    // MARK: - Actions

    @objc private func nameDidChange() {
        let trimmed = nameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        saveButton.isEnabled = !trimmed.isEmpty
    }

    @objc private func saveTapped() {
        let trimmed = nameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !trimmed.isEmpty else { return }

        let siblingFetch = Property.fetchRequest()
        siblingFetch.predicate = NSPredicate(format: "object == %@", object)
        let siblings = (try? context.fetch(siblingFetch)) ?? []
        let nextKey = FractionalIndex.nextKey(after: siblings)

        let property = Property(context: context)
        property.id = UUID()
        property.name = trimmed
        property.type = propertyType.rawValue
        property.sortOrder = nextKey
        property.object = object
        property.timestamp = Date()
        property.userTimestamp = Date()

        switch propertyType {
        case .string:
            let text = valueTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            property.setValue(string: text?.isEmpty == true ? nil : text)

        case .integer:
            let text = valueTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let i = Int64(text) {
                property.setValue(integer: i)
            }

        case .date:
            property.setValue(date: valueDatePicker?.date)

        case .description:
            let text = valueTextView?.text.trimmingCharacters(in: .whitespacesAndNewlines)
            property.setValue(string: text?.isEmpty == true ? nil : text)

        case .boolean:
            let isOn = valueSwitch?.isOn ?? false
            property.setValue(bool: isOn)
        }

        let objectName = object.name ?? ""
        do {
            try context.save()
            Log.persistence.info("Property created objectName=\(objectName, privacy: .public) propertyName=\(trimmed, privacy: .public) type=\(self.propertyType.rawValue, privacy: .public)")

            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.success)

            dismiss(animated: true)
        } catch {
            Log.persistence.error("Save failed op=createProperty objectName=\(objectName, privacy: .public) propertyName=\(trimmed, privacy: .public) error=\(error, privacy: .private)")
            let alert = UIAlertController(title: "Save Failed", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - UITextFieldDelegate

extension AddPropertyFormViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === nameTextField {
            saveTapped()
        }
        return true
    }
}
