import Foundation
import NitroModules
import UIKit

class CustomTextView: UITextView, UITextViewDelegate {
    var isContextMenuHidden: Bool = false
    var maxLength: Int?
    var onTextChanged: ((_ text: String) -> Void)?
    var onDidBeginEditing: (() -> Void)?
    var onDidEndEditing: (() -> Void)?
    var onKeyPressed: ((_ key: String) -> Void)?
    var onSelectionChanged: ((_ start: Double, _ end: Double) -> Void)?
    var onEditingSubmitted: ((_ text: String) -> Void)?
    var onContentSizeChanged: ((_ width: Double, _ height: Double) -> Void)?
    var submitBehavior: SubmitBehavior?
    var numberOfLines: Int?
    private var textWasPasted: Bool = false
    private var isMarkedTextValid: Bool = false
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
    weak var parentView: HybridMultiLineTextInputView?

    /// 行数制限プロパティ
    var maxNumberOfLines: Int?

    /// 現在の行数（折返し対応、日本語も対応）
    var actualNumberOfLines: Int {
        guard let layoutManager = self.layoutManager as NSLayoutManager?,
            let textContainer = self.textContainer as NSTextContainer?
        else {
            return self.text?.components(separatedBy: "\n").count ?? 1
        }
        layoutManager.ensureLayout(for: textContainer)
        var lineCount = 0
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) {
            _,
            _,
            _,
            _,
            _ in
            lineCount += 1
        }
        return lineCount
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTextView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }

    private func setupTextView() {
        self.clipsToBounds = false
        self.layer.masksToBounds = false
        self.delegate = self

        // Set default properties for UITextView
        self.backgroundColor = UIColor.clear
        self.isScrollEnabled = true
        self.isEditable = true
        self.isSelectable = true

        // Add observers for text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleTextDidChange(_:)),
            name: UITextView.textDidChangeNotification,
            object: self
        )
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

    // MARK: - UITextViewDelegate

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        let isComposing = self.markedTextRange != nil

        // Handle key press events first (before IME processing)
        if !self.textWasPasted && !isComposing {
            if text == "\n" {
                onKeyPressed?("Enter")

                // Check line limit for newline before allowing
                if let maxLines = numberOfLines, maxLines > 0 {
                    let current = textView.text ?? ""
                    let newText = (current as NSString).replacingCharacters(
                        in: range,
                        with: text
                    )
                    let currentLines = numberOfLinesInText(
                        newText,
                        textView: textView
                    )

                    if currentLines > maxLines {
                        // At line limit, submit instead of adding newline
                        onEditingSubmitted?(current)
                        textView.returnKeyType = .done
                        return false
                    }
                }

                // Handle submit behavior for multi-line
                if let behavior = submitBehavior {
                    switch behavior {
                    case .submit:
                        onEditingSubmitted?(self.text ?? "")
                        return false
                    case .blurandsubmit:
                        onEditingSubmitted?(self.text ?? "")
                        textView.resignFirstResponder()
                        return false
                    case .newline:
                        // Allow newline insertion (default UITextView behavior)
                        break
                    @unknown default:
                        break
                    }
                }
            } else if !text.isEmpty {
                onKeyPressed?(text)
            }
        }

        // For Japanese IME, allow marked text to proceed without restrictions
        if isComposing {
            self.isMarkedTextValid = true
            return true
        }

        // Get current text and proposed new text
        let current = self.text ?? ""
        let newText = (current as NSString).replacingCharacters(
            in: range,
            with: text
        )

        // Check line limits (only when not composing)
        if let maxLines = numberOfLines, maxLines > 0 {
            let currentLines = numberOfLinesInText(newText, textView: textView)
            if currentLines > maxLines {
                // For non-newline text that exceeds line limit, try to fit what we can
                if text != "\n" {
                    let trimmedText = trimTextToLines(
                        newText,
                        maxLines: maxLines,
                        textView: textView
                    )
                    if trimmedText != current {
                        // Apply the trimmed text
                        self.text = trimmedText
                        // Position cursor at end
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            let position = self.endOfDocument
                            self.selectedTextRange = self.textRange(
                                from: position,
                                to: position
                            )
                        }
                    }
                }
                return false
            }
        }

        // Check character limits (only when not composing)
        if let maxLen = self.maxLength {
            let allowedLength = maxLen - current.count + range.length
            if allowedLength <= 0 {
                // Always allow deletions
                return text.isEmpty
            }

            if text.count > allowedLength {
                var cutIndex = allowedLength
                if allowedLength > 0 {
                    let idx = text.index(
                        text.startIndex,
                        offsetBy: allowedLength - 1
                    )
                    let composed = text.rangeOfComposedCharacterSequence(
                        at: idx
                    )
                    let composedEnd = text.distance(
                        from: text.startIndex,
                        to: composed.upperBound
                    )
                    if composedEnd > allowedLength {
                        cutIndex = text.distance(
                            from: text.startIndex,
                            to: composed.lowerBound
                        )
                    }
                }
                let limitedEnd = text.index(
                    text.startIndex,
                    offsetBy: max(0, cutIndex)
                )
                let limited = String(text[..<limitedEnd])

                // Apply the limited text
                if let stringRange = Range(range, in: current) {
                    let finalText = current.replacingCharacters(
                        in: stringRange,
                        with: limited
                    )
                    self.text = finalText

                    // Position cursor after inserted text
                    let targetOffset = min(
                        finalText.count,
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
        }

        return true
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        onDidBeginEditing?()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        onDidEndEditing?()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard let range = self.selectedTextRange else { return }
        let start = self.offset(from: self.beginningOfDocument, to: range.start)
        let end = self.offset(from: self.beginningOfDocument, to: range.end)
        onSelectionChanged?(Double(max(0, start)), Double(max(0, end)))
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
        let isComposing = self.markedTextRange != nil

        // Re-apply text decoration and shadow when not composing
        if !isComposing {
            self.parentView?.reapplyTextDecoration()
            self.parentView?.reapplyTextShadow()
        }

        let currentText = self.text ?? ""

        // Only enforce limits when IME composition is complete
        if !isComposing {
            var textToApply = currentText
            var wasModified = false

            // Handle line limits - preserve as much text as possible
            if let maxLines = numberOfLines, maxLines > 0 {
                let currentLines = numberOfLinesInText(
                    textToApply,
                    textView: self
                )
                if currentLines > maxLines {
                    let trimmedText = trimTextToLines(
                        textToApply,
                        maxLines: maxLines,
                        textView: self
                    )
                    if trimmedText != textToApply {
                        textToApply = trimmedText
                        wasModified = true
                    }
                }
            }

            // Handle character limits - preserve as much text as possible
            if let maxLen = self.maxLength {
                if textToApply.count > maxLen {
                    var cutIndex = maxLen
                    if maxLen > 0 {
                        let idx = textToApply.index(
                            textToApply.startIndex,
                            offsetBy: maxLen - 1
                        )
                        let composed =
                            textToApply.rangeOfComposedCharacterSequence(
                                at: idx
                            )
                        let composedEnd = textToApply.distance(
                            from: textToApply.startIndex,
                            to: composed.upperBound
                        )
                        if composedEnd > maxLen {
                            cutIndex = textToApply.distance(
                                from: textToApply.startIndex,
                                to: composed.lowerBound
                            )
                        }
                    }
                    let endIdx = textToApply.index(
                        textToApply.startIndex,
                        offsetBy: max(0, cutIndex)
                    )
                    let limited = String(textToApply[..<endIdx])
                    if limited != textToApply {
                        textToApply = limited
                        wasModified = true
                    }
                }
            }

            // Apply the modified text if needed
            if wasModified {
                self.text = textToApply
                // Position cursor at end of preserved text
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let position = self.endOfDocument
                    self.selectedTextRange = self.textRange(
                        from: position,
                        to: position
                    )
                }
            }

            // Update return key based on current line count
            if let maxLines = numberOfLines, maxLines > 0 {
                let finalLines = numberOfLinesInText(
                    self.text ?? "",
                    textView: self
                )
                if finalLines >= maxLines {
                    self.returnKeyType = .done
                } else {
                    // Restore original return key type
                    self.parentView?.updateReturnKeyType()
                }
            }
        }

        // Always notify of changes
        onTextChanged?(self.text ?? "")
        onContentSizeChanged?(
            Double(self.contentSize.width),
            Double(self.contentSize.height)
        )

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

    // MARK: - Helper methods for line counting (Japanese IME aware)
    private func numberOfLinesInText(_ text: String, textView: UITextView)
        -> Int
    {
        guard !text.isEmpty else { return 1 }

        let textWidth =
            textView.frame.width - textView.textContainerInset.left
            - textView.textContainerInset.right - 2.0
            * textView.textContainer.lineFragmentPadding

        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(
                width: textWidth,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: textView.font ?? UIFont.systemFont(ofSize: 17)],
            context: nil
        )

        let lineHeight = textView.font?.lineHeight ?? 17
        let numberOfLines = Int(ceil(boundingRect.height / lineHeight))

        return max(numberOfLines, 1)
    }

    private func trimTextToLines(
        _ text: String,
        maxLines: Int,
        textView: UITextView
    ) -> String {
        guard maxLines > 0 else { return text }

        let font = textView.font ?? UIFont.systemFont(ofSize: 17)
        let textWidth =
            textView.frame.width - textView.textContainerInset.left
            - textView.textContainerInset.right - 2.0
            * textView.textContainer.lineFragmentPadding
        let lineHeight = font.lineHeight

        var currentText = ""
        let paragraphs = text.components(separatedBy: .newlines)
        var currentLineCount = 0

        for paragraph in paragraphs {
            if paragraph.isEmpty {
                currentLineCount += 1
                if currentLineCount <= maxLines {
                    currentText += "\n"
                } else {
                    break
                }
                continue
            }

            let boundingRect = (paragraph as NSString).boundingRect(
                with: CGSize(
                    width: textWidth,
                    height: CGFloat.greatestFiniteMagnitude
                ),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: font],
                context: nil
            )

            let linesForParagraph = Int(ceil(boundingRect.height / lineHeight))

            if currentLineCount + linesForParagraph <= maxLines {
                if !currentText.isEmpty && !currentText.hasSuffix("\n") {
                    currentText += "\n"
                    currentLineCount += 1
                }
                currentText += paragraph
                currentLineCount += linesForParagraph
            } else {
                // Fit as much as possible in the remaining lines
                let remainingLines = maxLines - currentLineCount
                if remainingLines > 0 {
                    if !currentText.isEmpty && !currentText.hasSuffix("\n") {
                        currentText += "\n"
                    }
                    let partialText = fitTextInLines(
                        paragraph,
                        maxLines: remainingLines,
                        font: font,
                        width: textWidth
                    )
                    currentText += partialText
                }
                break
            }
        }

        return currentText
    }

    private func fitTextInLines(
        _ text: String,
        maxLines: Int,
        font: UIFont,
        width: CGFloat
    )
        -> String
    {
        guard maxLines > 0 else { return "" }

        let lineHeight = font.lineHeight
        let maxHeight = CGFloat(maxLines) * lineHeight

        var left = 0
        var right = text.count

        while left < right {
            let mid = (left + right + 1) / 2
            let substring = String(text.prefix(mid))

            let boundingRect = (substring as NSString).boundingRect(
                with: CGSize(
                    width: width,
                    height: CGFloat.greatestFiniteMagnitude
                ),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: font],
                context: nil
            )

            if boundingRect.height <= maxHeight {
                left = mid
            } else {
                right = mid - 1
            }
        }

        return String(text.prefix(left))
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: UITextView.textDidChangeNotification,
            object: self
        )
    }
}

