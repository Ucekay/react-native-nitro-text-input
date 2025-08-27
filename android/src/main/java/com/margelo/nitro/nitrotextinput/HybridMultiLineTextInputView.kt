package com.margelo.nitro.nitrotextinput

import android.text.InputType
import android.util.TypedValue
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import com.facebook.react.uimanager.ThemedReactContext

class HybridMultiLineTextInputView(private val reactContext: ThemedReactContext) :
        HybridNitroMultiLineTextInputViewSpec() {

  // Backing Android View - Custom EditText for multi-line support
  private val editText: EditText =
          EditText(reactContext).apply {
            // Configure for multi-line input
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            isSingleLine = false
            maxLines = Int.MAX_VALUE
            setHorizontallyScrolling(false)

            // Set default properties
            setBackgroundResource(android.R.color.transparent)
            setPadding(0, 0, 0, 0)
          }

  override val view: View = editText

  // Property implementations
  override var allowFontScaling: Boolean? = null
  override var autoCapitalize: AutoCapitalize? = null
  override var autoComplete: AutoComplete? = null
  override var autoCorrect: Boolean? = null
  override var autoFocus: Boolean? = null
  override var contextMenuHidden: Boolean? = null
  override var defaultValue: String? = null
  override var editable: Boolean? = null
  override var enablesReturnKeyAutomatically: Boolean? = null
  override var keyboardType: KeyboardType? = null
  override var keyboardAppearance: KeyboardAppearance? = null
  override var maxFontSizeMultiplier: Double? = null
  override var maxLength: Double? = null

  override var numberOfLines: Double? = null
    set(value) {
      field = value
      updateNumberOfLines()
    }

  override var passwordRules: String? = null
  override var placeholder: String? = null
  override var placeholderTextColor: ProcessedColor? = null
  override var returnKeyType: ReturnKeyType? = null
  override var selection: TextSelection? = null
  override var selectionColor: ProcessedColor? = null
  override var secureTextEntry: Boolean? = null
  override var spellCheck: Boolean? = null
  override var selectTextOnFocus: Boolean? = null
  override var showSoftInputOnFocus: Boolean? = null
  override var smartInsertDelete: Boolean? = null
  override var submitBehavior: SubmitBehavior? = null
  override var textAlign: TextAlign? = null
  override var scrollEnabled: Boolean? = null
  override var textAttributes: TextAttributes? = null

  // Event callbacks
  override var onFocused: (() -> Unit)? = null
  override var onBlurred: (() -> Unit)? = null
  override var onTextChanged: ((text: String) -> Unit)? = null
  override var onEditingEnded: ((text: String) -> Unit)? = null
  override var onEditingSubmitted: ((text: String) -> Unit)? = null
  override var onSelectionChanged: ((start: Double, end: Double) -> Unit)? = null
  override var onKeyPressed: ((key: String) -> Unit)? = null
  override var onTouchBegan:
          ((
                  pageX: Double,
                  pageY: Double,
                  locationX: Double,
                  locationY: Double,
                  timestamp: Double) -> Unit)? =
          null
  override var onTouchEnded:
          ((
                  pageX: Double,
                  pageY: Double,
                  locationX: Double,
                  locationY: Double,
                  timestamp: Double) -> Unit)? =
          null
  override var onInitialHeightMeasured: ((height: Double) -> Unit)? = null
  override var onContentSizeChanged: ((width: Double, height: Double) -> Unit)? = null

  init {
    setupEditText()
  }

  private fun setupEditText() {
    // Set up text change listeners
    editText.setOnFocusChangeListener { _, hasFocus ->
      if (hasFocus) {
        onFocused?.invoke()
      } else {
        onBlurred?.invoke()
        onEditingEnded?.invoke(editText.text.toString())
      }
    }

    // Handle IME actions
    editText.setOnEditorActionListener { _, actionId, _ ->
      when (actionId) {
        EditorInfo.IME_ACTION_DONE, EditorInfo.IME_ACTION_SEND, EditorInfo.IME_ACTION_GO -> {
          onEditingSubmitted?.invoke(editText.text.toString())
          true
        }
        else -> false
      }
    }
  }

  private fun updateNumberOfLines() {
    val lines = numberOfLines
    if (lines != null && lines > 0) {
      val maxLines = lines.toInt()
      editText.maxLines = maxLines
      editText.setLines(maxLines)

      // Enable scrolling when content exceeds the line limit
      editText.isVerticalScrollBarEnabled = true
      editText.movementMethod = android.text.method.ScrollingMovementMethod()
    } else {
      // No line limit - allow unlimited lines
      editText.maxLines = Int.MAX_VALUE
      editText.minLines = 1
    }

    // Request layout update
    editText.requestLayout()

    // Notify content size change
    editText.post {
      val density = reactContext.resources.displayMetrics.density
      val widthPx = editText.width
      val heightPx = editText.height
      onContentSizeChanged?.invoke((widthPx / density).toDouble(), (heightPx / density).toDouble())
    }
  }

  // Method implementations
  override fun focus() {
    editText.requestFocus()
  }

  override fun blur() {
    editText.clearFocus()
  }

  override fun clear() {
    editText.setText("")
  }

  override fun isFocused(): Boolean {
    return editText.isFocused
  }

  // Helper method to convert dp to pixels
  private fun dpToPx(dp: Float): Int {
    return TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP,
                    dp,
                    reactContext.resources.displayMetrics
            )
            .toInt()
  }
}
