// biome-ignore lint/correctness/noUnusedImports: Needed for JSX runtime
import React from 'react'
import type { HostComponent, InputModeOptions } from 'react-native'
import { Platform, StyleSheet } from 'react-native'
import { NativeNitroTextInput } from './native-nitro-text-input'

type ReactProps<T> = T extends HostComponent<infer P> ? P : never
type NativeTextInputProps = ReactProps<typeof NativeNitroTextInput>
export interface NitroTextInputProps
  extends Omit<NativeTextInputProps, 'onInitialHeightMeasured'> {
  inputMode?: InputModeOptions
}

export function NitroTextInput(props: NitroTextInputProps) {
  const [measuredInitialHeight, setMeasuredInitialHeight] = React.useState<
    number | undefined
  >(undefined)

  const flattenedStyle = StyleSheet.flatten(props.style) ?? {}

  const hasExplicitHeight = flattenedStyle?.height != null

  // Map inputMode to keyboardType
  const getKeyboardTypeFromInputMode = () => {
    if (!props.inputMode) return props.keyboardType

    switch (props.inputMode) {
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
        return props.keyboardType // Keep original keyboardType for 'none'
      default:
        return props.keyboardType
    }
  }

  // Handle showSoftInputOnFocus for inputMode 'none'
  // const shouldShowSoftInput =
  //   props.inputMode === 'none' ? false : props.showSoftInputOnFocus

  const composedStyle = () => {
    if (!hasExplicitHeight && measuredInitialHeight != null) {
      return [
        // Preserve original user-provided style(s)
        props.style,
        // Apply measured height only when height isn't explicitly set
        { height: measuredInitialHeight, width: '100%' as const },
      ]
    }
    return [props.style, { width: '100%' as const }]
  }

  const handleInitialHeightMeasured = (height: number) => {
    setMeasuredInitialHeight(height)
  }

  return (
    <NativeNitroTextInput
      {...props}
      style={composedStyle()}
      keyboardType={getKeyboardTypeFromInputMode()}
      onInitialHeightMeasured={{ f: handleInitialHeightMeasured }}
    />
  )
}
