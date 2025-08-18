import Foundation
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
    var allowFontScaling: Bool? = true {
        didSet {
            Task {
                @MainActor in
                textField.adjustsFontForContentSizeCategory =
                    self.allowFontScaling ?? true
            }
        }
    }
    var autoCapitalize: AutoCapitalize? {
        didSet {
            Task {
                @MainActor in
                self.updateAutoCapitalize()
            }
        }
    }
    var autoCorrect: Bool? = true {
        didSet {
            Task {
                @MainActor in
                self.updateAutoCorrect()
            }
        }
    }
    var multiline: Bool? = false
    var placeholder: String? {
        didSet {
            Task { @MainActor in
                textField.placeholder = self.placeholder
            }
        }
    }
    var onInitialHeightMeasured: ((_ height: Double) -> Void)?

    private func updateAutoCorrect() {
        if let value = autoCorrect {
            textField.autocorrectionType = value ? .yes : .no
        } else {
            textField.autocorrectionType = .default
        }
    }

    private func updateAutoCapitalize() {
        switch self.autoCapitalize {
        case nil, .sentences:
            textField.autocapitalizationType = .sentences
        case .words:
            textField.autocapitalizationType = .words
        case .characters:
            textField.autocapitalizationType = .allCharacters
        case .none?:
            textField.autocapitalizationType = .none
        }
    }
}
