import Foundation
import NitroModules
import UIKit

class CustomTextField: UITextField {
    // 追加のカスタマイズがあればここに記述
    var isCaretHidden: Bool = false

    override func caretRect(for position: UITextPosition) -> CGRect {
        return isCaretHidden ? .zero : super.caretRect(for: position)
    }
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
    var autoComplete: AutoComplete? {
        didSet {
            Task {
                @MainActor in
                self.updateAutoComplete()
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
    var autoFocus: Bool? {
        didSet {
            Task { @MainActor in
                if self.autoFocus == true {
                    self.textField.becomeFirstResponder()
                } else {
                    self.textField.resignFirstResponder()
                }
            }
        }
    }
    var caretHidden: Bool? {
        didSet {
            Task { @MainActor in
                self.textField.isCaretHidden = self.caretHidden ?? false
                // Optionally resign and become first responder to force caret redraw
            }
        }
    }
    var clearButtonMode: ClearButtonMode? {
        didSet {
            Task {
                @MainActor in
                self.updateClearButtonMode()
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

    private func updateAutoComplete() {
        switch self.autoComplete {
        case .url:
            textField.textContentType = .URL
        case .namePrefix:
            textField.textContentType = .namePrefix
        case .name:
            textField.textContentType = .name
        case .nameSuffix:
            textField.textContentType = .nameSuffix
        case .givenName:
            textField.textContentType = .givenName
        case .middleName:
            textField.textContentType = .middleName
        case .familyName:
            textField.textContentType = .familyName
        case .nickname:
            textField.textContentType = .nickname
        case .organizationName:
            textField.textContentType = .organizationName
        case .jobTitle:
            textField.textContentType = .jobTitle
        case .location:
            textField.textContentType = .location
        case .fullStreetAddress:
            textField.textContentType = .fullStreetAddress
        case .streetAddressLine1:
            textField.textContentType = .streetAddressLine1
        case .streetAddressLine2:
            textField.textContentType = .streetAddressLine2
        case .addressCity:
            textField.textContentType = .addressCity
        case .addressCityAndState:
            textField.textContentType = .addressCityAndState
        case .addressState:
            textField.textContentType = .addressState
        case .postalCode:
            textField.textContentType = .postalCode
        case .sublocality:
            textField.textContentType = .sublocality
        case .countryName:
            textField.textContentType = .countryName
        case .username:
            textField.textContentType = .username
        case .password:
            textField.textContentType = .password
        case .newPassword:
            textField.textContentType = .newPassword
        case .oneTimeCode:
            textField.textContentType = .oneTimeCode
        case .emailAddress:
            textField.textContentType = .emailAddress
        case .telephoneNumber:
            textField.textContentType = .telephoneNumber
        case .cellularEid:
            if #available(iOS 17.4, *) {
                textField.textContentType = .cellularEID
            } else {
                // Fallback on earlier versions
            }
        case .cellularImei:
            if #available(iOS 17.4, *) {
                textField.textContentType = .cellularIMEI
            } else {
                // Fallback on earlier versions
            }
        case .creditCardNumber:
            textField.textContentType = .creditCardNumber
        case .creditCardExpiration:
            if #available(iOS 17.0, *) {
                textField.textContentType = .creditCardExpiration
            } else {
                // Fallback on earlier versions
            }
        case .creditCardExpirationMonth:
            if #available(iOS 17.0, *) {
                textField.textContentType = .creditCardExpirationMonth
            } else {
                // Fallback on earlier versions
            }
        case .creditCardExpirationYear:
            if #available(iOS 17.0, *) {
                textField.textContentType = .creditCardExpirationYear
            } else {
                // Fallback on earlier versions
            }
        case .creditCardSecurityCode:
            if #available(iOS 17.0, *) {
                textField.textContentType = .creditCardSecurityCode
            } else {
                // Fallback on earlier versions
            }
        case .creditCardType:
            if #available(iOS 17.0, *) {
                textField.textContentType = .creditCardType
            } else {
                // Fallback on earlier versions
            }
        case .creditCardName:
            if #available(iOS 17.0, *) {
                textField.textContentType = .creditCardName
            } else {
                // Fallback on earlier versions
            }
        case .creditCardGivenName:
            if #available(iOS 17.0, *) {
                textField.textContentType = .creditCardGivenName
            } else {
                // Fallback on earlier versions
            }
        case .creditCardMiddleName:
            if #available(iOS 17.0, *) {
                textField.textContentType = .creditCardMiddleName
            } else {
                // Fallback on earlier versions
            }
        case .creditCardFamilyName:
            if #available(iOS 17.0, *) {
                textField.textContentType = .creditCardFamilyName
            } else {
                // Fallback on earlier versions
            }
        case .birthdate:
            if #available(iOS 17.0, *) {
                textField.textContentType = .birthdate
            } else {
                // Fallback on earlier versions
            }
        case .birthdateDay:
            if #available(iOS 17.0, *) {
                textField.textContentType = .birthdateDay
            } else {
                // Fallback on earlier versions
            }
        case .birthdateMonth:
            if #available(iOS 17.0, *) {
                textField.textContentType = .birthdateMonth
            } else {
                // Fallback on earlier versions
            }
        case .birthdateYear:
            if #available(iOS 17.0, *) {
                textField.textContentType = .birthdateYear
            } else {
                // Fallback on earlier versions
            }
        case .dateTime:
            textField.textContentType = .dateTime
        case .flightNumber:
            textField.textContentType = .flightNumber
        case .shipmentTrackingNumber:
            textField.textContentType = .shipmentTrackingNumber
        default:
            break
        }
    }

    private func updateClearButtonMode() {
        switch self.clearButtonMode {
        case .never, .none:
            self.textField.clearButtonMode = .never
        case .whileEditing:
            self.textField.clearButtonMode = .whileEditing
        case .unlessEditing:
            self.textField.clearButtonMode = .unlessEditing
        case .always:
            self.textField.clearButtonMode = .always
        }
    }
}
