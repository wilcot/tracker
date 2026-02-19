import UIKit
import CoreData
import os

enum PropertyType: String, CaseIterable {
    case string = "string"
    case integer = "integer"
    case date = "date"

    var displayName: String {
        switch self {
        case .string: return "Text"
        case .integer: return "Number"
        case .date: return "Date"
        }
    }

    var systemImage: String {
        switch self {
        case .string: return "text.cursor"
        case .integer: return "number"
        case .date: return "calendar"
        }
    }
}

final class AddPropertyViewController: UIViewController {

    private let object: TrackedObject
    private let context: NSManagedObjectContext
    private var scrollView: UIScrollView!
    private var nameTextField: UITextField!
    private var typeControl: UISegmentedControl!
    private var valueContainerStack: UIStackView!
    private var valueTextField: UITextField?
    private var valueDatePicker: UIDatePicker?
    private var saveButton: UIBarButtonItem!

    init(object: TrackedObject, context: NSManagedObjectContext) {
        self.object = object
        self.context = context
        super.init(nibName: nil, bundle: nil)
        title = "New Property"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupNavBar()
        setupFields()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        nameTextField.becomeFirstResponder()
    }

    // MARK: - Setup

    private func setupNavBar() {
        saveButton = UIBarButtonItem(title: "Save", style: .prominent, target: self, action: #selector(saveTapped))
        saveButton.isEnabled = false
        navigationItem.rightBarButtonItem = saveButton
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
    }

    private func setupFields() {
        nameTextField = UITextField()
        nameTextField.placeholder = "Property name"
        nameTextField.borderStyle = .roundedRect
        nameTextField.autocapitalizationType = .words
        nameTextField.returnKeyType = .done
        nameTextField.delegate = self
        nameTextField.translatesAutoresizingMaskIntoConstraints = false

        typeControl = UISegmentedControl(items: PropertyType.allCases.map { $0.displayName })
        typeControl.selectedSegmentIndex = 0
        typeControl.translatesAutoresizingMaskIntoConstraints = false
        typeControl.addTarget(self, action: #selector(typeChanged), for: .valueChanged)

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        valueContainerStack = UIStackView()
        valueContainerStack.axis = .vertical
        valueContainerStack.spacing = 8
        valueContainerStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(nameTextField)
        scrollView.addSubview(typeControl)
        scrollView.addSubview(valueContainerStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            nameTextField.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            nameTextField.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            typeControl.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 16),
            typeControl.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            typeControl.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            valueContainerStack.topAnchor.constraint(equalTo: typeControl.bottomAnchor, constant: 16),
            valueContainerStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            valueContainerStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            valueContainerStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange),
            name: UITextField.textDidChangeNotification, object: nameTextField)
        buildValueUI(for: PropertyType.allCases[typeControl.selectedSegmentIndex])
    }

    @objc private func typeChanged() {
        buildValueUI(for: PropertyType.allCases[typeControl.selectedSegmentIndex])
    }

    private func buildValueUI(for type: PropertyType) {
        valueContainerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        valueTextField = nil
        valueDatePicker = nil

        switch type {
        case .string:
            let field = UITextField()
            field.placeholder = "Initial value (optional)"
            field.borderStyle = .roundedRect
            field.autocapitalizationType = .sentences
            field.translatesAutoresizingMaskIntoConstraints = false
            valueContainerStack.addArrangedSubview(field)
            valueTextField = field

        case .integer:
            let field = UITextField()
            field.placeholder = "Initial value (optional)"
            field.borderStyle = .roundedRect
            field.keyboardType = .numberPad
            field.translatesAutoresizingMaskIntoConstraints = false
            valueContainerStack.addArrangedSubview(field)
            valueTextField = field

        case .date:
            let picker = UIDatePicker()
            picker.datePickerMode = .date
            if #available(iOS 14.0, *) {
                picker.preferredDatePickerStyle = .inline
            } else {
                picker.preferredDatePickerStyle = .wheels
            }
            picker.translatesAutoresizingMaskIntoConstraints = false
            valueContainerStack.addArrangedSubview(picker)
            valueDatePicker = picker
        }
    }

    // MARK: - Actions

    @objc private func textDidChange() {
        let trimmed = nameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        saveButton.isEnabled = !trimmed.isEmpty
    }

    @objc private func saveTapped() {
        let trimmed = nameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !trimmed.isEmpty else { return }

        let selectedType = PropertyType.allCases[typeControl.selectedSegmentIndex]

        let siblingFetch = Property.fetchRequest()
        siblingFetch.predicate = NSPredicate(format: "object == %@", object)
        let siblings = (try? context.fetch(siblingFetch)) ?? []
        let nextKey = FractionalIndex.nextKey(after: siblings)

        let property = Property(context: context)
        property.id = UUID()
        property.name = trimmed
        property.type = selectedType.rawValue
        property.sortOrder = nextKey
        property.object = object
        property.timestamp = Date()
        property.userTimestamp = Date()

        switch selectedType {
        case .string:
            let valueText = valueTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            property.setValue(string: valueText?.isEmpty == true ? nil : valueText)
        case .integer:
            let valueText = valueTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let i = Int64(valueText) {
                property.setValue(integer: i)
            }
        case .date:
            property.setValue(date: valueDatePicker?.date)
        }

        let objectName = object.name ?? ""
        do {
            try context.save()
            Log.persistence.info("Property created objectName=\(objectName, privacy: .public) propertyName=\(trimmed, privacy: .public)")
            dismiss(animated: true)
        } catch {
            Log.persistence.error("Save failed op=createProperty objectName=\(objectName, privacy: .public) propertyName=\(trimmed, privacy: .public) error=\(error, privacy: .private)")
            let alert = UIAlertController(title: "Save Failed", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    @objc private func cancelTapped() {
        context.rollback()
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension AddPropertyViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        saveTapped()
        return true
    }
}
