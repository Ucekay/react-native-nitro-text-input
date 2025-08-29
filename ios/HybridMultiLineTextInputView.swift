import Foundation
import NitroModules
import UIKit

class CustomTextView: UITextView, UITextViewDelegate, UITextDropDelegate {
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
    var onContentSizeChanged: ((_ width: Double, _ height: Double) -> Void)?
    var submitBehavior: SubmitBehavior?
    var numberOfLines: Int?
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
    weak var parentView: HybridMultiLineTextInputView?

    // Placeholder support
    private let placeholderLabel = UILabel()
    private var placeholderTopConstraint: NSLayoutConstraint?
    var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
            updatePlaceholderVisibility()
        }
    }
    var placeholderTextColor: UIColor = UIColor.placeholderText {
        didSet {
            placeholderLabel.textColor = placeholderTextColor
        }
    }

    override var font: UIFont? {
        didSet {
            placeholderLabel.font = font ?? UIFont.systemFont(ofSize: 14)
            harmonizeInsetsWithSingleLineHeight()
        }
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

        // Setup placeholder
        setupPlaceholderLabel()

    // Harmonize insets with a single-line text field appearance
    harmonizeInsetsWithSingleLineHeight()

        // Add observers for text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleTextDidChange(_:)),
            name: UITextView.textDidChangeNotification,
            object: self
        )
    }

    private func setupPlaceholderLabel() {
        placeholderLabel.numberOfLines = 0
        placeholderLabel.textColor = placeholderTextColor
        placeholderLabel.font = self.font ?? UIFont.systemFont(ofSize: 14)
        placeholderLabel.backgroundColor = UIColor.clear
        placeholderLabel.isUserInteractionEnabled = false

        self.addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        let top = placeholderLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 0)
        self.placeholderTopConstraint = top
        NSLayoutConstraint.activate([
            top,
            placeholderLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 2),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -2),
        ])

        updatePlaceholderVisibility()
    }

    // Adjust textContainerInset so that (lineHeight + top+bottom) ~= intrinsic height of a UITextField with same font.
    // This reduces the initial multiline height to match single-line appearance.
    private func harmonizeInsetsWithSingleLineHeight() {
        guard let f = self.font else { return }
        // Create a transient text field to get the platform's intrinsic height for that font
        let tf = UITextField()
        tf.font = f
        let target = tf.intrinsicContentSize.height
        let line = f.lineHeight
        // Extra vertical space we need to distribute as padding (not negative)
        let extra = max(0, target - line)
        let vertical = extra / 2.0
        // Preserve current horizontal insets & padding; only adjust vertical parts
        var inset = self.textContainerInset
        inset.top = vertical
        inset.bottom = vertical
        // Avoid layout churn if unchanged
        if abs(inset.top - self.textContainerInset.top) > 0.1 || abs(inset.bottom - self.textContainerInset.bottom) > 0.1 {
            self.textContainerInset = inset
        }
        // Reduce internal left/right padding to feel closer to UITextField (lineFragmentPadding is applied on both sides)
        self.textContainer.lineFragmentPadding = 0
        // Update placeholder top constraint so placeholder baseline aligns similarly
        self.placeholderTopConstraint?.constant = inset.top
        // Trigger layout update without forcing immediate layout pass
        self.setNeedsLayout()
    }

    func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !self.text.isEmpty
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

    // MARK: - UITextViewDelegate

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        // If there is markedTextRange (IME composition in progress), always allow change
        if self.markedTextRange != nil {
            return true
        }

        // 厳格な行数制限ロジック（変換中ではない通常入力時のみ）
        if let maxLines = numberOfLines, maxLines > 0 {
            let newText = (textView.text as NSString).replacingCharacters(
                in: range,
                with: text
            )
            let currentLines = numberOfLinesInText(
                newText,
                textView: textView
            )
            if currentLines > maxLines {
                return false  // 行数制限超過を禁止
            }
        }

        // Handle key press events（旧ロジックはそのまま）
        if self.textWasPasted == false {
            if text == "\n" {
                onKeyPressed?("Enter")

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

        // Allow IME composition to proceed without truncation
        guard let maxLen = self.maxLength else { return true }

        let current = self.text ?? ""
        let allowedLength = maxLen - current.count + range.length
        if allowedLength <= 0 {
            // Always allow deletions
            return text.isEmpty
        }

        let incoming = text
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
        // Re-apply text decoration and shadow when not composing (markedTextRange is nil)
        if self.markedTextRange == nil {
            self.parentView?.reapplyTextDecoration()
            self.parentView?.reapplyTextShadow()
        }

        // Enforce maxLength for text
        guard let maxLen = self.maxLength else {
            // Enforce numberOfLines trimming only if markedTextRange == nil
            if self.markedTextRange == nil,
                let maxLines = self.numberOfLines, maxLines > 0
            {
                let current = self.text ?? ""
                let currentLines = numberOfLinesInText(current, textView: self)
                if currentLines > maxLines {
                    // Trim text to maxLines
                    if let trimmedText = trimmedTextToMaxLines(
                        current,
                        maxLines: maxLines
                    ) {
                        self.text = trimmedText
                    }
                }
            }
            // Notify text changed and content size changed
            onTextChanged?(self.text ?? "")
            // Defer content size reporting to the next runloop so that UIKit has
            // a chance to update contentSize after the text mutation & layout pass.
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onContentSizeChanged?(
                    Double(self.contentSize.width),
                    Double(self.contentSize.height)
                )
            }
            return
        }

        // Do not enforce while composing
        if self.markedTextRange != nil { return }

        // Enforce maxLength first
        let current = self.text ?? ""
        if current.count > maxLen {
            var cutIndex = maxLen
            if maxLen > 0 {
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
            let endIdx = current.index(
                current.startIndex,
                offsetBy: max(0, cutIndex)
            )
            let limited = String(current[..<endIdx])
            self.text = limited
        }

        // After enforcing maxLength, enforce numberOfLines if set
        if let maxLines = self.numberOfLines, maxLines > 0 {
            let currentAfterLengthTrim = self.text ?? ""
            let currentLines = numberOfLinesInText(
                currentAfterLengthTrim,
                textView: self
            )
            if currentLines > maxLines {
                if let trimmedText = trimmedTextToMaxLines(
                    currentAfterLengthTrim,
                    maxLines: maxLines
                ) {
                    self.text = trimmedText
                }
            }
        }

        // Notify text changed and content size changed after any trimming
        onTextChanged?(self.text ?? "")

        // Update placeholder visibility
        updatePlaceholderVisibility()

        // Defer content size reporting (see comment above) to avoid transient 0 height values
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onContentSizeChanged?(
                Double(self.contentSize.width),
                Double(self.contentSize.height)
            )
        }

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

    // MARK: - Helper methods for line counting
    private func numberOfLinesInText(_ text: String, textView: UITextView)
        -> Int
    {
        guard !text.isEmpty else { return 1 }

        let textWidth =
            textView.frame.width - textView.textContainerInset.left
            - textView.textContainerInset.right
            - 2.0 * textView.textContainer.lineFragmentPadding

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

    // Trim text to fit within maxLines line count, preserving composed characters
    private func trimmedTextToMaxLines(_ text: String, maxLines: Int) -> String?
    {
        guard maxLines > 0 else { return text }

        var low = 0
        var high = text.count
        var bestFit = text

        while low <= high {
            let mid = (low + high) / 2
            guard mid <= text.count else { break }
            let idx = text.index(text.startIndex, offsetBy: mid)
            let candidate = String(text[..<idx])
            let lines = numberOfLinesInText(candidate, textView: self)
            if lines <= maxLines {
                bestFit = candidate
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return bestFit
    }

    // MARK: - UITextDropDelegate
    @available(iOS 11.0, *)
    func textDroppableView(
        _ textDroppableView: UIView & UITextDroppable,
        willBecomeEditableForDrop drop: UITextDropRequest
    ) -> UITextDropEditability {
        // Allow text editing for drops
        return .temporary
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: UITextView.textDidChangeNotification,
            object: self
        )
    }

    // MARK: - Layout observation for reliable content size events
    private var lastReportedContentSize: CGSize = .zero
    override func layoutSubviews() {
        super.layoutSubviews()
        let size = self.contentSize
        // Avoid spamming identical values; also skip obviously invalid zero heights unless truly empty
        if size != lastReportedContentSize {
            lastReportedContentSize = size
            // Only report after UIKit finalized layout in this cycle
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Re-check to ensure it hasn't changed again before dispatch executed
                let current = self.contentSize
                if current.height > 0 || current.width > 0 { // basic sanity
                    self.onContentSizeChanged?(
                        Double(current.width),
                        Double(current.height)
                    )
                }
            }
        }
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

        // Initialize immediately for proper color application
        self.baseFont = UIFont.systemFont(ofSize: 14)
        self.textView.font = self.baseFont
        self.wireTextViewEventCallbacks()

        // Defer layout-dependent operations until layout pass to get accurate intrinsic height
        Task { @MainActor in
            // Ensure layout is up-to-date
            self.textView.setNeedsLayout()
            self.textView.layoutIfNeeded()

            // Apply all styling immediately after layout
            self.applyTextAttributes()
            self.applyFontScaling()
            self.updateNumberOfLines()

            // Calculate initial height using content size
            // For UITextView, we need to ensure proper sizing calculation
            let initialHeight = self.calculateInitialHeight()
            if let callback = self.onInitialHeightMeasured {
                callback(initialHeight)
            }
        }

        // Re-dispatch once more after next runloop to capture any inset/font adjustments done inside CustomTextView
        Task { @MainActor in
            await Task.yield()
            self.textView.setNeedsLayout()
            self.textView.layoutIfNeeded()
            if let callback = self.onInitialHeightMeasured {
                let height = self.calculateInitialHeight()
                callback(height)
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

    // MARK: - Initial Height Calculation
    private func calculateInitialHeight() -> Double {
        let contentHeight = self.textView.contentSize.height
        let intrinsicHeight = self.textView.intrinsicContentSize.height
        let calculatedHeight = max(contentHeight, intrinsicHeight)
        let referenceHeight = self.singleLineReferenceHeight()
        return Double(max(calculatedHeight, referenceHeight))
    }

    // Intrinsic single-line reference (UITextField) height cache
    private static var singleLineHeightCache: [String: CGFloat] = [:]
    private func singleLineReferenceHeight() -> CGFloat {
        let font = self.textView.font ?? self.baseFont
        let key = "\(font.fontName)#\(font.pointSize)"
        if let cached = Self.singleLineHeightCache[key] { return cached }
        let tf = UITextField()
        tf.font = font
        let h = tf.intrinsicContentSize.height
        Self.singleLineHeightCache[key] = h
        return h
    }

    private func resolveProcessedColor(_ processedColor: ProcessedColor)
        -> UIColor?
    {
        switch processedColor {
        case .second(let doubleValue):
            // Handle integer color values (convert from 32-bit ARGB)
            let color = UInt32(doubleValue)
            let alpha = CGFloat((color >> 24) & 0xFF) / 255.0
            let red = CGFloat((color >> 16) & 0xFF) / 255.0
            let green = CGFloat((color >> 8) & 0xFF) / 255.0
            let blue = CGFloat(color & 0xFF) / 255.0
            return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        case .first(let json):
            // Handle semantic/dynamic colors
            return resolveSemanticColor(from: json)
        }
    }

    private func resolveSemanticColor(from json: Any) -> UIColor? {
        guard let dict = json as? [String: Any] else {
            return nil
        }

        // Handle semantic color names
        if let semantic = dict["semantic"] as? String {
            return resolveSystemColor(semantic)
        }

        // Handle dynamic colors with light/dark variants
        if let dynamic = dict["dynamic"] as? [String: Any] {
            if #available(iOS 13.0, *) {
                return UIColor { traitCollection in
                    let isDarkMode = traitCollection.userInterfaceStyle == .dark

                    if isDarkMode,
                        let darkColor = dynamic["dark"] as? [String: Any]
                    {
                        return self.resolveColorComponents(from: darkColor)
                            ?? UIColor.label
                    } else if let lightColor = dynamic["light"]
                        as? [String: Any]
                    {
                        return self.resolveColorComponents(from: lightColor)
                            ?? UIColor.label
                    }

                    return UIColor.label
                }
            } else {
                // Fallback to light color for iOS < 13
                if let lightColor = dynamic["light"] as? [String: Any] {
                    return resolveColorComponents(from: lightColor)
                }
            }
        }

        // Handle direct color components
        return resolveColorComponents(from: dict)
    }

    private func resolveSystemColor(_ colorName: String) -> UIColor? {
        switch colorName.lowercased() {
        case "label":
            if #available(iOS 13.0, *) {
                return UIColor.label
            } else {
                return UIColor.black
            }
        case "secondarylabel":
            if #available(iOS 13.0, *) {
                return UIColor.secondaryLabel
            } else {
                return UIColor.darkGray
            }
        case "tertiarylabel":
            if #available(iOS 13.0, *) {
                return UIColor.tertiaryLabel
            } else {
                return UIColor.lightGray
            }
        case "quaternarylabel":
            if #available(iOS 13.0, *) {
                return UIColor.quaternaryLabel
            } else {
                return UIColor.lightGray
            }
        case "placeholdertext":
            if #available(iOS 13.0, *) {
                return UIColor.placeholderText
            } else {
                return UIColor.lightGray
            }
        case "systembackground":
            if #available(iOS 13.0, *) {
                return UIColor.systemBackground
            } else {
                return UIColor.white
            }
        case "secondarysystembackground":
            if #available(iOS 13.0, *) {
                return UIColor.secondarySystemBackground
            } else {
                return UIColor.groupTableViewBackground
            }
        case "tertiarysystembackground":
            if #available(iOS 13.0, *) {
                return UIColor.tertiarySystemBackground
            } else {
                return UIColor.groupTableViewBackground
            }
        case "systemblue":
            return UIColor.systemBlue
        case "systemgreen":
            return UIColor.systemGreen
        case "systemred":
            return UIColor.systemRed
        case "systemorange":
            return UIColor.systemOrange
        case "systemyellow":
            return UIColor.systemYellow
        case "systempink":
            return UIColor.systemPink
        case "systempurple":
            return UIColor.systemPurple
        case "systemteal":
            if #available(iOS 13.0, *) {
                return UIColor.systemTeal
            } else {
                return UIColor.cyan
            }
        case "systemindigo":
            if #available(iOS 13.0, *) {
                return UIColor.systemIndigo
            } else {
                return UIColor.blue
            }
        case "systemgray":
            return UIColor.systemGray
        default:
            return nil
        }
    }

    private func resolveColorComponents(from dict: [String: Any]) -> UIColor? {
        if let r = dict["r"] as? Double,
            let g = dict["g"] as? Double,
            let b = dict["b"] as? Double
        {
            let alpha = dict["a"] as? Double ?? 1.0
            return UIColor(
                red: CGFloat(r / 255.0),
                green: CGFloat(g / 255.0),
                blue: CGFloat(b / 255.0),
                alpha: CGFloat(alpha)
            )
        }

        if let hex = dict["hex"] as? String {
            return resolveHexColor(hex)
        }

        return nil
    }

    private func resolveHexColor(_ hex: String) -> UIColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if length == 6 {
            red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x0000FF) / 255.0
            alpha = 1.0
        } else if length == 8 {
            red = CGFloat((rgb & 0xFF00_0000) >> 24) / 255.0
            green = CGFloat((rgb & 0x00FF_0000) >> 16) / 255.0
            blue = CGFloat((rgb & 0x0000_FF00) >> 8) / 255.0
            alpha = CGFloat(rgb & 0x0000_00FF) / 255.0
        } else {
            return nil
        }

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
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
                    let newHeight = self.calculateInitialHeight()
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

    var caretHidden: Bool? {
        didSet {
            Task { @MainActor in
                self.textView.isCaretHidden = self.caretHidden ?? false
            }
        }
    }

    var clearTextOnFocus: Bool? {
        didSet {
            self.textView.clearTextOnFocus = self.clearTextOnFocus ?? false
        }
    }

    var clearButtonMode: ClearButtonMode? {
        didSet {
            // UITextView doesn't support clearButtonMode, but we handle it gracefully
            // This is intentionally a no-op for multi-line text input
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
                    let newHeight = self.calculateInitialHeight()
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

    var numberOfLines: Double? {
        didSet {
            Task { @MainActor in
                updateNumberOfLines()
                // Pass numberOfLines to CustomTextView
                if let lines = numberOfLines, lines > 0 {
                    self.textView.numberOfLines = Int(lines)
                } else {
                    self.textView.numberOfLines = nil
                }
            }
        }
    }

    var placeholder: String? {
        didSet {
            Task { @MainActor in
                self.textView.placeholder = self.placeholder
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
                if let color = self.placeholderTextColor {
                    self.textView.placeholderTextColor =
                        self.resolveProcessedColor(color)
                        ?? UIColor.placeholderText
                } else {
                    self.textView.placeholderTextColor = UIColor.placeholderText
                }
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
            // Apply text color immediately if available, even before full layout
            if let attrs = self.textAttributes, let color = attrs.color {
                if let resolvedColor = resolveProcessedColor(color) {
                    self.textView.textColor = resolvedColor
                }
            }

            Task { @MainActor in
                self.applyTextAttributes()
                Task { @MainActor in
                    self.applyEffectiveTextAlignment()
                }

                // Recalculate height when text attributes change (font size, etc.)
                if let callback = self.onInitialHeightMeasured {
                    let newHeight = self.calculateInitialHeight()
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

            // Explicitly refresh placeholder visibility because programmatic text change + manual onTextChanged
            // may run before UITextView posts its textDidChange notification.
            self.textView.updatePlaceholderVisibility()
        }
    }

    func isFocused() -> Bool {
        return textView.isFirstResponder
    }

    func scrollRangeToVisible(start: Int, end: Int) {
        Task { @MainActor in
            let range = NSRange(location: start, length: max(0, end - start))
            self.textView.scrollRangeToVisible(range)
        }
    }

    func getContentSize() -> (width: Double, height: Double) {
        return (
            Double(textView.contentSize.width),
            Double(textView.contentSize.height)
        )
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

    private func updateReturnKeyType() {
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
            let newHeight = self.calculateInitialHeight()
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
            guard let self = self else { return }
            let reference = Double(self.singleLineReferenceHeight())
            let normalizedHeight = max(height, reference)
            self.onContentSizeChanged?(width, normalizedHeight)
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

        // Start with a clean attributed string to properly apply all attributes
        let currentText = self.textView.text ?? ""
        let mutableAttributedString = NSMutableAttributedString(
            string: currentText
        )
        let fullRange = NSRange(location: 0, length: currentText.count)

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

        // Apply font variants if available
        if let variants = attrs.fontVariant, !variants.isEmpty {
            font = applyFontVariant(to: font, variants: variants)
        }

        // Add font attribute
        mutableAttributedString.addAttribute(
            .font,
            value: font,
            range: fullRange
        )

        // Apply text color
        if let color = attrs.color {
            let resolvedColor = resolveProcessedColor(color)
            if let textColor = resolvedColor {
                // Set both UITextView's textColor property and attributed string color
                self.textView.textColor = textColor
                mutableAttributedString.addAttribute(
                    .foregroundColor,
                    value: textColor,
                    range: fullRange
                )
            }
        } else {
            // Reset to system default if no color specified
            self.textView.textColor = nil
        }

        // Apply letter spacing
        if let letterSpacing = attrs.letterSpacing {
            mutableAttributedString.addAttribute(
                .kern,
                value: letterSpacing,
                range: fullRange
            )
        }

        // Apply writing direction
        if let writingDirection = attrs.writingDirection {
            let nsWritingDirection =
                HybridMultiLineTextInputView.nsWritingDirection(
                    from: writingDirection
                )
            mutableAttributedString.addAttribute(
                .writingDirection,
                value: [nsWritingDirection.rawValue],
                range: fullRange
            )
        }

        // Apply text decoration (underline/strikethrough)
        if let decorationLine = attrs.textDecorationLine,
            decorationLine != .none
        {
            // Apply underline
            if decorationLine == .underline
                || decorationLine == .underlineLineThrough
            {
                let underlineStyle = nsUnderlineStyle(
                    from: attrs.textDecorationStyle ?? .solid
                )
                mutableAttributedString.addAttribute(
                    .underlineStyle,
                    value: underlineStyle.rawValue,
                    range: fullRange
                )

                if let decorationColor = attrs.textDecorationColor,
                    let resolvedColor = resolveProcessedColor(decorationColor)
                {
                    mutableAttributedString.addAttribute(
                        .underlineColor,
                        value: resolvedColor,
                        range: fullRange
                    )
                }
            }

            // Apply strikethrough
            if decorationLine == .lineThrough
                || decorationLine == .underlineLineThrough
            {
                let strikethroughStyle = nsUnderlineStyle(
                    from: attrs.textDecorationStyle ?? .solid
                )
                mutableAttributedString.addAttribute(
                    .strikethroughStyle,
                    value: strikethroughStyle.rawValue,
                    range: fullRange
                )

                if let decorationColor = attrs.textDecorationColor,
                    let resolvedColor = resolveProcessedColor(decorationColor)
                {
                    mutableAttributedString.addAttribute(
                        .strikethroughColor,
                        value: resolvedColor,
                        range: fullRange
                    )
                }
            }
        }

        // Apply text shadow
        if let shadowOffset = attrs.textShadowOffset,
            let shadowRadius = attrs.textShadowRadius
        {
            let shadow = NSShadow()
            shadow.shadowOffset = CGSize(
                width: shadowOffset.width,
                height: shadowOffset.height
            )
            shadow.shadowBlurRadius = CGFloat(shadowRadius)

            if let shadowColor = attrs.textShadowColor,
                let resolvedColor = resolveProcessedColor(shadowColor)
            {
                shadow.shadowColor = resolvedColor
            }

            mutableAttributedString.addAttribute(
                .shadow,
                value: shadow,
                range: fullRange
            )
        }

        // Apply paragraph style for line break properties and text alignment
        let paragraphStyle = NSMutableParagraphStyle()
        var shouldApplyParagraphStyle = false

        // (Removed custom lineHeight support)

        // Apply text alignment
        let effectiveAlign: TextAlignAttributes? =
            self.textAlignToAttributes(self.textAlign) ?? attrs.textAlign
        if let align = effectiveAlign {
            paragraphStyle.alignment =
                HybridMultiLineTextInputView.nsTextAlignment(from: align)
            shouldApplyParagraphStyle = true
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
                shouldApplyParagraphStyle = true
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
            shouldApplyParagraphStyle = true
        }

        if shouldApplyParagraphStyle {
            mutableAttributedString.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: fullRange
            )
        }

        // Set the attributed text with all attributes applied
        self.textView.attributedText = mutableAttributedString
        // Build typingAttributes once so newly typed text inherits all styles (underline, strike, shadow, color, etc.)
        var typingAttributes: [NSAttributedString.Key: Any] = [:]
        mutableAttributedString.enumerateAttributes(in: fullRange, options: []) { attrs, _, _ in
            for (k, v) in attrs { typingAttributes[k] = v }
        }
        if typingAttributes[.font] == nil { typingAttributes[.font] = self.textView.font }
        if typingAttributes[.foregroundColor] == nil { typingAttributes[.foregroundColor] = self.textView.textColor }
        self.textView.typingAttributes = typingAttributes

        // Apply text transform to the plain text if needed
        if let transform = attrs.textTransform {
            let transformedText = applyTextTransform(currentText)
            if transformedText != currentText {
                // Reapply all attributes to the transformed text
                let newAttributedString = NSMutableAttributedString(
                    string: transformedText
                )
                let newRange = NSRange(
                    location: 0,
                    length: transformedText.count
                )

                // Copy all attributes from the previous attributed string
                mutableAttributedString.enumerateAttributes(
                    in: fullRange,
                    options: []
                ) { attributes, _, _ in
                    for (key, value) in attributes {
                        newAttributedString.addAttribute(
                            key,
                            value: value,
                            range: newRange
                        )
                    }
                }

                self.textView.attributedText = newAttributedString
                // Update typingAttributes to reflect transformed text's attributes.
                var newTyping: [NSAttributedString.Key: Any] = [:]
                let newFullRange = NSRange(location: 0, length: newAttributedString.length)
                newAttributedString.enumerateAttributes(in: newFullRange, options: []) { attrs, _, _ in
                    for (k, v) in attrs { newTyping[k] = v }
                }
                if newTyping[.font] == nil { newTyping[.font] = self.textView.font }
                if newTyping[.foregroundColor] == nil { newTyping[.foregroundColor] = self.textView.textColor }
                self.textView.typingAttributes = newTyping
            }
        }
    }

    private func clearAttributedTextAndPreserveContent() {
        // Helper method to clear all attributed text while preserving plain text content
        if let currentText = self.textView.text, !currentText.isEmpty {
            let plainText = currentText
            self.textView.attributedText = nil
            self.textView.text = plainText
        } else {
            self.textView.attributedText = nil
        }
    }

    private func resetToDefaultAttributes() {
        // Reset all text attributes to defaults
        self.textView.textColor = UIColor.label  // Use system default label color
        self.baseFont = UIFont.systemFont(ofSize: 14)  // Reset base font to default
        self.textView.font = self.baseFont  // Default size and weight

        // Only set default alignment if textAlign is not specified
        if self.textAlign == nil {
            self.textView.textAlignment = .natural
        }

        // Clear any attributed text to remove spacing, decorations, shadows, colors
        clearAttributedTextAndPreserveContent()
        self.applyEffectiveTextAlignment()

        // Reset user interaction to default
        updateUserSelect(userSelect: .auto)
    }

    private static func nsWritingDirection(
        from writingDirection: WritingDirection
    ) -> NSWritingDirection {
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
            self.textView.isSelectable = false
            self.textView.isUserInteractionEnabled = false
        case .text:
            self.textView.isSelectable = true
            self.textView.isEditable = false
            self.textView.isUserInteractionEnabled = true
        case .all, .auto:
            self.textView.isSelectable = true
            self.textView.isEditable = self.editable ?? true
            self.textView.isUserInteractionEnabled = true
        case .contain:
            // .contain allows selection but restricts dragging outside bounds
            self.textView.isSelectable = true
            self.textView.isEditable = self.editable ?? true
            self.textView.isUserInteractionEnabled = true
        // UITextView doesn't have direct equivalent to CSS user-select: contain
        // but we can use the default behavior with selection enabled
        @unknown default:
            self.textView.isSelectable = true
            self.textView.isEditable = self.editable ?? true
            self.textView.isUserInteractionEnabled = true
        }
    }

    // MARK: - FontVariant Support
    private static let fontVariantFeatureMap:
        [String: [UIFontDescriptor.FeatureKey: Any]] = {
            if #available(iOS 15.0, *) {
                return [
                    "small-caps": [
                        .type: kLowerCaseType,
                        .selector: kLowerCaseSmallCapsSelector,
                    ],
                    "oldstyle-nums": [
                        .type: kNumberCaseType,
                        .selector: kLowerCaseNumbersSelector,
                    ],
                    "lining-nums": [
                        .type: kNumberCaseType,
                        .selector: kUpperCaseNumbersSelector,
                    ],
                    "tabular-nums": [
                        .type: kNumberSpacingType,
                        .selector: kMonospacedNumbersSelector,
                    ],
                    "proportional-nums": [
                        .type: kNumberSpacingType,
                        .selector: kProportionalNumbersSelector,
                    ],
                    "common-ligatures": [
                        .type: kLigaturesType,
                        .selector: kCommonLigaturesOnSelector,
                    ],
                    "no-common-ligatures": [
                        .type: kLigaturesType,
                        .selector: kCommonLigaturesOffSelector,
                    ],
                    "discretionary-ligatures": [
                        .type: kLigaturesType,
                        .selector: kRareLigaturesOnSelector,
                    ],
                    "no-discretionary-ligatures": [
                        .type: kLigaturesType,
                        .selector: kRareLigaturesOffSelector,
                    ],
                    "historical-ligatures": [
                        .type: kLigaturesType,
                        .selector: kHistoricalLigaturesOnSelector,
                    ],
                    "no-historical-ligatures": [
                        .type: kLigaturesType,
                        .selector: kHistoricalLigaturesOffSelector,
                    ],
                    "contextual": [
                        .type: kContextualAlternatesType,
                        .selector: kContextualAlternatesOnSelector,
                    ],
                    "no-contextual": [
                        .type: kContextualAlternatesType,
                        .selector: kContextualAlternatesOffSelector,
                    ],
                ]
            } else {
                return [
                    "small-caps": [
                        .featureIdentifier: kLowerCaseType,
                        .typeIdentifier: kLowerCaseSmallCapsSelector,
                    ],
                    "oldstyle-nums": [
                        .featureIdentifier: kNumberCaseType,
                        .typeIdentifier: kLowerCaseNumbersSelector,
                    ],
                    "lining-nums": [
                        .featureIdentifier: kNumberCaseType,
                        .typeIdentifier: kUpperCaseNumbersSelector,
                    ],
                    "tabular-nums": [
                        .featureIdentifier: kNumberSpacingType,
                        .typeIdentifier: kMonospacedNumbersSelector,
                    ],
                    "proportional-nums": [
                        .featureIdentifier: kNumberSpacingType,
                        .typeIdentifier: kProportionalNumbersSelector,
                    ],
                    "common-ligatures": [
                        .featureIdentifier: kLigaturesType,
                        .typeIdentifier: kCommonLigaturesOnSelector,
                    ],
                    "no-common-ligatures": [
                        .featureIdentifier: kLigaturesType,
                        .typeIdentifier: kCommonLigaturesOffSelector,
                    ],
                    "discretionary-ligatures": [
                        .featureIdentifier: kLigaturesType,
                        .typeIdentifier: kRareLigaturesOnSelector,
                    ],
                    "no-discretionary-ligatures": [
                        .featureIdentifier: kLigaturesType,
                        .typeIdentifier: kRareLigaturesOffSelector,
                    ],
                    "historical-ligatures": [
                        .featureIdentifier: kLigaturesType,
                        .typeIdentifier: kHistoricalLigaturesOnSelector,
                    ],
                    "no-historical-ligatures": [
                        .featureIdentifier: kLigaturesType,
                        .typeIdentifier: kHistoricalLigaturesOffSelector,
                    ],
                    "contextual": [
                        .featureIdentifier: kContextualAlternatesType,
                        .typeIdentifier: kContextualAlternatesOnSelector,
                    ],
                    "no-contextual": [
                        .featureIdentifier: kContextualAlternatesType,
                        .typeIdentifier: kContextualAlternatesOffSelector,
                    ],
                ]
            }
        }()

    private func applyFontVariant(to font: UIFont, variants: [FontVariant])
        -> UIFont
    {
        var features: [[UIFontDescriptor.FeatureKey: Any]] = []

        for variant in variants {
            let variantString = fontVariantToString(variant)

            // Handle stylistic sets separately
            if variantString.hasPrefix("stylistic-") {
                if let stylisticFeature = stylisticSetFeature(for: variant) {
                    features.append(stylisticFeature)
                }
            } else if let feature =
                HybridMultiLineTextInputView.fontVariantFeatureMap[
                    variantString
                ]
            {
                features.append(feature)
            }
        }

        guard !features.isEmpty else { return font }

        let descriptor = font.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName.featureSettings: features
        ])

        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    private func stylisticSetFeature(for variant: FontVariant)
        -> [UIFontDescriptor.FeatureKey: Any]?
    {
        let stylisticSetNumber: Int
        switch variant {
        case .stylisticOne: stylisticSetNumber = 1
        case .stylisticTwo: stylisticSetNumber = 2
        case .stylisticThree: stylisticSetNumber = 3
        case .stylisticFour: stylisticSetNumber = 4
        case .stylisticFive: stylisticSetNumber = 5
        case .stylisticSix: stylisticSetNumber = 6
        case .stylisticSeven: stylisticSetNumber = 7
        case .stylisticEight: stylisticSetNumber = 8
        case .stylisticNine: stylisticSetNumber = 9
        case .stylisticTen: stylisticSetNumber = 10
        case .stylisticEleven: stylisticSetNumber = 11
        case .stylisticTwelve: stylisticSetNumber = 12
        case .stylisticThirteen: stylisticSetNumber = 13
        case .stylisticFourteen: stylisticSetNumber = 14
        case .stylisticFifteen: stylisticSetNumber = 15
        case .stylisticSixteen: stylisticSetNumber = 16
        case .stylisticSeventeen: stylisticSetNumber = 17
        case .stylisticEighteen: stylisticSetNumber = 18
        case .stylisticNineteen: stylisticSetNumber = 19
        case .stylisticTwenty: stylisticSetNumber = 20
        default: return nil
        }

        if #available(iOS 15.0, *) {
            return [
                .type: kStylisticAlternativesType,
                .selector: stylisticSetNumber + kStylisticAltOneOnSelector - 1,
            ]
        } else {
            return [
                .featureIdentifier: kStylisticAlternativesType,
                .typeIdentifier: stylisticSetNumber + kStylisticAltOneOnSelector
                    - 1,
            ]
        }
    }

    private func fontVariantToString(_ variant: FontVariant) -> String {
        switch variant {
        case .smallCaps:
            return "small-caps"
        case .oldstyleNums:
            return "oldstyle-nums"
        case .liningNums:
            return "lining-nums"
        case .tabularNums:
            return "tabular-nums"
        case .proportionalNums:
            return "proportional-nums"
        case .commonLigatures:
            return "common-ligatures"
        case .noCommonLigatures:
            return "no-common-ligatures"
        case .discretionaryLigatures:
            return "discretionary-ligatures"
        case .noDiscretionaryLigatures:
            return "no-discretionary-ligatures"
        case .historicalLigatures:
            return "historical-ligatures"
        case .noHistoricalLigatures:
            return "no-historical-ligatures"
        case .contextual:
            return "contextual"
        case .noContextual:
            return "no-contextual"
        case .stylisticOne:
            return "stylistic-01"
        case .stylisticTwo:
            return "stylistic-02"
        case .stylisticThree:
            return "stylistic-03"
        case .stylisticFour:
            return "stylistic-04"
        case .stylisticFive:
            return "stylistic-05"
        case .stylisticSix:
            return "stylistic-06"
        case .stylisticSeven:
            return "stylistic-07"
        case .stylisticEight:
            return "stylistic-08"
        case .stylisticNine:
            return "stylistic-09"
        case .stylisticTen:
            return "stylistic-10"
        case .stylisticEleven:
            return "stylistic-11"
        case .stylisticTwelve:
            return "stylistic-12"
        case .stylisticThirteen:
            return "stylistic-13"
        case .stylisticFourteen:
            return "stylistic-14"
        case .stylisticFifteen:
            return "stylistic-15"
        case .stylisticSixteen:
            return "stylistic-16"
        case .stylisticSeventeen:
            return "stylistic-17"
        case .stylisticEighteen:
            return "stylistic-18"
        case .stylisticNineteen:
            return "stylistic-19"
        case .stylisticTwenty:
            return "stylistic-20"
        @unknown default:
            return ""
        }
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
        // Keep typingAttributes in sync so decoration persists while typing.
        var typingAttrs: [NSAttributedString.Key: Any] = [:]
        mutableAttributedString.enumerateAttributes(in: fullRange, options: []) { attrs, _, _ in
            for (k, v) in attrs { typingAttrs[k] = v }
        }
        if typingAttrs[.font] == nil { typingAttrs[.font] = self.textView.font }
        if typingAttrs[.foregroundColor] == nil { typingAttrs[.foregroundColor] = self.textView.textColor }
        self.textView.typingAttributes = typingAttrs
    }

    // MARK: - Text Decoration Support (moved to applyTextAttributes)
    // Text decoration is now handled within applyTextAttributes() method

    private func nsUnderlineStyle(from decorationStyle: TextDecorationStyle)
        -> NSUnderlineStyle
    {
        switch decorationStyle {
        case .solid:
            return .single
        case .double:
            return .double
        case .dotted:
            // Need to include a base style (single) + pattern to actually render.
            return [.single, .patternDot]
        case .dashed:
            // Need to include a base style (single) + pattern to actually render.
            return [.single, .patternDash]
        }
    }

    private func resolveTextDecorationColor(_ decorationColor: ProcessedColor)
        -> UIColor?
    {
        return resolveProcessedColor(decorationColor)
    }

    // MARK: - Text Shadow Support
    private func applyTextShadow(
        shadowOffset: TextShadowOffset,
        shadowRadius: Double,
        color: ProcessedColor?
    ) {
        let currentText = self.textView.text ?? ""
        guard !currentText.isEmpty else { return }

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

        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(
            width: shadowOffset.width,
            height: shadowOffset.height
        )
        shadow.shadowBlurRadius = CGFloat(shadowRadius)

        if let shadowColor = color {
            shadow.shadowColor =
                resolveTextShadowColor(shadowColor) ?? UIColor.black
        } else {
            shadow.shadowColor = UIColor.black
        }

        mutableAttributedString.addAttribute(
            .shadow,
            value: shadow,
            range: NSRange(location: 0, length: mutableAttributedString.length)
        )

        self.textView.attributedText = mutableAttributedString
    }

    private func resolveTextShadowColor(_ shadowColor: ProcessedColor)
        -> UIColor?
    {
        return resolveProcessedColor(shadowColor)
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

    // MARK: - Utility Methods for Text Decoration and Shadow (updated)
    // These methods now trigger full text attributes reapplication for consistency
    func reapplyTextDecoration() {
        // Apply only text decoration attributes to current text
        guard let attrs = self.textAttributes,
            let decorationLine = attrs.textDecorationLine,
            decorationLine != .none
        else { return }

        let currentText = self.textView.text ?? ""
        guard !currentText.isEmpty else { return }

        // Get existing attributed text or create new one
        let mutableAttributedString: NSMutableAttributedString
        if let existingAttributedText = self.textView.attributedText {
            mutableAttributedString = NSMutableAttributedString(
                attributedString: existingAttributedText
            )
        } else {
            mutableAttributedString = NSMutableAttributedString(
                string: currentText
            )
            // Ensure basic attributes are preserved
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

        // Remove existing decoration attributes
        mutableAttributedString.removeAttribute(
            .underlineStyle,
            range: fullRange
        )
        mutableAttributedString.removeAttribute(
            .underlineColor,
            range: fullRange
        )
        mutableAttributedString.removeAttribute(
            .strikethroughStyle,
            range: fullRange
        )
        mutableAttributedString.removeAttribute(
            .strikethroughColor,
            range: fullRange
        )

        // Apply new decoration
        if decorationLine == .underline
            || decorationLine == .underlineLineThrough
        {
            let underlineStyle = nsUnderlineStyle(
                from: attrs.textDecorationStyle ?? .solid
            )
            mutableAttributedString.addAttribute(
                .underlineStyle,
                value: underlineStyle.rawValue,
                range: fullRange
            )

            if let decorationColor = attrs.textDecorationColor,
                let resolvedColor = resolveProcessedColor(decorationColor)
            {
                mutableAttributedString.addAttribute(
                    .underlineColor,
                    value: resolvedColor,
                    range: fullRange
                )
            }
        }

        if decorationLine == .lineThrough
            || decorationLine == .underlineLineThrough
        {
            let strikethroughStyle = nsUnderlineStyle(
                from: attrs.textDecorationStyle ?? .solid
            )
            mutableAttributedString.addAttribute(
                .strikethroughStyle,
                value: strikethroughStyle.rawValue,
                range: fullRange
            )

            if let decorationColor = attrs.textDecorationColor,
                let resolvedColor = resolveProcessedColor(decorationColor)
            {
                mutableAttributedString.addAttribute(
                    .strikethroughColor,
                    value: resolvedColor,
                    range: fullRange
                )
            }
        }

        self.textView.attributedText = mutableAttributedString
    }

    func reapplyTextShadow() {
        // Apply only text shadow attributes to current text
        guard let attrs = self.textAttributes,
            let shadowOffset = attrs.textShadowOffset,
            let shadowRadius = attrs.textShadowRadius,
            shadowRadius > 0
        else { return }

        let currentText = self.textView.text ?? ""
        guard !currentText.isEmpty else { return }

        // Get existing attributed text or create new one
        let mutableAttributedString: NSMutableAttributedString
        if let existingAttributedText = self.textView.attributedText {
            mutableAttributedString = NSMutableAttributedString(
                attributedString: existingAttributedText
            )
        } else {
            mutableAttributedString = NSMutableAttributedString(
                string: currentText
            )
            // Ensure basic attributes are preserved
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

        // Remove existing shadow
        mutableAttributedString.removeAttribute(.shadow, range: fullRange)

        // Apply new shadow
        let shadow = NSShadow()
        shadow.shadowOffset = CGSize(
            width: shadowOffset.width,
            height: shadowOffset.height
        )
        shadow.shadowBlurRadius = CGFloat(shadowRadius)

        if let shadowColor = attrs.textShadowColor,
            let resolvedColor = resolveProcessedColor(shadowColor)
        {
            shadow.shadowColor = resolvedColor
        }

        mutableAttributedString.addAttribute(
            .shadow,
            value: shadow,
            range: fullRange
        )
        self.textView.attributedText = mutableAttributedString
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
            - textView.textContainerInset.right
            - 2.0 * textView.textContainer.lineFragmentPadding

        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(
                width: textWidth,
                height: CGFloat.greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: textView.font ?? UIFont.systemFont(ofSize: 17)],
            context: nil
        )

        // Prefer explicit textAttributes.lineHeight if set (and >= font lineHeight), else font lineHeight
        let explicit = self.textAttributes?.lineHeight.flatMap { $0 > 0 ? CGFloat($0) : nil }
        let fontLine = textView.font?.lineHeight ?? 17
        let lineHeight = max(explicit ?? fontLine, fontLine)
        let numberOfLines = Int(ceil(boundingRect.height / lineHeight))

        return max(numberOfLines, 1)
    }
}
