// biome-ignore lint/correctness/noUnusedImports: Needed for JSX runtime
import React from 'react'
import type { HostComponent } from 'react-native'
import { StyleSheet } from 'react-native'
import { NativeNitroTextInput } from './native-nitro-text-input'

type ReactProps<T> = T extends HostComponent<infer P> ? P : never
type NativeTextInputProps = ReactProps<typeof NativeNitroTextInput>
export interface NitroTextInputProps
  extends Omit<NativeTextInputProps, 'onInitialHeightMeasured'> {}

export function NitroTextInput(props: NitroTextInputProps) {
  const [measuredInitialHeight, setMeasuredInitialHeight] = React.useState<
    number | undefined
  >(undefined)

  const flattenedStyle = React.useMemo(() => {
    // `style` can be an object or an array; flatten to inspect height
    return StyleSheet.flatten((props as any).style) ?? {}
  }, [props])

  const hasExplicitHeight = flattenedStyle?.height != null

  const composedStyle = React.useMemo(() => {
    if (!hasExplicitHeight && measuredInitialHeight != null) {
      return [
        // Preserve original user-provided style(s)
        (props as any).style,
        // Apply measured height only when height isn't explicitly set
        { height: measuredInitialHeight },
      ]
    }
    return (props as any).style
  }, [hasExplicitHeight, measuredInitialHeight, props])

  const handleInitialHeightMeasured = React.useCallback((height: number) => {
    setMeasuredInitialHeight(height)
  }, [])

  return (
    <NativeNitroTextInput
      {...(props as any)}
      style={composedStyle}
      onInitialHeightMeasured={handleInitialHeightMeasured}
    />
  )
}
