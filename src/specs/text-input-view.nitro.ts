// TODO: Export specs that extend HybridObject<...> here
import type {
	HybridView,
	HybridViewMethods,
	HybridViewProps,
} from "react-native-nitro-modules";

export type AutoCapitalize = "none" | "sentences" | "words" | "characters";
export type AutoComplete =
	| "url"
	| "name-prefix"
	| "name"
	| "name-suffix"
	| "given-name"
	| "middle-name"
	| "family-name"
	| "nickname"
	| "organization-name"
	| "job-title"
	| "location"
	| "full-street-address"
	| "street-address-line1"
	| "street-address-line2"
	| "address-city"
	| "address-city-and-state"
	| "address-state"
	| "postal-code"
	| "sublocality"
	| "country-name"
	| "username"
	| "password"
	| "new-password"
	| "one-time-code"
	| "email-address"
	| "telephone-number"
	| "cellular-eid"
	| "cellular-imei"
	| "credit-card-number"
	| "credit-card-expiration"
	| "credit-card-expiration-month"
	| "credit-card-expiration-year"
	| "credit-card-security-code"
	| "credit-card-type"
	| "credit-card-name"
	| "credit-card-given-name"
	| "credit-card-middle-name"
	| "credit-card-family-name"
	| "birthdate"
	| "birthdate-day"
	| "birthdate-month"
	| "birthdate-year"
	| "date-time"
	| "flight-number"
	| "shipment-tracking-number";

export type ClearButtonMode =
	| "never"
	| "while-editing"
	| "unless-editing"
	| "always";

export type ReturnKeyType =
	| "go"
	| "google"
	| "join"
	| "next"
	| "route"
	| "search"
	| "send"
	| "yahoo"
	| "done"
	| "emergency-call"
	| "continue";

export type KeyboardType =
	| "default"
	| "ascii-capable"
	| "numbers-and-punctuation"
	| "url"
	| "number-pad"
	| "phone-pad"
	| "name-phone-pad"
	| "email-address"
	| "decimal-pad"
	| "twitter"
	| "web-search"
	| "ascii-capable-number-pad";

export type KeyboardAppearance = "default" | "light" | "dark";

export type MaxFontMultiplier = number | null | undefined;

export type SubmitBehavior = "submit" | "blurAndSubmit" | "newline";

export type TextAlign = "left" | "center" | "right" | "natural";

// A processed color (AARRGGBB) or JSON-stringified OpaqueColor (semantic/dynamic)
export type ProcessedColor = number | string | null | undefined;

// (kept simple per RN API shape)

export interface TextSelection {
	start: number;
	end: number;
}

export interface NitroTextInputViewProps extends HybridViewProps {
	allowFontScaling?: boolean;
	autoCapitalize?: AutoCapitalize;
	autoComplete?: AutoComplete;
	autoCorrect?: boolean;
	autoFocus?: boolean;
	caretHidden?: boolean;
	clearButtonMode?: ClearButtonMode;
	clearTextOnFocus?: boolean;
	contextMenuHidden?: boolean;
	defaultValue?: string;
	editable?: boolean;
	enablesReturnKeyAutomatically?: boolean;
	keyboardType?: KeyboardType;
	keyboardAppearance?: KeyboardAppearance;
	maxFontSizeMultiplier?: MaxFontMultiplier;
	maxLength?: number;
	multiline?: boolean;
	passwordRules?: string | null;
	placeholder?: string;
	textAlign?: TextAlign;
	placeholderTextColor?: ProcessedColor;
	returnKeyType?: ReturnKeyType;
	selection?: TextSelection;
	selectionColor?: ProcessedColor;
	secureTextEntry?: boolean;
	spellCheck?: boolean;
	selectTextOnFocus?: boolean;
	showSoftInputOnFocus?: boolean;
	smartInsertDelete?: boolean;
	submitBehavior?: SubmitBehavior;
	onFocused?: () => void;
	onBlurred?: () => void;
	onTextChanged?: (text: string) => void;
	onEditingEnded?: (text: string) => void;
	onEditingSubmitted?: (text: string) => void;
	onSelectionChanged?: (start: number, end: number) => void;
	onKeyPressed?: (key: string) => void;
	onTouchBegan?: (
		pageX: number,
		pageY: number,
		locationX: number,
		locationY: number,
		timestamp: number,
	) => void;
	onTouchEnded?: (
		pageX: number,
		pageY: number,
		locationX: number,
		locationY: number,
		timestamp: number,
	) => void;
	/**
	 * Called once when the initial height has been measured (pt).
	 */
	onInitialHeightMeasured?: (height: number) => void;
}

export interface NitroTextInputViewMethods extends HybridViewMethods {
	focus(): void;
	blur(): void;
	clear(): void;
	isFocused(): boolean;
}

export type NitroTextInputView = HybridView<
	NitroTextInputViewProps,
	NitroTextInputViewMethods
>;
