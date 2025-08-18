import NitroModules
import UIKit

class CustomTextField: UITextField {
    // 追加のカスタマイズがあればここに記述
}

class HybridTextInputView: HybridNitroTextInputViewSpec {
    private let textField = CustomTextField()
    var view: UIView { return textField }

    override init() {
        super.init()
        self.textField.placeholder = " "
        // Defer until layout pass to get accurate intrinsic height
        Task { @MainActor in
            // Ensure layout is up-to-date
            self.textField.setNeedsLayout()
            self.textField.layoutIfNeeded()
            // Calculate height using intrinsicContentSize as first measurement
            let initialHeight = self.textField.intrinsicContentSize.height
            if let callback = self.onInitialHeightMeasured {
                callback(initialHeight)
            }
        }
    }
    // Props
    var autoCorrect: Bool = false
    var placeholder: String? {
        didSet {
            Task { @MainActor in
                self.updatePlaceholder()
            }
        }
    }
    var onInitialHeightMeasured: ((_ height: Double) -> Void)?

    private func updatePlaceholder() {
        textField.placeholder = self.placeholder
    }
}
