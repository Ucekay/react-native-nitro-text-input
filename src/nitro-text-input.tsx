// biome-ignore lint/correctness/noUnusedImports: Needed for JSX runtime
import React from 'react'
import type { HostComponent } from 'react-native'
import { NativeNitroTextInput } from './native-nitro-text-input'

type ReactProps<T> = T extends HostComponent<infer P> ? P : never
type NativeTextInputProps = ReactProps<typeof NativeNitroTextInput>
export interface NitroTextInputProps
  extends Omit<NativeTextInputProps, 'onInitialHeightMeasured'> {}

export function NitroTextInput(props: NitroTextInputProps) {
  return <NativeNitroTextInput {...props} />
}
