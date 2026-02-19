import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        Task { @MainActor in
            await CoreDataStack.shared.awaitReady()
            if CoreDataStack.shared.loadError != nil {
                window.rootViewController = self.makeDataLoadErrorViewController()
            } else {
                let objectsVC = ObjectsViewController(context: CoreDataStack.shared.viewContext)
                let nav = UINavigationController(rootViewController: objectsVC)
                nav.navigationBar.prefersLargeTitles = true
                window.rootViewController = nav
            }
            window.makeKeyAndVisible()
        }
    }

    private func makeDataLoadErrorViewController() -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Could not load data. Please try again."
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: vc.view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: vc.view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
        ])
        return vc
    }
}
