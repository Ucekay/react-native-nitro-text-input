import Foundation
import NitroModules
import UIKit

class CustomTextField: UITextField, UITextFieldDelegate {
    // 追加のカスタマイズがあればここに記述
    var isCaretHidden: Bool = false
    var clearTextOnFocus: Bool = false
    var isContextMenuHidden: Bool = false
    var maxLength: Int?
    var onTextChanged: ((_ text: String) -> Void)?
    var onDidBeginEditing: (() -> Void)?
    var onDidEndEditing: (() -> Void)?
    var onKeyPressed: ((_ key: String) -> Void)?
    var onSelectionChanged: ((_ start: Double, _ end: Double) -> Void)?
    var onEditingSubmitted: ((_ text: String) -> Void)?
    var submitBehavior: SubmitBehavior?
    private var textWasPasted: Bool = false
    var onTouchBegan:
        (
            (
                _ pageX: Double, _ pageY: Double, _ locationX: Double,
                _ locationY: Double, _ timestamp: Double
            ) -> Void
        )?
    var onTouchEnded:
        (
            (
                _ pageX: Double, _ pageY: Double, _ locationX: Double,
                _ locationY: Double, _ timestamp: Double
            ) -> Void
        )?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = false
        self.layer.masksToBounds = false
        self.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleTextDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: self
        )
        // Selection change will be handled via UITextFieldDelegate (iOS 13+)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.clipsToBounds = false
        self.layer.masksToBounds = false
        self.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleTextDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: self
        )
        // Selection change will be handled via UITextFieldDelegate (iOS 13+)
    }

    override func caretRect(for position: UITextPosition) -> CGRect {
        return isCaretHidden ? .zero : super.caretRect(for: position)
    }

    override func becomeFirstResponder() -> Bool {
        if clearTextOnFocus {
            self.text = ""
        }
        return super.becomeFirstResponder()
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?)
        -> Bool
    {
        if isContextMenuHidden { return false }
        return super.canPerformAction(action, withSender: sender)
    }

    @available(iOS 13.0, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        if #available(iOS 17.0, *), isContextMenuHidden {
            builder.remove(menu: .autoFill)
        }
        super.buildMenu(with: builder)
    }

    // MARK: - UITextFieldDelegate (maxLength enforcement)
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if self.textWasPasted == false {
            if string == "\n" {
                onKeyPressed?("Enter")
            } else if !string.isEmpty {
                onKeyPressed?(string)
            }
        }
        // Allow IME composition to proceed without truncation
        if self.markedTextRange != nil { return true }
        guard let maxLen = self.maxLength else { return true }

        let current =
            (self.attributedText?.string ?? self.text ?? "") as NSString
        let allowedLength = maxLen - current.length + range.length
        if allowedLength <= 0 {
            // Always allow deletions
            return string.isEmpty
        }

        let incoming = string as NSString
        if incoming.length > allowedLength {
            var cutIndex = allowedLength
            if allowedLength > 0 {
                let composed = incoming.rangeOfComposedCharacterSequence(
                    at: allowedLength - 1
                )
                if composed.location + composed.length > allowedLength {
                    cutIndex = composed.location
                }
            }
            let limited = incoming.substring(to: max(0, cutIndex))
            let newText = current.replacingCharacters(in: range, with: limited)
            self.text = newText
            // Keep caret right after the actually inserted (trimmed) text.
            // Defer to next runloop to avoid UIKit overriding it after we return false.
            let targetOffset = min(
                (newText as NSString).length,
                range.location + (limited as NSString).length
            )
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let start = self.position(
                    from: self.beginningOfDocument,
                    offset: targetOffset
                ) {
                    self.selectedTextRange = self.textRange(
                        from: start,
                        to: start
                    )
                }
            }
            return false
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        onDidBeginEditing?()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        onDidEndEditing?()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Single-line: default to blurAndSubmit when nil or 'newline'
        var behavior = submitBehavior ?? .blurandsubmit
        if behavior == .newline { behavior = .blurandsubmit }
        if behavior == .submit || behavior == .blurandsubmit {
            onEditingSubmitted?(self.text ?? "")
        }
        if behavior == .blurandsubmit {
            // Explicitly blur to ensure keyboard hides
            textField.resignFirstResponder()
            return true
        }
        // For 'submit', do not blur or resign
        return false
    }

    override func deleteBackward() {
        onKeyPressed?("Backspace")
        super.deleteBackward()
    }

    override func paste(_ sender: Any?) {
        self.textWasPasted = true
        super.paste(sender)
        DispatchQueue.main.async { [weak self] in
            self?.textWasPasted = false
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let local = touch.location(in: self)
            var page = local
            if let window = self.window {
                page = touch.location(in: window)
            }
            let ts = touch.timestamp * 1000.0
            onTouchBegan?(page.x, page.y, local.x, local.y, ts)
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let local = touch.location(in: self)
            var page = local
            if let window = self.window {
                page = touch.location(in: window)
            }
            let ts = touch.timestamp * 1000.0
            onTouchEnded?(page.x, page.y, local.x, local.y, ts)
        }
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        if let touch = touches.first {
            let local = touch.location(in: self)
            var page = local
            if let window = self.window {
                page = touch.location(in: window)
            }
            let ts = touch.timestamp * 1000.0
            onTouchEnded?(page.x, page.y, local.x, local.y, ts)
        }
        super.touchesCancelled(touches, with: event)
    }

    @objc private func handleTextDidChange(_ notification: Notification) {
        guard let maxLen = self.maxLength else { return }
        // Do not enforce while composing
        if self.markedTextRange != nil { return }
        let current =
            (self.attributedText?.string ?? self.text ?? "") as NSString
        if current.length > maxLen {
            var cutIndex = maxLen
            if maxLen > 0 {
                let composed = current.rangeOfComposedCharacterSequence(
                    at: maxLen - 1
                )
                if composed.location + composed.length > maxLen {
                    cutIndex = composed.location
                }
            }
            let limited = current.substring(to: max(0, cutIndex))
            self.text = limited
        }
        // Notify text changed after any trimming
        onTextChanged?(self.text ?? "")
        // Also notify selection changed after text updates
        if let range = self.selectedTextRange {
            let start = self.offset(
                from: self.beginningOfDocument,
                to: range.start
            )
            let end = self.offset(from: self.beginningOfDocument, to: range.end)
            onSelectionChanged?(Double(max(0, start)), Double(max(0, end)))
        }
    }

    @available(iOS 13.0, *)
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard let range = self.selectedTextRange else { return }
        let start = self.offset(from: self.beginningOfDocument, to: range.start)
        let end = self.offset(from: self.beginningOfDocument, to: range.end)
        onSelectionChanged?(Double(max(0, start)), Double(max(0, end)))
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: UITextField.textDidChangeNotification,
            object: self
        )
    }
}

