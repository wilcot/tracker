import UIKit
import CoreData
import os

@MainActor
protocol ObjectFormViewControllerDelegate: AnyObject {
    func objectFormViewControllerDidSave(_ controller: ObjectFormViewController)
    func objectFormViewControllerDidCancel(_ controller: ObjectFormViewController)
}

final class ObjectFormViewController: UITableViewController {

    enum Mode {
        case create
        case edit(TrackedObject)
    }

    private static let logger = Logger(subsystem: Log.subsystem, category: "persistence")

    weak var delegate: ObjectFormViewControllerDelegate?

    let context: NSManagedObjectContext
    private let mode: Mode

    private var titleText: String = ""
    private var descriptionText: String = ""
    private var selectedColorHex: String?
    private var selectedIconName: String?

    private lazy var titleTextField: UITextField = {
        let tf = UITextField()
        tf.font = .preferredFont(forTextStyle: .body)
        tf.placeholder = "Object name"
        tf.autocapitalizationType = .words
        tf.returnKeyType = .done
        tf.delegate = self
        return tf
    }()

    private lazy var descriptionTextView: UITextView = {
        let tv = UITextView()
        tv.font = .preferredFont(forTextStyle: .body)
        tv.textColor = .label
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: -4)
        tv.isScrollEnabled = false
        tv.delegate = self
        return tv
    }()

    private lazy var descriptionPlaceholder: UILabel = {
        let label = UILabel()
        label.text = "Add a description"
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .placeholderText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var colorSwatchView: ColorSwatchCollectionView = {
        let view = ColorSwatchCollectionView()
        view.delegate = self
        return view
    }()

    private lazy var iconPickerView: IconPickerCollectionView = {
        let view = IconPickerCollectionView()
        view.delegate = self
        return view
    }()

    private var isSaveEnabled: Bool {
        !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Init

    init(context: NSManagedObjectContext, mode: Mode) {
        self.context = context
        self.mode = mode
        super.init(style: .insetGrouped)

        if case .edit(let object) = mode {
            titleText = object.name ?? ""
            descriptionText = object.objectDescription ?? ""
            selectedColorHex = object.colorHex
            selectedIconName = object.iconName
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        configureInitialValues()
        tableView.keyboardDismissMode = .interactive
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        titleTextField.becomeFirstResponder()
    }

    // MARK: - Setup

    private func setupNavigation() {
        switch mode {
        case .create:
            title = "New Object"
        case .edit:
            title = "Edit Object"
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )

        updateSaveButton()
    }

    private func configureInitialValues() {
        titleTextField.text = titleText
        descriptionTextView.text = descriptionText
        descriptionPlaceholder.isHidden = !descriptionText.isEmpty
        colorSwatchView.selectedHex = selectedColorHex
        iconPickerView.selectedIcon = selectedIconName
        iconPickerView.accentColor = ObjectColorCodec.uiColor(from: selectedColorHex)
    }

    private func updateSaveButton() {
        navigationItem.rightBarButtonItem?.isEnabled = isSaveEnabled
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        context.rollback()
        delegate?.objectFormViewControllerDidCancel(self)
    }

    @objc private func saveTapped() {
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDesc: String? = trimmedDesc.isEmpty ? nil : trimmedDesc

        switch mode {
        case .create:
            createObject(name: trimmedTitle, description: finalDesc, colorHex: selectedColorHex, iconName: selectedIconName)
        case .edit(let object):
            updateObject(object, name: trimmedTitle, description: finalDesc, colorHex: selectedColorHex, iconName: selectedIconName)
        }
    }

    private func createObject(name: String, description: String?, colorHex: String?, iconName: String?) {
        let allObjects = (try? context.fetch(TrackedObject.fetchRequest())) ?? []
        let nextKey = FractionalIndex.nextKey(after: allObjects)

        let object = TrackedObject(context: context)
        object.id = UUID()
        object.name = name
        object.objectDescription = description
        object.colorHex = colorHex
        object.iconName = iconName
        object.createdAt = Date()
        object.sortOrder = nextKey

        saveContext(operationName: "createObject", objectName: name)
    }

    private func updateObject(_ object: TrackedObject, name: String, description: String?, colorHex: String?, iconName: String?) {
        object.name = name
        object.objectDescription = description
        object.colorHex = colorHex
        object.iconName = iconName

        saveContext(operationName: "updateObject", objectName: name)
    }

    private func saveContext(operationName: String, objectName: String) {
        do {
            try context.save()
            Self.logger.info("Object saved op=\(operationName, privacy: .public) objectName=\(objectName, privacy: .public)")
            delegate?.objectFormViewControllerDidSave(self)
        } catch {
            Self.logger.error("Save failed op=\(operationName, privacy: .public) objectName=\(objectName, privacy: .public) error=\(error, privacy: .private)")
            let alert = UIAlertController(
                title: "Save Failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return nil
        case 1: return "Description"
        case 2: return "Icon"
        case 3: return "Color"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none

        switch indexPath.section {
        case 0:
            titleTextField.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(titleTextField)
            NSLayoutConstraint.activate([
                titleTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                titleTextField.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                titleTextField.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                titleTextField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
            ])

        case 1:
            descriptionTextView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(descriptionTextView)
            cell.contentView.addSubview(descriptionPlaceholder)
            NSLayoutConstraint.activate([
                descriptionTextView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                descriptionTextView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                descriptionTextView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                descriptionTextView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),

                descriptionPlaceholder.topAnchor.constraint(equalTo: descriptionTextView.topAnchor),
                descriptionPlaceholder.leadingAnchor.constraint(equalTo: descriptionTextView.leadingAnchor, constant: 1),
            ])

        case 2:
            iconPickerView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(iconPickerView)
            NSLayoutConstraint.activate([
                iconPickerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                iconPickerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                iconPickerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                iconPickerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            ])

        case 3:
            colorSwatchView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(colorSwatchView)
            NSLayoutConstraint.activate([
                colorSwatchView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
                colorSwatchView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                colorSwatchView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                colorSwatchView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            ])

        default:
            break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return 44
        case 1: return 180
        case 2: return 260
        case 3: return 124
        default: return UITableView.automaticDimension
        }
    }
}

// MARK: - UITextFieldDelegate

extension ObjectFormViewController: UITextFieldDelegate {

    func textFieldDidChangeSelection(_ textField: UITextField) {
        titleText = textField.text ?? ""
        updateSaveButton()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITextViewDelegate

extension ObjectFormViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        descriptionText = textView.text ?? ""
        descriptionPlaceholder.isHidden = !descriptionText.isEmpty
    }
}

// MARK: - ColorSwatchCollectionViewDelegate

extension ObjectFormViewController: ColorSwatchCollectionViewDelegate {

    func colorSwatchCollectionView(_ collectionView: ColorSwatchCollectionView, didSelectColorHex hex: String?) {
        selectedColorHex = hex
        iconPickerView.accentColor = ObjectColorCodec.uiColor(from: hex)
    }
}

// MARK: - IconPickerCollectionViewDelegate

extension ObjectFormViewController: IconPickerCollectionViewDelegate {

    func iconPickerCollectionView(_ view: IconPickerCollectionView, didSelectIcon iconName: String?) {
        selectedIconName = iconName
    }
}
