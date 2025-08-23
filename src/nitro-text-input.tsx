// biome-ignore lint/correctness/noUnusedImports: Needed for JSX runtime
import React from 'react'
import type {
  HostComponent,
  InputModeOptions,
  TextInputProps,
} from 'react-native'
import { Platform, processColor, StyleSheet } from 'react-native'
import { NativeNitroTextInput } from './native-nitro-text-input'

type ReactProps<T> = T extends HostComponent<infer P> ? P : never
type NativeTextInputProps = ReactProps<typeof NativeNitroTextInput>
export interface NitroTextInputProps
  extends Omit<
    NativeTextInputProps,
    | 'onInitialHeightMeasured'
    | 'onBlurred'
    | 'onTextChanged'
    | 'onEditingEnded'
    | 'onEditingSubmitted'
    | 'onTauchBegan'
    | 'onTouchEnded'
    | 'onSelectionChanged'
    | 'onFocused'
    | 'onKeyPressed'
    | 'placeholderTextColor'
  > {
  inputMode?: InputModeOptions
  onBlur?: () => void
  onChangeText?: (text: string) => void
  onEndEditing?: (text: string) => void
  onSubmitEditing?: (text: string) => void
  onSelectionChange?: (selection: { start: number; end: number }) => void
  onPressIn?: (
    pageX: number,
    pageY: number,
    locationX: number,
    locationY: number,
    timestamp: number
  ) => void
  onPressOut?: (
    pageX: number,
    pageY: number,
    locationX: number,
    locationY: number,
    timestamp: number
  ) => void
  onFocus?: () => void
  onKeyPress?: (key: string) => void
  placeholderTextColor?: TextInputProps['placeholderTextColor'] | undefined
}

export function NitroTextInput(props: NitroTextInputProps) {
  const [measuredInitialHeight, setMeasuredInitialHeight] = React.useState<
    number | undefined
  >(undefined)

  const {
    style,
    keyboardType,
    inputMode,
    onBlur,
    onChangeText,
    onEndEditing,
    onSubmitEditing,
    onSelectionChange,
    onPressIn,
    onPressOut,
    onFocus,
    onKeyPress,
    placeholderTextColor,
    ...others
  } = props

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
      placeholderTextColor={(() => {
        const processed = processColor(placeholderTextColor ?? undefined)
        if (processed == null) return undefined
        return typeof processed === 'number'
          ? processed
          : JSON.stringify(processed)
      })()}
      keyboardType={getKeyboardTypeFromInputMode()}
      onBlurred={{ f: onBlur }}
      onTextChanged={{ f: onChangeText }}
      onEditingEnded={{ f: onEndEditing }}
      onEditingSubmitted={{ f: onSubmitEditing }}
      onSelectionChanged={{
        f: (start, end) => onSelectionChange?.({ start, end }),
      }}
      onTouchBegan={{ f: onPressIn }}
      onTouchEnded={{ f: onPressOut }}
      onFocused={{ f: onFocus }}
      onKeyPressed={{ f: onKeyPress }}
      onInitialHeightMeasured={{ f: handleInitialHeightMeasured }}
      style={composedStyle()}
    />
  )
}
