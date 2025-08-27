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

    // Reference to parent view for text decoration re-application
    weak var parentView: HybridTextInputView?

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

        let current = self.attributedText?.string ?? self.text ?? ""
        let allowedLength = maxLen - current.count + range.length
        if allowedLength <= 0 {
            // Always allow deletions
            return string.isEmpty
        }

        let incoming = string
        if incoming.count > allowedLength {
            var cutIndex = allowedLength
            if allowedLength > 0 {
                let idx = incoming.index(
                    incoming.startIndex,
                    offsetBy: allowedLength - 1
                )
                let composed = incoming.rangeOfComposedCharacterSequence(
                    at: idx
                )
                let composedEnd = incoming.distance(
                    from: incoming.startIndex,
                    to: composed.upperBound
                )
                if composedEnd > allowedLength {
                    cutIndex = incoming.distance(
                        from: incoming.startIndex,
                        to: composed.lowerBound
                    )
                }
            }
            let limitedEnd = incoming.index(
                incoming.startIndex,
                offsetBy: max(0, cutIndex)
            )
            let limited = String(incoming[..<limitedEnd])
            // Now replace the characters in the current string in the given range
            if let stringRange = Range(range, in: current) {
                let newText = current.replacingCharacters(
                    in: stringRange,
                    with: limited
                )
                self.text = newText
                // Keep caret right after the actually inserted (trimmed) text.
                let targetOffset = min(
                    newText.count,
                    range.location + limited.count
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
        // Re-apply text decoration and shadow when not composing (markedTextRange is nil)
        if self.markedTextRange == nil {
            self.parentView?.reapplyTextDecoration()
            self.parentView?.reapplyTextShadow()
        }

        guard let maxLen = self.maxLength else { return }
        // Do not enforce while composing
        if self.markedTextRange != nil { return }
        let current = self.attributedText?.string ?? self.text ?? ""
        if current.count > maxLen {
            var cutIndex = maxLen
            if maxLen > 0 {
                // Convert to String.Index
                let idx = current.index(
                    current.startIndex,
                    offsetBy: maxLen - 1
                )
                let composed = current.rangeOfComposedCharacterSequence(at: idx)
                let composedEnd = current.distance(
                    from: current.startIndex,
                    to: composed.upperBound
                )
                if composedEnd > maxLen {
                    cutIndex = current.distance(
                        from: current.startIndex,
                        to: composed.lowerBound
                    )
                }
            }
            // Safely get String.Index for cutIndex
            let endIdx = current.index(
                current.startIndex,
                offsetBy: max(0, cutIndex)
            )
            let limited = String(current[..<endIdx])
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
    private var baseFont: UIFont = UIFont.systemFont(ofSize: 14)
    private var hasAppliedDefaultValue: Bool = false
    var view: UIView { return textField }

    override init() {
        super.init()
        self.textField.clipsToBounds = false
        self.textField.layer.masksToBounds = false
        // Set parent reference for text decoration re-application
        self.textField.parentView = self
        // Defer until layout pass to get accurate intrinsic height
        Task { @MainActor in
            // Ensure layout is up-to-date
            self.textField.setNeedsLayout()
            self.textField.layoutIfNeeded()
            // Set default font size to 14pt and cache base font for scaling
            self.baseFont = UIFont.systemFont(ofSize: 14)
            self.textField.font = self.baseFont
            self.applyTextAttributes()
            self.applyFontScaling()
            self.wireTextFieldEventCallbacks()
            // Calculate initial height using intrinsic content size
            let initialHeight = Double(
                self.textField.intrinsicContentSize.height
            )
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
    private func performFocus() {
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
            self.applyEffectiveTextAlignment()
        }
        if self.selectTextOnFocus == true {
            DispatchQueue.main.async { [weak self] in
                self?.textField.selectAll(nil)
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
                // Recalculate height when font scaling changes
                if let callback = self.onInitialHeightMeasured {
                    let newHeight = Double(
                        self.textField.intrinsicContentSize.height
                    )
                    callback(newHeight)
                }
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
                    self.performFocus()
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
                // Recalculate height when font multiplier changes
                if let callback = self.onInitialHeightMeasured {
                    let newHeight = Double(
                        self.textField.intrinsicContentSize.height
                    )
                    callback(newHeight)
                }
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
                self.applyEffectiveTextAlignment()
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
    var textAttributes: TextAttributes? {
        didSet {
            Task { @MainActor in
                self.applyTextAttributes()
                Task { @MainActor in
                    self.applyEffectiveTextAlignment()
                }
                // Recalculate height when text attributes change (font size, etc.)
                if let callback = self.onInitialHeightMeasured {
                    let newHeight = Double(
                        self.textField.intrinsicContentSize.height
                    )
                    callback(newHeight)
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

    private func applyEffectiveTextAlignment() {
        let effectiveAlign: TextAlignAttributes? =
            self.textAlignToAttributes(self.textAlign)
            ?? self.textAttributes?.textAlign
        let alignment: NSTextAlignment
        if let align = effectiveAlign {
            alignment = HybridTextInputView.nsTextAlignment(from: align)
        } else {
            alignment = .natural
        }
        self.textField.textAlignment = alignment

        // Apply paragraph style alignment to attributedText or plain text if present
        if let attributedText = self.textField.attributedText,
            attributedText.length > 0
        {
            let mutableAttrText = NSMutableAttributedString(
                attributedString: attributedText
            )
            let fullRange = NSRange(location: 0, length: mutableAttrText.length)
            mutableAttrText.enumerateAttribute(
                .paragraphStyle,
                in: fullRange,
                options: []
            ) { value, range, _ in
                let paragraphStyle: NSMutableParagraphStyle
                if let existingStyle = value as? NSParagraphStyle {
                    paragraphStyle =
                        existingStyle.mutableCopy() as? NSMutableParagraphStyle
                        ?? NSMutableParagraphStyle()
                } else {
                    paragraphStyle = NSMutableParagraphStyle()
                }
                paragraphStyle.alignment = alignment
                mutableAttrText.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: range
                )
            }
            self.textField.attributedText = mutableAttrText
        } else if let plainText = self.textField.text, !plainText.isEmpty {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment
            let attrString = NSAttributedString(
                string: plainText,
                attributes: [.paragraphStyle: paragraphStyle]
            )
            self.textField.attributedText = attrString
        }
    }

    private func textAlignToAttributes(_ align: TextAlign?)
        -> TextAlignAttributes?
    {
        guard let align = align else { return nil }
        switch align {
        case .center: return .center
        case .left: return .left
        case .right: return .right
        case .natural: return nil
        default: return .auto  // .natural相当は .auto に統一
        }
    }

    func focus() {
        Task { @MainActor in
            self.performFocus()
        }
    }
    func blur() {
        Task { @MainActor in
            self.textField.resignFirstResponder()
        }
    }
    func clear() {
        Task { @MainActor in
            // Ensure text field is in a valid state
            guard self.textField.superview != nil else { return }

            // Clear text and reset selection
            self.textField.text = ""

            // Reset selection to the beginning
            let start = self.textField.beginningOfDocument
            if let range = self.textField.textRange(from: start, to: start) {
                self.textField.selectedTextRange = range
            }

            // Trigger text changed event
            self.textField.onTextChanged?("")
        }
    }
    func isFocused() -> Bool {
        return textField.isFirstResponder
    }

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
        guard let type = self.returnKeyType else {
            self.textField.returnKeyType = .default
            return
        }
        switch type {
        case .default:
            self.textField.returnKeyType = .default
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
        // Recalculate height when system font size changes
        if let callback = self.onInitialHeightMeasured {
            let newHeight = Double(self.textField.intrinsicContentSize.height)
            callback(newHeight)
        }
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

    private func applyTextAttributes() {
        guard let attrs = self.textAttributes else {
            // If no attributes are provided, reset to defaults
            self.resetToDefaultAttributes()
            return
        }

        // Color - reset to default if not specified
        if let color = attrs.color {
            // Resolve color similarly to updatePlaceholderAttributedColor
            let uiColor: UIColor? = {
                switch color {
                case .second(let doubleValue):
                    let v = UInt32(clamping: Int64(doubleValue))
                    let a = CGFloat((v >> 24) & 0xFF) / 255.0
                    let r = CGFloat((v >> 16) & 0xFF) / 255.0
                    let g = CGFloat((v >> 8) & 0xFF) / 255.0
                    let b = CGFloat(v & 0xFF) / 255.0
                    return UIColor(red: r, green: g, blue: b, alpha: a)
                case .first(let json):
                    var parsedDict: [String: Any]? = nil
                    if let data = json.data(using: .utf8),
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
                            return UIColor(named: name) ?? UIColor.value(
                                forKey: name
                            ) as? UIColor
                        }
                        if let dynamic = dict["dynamic"] as? [String: Any] {
                            let light =
                                HybridTextInputView.resolveColor(
                                    any: dynamic["light"]
                                ) ?? UIColor.placeholderText
                            let dark =
                                HybridTextInputView.resolveColor(
                                    any: dynamic["dark"]
                                ) ?? light
                            if #available(iOS 13.0, *) {
                                return UIColor { traits in
                                    traits.userInterfaceStyle == .dark
                                        ? dark : light
                                }
                            } else {
                                return light
                            }
                        }
                    }
                    return nil
                }
            }()
            if let uiColor = uiColor {
                self.textField.textColor = uiColor
            }
        } else {
            // Reset to default color and clear any attributed text that might have color
            self.textField.textColor = nil
            // Clear attributed text to remove any color attributes
            clearAttributedTextAndPreserveContent()
        }

        // Font size, weight, style
        var font = self.baseFont

        // Apply font size - use default (14pt) if not specified
        if let fontSize = attrs.fontSize, fontSize > 0 {
            font = font.withSize(CGFloat(fontSize))
        } else {
            // Reset to default font size (14pt)
            font = font.withSize(14.0)
        }

        // Apply font weight - use default if not specified
        if let weightVal = attrs.fontWeight {
            let weight: UIFont.Weight
            switch weightVal {
            case .first(let weightName):
                weight = UIFont.Weight(
                    rawValue: HybridTextInputView.fontWeightFromString(
                        weightName
                    )
                )
            case .second(let weightDouble):
                weight = UIFont.Weight(rawValue: CGFloat(weightDouble))
            }
            font = HybridTextInputView.font(font: font, weight: weight)
        } else {
            // Reset to default font weight (regular)
            font = HybridTextInputView.font(font: font, weight: .regular)
        }

        // Apply font style - reset to normal if not specified
        if let style = attrs.fontStyle, style.lowercased() == "italic" {
            font = HybridTextInputView.italicFont(font: font)
        }
        // Note: If fontStyle is nil or not "italic", font remains non-italic (default)

        // Font variant
        if let fontVariant = attrs.fontVariant, !fontVariant.isEmpty {
            font = self.applyFontVariant(to: font, variants: fontVariant)
        }

        self.textField.font = font

        // Letter spacing - reset if not specified
        if let spacing = attrs.letterSpacing, spacing != 0 {
            if let currentText = self.textField.text, !currentText.isEmpty {
                let attrStr = NSMutableAttributedString(string: currentText)
                attrStr.addAttribute(
                    .kern,
                    value: CGFloat(spacing),
                    range: NSRange(location: 0, length: attrStr.length)
                )
                self.textField.attributedText = attrStr
            }
        } else {
            // Reset letter spacing by clearing attributed text if it was set for spacing
            if self.textField.attributedText != nil {
                clearAttributedTextAndPreserveContent()
            }
        }

        // Text decoration - reset if not specified
        if let decorationLine = attrs.textDecorationLine,
            decorationLine != .none
        {
            self.applyTextDecoration(
                decorationLine: decorationLine,
                decorationStyle: attrs.textDecorationStyle ?? .solid,
                decorationColor: attrs.textDecorationColor
            )
        } else {
            // Reset text decoration by clearing attributed text decorations
            clearAttributedTextAndPreserveContent()
        }

        // Text shadow - reset if not specified
        if let shadowOffset = attrs.textShadowOffset,
            let shadowRadius = attrs.textShadowRadius,
            shadowRadius > 0
        {
            self.applyTextShadow(
                offset: shadowOffset,
                radius: shadowRadius,
                color: attrs.textShadowColor
            )
        } else {
            // Reset text shadow by clearing shadow attributes
            clearAttributedTextAndPreserveContent()
        }

        // Writing Direction - reset to default if not specified
        if let writingDirection = attrs.writingDirection {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.baseWritingDirection =
                HybridTextInputView.nsWritingDirection(
                    from: writingDirection
                )

            if let currentText = self.textField.text, !currentText.isEmpty {
                let attrStr = NSMutableAttributedString(string: currentText)
                attrStr.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: NSRange(location: 0, length: attrStr.length)
                )
                self.textField.attributedText = attrStr
            }
        } else {
            // Reset writing direction to default (.natural)
            if let currentText = self.textField.text, !currentText.isEmpty {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.baseWritingDirection = .natural
                let attrStr = NSMutableAttributedString(string: currentText)
                attrStr.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle,
                    range: NSRange(location: 0, length: attrStr.length)
                )
                self.textField.attributedText = attrStr
            }
        }

        // User Select - reset to default if not specified
        if let userSelect = attrs.userSelect {
            updateUserSelect(userSelect: userSelect)
        } else {
            // Reset to default user select behavior (.auto/.text)
            updateUserSelect(userSelect: .auto)
        }

        // Apply effective text alignment once after all text attribute changes
        self.applyEffectiveTextAlignment()

        // Line height is not supported for single-line fields
    }

    private func clearAttributedTextAndPreserveContent() {
        // Helper method to clear all attributed text while preserving plain text content
        if let currentText = self.textField.text, !currentText.isEmpty {
            // Temporarily store the text
            let plainText = currentText
            // Clear attributed text first
            self.textField.attributedText = nil
            // Set plain text back
            self.textField.text = plainText
        } else {
            // Clear both if no text
            self.textField.attributedText = nil
            self.textField.text = nil
        }
    }

    private func resetToDefaultAttributes() {
        // Reset all text attributes to defaults
        self.textField.textColor = nil  // System default
        self.baseFont = UIFont.systemFont(ofSize: 14)  // Reset base font to default
        self.textField.font = self.baseFont  // Default size and weight

        // Only set default alignment if textAlign is not specified
        if self.textAlign == nil {
            self.textField.textAlignment = .natural  // Default alignment
        }

        // Clear any attributed text to remove spacing, decorations, shadows, colors
        clearAttributedTextAndPreserveContent()
        self.applyEffectiveTextAlignment()

        // Reset user interaction to default
        updateUserSelect(userSelect: .auto)
    }

    // MARK: - Writing Direction Support

    private static func nsWritingDirection(
        from writingDirection: WritingDirection
    )
        -> NSWritingDirection
    {
        switch writingDirection {
        case .ltr:
            return .leftToRight
        case .rtl:
            return .rightToLeft
        case .auto:
            return .natural
        }
    }

    // MARK: - User Select Support

    private func updateUserSelect(userSelect: UserSelect) {
        switch userSelect {
        case .none:
            // Disable text selection completely
            self.textField.isUserInteractionEnabled = false
        case .auto, .text:
            // Enable text selection (default behavior)
            self.textField.isUserInteractionEnabled = true
        case .all:
            // Enable text selection with select all behavior
            self.textField.isUserInteractionEnabled = true
        // Could add auto-select all behavior here if needed
        case .contain:
            // Enable limited text selection
            self.textField.isUserInteractionEnabled = true
        }
    }

    // MARK: - FontVariant Support

    private static let fontVariantFeatureMap: [String: [String: Any]] = [
        // Numeric variants
        "oldstyle-nums": [
            kCTFontFeatureTypeIdentifierKey as String: kNumberCaseType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kLowerCaseNumbersSelector,
        ],
        "lining-nums": [
            kCTFontFeatureTypeIdentifierKey as String: kNumberCaseType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kUpperCaseNumbersSelector,
        ],
        "tabular-nums": [
            kCTFontFeatureTypeIdentifierKey as String: kNumberSpacingType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kMonospacedNumbersSelector,
        ],
        "proportional-nums": [
            kCTFontFeatureTypeIdentifierKey as String: kNumberSpacingType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kProportionalNumbersSelector,
        ],

        // Small caps
        "small-caps": [
            kCTFontFeatureTypeIdentifierKey as String: kLowerCaseType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kLowerCaseSmallCapsSelector,
        ],

        // Ligatures
        "common-ligatures": [
            kCTFontFeatureTypeIdentifierKey as String: kLigaturesType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kCommonLigaturesOnSelector,
        ],
        "no-common-ligatures": [
            kCTFontFeatureTypeIdentifierKey as String: kLigaturesType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kCommonLigaturesOffSelector,
        ],
        "discretionary-ligatures": [
            kCTFontFeatureTypeIdentifierKey as String: kLigaturesType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kRareLigaturesOnSelector,
        ],
        "no-discretionary-ligatures": [
            kCTFontFeatureTypeIdentifierKey as String: kLigaturesType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kRareLigaturesOffSelector,
        ],
        "historical-ligatures": [
            kCTFontFeatureTypeIdentifierKey as String: kLigaturesType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kHistoricalLigaturesOnSelector,
        ],
        "no-historical-ligatures": [
            kCTFontFeatureTypeIdentifierKey as String: kLigaturesType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kHistoricalLigaturesOffSelector,
        ],
        "contextual": [
            kCTFontFeatureTypeIdentifierKey as String:
                kContextualAlternatesType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kContextualAlternatesOnSelector,
        ],
        "no-contextual": [
            kCTFontFeatureTypeIdentifierKey as String:
                kContextualAlternatesType,
            kCTFontFeatureSelectorIdentifierKey as String:
                kContextualAlternatesOffSelector,
        ],
    ]

    private func applyFontVariant(to font: UIFont, variants: [FontVariant])
        -> UIFont
    {
        guard !variants.isEmpty else { return font }

        var features: [[String: Any]] = []

        for variant in variants {
            // Convert enum to string representation
            let variantString = fontVariantToString(variant)

            // Handle stylistic alternates (stylistic-one through stylistic-twenty)
            if variantString.hasPrefix("stylistic-") {
                let numberPart = String(
                    variantString.dropFirst("stylistic-".count)
                )
                if let number = stylisticNumberToInt(numberPart),
                    number >= 1 && number <= 20
                {
                    features.append([
                        kCTFontFeatureTypeIdentifierKey as String:
                            kStylisticAlternativesType,
                        kCTFontFeatureSelectorIdentifierKey as String: number
                            - 1
                            + kStylisticAltOneOnSelector,
                    ])
                }
            } else if let featureSettings =
                HybridTextInputView.fontVariantFeatureMap[variantString]
            {
                features.append(featureSettings)
            }
        }

        guard !features.isEmpty else { return font }

        let fontDescriptor = font.fontDescriptor
        let newDescriptor = fontDescriptor.addingAttributes([
            kCTFontFeatureSettingsAttribute as UIFontDescriptor.AttributeName:
                features
        ])

        return UIFont(descriptor: newDescriptor, size: font.pointSize)
    }

    private func fontVariantToString(_ variant: FontVariant) -> String {
        switch variant {
        case .smallCaps: return "small-caps"
        case .oldstyleNums: return "oldstyle-nums"
        case .liningNums: return "lining-nums"
        case .tabularNums: return "tabular-nums"
        case .commonLigatures: return "common-ligatures"
        case .noCommonLigatures: return "no-common-ligatures"
        case .discretionaryLigatures: return "discretionary-ligatures"
        case .noDiscretionaryLigatures: return "no-discretionary-ligatures"
        case .historicalLigatures: return "historical-ligatures"
        case .noHistoricalLigatures: return "no-historical-ligatures"
        case .contextual: return "contextual"
        case .noContextual: return "no-contextual"
        case .proportionalNums: return "proportional-nums"
        case .stylisticOne: return "stylistic-one"
        case .stylisticTwo: return "stylistic-two"
        case .stylisticThree: return "stylistic-three"
        case .stylisticFour: return "stylistic-four"
        case .stylisticFive: return "stylistic-five"
        case .stylisticSix: return "stylistic-six"
        case .stylisticSeven: return "stylistic-seven"
        case .stylisticEight: return "stylistic-eight"
        case .stylisticNine: return "stylistic-nine"
        case .stylisticTen: return "stylistic-ten"
        case .stylisticEleven: return "stylistic-eleven"
        case .stylisticTwelve: return "stylistic-twelve"
        case .stylisticThirteen: return "stylistic-thirteen"
        case .stylisticFourteen: return "stylistic-fourteen"
        case .stylisticFifteen: return "stylistic-fifteen"
        case .stylisticSixteen: return "stylistic-sixteen"
        case .stylisticSeventeen: return "stylistic-seventeen"
        case .stylisticEighteen: return "stylistic-eighteen"
        case .stylisticNineteen: return "stylistic-nineteen"
        case .stylisticTwenty: return "stylistic-twenty"
        }
    }

    private func stylisticNumberToInt(_ numberWord: String) -> Int? {
        let numbers = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
            "fifteen": 15,
            "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
            "twenty": 20,
        ]
        return numbers[numberWord]
    }

    private static func fontWeightFromString(_ string: String) -> CGFloat {
        switch string.lowercased() {
        case "normal", "400": return UIFont.Weight.regular.rawValue
        case "bold", "700": return UIFont.Weight.bold.rawValue
        case "100": return UIFont.Weight.ultraLight.rawValue
        case "200": return UIFont.Weight.thin.rawValue
        case "300": return UIFont.Weight.light.rawValue
        case "500": return UIFont.Weight.medium.rawValue
        case "600": return UIFont.Weight.semibold.rawValue
        case "800": return UIFont.Weight.heavy.rawValue
        case "900": return UIFont.Weight.black.rawValue
        default:
            if let num = Double(string) {
                return CGFloat(num)
            }
            return UIFont.Weight.regular.rawValue
        }
    }
    private static func font(font: UIFont, weight: UIFont.Weight) -> UIFont {
        let descriptor = font.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
    private static func italicFont(font: UIFont) -> UIFont {
        let descriptor =
            font.fontDescriptor.withSymbolicTraits(.traitItalic)
            ?? font.fontDescriptor
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
    private static func nsTextAlignment(from align: TextAlignAttributes)
        -> NSTextAlignment
    {
        switch align {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        case .justify: return .justified
        case .auto: return .natural
        }
    }

    private func applyTextDecoration(
        decorationLine: TextDecorationLine,
        decorationStyle: TextDecorationStyle,
        decorationColor: ProcessedColor?
    ) {
        guard let text = self.textField.text, !text.isEmpty else { return }

        let attributedString = NSMutableAttributedString(string: text)

        // Copy existing attributes from the text field
        if let existingFont = self.textField.font {
            attributedString.addAttribute(
                .font,
                value: existingFont,
                range: NSRange(location: 0, length: text.count)
            )
        }
        if let existingColor = self.textField.textColor {
            attributedString.addAttribute(
                .foregroundColor,
                value: existingColor,
                range: NSRange(location: 0, length: text.count)
            )
        }

        // Convert decoration style to NSUnderlineStyle
        let underlineStyle = self.nsUnderlineStyle(from: decorationStyle)
        let range = NSRange(location: 0, length: text.count)

        // Apply decoration based on type
        switch decorationLine {
        case .underline:
            attributedString.addAttribute(
                .underlineStyle,
                value: underlineStyle.rawValue,
                range: range
            )
            if let color = self.resolveTextDecorationColor(decorationColor) {
                attributedString.addAttribute(
                    .underlineColor,
                    value: color,
                    range: range
                )
            }

        case .lineThrough:
            attributedString.addAttribute(
                .strikethroughStyle,
                value: underlineStyle.rawValue,
                range: range
            )
            if let color = self.resolveTextDecorationColor(decorationColor) {
                attributedString.addAttribute(
                    .strikethroughColor,
                    value: color,
                    range: range
                )
            }

        case .underlineLineThrough:
            attributedString.addAttribute(
                .underlineStyle,
                value: underlineStyle.rawValue,
                range: range
            )
            attributedString.addAttribute(
                .strikethroughStyle,
                value: underlineStyle.rawValue,
                range: range
            )
            if let color = self.resolveTextDecorationColor(decorationColor) {
                attributedString.addAttribute(
                    .underlineColor,
                    value: color,
                    range: range
                )
                attributedString.addAttribute(
                    .strikethroughColor,
                    value: color,
                    range: range
                )
            }

        case .none:
            break
        }

        self.textField.attributedText = attributedString
        self.applyEffectiveTextAlignment()
    }

    private func nsUnderlineStyle(from decorationStyle: TextDecorationStyle)
        -> NSUnderlineStyle
    {
        switch decorationStyle {
        case .solid:
            return .single
        case .double:
            return .double
        case .dotted:
            return [.single, .patternDot]
        case .dashed:
            return [.single, .patternDash]
        }
    }

    func reapplyTextDecoration() {
        guard let attrs = self.textAttributes,
            let decorationLine = attrs.textDecorationLine,
            decorationLine != .none
        else { return }

        self.applyTextDecoration(
            decorationLine: decorationLine,
            decorationStyle: attrs.textDecorationStyle ?? .solid,
            decorationColor: attrs.textDecorationColor
        )
    }

    private func resolveTextDecorationColor(_ decorationColor: ProcessedColor?)
        -> UIColor?
    {
        guard let decorationColor = decorationColor else { return nil }
        switch decorationColor {
        case .second(let doubleValue):
            let v = UInt32(clamping: Int64(doubleValue))
            let a = CGFloat((v >> 24) & 0xFF) / 255.0
            let r = CGFloat((v >> 16) & 0xFF) / 255.0
            let g = CGFloat((v >> 8) & 0xFF) / 255.0
            let b = CGFloat(v & 0xFF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: a)
        case .first(let json):
            var parsedDict: [String: Any]? = nil
            if let data = json.data(using: .utf8),
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
                        HybridTextInputView.resolveColor(any: dynamic["light"])
                        ?? UIColor.label
                    let dark =
                        HybridTextInputView.resolveColor(any: dynamic["dark"])
                        ?? light
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

    // MARK: - Text Shadow Support

    private func applyTextShadow(
        offset: TextShadowOffset,
        radius: Double,
        color: ProcessedColor?
    ) {
        guard let text = self.textField.text, !text.isEmpty else { return }

        let attributedString = NSMutableAttributedString(string: text)

        // Copy existing attributes from the text field
        if let existingFont = self.textField.font {
            attributedString.addAttribute(
                .font,
                value: existingFont,
                range: NSRange(location: 0, length: text.count)
            )
        }
        if let existingColor = self.textField.textColor {
            attributedString.addAttribute(
                .foregroundColor,
                value: existingColor,
                range: NSRange(location: 0, length: text.count)
            )
        }

        // Create shadow object
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(width: offset.width, height: offset.height)
        shadow.shadowBlurRadius = CGFloat(radius)

        // Set shadow color if provided
        if let shadowColor = self.resolveTextShadowColor(color) {
            shadow.shadowColor = shadowColor
        }

        // Apply shadow to attributed string
        attributedString.addAttribute(
            .shadow,
            value: shadow,
            range: NSRange(location: 0, length: text.count)
        )

        self.textField.attributedText = attributedString
        self.applyEffectiveTextAlignment()
    }

    private func resolveTextShadowColor(_ shadowColor: ProcessedColor?)
        -> UIColor?
    {
        guard let shadowColor = shadowColor else {
            return UIColor.black.withAlphaComponent(0.3)
        }
        switch shadowColor {
        case .second(let doubleValue):
            let v = UInt32(clamping: Int64(doubleValue))
            let a = CGFloat((v >> 24) & 0xFF) / 255.0
            let r = CGFloat((v >> 16) & 0xFF) / 255.0
            let g = CGFloat((v >> 8) & 0xFF) / 255.0
            let b = CGFloat(v & 0xFF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: a)
        case .first(let json):
            var parsedDict: [String: Any]? = nil
            if let data = json.data(using: .utf8),
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
                        HybridTextInputView.resolveColor(any: dynamic["light"])
                        ?? UIColor.black.withAlphaComponent(0.3)
                    let dark =
                        HybridTextInputView.resolveColor(any: dynamic["dark"])
                        ?? light
                    if #available(iOS 13.0, *) {
                        return UIColor { traits in
                            traits.userInterfaceStyle == .dark ? dark : light
                        }
                    } else {
                        return light
                    }
                }
            }
            return UIColor.black.withAlphaComponent(0.3)
        }
    }

    func reapplyTextShadow() {
        guard let attrs = self.textAttributes,
            let shadowOffset = attrs.textShadowOffset,
            let shadowRadius = attrs.textShadowRadius,
            shadowRadius > 0
        else { return }

        self.applyTextShadow(
            offset: shadowOffset,
            radius: shadowRadius,
            color: attrs.textShadowColor
        )
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