class HybridMultiLineTextInputView: HybridNitroMultiLineTextInputViewSpec {
    private let textView = CustomTextView()
    private var baseFont: UIFont = UIFont.systemFont(ofSize: 14)
    private var hasAppliedDefaultValue: Bool = false
    var view: UIView { return textView }

    override init() {
        super.init()
        self.textView.clipsToBounds = false
        self.textView.layer.masksToBounds = false

        // Set parent reference for text decoration re-application
        self.textView.parentView = self

        // Defer until layout pass to get accurate intrinsic height
        Task { @MainActor in
            // Ensure layout is up-to-date
            self.textView.setNeedsLayout()
            self.textView.layoutIfNeeded()

            // Set default font size to 14pt and cache base font for scaling
            self.baseFont = UIFont.systemFont(ofSize: 14)
            self.textView.font = self.baseFont
            self.applyTextAttributes()
            self.applyFontScaling()
            self.wireTextViewEventCallbacks()

            // Calculate initial height using content size
            let initialHeight = Double(self.textView.contentSize.height)
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
            self.textView.inputView = nil
        } else {
            self.textView.inputView = UIView()
        }
        _ = self.textView.becomeFirstResponder()

        if self.selectTextOnFocus == true {
            DispatchQueue.main.async { [weak self] in
                self?.textView.selectAll(nil)
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

    // MARK: - Props
    var allowFontScaling: Bool? = true {
        didSet {
            Task {
                @MainActor in
                self.applyFontScaling()

                // Recalculate height when font scaling changes
                if let callback = self.onInitialHeightMeasured {
                    let newHeight = Double(self.textView.contentSize.height)
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
                    self.textView.resignFirstResponder()
                }
            }
        }
    }

    var contextMenuHidden: Bool? {
        didSet {
            Task {
                @MainActor in
                self.textView.isContextMenuHidden =
                    self.contextMenuHidden ?? false
                if #available(iOS 18.0, *) {
                    if self.contextMenuHidden == true {
                        self.textView.writingToolsBehavior = .none
                    } else {
                        self.textView.writingToolsBehavior = .default
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
            self.textView.submitBehavior = self.submitBehavior
        }
    }

    var editable: Bool? {
        didSet {
            self.textView.isEditable = self.editable ?? true
        }
    }

    var maxFontSizeMultiplier: Double? {
        didSet {
            Task { @MainActor in
                self.applyFontScaling()

                // Recalculate height when font multiplier changes
                if let callback = self.onInitialHeightMeasured {
                    let newHeight = Double(self.textView.contentSize.height)
                    callback(newHeight)
                }
            }
        }
    }

    var enablesReturnKeyAutomatically: Bool? {
        didSet {
            Task {
                @MainActor in
                self.textView.enablesReturnKeyAutomatically =
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
                        self.textView.passwordRules = UITextInputPasswordRules(
                            descriptor: rules
                        )
                    } else {
                        self.textView.passwordRules = nil
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
                self.textView.maxLength = max(0, Int(floor(value)))
            } else {
                self.textView.maxLength = nil
            }
        }
    }

    /// 現在の行数（日本語や折返しにも対応）
    var numberOfLines: Double? {
        didSet {
            Task { @MainActor in
                updateNumberOfLines()
                // Pass numberOfLines to CustomTextView
                if let lines = numberOfLines, lines > 0 {
                    self.textView.maxNumberOfLines = Int(lines)
                } else {
                    self.textView.maxNumberOfLines = nil
                }
            }
        }
    }

    var placeholder: String? {
        didSet {
            Task { @MainActor in
                // UITextView doesn't have built-in placeholder, but we can implement it if needed
                // For now, this is a no-op for UITextView
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
                // UITextView doesn't have built-in placeholder, but we can implement it if needed
                // For now, this is a no-op for UITextView
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
                self.textView.isSecureTextEntry = self.secureTextEntry ?? false
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
                    let start = self.textView.position(
                        from: self.textView.beginningOfDocument,
                        offset: startOffset
                    ),
                    let end = self.textView.position(
                        from: self.textView.beginningOfDocument,
                        offset: endOffset
                    )
                else { return }
                if let range = self.textView.textRange(from: start, to: end) {
                    self.textView.selectedTextRange = range
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
                    self.textView.inputView = nil
                    if self.textView.isFirstResponder {
                        self.textView.reloadInputViews()
                    }
                } else {
                    self.textView.inputView = UIView()
                }
            }
        }
    }

    var smartInsertDelete: Bool? {
        didSet {
            Task { @MainActor in
                if #available(iOS 13.0, *) {
                    if let enabled = self.smartInsertDelete {
                        self.textView.smartInsertDeleteType =
                            enabled ? .yes : .no
                    } else {
                        self.textView.smartInsertDeleteType = .default
                    }
                }
            }
        }
    }

    var spellCheck: Bool? {
        didSet {
            Task { @MainActor in
                if let v = self.spellCheck {
                    self.textView.spellCheckingType = v ? .yes : .no
                } else {
                    self.textView.spellCheckingType = .default
                }
            }
        }
    }

    var scrollEnabled: Bool? {
        didSet {
            Task { @MainActor in
                self.textView.isScrollEnabled = self.scrollEnabled ?? true
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
                    let newHeight = Double(self.textView.contentSize.height)
                    callback(newHeight)
                }
            }
        }
    }

    var onInitialHeightMeasured: ((_ height: Double) -> Void)?
    var onContentSizeChanged: ((_ width: Double, _ height: Double) -> Void)?
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

    // MARK: - Methods
    func focus() {
        Task { @MainActor in
            self.performFocus()
        }
    }

    func blur() {
        Task { @MainActor in
            self.textView.resignFirstResponder()
        }
    }

    func clear() {
        Task { @MainActor in
            // Ensure text view is in a valid state
            guard self.textView.superview != nil else { return }

            // Clear text and reset selection
            self.textView.text = applyTextTransform("")

            // Reset selection to the beginning
            let start = self.textView.beginningOfDocument
            if let range = self.textView.textRange(from: start, to: start) {
                self.textView.selectedTextRange = range
            }

            // Trigger text changed event
            self.textView.onTextChanged?("")
        }
    }

    func isFocused() -> Bool {
        return textView.isFirstResponder
    }

    // MARK: - Private Implementation Methods
    // Note: Many of these methods are copied from HybridTextInputView and adapted for UITextView
    // They should be factored out into a common utility class in a real implementation

    private func applyEffectiveTextAlignment() {
        let effectiveAlign: TextAlignAttributes? =
            self.textAlignToAttributes(self.textAlign)
            ?? self.textAttributes?.textAlign
        let alignment: NSTextAlignment
        if let align = effectiveAlign {
            alignment = HybridMultiLineTextInputView.nsTextAlignment(
                from: align
            )
        } else {
            alignment = .natural
        }
        self.textView.textAlignment = alignment
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
        default: return .auto
        }
    }

    private func updateAutoCorrect() {
        if let value = autoCorrect {
            textView.autocorrectionType = value ? .yes : .no
        } else {
            textView.autocorrectionType = .default
        }
    }

    private func updateAutoCapitalize() {
        switch self.autoCapitalize {
        case nil, .sentences:
            textView.autocapitalizationType = .sentences
        case .words:
            textView.autocapitalizationType = .words
        case .characters:
            textView.autocapitalizationType = .allCharacters
        case .none?:
            textView.autocapitalizationType = .none
        }
    }

    private func updateAutoComplete() {
        guard let auto = self.autoComplete else {
            textView.textContentType = nil
            return
        }
        // Implementation matches HybridTextInputView
        switch auto {
        case .url:
            textView.textContentType = .URL
        case .namePrefix:
            textView.textContentType = .namePrefix
        case .name:
            textView.textContentType = .name
        case .nameSuffix:
            textView.textContentType = .nameSuffix
        case .givenName:
            textView.textContentType = .givenName
        case .middleName:
            textView.textContentType = .middleName
        case .familyName:
            textView.textContentType = .familyName
        case .nickname:
            textView.textContentType = .nickname
        case .organizationName:
            textView.textContentType = .organizationName
        case .jobTitle:
            textView.textContentType = .jobTitle
        case .location:
            textView.textContentType = .location
        case .fullStreetAddress:
            textView.textContentType = .fullStreetAddress
        case .streetAddressLine1:
            textView.textContentType = .streetAddressLine1
        case .streetAddressLine2:
            textView.textContentType = .streetAddressLine2
        case .addressCity:
            textView.textContentType = .addressCity
        case .addressCityAndState:
            textView.textContentType = .addressCityAndState
        case .addressState:
            textView.textContentType = .addressState
        case .postalCode:
            textView.textContentType = .postalCode
        case .sublocality:
            textView.textContentType = .sublocality
        case .countryName:
            textView.textContentType = .countryName
        case .username:
            textView.textContentType = .username
        case .password:
            textView.textContentType = .password
        case .newPassword:
            textView.textContentType = .newPassword
        case .oneTimeCode:
            textView.textContentType = .oneTimeCode
        case .emailAddress:
            textView.textContentType = .emailAddress
        case .telephoneNumber:
            textView.textContentType = .telephoneNumber
        case .cellularEid:
            if #available(iOS 17.4, *) {
                textView.textContentType = .cellularEID
            }
        case .cellularImei:
            if #available(iOS 17.4, *) {
                textView.textContentType = .cellularIMEI
            }
        case .creditCardNumber:
            textView.textContentType = .creditCardNumber
        case .creditCardExpiration:
            if #available(iOS 17.0, *) {
                textView.textContentType = .creditCardExpiration
            }
        case .creditCardExpirationMonth:
            if #available(iOS 17.0, *) {
                textView.textContentType = .creditCardExpirationMonth
            }
        case .creditCardExpirationYear:
            if #available(iOS 17.0, *) {
                textView.textContentType = .creditCardExpirationYear
            }
        case .creditCardSecurityCode:
            if #available(iOS 17.0, *) {
                textView.textContentType = .creditCardSecurityCode
            }
        case .creditCardType:
            if #available(iOS 17.0, *) {
                textView.textContentType = .creditCardType
            }
        case .creditCardName:
            if #available(iOS 17.0, *) {
                textView.textContentType = .creditCardName
            }
        case .creditCardGivenName:
            if #available(iOS 17.0, *) {
                textView.textContentType = .creditCardGivenName
            }
        case .creditCardMiddleName:
            if #available(iOS 17.0, *) {
                textView.textContentType = .creditCardMiddleName
            }
        case .creditCardFamilyName:
            if #available(iOS 17.0, *) {
                textView.textContentType = .creditCardFamilyName
            }
        case .birthdate:
            if #available(iOS 17.0, *) {
                textView.textContentType = .birthdate
            }
        case .birthdateDay:
            if #available(iOS 17.0, *) {
                textView.textContentType = .birthdateDay
            }
        case .birthdateMonth:
            if #available(iOS 17.0, *) {
                textView.textContentType = .birthdateMonth
            }
        case .birthdateYear:
            if #available(iOS 17.0, *) {
                textView.textContentType = .birthdateYear
            }
        case .dateTime:
            textView.textContentType = .dateTime
        case .flightNumber:
            textView.textContentType = .flightNumber
        case .shipmentTrackingNumber:
            textView.textContentType = .shipmentTrackingNumber
        }
    }

    private func setDefaultValue() {
        guard self.hasAppliedDefaultValue == false else { return }
        guard let initialText = self.defaultValue,
            !(self.textView.text?.isEmpty == false)
        else { return }
        self.textView.text = applyTextTransform(initialText)
        self.hasAppliedDefaultValue = true
    }

    private func updateKeyboardType() {
        guard let type = self.keyboardType else {
            self.textView.keyboardType = .default
            return
        }
        switch type {
        case .url:
            self.textView.keyboardType = .URL
        case .emailAddress:
            self.textView.keyboardType = .emailAddress
        case .default:
            self.textView.keyboardType = .default
        case .asciiCapable:
            self.textView.keyboardType = .asciiCapable
        case .numbersAndPunctuation:
            self.textView.keyboardType = .numbersAndPunctuation
        case .numberPad:
            self.textView.keyboardType = .numberPad
        case .phonePad:
            self.textView.keyboardType = .phonePad
        case .namePhonePad:
            self.textView.keyboardType = .namePhonePad
        case .decimalPad:
            self.textView.keyboardType = .decimalPad
        case .twitter:
            self.textView.keyboardType = .twitter
        case .webSearch:
            self.textView.keyboardType = .webSearch
        case .asciiCapableNumberPad:
            if #available(iOS 10.0, *) {
                self.textView.keyboardType = .asciiCapableNumberPad
            } else {
                self.textView.keyboardType = .numberPad
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
        self.textView.keyboardAppearance = appearance
    }

    fileprivate func updateReturnKeyType() {
        guard let type = self.returnKeyType else {
            self.textView.returnKeyType = .default
            return
        }
        switch type {
        case .default:
            self.textView.returnKeyType = .default
        case .go:
            self.textView.returnKeyType = .go
        case .google:
            self.textView.returnKeyType = .google
        case .join:
            self.textView.returnKeyType = .join
        case .next:
            self.textView.returnKeyType = .next
        case .route:
            self.textView.returnKeyType = .route
        case .search:
            self.textView.returnKeyType = .search
        case .send:
            self.textView.returnKeyType = .send
        case .yahoo:
            self.textView.returnKeyType = .yahoo
        case .done:
            self.textView.returnKeyType = .done
        case .emergencyCall:
            self.textView.returnKeyType = .emergencyCall
        case .continue:
            if #available(iOS 9.0, *) {
                self.textView.returnKeyType = .`continue`
            } else {
                self.textView.returnKeyType = .default
            }
        }
    }

    private func updateSelectionTintColor() {
        guard let value = self.selectionColor else {
            self.textView.tintColor = nil
            return
        }
        if case .second(let doubleValue) = value {
            let v = UInt32(clamping: Int64(doubleValue))
            let a = CGFloat((v >> 24) & 0xFF) / 255.0
            let r = CGFloat((v >> 16) & 0xFF) / 255.0
            let g = CGFloat((v >> 8) & 0xFF) / 255.0
            let b = CGFloat(v & 0xFF) / 255.0
            self.textView.tintColor = UIColor(
                red: r,
                green: g,
                blue: b,
                alpha: a
            )
            return
        }
        // Additional color resolution logic would go here (semantic/dynamic colors)
    }

    // MARK: - Font Scaling
    @objc private func handleContentSizeCategoryDidChange() {
        self.applyFontScaling()

        // Recalculate height when system font size changes
        if let callback = self.onInitialHeightMeasured {
            let newHeight = Double(self.textView.contentSize.height)
            callback(newHeight)
        }
    }

    private func resolvedMaxFontSizeMultiplier() -> CGFloat? {
        guard let value = self.maxFontSizeMultiplier else { return nil }
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
            compatibleWith: self.textView.traitCollection
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
        self.textView.font = newFont
    }

    // MARK: - Event Callbacks
    private func wireTextViewEventCallbacks() {
        self.textView.onDidBeginEditing = { [weak self] in
            guard let self = self else { return }
            if self.selectTextOnFocus == true {
                DispatchQueue.main.async { [weak self] in
                    self?.textView.selectAll(nil)
                }
            }
            self.onFocused?()
        }

        self.textView.onDidEndEditing = { [weak self] in
            guard let self = self else { return }
            if let onEditingEndedCallback = self.onEditingEnded {
                onEditingEndedCallback(self.textView.text ?? "")
            }
            self.onBlurred?()
        }

        self.textView.onTextChanged = { [weak self] text in
            self?.onTextChanged?(text)
        }

        self.textView.onSelectionChanged = { [weak self] start, end in
            self?.onSelectionChanged?(start, end)
        }

        self.textView.onEditingSubmitted = { [weak self] text in
            self?.onEditingSubmitted?(text)
        }

        self.textView.onContentSizeChanged = { [weak self] width, height in
            self?.onContentSizeChanged?(width, height)
        }

        self.textView.onKeyPressed = { [weak self] key in
            self?.onKeyPressed?(key)
        }

        self.textView.onTouchBegan = {
            [weak self] pageX, pageY, locationX, locationY, timestamp in
            self?.onTouchBegan?(pageX, pageY, locationX, locationY, timestamp)
        }

        self.textView.onTouchEnded = {
            [weak self] pageX, pageY, locationX, locationY, timestamp in
            self?.onTouchEnded?(pageX, pageY, locationX, locationY, timestamp)
        }
    }

    // MARK: - Text Attributes (simplified implementation)
    private func applyTextAttributes() {
        guard let attrs = self.textAttributes else {
            self.resetToDefaultAttributes()
            return
        }

        // Apply font size
        var font = self.baseFont
        if let fontSize = attrs.fontSize, fontSize > 0 {
            font = font.withSize(CGFloat(fontSize))
        }

        // Apply font weight
        if let weightVal = attrs.fontWeight {
            let weight: UIFont.Weight
            switch weightVal {
            case .first(let weightName):
                weight = UIFont.Weight(
                    rawValue: HybridMultiLineTextInputView.fontWeightFromString(
                        weightName
                    )
                )
            case .second(let weightDouble):
                weight = UIFont.Weight(rawValue: CGFloat(weightDouble))
            }
            font = HybridMultiLineTextInputView.font(font: font, weight: weight)
        }

        // Apply font style
        if let style = attrs.fontStyle, style.lowercased() == "italic" {
            font = HybridMultiLineTextInputView.italicFont(font: font)
        }

        self.textView.font = font

        // Apply text color
        if let color = attrs.color {
            switch color {
            case .second(let doubleValue):
                let v = UInt32(clamping: Int64(doubleValue))
                let a = CGFloat((v >> 24) & 0xFF) / 255.0
                let r = CGFloat((v >> 16) & 0xFF) / 255.0
                let g = CGFloat((v >> 8) & 0xFF) / 255.0
                let b = CGFloat(v & 0xFF) / 255.0
                self.textView.textColor = UIColor(
                    red: r,
                    green: g,
                    blue: b,
                    alpha: a
                )
            case .first(_):
                // Handle semantic/dynamic colors if needed
                break
            }
        }

        // Apply text transform
        if let currentText = self.textView.text, !currentText.isEmpty {
            self.textView.text = applyTextTransform(currentText)
        }

        // Apply lineBreakStrategyIOS and lineBreakModeIOS
        applyLineBreakProperties()
    }

    // MARK: - Line Break Properties
    private func applyLineBreakProperties() {
        guard let attrs = self.textAttributes else { return }

        // Get current attributed text or create new one
        let currentText = self.textView.text ?? ""
        let mutableAttributedString: NSMutableAttributedString

        if let existingAttributedText = self.textView.attributedText {
            mutableAttributedString = NSMutableAttributedString(
                attributedString: existingAttributedText
            )
        } else {
            mutableAttributedString = NSMutableAttributedString(
                string: currentText
            )
            // Apply current font and color
            if let font = self.textView.font {
                mutableAttributedString.addAttribute(
                    .font,
                    value: font,
                    range: NSRange(location: 0, length: currentText.count)
                )
            }
            if let textColor = self.textView.textColor {
                mutableAttributedString.addAttribute(
                    .foregroundColor,
                    value: textColor,
                    range: NSRange(location: 0, length: currentText.count)
                )
            }
        }

        let fullRange = NSRange(
            location: 0,
            length: mutableAttributedString.length
        )

        // Create or get existing paragraph style
        let paragraphStyle = NSMutableParagraphStyle()

        // Preserve existing paragraph style attributes if any
        mutableAttributedString.enumerateAttribute(
            .paragraphStyle,
            in: fullRange,
            options: []
        ) {
            (value, range, _) in
            if let existingStyle = value as? NSParagraphStyle {
                paragraphStyle.setParagraphStyle(existingStyle)
            }
        }

        // Apply lineBreakStrategyIOS (iOS 14.0+)
        if let lineBreakStrategy = attrs.lineBreakStrategyIOS {
            if #available(iOS 14.0, *) {
                switch lineBreakStrategy {
                case .none:
                    paragraphStyle.lineBreakStrategy = []
                case .standard:
                    paragraphStyle.lineBreakStrategy = .standard
                case .hangulWord:
                    paragraphStyle.lineBreakStrategy = .hangulWordPriority
                case .pushOut:
                    paragraphStyle.lineBreakStrategy = .pushOut
                }
            }
        }

        // Apply lineBreakModeIOS
        if let lineBreakMode = attrs.lineBreakModeIOS {
            switch lineBreakMode {
            case .wordwrapping:
                paragraphStyle.lineBreakMode = .byWordWrapping
            case .char:
                paragraphStyle.lineBreakMode = .byCharWrapping
            case .clip:
                paragraphStyle.lineBreakMode = .byClipping
            case .head:
                paragraphStyle.lineBreakMode = .byTruncatingHead
            case .middle:
                paragraphStyle.lineBreakMode = .byTruncatingMiddle
            case .tail:
                paragraphStyle.lineBreakMode = .byTruncatingTail
            }
        }

        // Apply the paragraph style
        mutableAttributedString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: fullRange
        )
        self.textView.attributedText = mutableAttributedString
    }

    private func resetToDefaultAttributes() {
        self.textView.textColor = nil
        self.baseFont = UIFont.systemFont(ofSize: 14)
        self.textView.font = self.baseFont
        self.applyEffectiveTextAlignment()
    }

    private func applyTextTransform(_ text: String) -> String {
        guard let transform = self.textAttributes?.textTransform else {
            return text
        }
        switch transform {
        case .uppercase:
            return text.uppercased(with: Locale.current)
        case .lowercase:
            return text.lowercased(with: Locale.current)
        case .capitalize:
            return text.capitalized(with: Locale.current)
        case .none:
            return text
        @unknown default:
            return text
        }
    }

    // MARK: - Utility Methods for Text Decoration (stubs for now)
    func reapplyTextDecoration() {
        // TODO: Implement text decoration re-application for UITextView
    }

    func reapplyTextShadow() {
        // TODO: Implement text shadow re-application for UITextView
    }

    // MARK: - Static Helper Methods
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

    // MARK: - Number of Lines Implementation
    private func updateNumberOfLines() {
        guard let numberOfLines = self.numberOfLines else {
            // If numberOfLines is nil, allow unlimited lines
            self.textView.textContainer.maximumNumberOfLines = 0
            self.textView.returnKeyType = .default
            return
        }

        // Convert Double to Int and ensure it's at least 0
        let maxLines = max(0, Int(numberOfLines))

        // Set the maximum number of lines for the text container
        // 0 means unlimited lines in iOS
        self.textView.textContainer.maximumNumberOfLines = maxLines

        // Update return key type based on current content
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateReturnKeyForLineLimit()
        }

        // Force layout update to apply the changes
        self.textView.setNeedsLayout()
        self.textView.layoutIfNeeded()

        // Notify content size change after line limit is applied
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onContentSizeChanged?(
                Double(self.textView.contentSize.width),
                Double(self.textView.contentSize.height)
            )
        }
    }

    private func updateReturnKeyForLineLimit() {
        guard let maxLines = self.numberOfLines, maxLines > 0 else {
            return
        }

        let currentText = self.textView.text ?? ""
        let currentLines = numberOfLinesInText(
            currentText,
            textView: self.textView
        )

        // If we're at or near the line limit, change return key to "Done"
        if currentLines >= Int(maxLines) {
            self.textView.returnKeyType = .done
        } else {
            // Restore original return key type
            self.updateReturnKeyType()
        }
    }

    private func numberOfLinesInText(_ text: String, textView: UITextView)
        -> Int
    {
        guard !text.isEmpty else { return 1 }

        let textWidth =
            textView.frame.width - textView.textContainerInset.left
            - textView.textContainerInset.right - 2.0
            * textView.textContainer.lineFragmentPadding

        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(
                width: textWidth,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: textView.font ?? UIFont.systemFont(ofSize: 17)],
            context: nil
        )

        let lineHeight = textView.font?.lineHeight ?? 17
        let numberOfLines = Int(ceil(boundingRect.height / lineHeight))

        return max(numberOfLines, 1)
    }
}