class HybridTextInputView: HybridNitroTextInputViewSpec {
    private let textField = CustomTextField()
    private var baseFont: UIFont = UIFont.systemFont(ofSize: 17)
    private var hasAppliedDefaultValue: Bool = false
    var view: UIView { return textField }

    override init() {
        super.init()
        self.textField.clipsToBounds = false
        self.textField.layer.masksToBounds = false
        // Defer until layout pass to get accurate intrinsic height
        Task { @MainActor in
            // Ensure layout is up-to-date
            self.textField.setNeedsLayout()
            self.textField.layoutIfNeeded()
            // Cache base font for scaling
            self.baseFont = self.textField.font ?? UIFont.systemFont(ofSize: 17)
            self.applyFontScaling()
            self.wireTextFieldEventCallbacks()
            // Calculate height using intrinsicContentSize as first measurement
            let initialHeight = self.textField.intrinsicContentSize.height
            if let callback = self.onInitialHeightMeasured {
                callback(initialHeight)
            }
        }
        // Listen for Dynamic Type changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleContentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    override func focus() {
        Task { @MainActor in
            // Apply showSoftInputOnFocus before focusing
            let show = self.showSoftInputOnFocus ?? true
            if show {
                self.textField.inputView = nil
            } else {
                self.textField.inputView = UIView()
            }
            _ = self.textField.becomeFirstResponder()
            if self.clearTextOnFocus == true {
                self.textField.attributedText = NSAttributedString()
            }
            if self.selectTextOnFocus == true {
                DispatchQueue.main.async { [weak self] in
                    self?.textField.selectAll(nil)
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    // Props
    var allowFontScaling: Bool? = true {
        didSet {
            Task {
                @MainActor in
                // We'll manage scaling manually to support maxFontSizeMultiplier caps
                self.textField.adjustsFontForContentSizeCategory = false
                self.applyFontScaling()
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
                    // Ensure inputView reflects showSoftInputOnFocus before focusing
                    let show = self.showSoftInputOnFocus ?? true
                    if show {
                        self.textField.inputView = nil
                    } else {
                        self.textField.inputView = UIView()
                    }
                    _ = self.textField.becomeFirstResponder()
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
    var clearTextOnFocus: Bool? {
        didSet {
            self.textField.clearTextOnFocus = self.clearTextOnFocus ?? false
        }
    }
    var contextMenuHidden: Bool? {
        didSet {
            Task {
                @MainActor in
                self.textField.isContextMenuHidden =
                    self.contextMenuHidden ?? false
                if #available(iOS 18.0, *) {
                    if self.contextMenuHidden == true {
                        self.textField.writingToolsBehavior = .none
                    } else {
                        self.textField.writingToolsBehavior = .default
                    }
                }
            }
        }
    }
    var defaultValue: String? {
        didSet {
            Task { @MainActor in
                self.setDefaultValue()
            }
        }
    }
    var submitBehavior: SubmitBehavior? {
        didSet {
            self.textField.submitBehavior = self.submitBehavior
        }
    }
    var editable: Bool? {
        didSet {
            self.textField.isEnabled = self.editable ?? true
        }
    }
    var maxFontSizeMultiplier: Double? {
        didSet {
            Task { @MainActor in
                self.applyFontScaling()
            }
        }
    }
    var enablesReturnKeyAutomatically: Bool? {
        didSet {
            Task {
                @MainActor in
                self.textField.enablesReturnKeyAutomatically =
                    self.enablesReturnKeyAutomatically ?? false
            }
        }
    }
    var keyboardType: KeyboardType? {
        didSet {
            Task {
                @MainActor in
                self.updateKeyboardType()
            }
        }
    }
    var passwordRules: String? {
        didSet {
            Task { @MainActor in
                if #available(iOS 12.0, *) {
                    if let rules = self.passwordRules, rules.isEmpty == false {
                        self.textField.passwordRules = UITextInputPasswordRules(
                            descriptor: rules
                        )
                    } else {
                        self.textField.passwordRules = nil
                    }
                }
            }
        }
    }
    var keyboardAppearance: KeyboardAppearance? {
        didSet {
            Task { @MainActor in
                self.updateKeyboardAppearance()
            }
        }
    }
    var maxLength: Double? {
        didSet {
            if let value = self.maxLength, value.isFinite {
                self.textField.maxLength = max(0, Int(floor(value)))
            } else {
                self.textField.maxLength = nil
            }
        }
    }
    var multiline: Bool? = false
    var placeholder: String? {
        didSet {
            Task { @MainActor in
                textField.placeholder = self.placeholder
                self.updatePlaceholderAttributedColor()
            }
        }
    }
    var textAlign: TextAlign? {
        didSet {
            Task { @MainActor in
                let alignment: NSTextAlignment
                switch self.textAlign {
                case .some(.center): alignment = .center
                case .some(.right): alignment = .right
                case .some(.left): alignment = .left
                case .some(.natural), .none: alignment = .natural
                }
                self.textField.textAlignment = alignment
            }
        }
    }
    var placeholderTextColor: ProcessedColor? {
        didSet {
            Task { @MainActor in
                self.updatePlaceholderAttributedColor()
            }
        }
    }
    var returnKeyType: ReturnKeyType? {
        didSet {
            Task {
                @MainActor in
                self.updateReturnKeyType()
            }
        }
    }
    var secureTextEntry: Bool? {
        didSet {
            Task { @MainActor in
                self.textField.isSecureTextEntry = self.secureTextEntry ?? false
            }
        }
    }
    var selection: TextSelection? {
        didSet {
            Task { @MainActor in
                guard let sel = self.selection else { return }
                let startOffset = Int(sel.start)
                let endOffset = Int(sel.end)
                guard
                    let start = self.textField.position(
                        from: self.textField.beginningOfDocument,
                        offset: startOffset
                    ),
                    let end = self.textField.position(
                        from: self.textField.beginningOfDocument,
                        offset: endOffset
                    )
                else { return }
                if let range = self.textField.textRange(from: start, to: end) {
                    self.textField.selectedTextRange = range
                }
            }
        }
    }
    var selectionColor: ProcessedColor? {
        didSet {
            Task { @MainActor in
                self.updateSelectionTintColor()
            }
        }
    }
    var selectTextOnFocus: Bool? = false
    var showSoftInputOnFocus: Bool? = true {
        didSet {
            Task { @MainActor in
                let show = self.showSoftInputOnFocus ?? true
                if show {
                    self.textField.inputView = nil
                    if self.textField.isFirstResponder {
                        self.textField.reloadInputViews()
                    }
                } else {
                    self.textField.inputView = UIView()
                }
            }
        }
    }
    var smartInsertDelete: Bool? {
        didSet {
            Task { @MainActor in
                if #available(iOS 13.0, *) {
                    if let enabled = self.smartInsertDelete {
                        self.textField.smartInsertDeleteType =
                            enabled
                            ? .yes : .no
                    } else {
                        self.textField.smartInsertDeleteType = .default
                    }
                }
            }
        }
    }
    var spellCheck: Bool? {
        didSet {
            Task { @MainActor in
                if let v = self.spellCheck {
                    self.textField.spellCheckingType = v ? .yes : .no
                } else {
                    self.textField.spellCheckingType = .default
                }
            }
        }
    }

    var onInitialHeightMeasured: ((_ height: Double) -> Void)?
    var onBlurred: (() -> Void)?
    var onEditingEnded: ((_ text: String) -> Void)?
    var onEditingSubmitted: ((_ text: String) -> Void)?
    var onFocused: (() -> Void)?
    var onKeyPressed: ((String) -> Void)?
    var onSelectionChanged: ((_ start: Double, _ end: Double) -> Void)?
    var onTextChanged: ((_ text: String) -> Void)?
    var onTouchBegan:
        (
            (
                _ pageX: Double, _ pageY: Double, _ locationX: Double,
                _ locationY: Double, _ timestamp: Double
            ) -> Void
        )?
    var onTouchEnded:
        (
            (
                _ pageX: Double, _ pageY: Double, _ locationX: Double,
                _ locationY: Double, _ timestamp: Double
            ) -> Void
        )?

    func focus() {

    }
    func blur() {}
    func clear() {}
    func isFocused() {}

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
        guard let auto = self.autoComplete else {
            // Reset to no content type when unset
            textField.textContentType = nil
            return
        }
        switch auto {
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
        guard let mode = self.clearButtonMode else {
            self.textField.clearButtonMode = .never
            return
        }
        switch mode {
        case .never:
            self.textField.clearButtonMode = .never
        case .whileEditing:
            self.textField.clearButtonMode = .whileEditing
        case .unlessEditing:
            self.textField.clearButtonMode = .unlessEditing
        case .always:
            self.textField.clearButtonMode = .always
        }
    }

    private func setDefaultValue() {
        guard self.hasAppliedDefaultValue == false else { return }
        guard let initialText = self.defaultValue,
            !(self.textField.text?.isEmpty == false)
        else { return }
        self.textField.text = initialText
        self.hasAppliedDefaultValue = true
    }

    private func updateReturnKeyType() {
        guard let hint = self.returnKeyType else {
            self.textField.returnKeyType = .default
            return
        }
        switch hint {
        case .go:
            self.textField.returnKeyType = .go
        case .google:
            self.textField.returnKeyType = .google
        case .join:
            self.textField.returnKeyType = .join
        case .next:
            self.textField.returnKeyType = .next
        case .route:
            self.textField.returnKeyType = .route
        case .search:
            self.textField.returnKeyType = .search
        case .send:
            self.textField.returnKeyType = .send
        case .yahoo:
            self.textField.returnKeyType = .yahoo
        case .done:
            self.textField.returnKeyType = .done
        case .emergencyCall:
            self.textField.returnKeyType = .emergencyCall
        case .continue:
            if #available(iOS 9.0, *) {
                self.textField.returnKeyType = .`continue`
            } else {
                self.textField.returnKeyType = .default
            }
        }
    }

    private func updateKeyboardType() {
        guard let type = self.keyboardType else {
            self.textField.keyboardType = .default
            return
        }
        switch type {
        case .url:
            self.textField.keyboardType = .URL
        case .emailAddress:
            self.textField.keyboardType = .emailAddress
        case .default:
            self.textField.keyboardType = .default
        case .asciiCapable:
            self.textField.keyboardType = .asciiCapable
        case .numbersAndPunctuation:
            self.textField.keyboardType = .numbersAndPunctuation
        case .numberPad:
            self.textField.keyboardType = .numberPad
        case .phonePad:
            self.textField.keyboardType = .phonePad
        case .namePhonePad:
            self.textField.keyboardType = .namePhonePad
        case .decimalPad:
            self.textField.keyboardType = .decimalPad
        case .twitter:
            self.textField.keyboardType = .twitter
        case .webSearch:
            self.textField.keyboardType = .webSearch
        case .asciiCapableNumberPad:
            if #available(iOS 10.0, *) {
                self.textField.keyboardType = .asciiCapableNumberPad
            } else {
                self.textField.keyboardType = .numberPad
            }
        }
    }

    private func updateKeyboardAppearance() {
        let appearance: UIKeyboardAppearance
        switch self.keyboardAppearance {
        case .light?:
            appearance = .light
        case .dark?:
            appearance = .dark
        case .default?, nil:
            fallthrough
        default:
            appearance = .default
        }
        self.textField.keyboardAppearance = appearance
    }

    private func updatePlaceholderAttributedColor() {
        // Only for single-line (UITextField). For multiline we'd overlay a UILabel.
        let color: UIColor? = {
            guard let value = self.placeholderTextColor else { return nil }
            // Accept either numeric (AARRGGBB) or stringified object from processColor
            if case .second(let doubleValue) = value {
                let v = UInt32(clamping: Int64(doubleValue))
                let a = CGFloat((v >> 24) & 0xFF) / 255.0
                let r = CGFloat((v >> 16) & 0xFF) / 255.0
                let g = CGFloat((v >> 8) & 0xFF) / 255.0
                let b = CGFloat(v & 0xFF) / 255.0
                return UIColor(red: r, green: g, blue: b, alpha: a)
            }
            var parsedDict: [String: Any]? = nil
            if case .first(let json) = value,
                let data = json.data(using: .utf8),
                let dict = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any]
            {
                parsedDict = dict
            }
            if let dict = parsedDict {
                if let semantic = dict["semantic"] as? [String],
                    let name = semantic.first
                {
                    // Try named color first, fallback to system semantic mapping if needed
                    return UIColor(named: name) ?? UIColor.value(forKey: name)
                        as? UIColor
                }
                if let dynamic = dict["dynamic"] as? [String: Any] {
                    // Resolve light/dark now for current trait; provide dynamic provider to adapt
                    let lightAny = dynamic["light"]
                    let darkAny = dynamic["dark"]
                    let light =
                        HybridTextInputView.resolveColor(any: lightAny)
                        ?? UIColor.placeholderText
                    let dark =
                        HybridTextInputView.resolveColor(any: darkAny) ?? light
                    if #available(iOS 13.0, *) {
                        return UIColor { traits in
                            traits.userInterfaceStyle == .dark ? dark : light
                        }
                    } else {
                        return light
                    }
                }
            }
            return nil
        }()

        if let placeholderText = self.placeholder {
            var attributes: [NSAttributedString.Key: Any] = [:]
            if let color = color {
                attributes[.foregroundColor] = color
            }
            self.textField.attributedPlaceholder = NSAttributedString(
                string: placeholderText,
                attributes: attributes
            )
        } else {
            // Clear to let UIKit default apply
            self.textField.attributedPlaceholder = nil
        }
    }

