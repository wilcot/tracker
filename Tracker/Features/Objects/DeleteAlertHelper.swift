import UIKit

@MainActor
struct DeleteAlertHelper {

    static func presentDeleteConfirmation(
        from viewController: UIViewController,
        title: String,
        message: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in onCancel() })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in onConfirm() })
        viewController.present(alert, animated: true)
    }
}
