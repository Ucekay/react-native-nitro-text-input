// TODO: Export specs that extend HybridObject<...> here
import type {
  HybridView,
  HybridViewMethods,
  HybridViewProps,
} from 'react-native-nitro-modules'

export type AutoCapitalize = 'none' | 'sentences' | 'words' | 'characters'
export type AutoComplete =
  | 'url'
  | 'name-prefix'
  | 'name'
  | 'name-suffix'
  | 'given-name'
  | 'middle-name'
  | 'family-name'
  | 'nickname'
  | 'organization-name'
  | 'job-title'
  | 'location'
  | 'full-street-address'
  | 'street-address-line1'
  | 'street-address-line2'
  | 'address-city'
  | 'address-city-and-state'
  | 'address-state'
  | 'postal-code'
  | 'sublocality'
  | 'country-name'
  | 'username'
  | 'password'
  | 'new-password'
  | 'one-time-code'
  | 'email-address'
  | 'telephone-number'
  | 'cellular-eid'
  | 'cellular-imei'
  | 'credit-card-number'
  | 'credit-card-expiration'
  | 'credit-card-expiration-month'
  | 'credit-card-expiration-year'
  | 'credit-card-security-code'
  | 'credit-card-type'
  | 'credit-card-name'
  | 'credit-card-given-name'
  | 'credit-card-middle-name'
  | 'credit-card-family-name'
  | 'birthdate'
  | 'birthdate-day'
  | 'birthdate-month'
  | 'birthdate-year'
  | 'date-time'
  | 'flight-number'
  | 'shipment-tracking-number'

export type ClearButtonMode =
  | 'never'
  | 'while-editing'
  | 'unless-editing'
  | 'always'

export interface NitroTextInputViewProps extends HybridViewProps {
  allowFontScaling?: boolean
  autoCapitalize?: AutoCapitalize
  autoComplete?: AutoComplete
  autoCorrect?: boolean
  autoFocus?: boolean
  caretHidden?: boolean
  clearButtonMode?: ClearButtonMode
  clearTextOnFocus?: boolean
  contextMenuHidden?: boolean
  /**
   * Provides an initial value that will change when the user starts typing. Useful for simple use-cases where you don’t want to deal with listening to events and updating the value prop to keep the controlled state in sync.
   *
   * 注意: NitroTextInput の `defaultValue` は「初期化時にのみ」反映されます。マウント後にこの props を更新しても、既に表示中のテキストは上書きされません。
   * - 初回マウント時、フィールドが空の場合に初期値として適用されます。
   * - ユーザー入力などでテキストが既に存在する場合は上書きしません。
   */
  defaultValue?: string
  editable?: boolean
  enablesReturnKeyAutomatically?: boolean
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