    private func updateSelectionTintColor() {
        guard let value = self.selectionColor else {
            self.textField.tintColor = nil
            return
        }
        if case .second(let doubleValue) = value {
            let v = UInt32(clamping: Int64(doubleValue))
            let a = CGFloat((v >> 24) & 0xFF) / 255.0
            let r = CGFloat((v >> 16) & 0xFF) / 255.0
            let g = CGFloat((v >> 8) & 0xFF) / 255.0
            let b = CGFloat(v & 0xFF) / 255.0
            self.textField.tintColor = UIColor(
                red: r,
                green: g,
                blue: b,
                alpha: a
            )
            return
        }
        if case .first(let json) = value,
            let data = json.data(using: .utf8),
            let dict = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        {
            if let semantic = dict["semantic"] as? [String],
                let name = semantic.first
            {
                self.textField.tintColor =
                    UIColor(named: name) ?? UIColor.value(forKey: name)
                    as? UIColor
                return
            }
            if let dynamic = dict["dynamic"] as? [String: Any] {
                let light =
                    HybridTextInputView.resolveColor(any: dynamic["light"])
                    ?? self.textField.tintColor
                let dark =
                    HybridTextInputView.resolveColor(any: dynamic["dark"])
                    ?? light
                if #available(iOS 13.0, *) {
                    self.textField.tintColor = UIColor { traits in
                        traits.userInterfaceStyle == .dark
                            ? (dark ?? light ?? UIColor.tintColor)
                            : (light ?? UIColor.tintColor)
                    }
                } else {
                    self.textField.tintColor = light
                }
                return
            }
        }
    }

    // MARK: - Font Scaling (allowFontScaling, maxFontSizeMultiplier)
    @objc private func handleContentSizeCategoryDidChange() {
        self.applyFontScaling()
    }

    private func resolvedMaxFontSizeMultiplier() -> CGFloat? {
        // Here we only interpret the local value. In a full text tree this would resolve inheritance.
        guard let value = self.maxFontSizeMultiplier else { return nil }  // nil: inherit (treated as no cap here)
        if value.isNaN { return nil }
        if value == 0 { return 0 }
        return CGFloat(value)
    }

    private func currentMultiplier(baseFont: UIFont) -> CGFloat {
        guard self.allowFontScaling ?? true else { return 1.0 }
        let baseSize = max(0.0001, baseFont.pointSize)
        let metrics = UIFontMetrics(forTextStyle: .body)
        let scaled = metrics.scaledValue(
            for: baseSize,
            compatibleWith: self.textField.traitCollection
        )
        var m = max(0.0001, scaled / baseSize)
        if let cap = resolvedMaxFontSizeMultiplier(), cap >= 1.0 {
            m = min(m, cap)
        }
        return m
    }

    private func applyFontScaling() {
        let multiplier = currentMultiplier(baseFont: self.baseFont)
        let newFont = self.baseFont.withSize(
            self.baseFont.pointSize * multiplier
        )
        self.textField.font = newFont
        // UITextField is single-line; explicit lineHeight control is not applicable.
    }

    // MARK: - Focus/Blur events
    private func wireTextFieldEventCallbacks() {
        self.textField.onDidBeginEditing = { [weak self] in
            guard let self = self else { return }
            if self.selectTextOnFocus == true {
                // Defer selection to override iOS' tap-based caret placement
                DispatchQueue.main.async { [weak self] in
                    self?.textField.selectAll(nil)
                }
            }
            self.onFocused?()
        }
        self.textField.onDidEndEditing = { [weak self] in
            guard let self = self else { return }
            // Fire onEditingEnded first with final text, then onBlurred
            if let onEditingEndedCallback = self.onEditingEnded {
                onEditingEndedCallback(self.textField.text ?? "")
            }
            self.onBlurred?()
        }
        self.textField.onTextChanged = { [weak self] text in
            self?.onTextChanged?(text)
        }
        self.textField.onSelectionChanged = { [weak self] start, end in
            self?.onSelectionChanged?(start, end)
        }
        self.textField.onEditingSubmitted = { [weak self] text in
            self?.onEditingSubmitted?(text)
        }
        // Key press events are emitted in delegate methods (shouldChangeCharactersIn/deleteBackward)
        // Wire through to Hybrid layer by copying closures
        self.textField.onKeyPressed = { [weak self] key in
            self?.onKeyPressed?(key)
        }
        self.textField.onTouchBegan = {
            [weak self]
            pageX,
            pageY,
            locationX,
            locationY,
            timestamp in
            self?.onTouchBegan?(pageX, pageY, locationX, locationY, timestamp)
        }
        self.textField.onTouchEnded = {
            [weak self]
            pageX,
            pageY,
            locationX,
            locationY,
            timestamp in
            self?.onTouchEnded?(pageX, pageY, locationX, locationY, timestamp)
        }
    }

}

