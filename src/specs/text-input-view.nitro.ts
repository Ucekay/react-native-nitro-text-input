// TODO: Export specs that extend HybridObject<...> here
import type {
  HybridView,
  HybridViewMethods,
  HybridViewProps,
} from 'react-native-nitro-modules'

export type AutoCapitalize = 'none' | 'sentences' | 'words' | 'characters'

export interface NitroTextInputViewProps extends HybridViewProps {
  allowFontScaling?: boolean
  autoCapitalize?: AutoCapitalize
  autoCorrect?: boolean
  multiline?: boolean
  placeholder?: string
  /**
   * Called once when the initial height has been measured (pt).
   */
  onInitialHeightMeasured?: (height: number) => void
}

export interface NitroTextInputViewMethods extends HybridViewMethods {}

export type NitroTextInputView = HybridView<
  NitroTextInputViewProps,
  NitroTextInputViewMethods
>
