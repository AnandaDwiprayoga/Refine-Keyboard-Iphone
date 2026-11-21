import SwiftUI
import UIKit

/// Hosts the SwiftUI keyboard and forwards text changes to the model.
final class KeyboardViewController: UIInputViewController {
    static let height: CGFloat = 272

    private var model: KeyboardModel!
    private var hosting: UIHostingController<KeyboardView>!

    override func viewDidLoad() {
        super.viewDidLoad()
        model = KeyboardModel(controller: self)
        hosting = UIHostingController(rootView: KeyboardView(model: model, controller: self))
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        let height = view.heightAnchor.constraint(equalToConstant: Self.height)
        height.priority = .defaultHigh  // avoids fights with the system's own height constraint
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.textChanged()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        model.textChanged()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        model.textChanged()
    }
}

/// The 🌐 key. It has to be a UIKit control so a long press can show the
/// system's keyboard list through handleInputModeList(from:with:).
struct GlobeKey: UIViewRepresentable {
    let controller: UIInputViewController

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.tintColor = .label
        button.accessibilityLabel = "Next keyboard"
        button.addTarget(controller, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}