extension HybridTextInputView {
    static func resolveColor(any: Any?) -> UIColor? {
        guard let value = any else { return nil }
        if let doubleValue = value as? Double {
            let v = UInt32(clamping: Int64(doubleValue))
            let a = CGFloat((v >> 24) & 0xFF) / 255.0
            let r = CGFloat((v >> 16) & 0xFF) / 255.0
            let g = CGFloat((v >> 8) & 0xFF) / 255.0
            let b = CGFloat(v & 0xFF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
        // Accept either a JSON string or a dictionary for OpaqueColor
        var parsedDict: [String: Any]? = nil
        if let dict = value as? [String: Any] {
            parsedDict = dict
        } else if let json = value as? String,
            let data = json.data(using: .utf8),
            let dict = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        {
            parsedDict = dict
        }
        if let dict = parsedDict {
            if let semantic = dict["semantic"] as? [String],
                let name = semantic.first
            {
                return UIColor(named: name) ?? UIColor.value(forKey: name)
                    as? UIColor
            }
            if let dynamic = dict["dynamic"] as? [String: Any] {
                let light =
                    resolveColor(any: dynamic["light"])
                    ?? UIColor.placeholderText
                let dark = resolveColor(any: dynamic["dark"]) ?? light
                if #available(iOS 13.0, *) {
                    return UIColor { traits in
                        traits.userInterfaceStyle == .dark ? dark : light
                    }
                } else {
                    return light
                }
            }
        }
        return nil
    }
}
