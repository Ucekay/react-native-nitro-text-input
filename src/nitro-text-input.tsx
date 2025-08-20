// biome-ignore lint/correctness/noUnusedImports: Needed for JSX runtime
import React from 'react'
import type { HostComponent, InputModeOptions } from 'react-native'
import { Platform, StyleSheet } from 'react-native'
import { NativeNitroTextInput } from './native-nitro-text-input'

type ReactProps<T> = T extends HostComponent<infer P> ? P : never
type NativeTextInputProps = ReactProps<typeof NativeNitroTextInput>
export interface NitroTextInputProps
  extends Omit<
    NativeTextInputProps,
    'onInitialHeightMeasured' | 'onBlurred' | 'onTextChanged'
  > {
  inputMode?: InputModeOptions
  onBlur?: () => void
  onChangeText?: (text: string) => void
}

export function NitroTextInput(props: NitroTextInputProps) {
  const [measuredInitialHeight, setMeasuredInitialHeight] = React.useState<
    number | undefined
  >(undefined)

  const { style, keyboardType, inputMode, onBlur, onChangeText, ...others } =
    props

  const flattenedStyle = StyleSheet.flatten(style) ?? {}

  const hasExplicitHeight = flattenedStyle?.height != null

  // Map inputMode to keyboardType
  const getKeyboardTypeFromInputMode = () => {
    if (!inputMode) return keyboardType

    switch (inputMode) {
      case 'text':
        return 'default'
      case 'decimal':
        return 'decimal-pad'
      case 'numeric':
        return 'number-pad'
      case 'tel':
        return 'phone-pad'
      case 'search':
        return Platform.OS === 'ios' ? 'web-search' : 'default'
      case 'email':
        return 'email-address'
      case 'url':
        return 'url'
      case 'none':
        return keyboardType // Keep original keyboardType for 'none'
      default:
        return keyboardType
    }
  }

  // Handle showSoftInputOnFocus for inputMode 'none'
  // const shouldShowSoftInput =
  //   props.inputMode === 'none' ? false : props.showSoftInputOnFocus

  const composedStyle = () => {
    if (!hasExplicitHeight && measuredInitialHeight != null) {
      return [
        // Preserve original user-provided style(s)
        style,
        // Apply measured height only when height isn't explicitly set
        { height: measuredInitialHeight, width: '100%' as const },
      ]
    }
    return [style, { width: '100%' as const }]
  }

  const handleInitialHeightMeasured = (height: number) => {
    setMeasuredInitialHeight(height)
  }

  return (
    <NativeNitroTextInput
      {...others}
      keyboardType={getKeyboardTypeFromInputMode()}
      onBlurred={{ f: onBlur }}
      onTextChanged={{ f: onChangeText }}
      onInitialHeightMeasured={{ f: handleInitialHeightMeasured }}
      style={composedStyle()}
    />
  )
}
