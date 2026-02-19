import UIKit
import CoreData

final class CreateObjectViewController: UIViewController {

    let context: NSManagedObjectContext
    private var nameTextField: UITextField!
    private var saveButton: UIBarButtonItem!

    init(context: NSManagedObjectContext) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
        title = "New Object"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupNavBar()
        setupTextField()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        nameTextField.becomeFirstResponder()
    }

    // MARK: - Setup

    private func setupNavBar() {
        saveButton = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        saveButton.isEnabled = false
        navigationItem.rightBarButtonItem = saveButton

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
    }

    private func setupTextField() {
        nameTextField = UITextField()
        nameTextField.placeholder = "Object name"
        nameTextField.borderStyle = .roundedRect
        nameTextField.autocapitalizationType = .words
        nameTextField.returnKeyType = .done
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.delegate = self

        view.addSubview(nameTextField)
        NSLayoutConstraint.activate([
            nameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            nameTextField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: UITextField.textDidChangeNotification,
            object: nameTextField
        )
    }

    // MARK: - Actions

    @objc private func textDidChange() {
        let trimmed = nameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        saveButton.isEnabled = !trimmed.isEmpty
    }

    @objc private func saveTapped() {
        let trimmed = nameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !trimmed.isEmpty else { return }

        let object = TrackerObject(context: context)
        object.id = UUID()
        object.name = trimmed
        object.createdAt = Date()

        do {
            try context.save()
            dismiss(animated: true)
        } catch {
            let alert = UIAlertController(
                title: "Save Failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
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

extension CreateObjectViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        saveTapped()
        return true
    }
}
