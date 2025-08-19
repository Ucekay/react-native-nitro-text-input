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
