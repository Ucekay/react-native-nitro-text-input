package com.margelo.nitro.nitrotextinput

import android.view.View
import com.facebook.react.uimanager.ThemedReactContext

class HybridTextInputView(private val reactContext: ThemedReactContext) :
        HybridNitroTextInputViewSpec() {
  // Props (temporary placeholder)
  var autoCorrect: Boolean = false

  // Backing Android View
  override val view: View = View(reactContext)
}
