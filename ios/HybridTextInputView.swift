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
        self.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleTextDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: self
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleTextDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: self
        )
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
        if self.markedTextRange == nil && self.textWasPasted == false {
            if !string.isEmpty {
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
    var enterKeyHint: EnterKeyHint? {
        didSet {
            Task {
                @MainActor in
                self.updateEnterKeyHint()
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
            }
        }
    }

    var onInitialHeightMeasured: ((_ height: Double) -> Void)?
    var onBlurred: (() -> Void)?
    var onTextChanged: ((_ text: String) -> Void)?
    var onEditingEnded: ((_ text: String) -> Void)?
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

    private func updateEnterKeyHint() {
        guard let hint = self.enterKeyHint else {
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
