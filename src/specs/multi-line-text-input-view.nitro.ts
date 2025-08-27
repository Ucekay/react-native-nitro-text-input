import type { FontVariant } from "react-native";
import type {
	HybridView,
	HybridViewMethods,
	HybridViewProps,
} from "react-native-nitro-modules";

// Re-use types from the existing text-input-view spec
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

type FontStyle = string;
type FontWeight = string | number;

export type ReturnKeyType =
	| "default"
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

export type LineBreakStrategyIOS = 'none' | 'standard' | 'hangul-word' | 'push-out'

export type LineBreakModeIOS = 'wordWrapping' | 'char' | 'clip' | 'head' | 'middle' | 'tail'

export type MaxFontMultiplier = number | null | undefined;

// A processed color (AARRGGBB) or JSON-stringified OpaqueColor (semantic/dynamic)
export type ProcessedColor = number | string | null | undefined;

export type SubmitBehavior = "submit" | "blurAndSubmit" | "newline";

export type TextAlign = "left" | "center" | "right" | "natural";

type TextAlignAttributes = "auto" | "left" | "right" | "center" | "justify";

type TextDecorationLine =
	| "none"
	| "underline"
	| "line-through"
	| "underline line-through";

type TextDecorationStyle = "solid" | "double" | "dotted" | "dashed";

export interface TextSelection {
	start: number;
	end: number;
}

type TextShadowOffset = {
	width: number;
	height: number;
};

type TextTransform = "none" | "capitalize" | "uppercase" | "lowercase";

type WritingDirection = "auto" | "ltr" | "rtl";

type UserSelect = "auto" | "text" | "none" | "contain" | "all";

export interface TextAttributes {
	color?: ProcessedColor;
	fontSize?: number;
	fontStyle?: FontStyle;
	fontWeight?: FontWeight;
	fontVariant?: FontVariant[];
	letterSpacing?: number;
	lineBreakStrategyIOS?: LineBreakStrategyIOS;
	lineBreakModeIOS?: LineBreakModeIOS;
	lineHeight?: number;
	textAlign?: TextAlignAttributes;
	textDecorationColor?: ProcessedColor;
	textDecorationLine?: TextDecorationLine;
	textDecorationStyle?: TextDecorationStyle;
	textShadowColor?: ProcessedColor;
	textShadowOffset?: TextShadowOffset;
	textShadowRadius?: number;
	textTransform?: TextTransform;
	writingDirection?: WritingDirection;
	userSelect?: UserSelect;
}

export interface NitroMultiLineTextInputViewProps extends HybridViewProps {
	allowFontScaling?: boolean;
	autoCapitalize?: AutoCapitalize;
	autoComplete?: AutoComplete;
	autoCorrect?: boolean;
	autoFocus?: boolean;
	contextMenuHidden?: boolean;
	defaultValue?: string;
	editable?: boolean;
	enablesReturnKeyAutomatically?: boolean;
	keyboardType?: KeyboardType;
	keyboardAppearance?: KeyboardAppearance;
	maxFontSizeMultiplier?: MaxFontMultiplier;
	maxLength?: number;
	numberOfLines?: number;
	passwordRules?: string | null;
	placeholder?: string;
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
	textAlign?: TextAlign;
	scrollEnabled?: boolean;
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
	/**
	 * Called when the content size of the text view changes (for multi-line).
	 */
	onContentSizeChanged?: (width: number, height: number) => void;

	textAttributes?: TextAttributes;
}

export interface NitroMultiLineTextInputViewMethods extends HybridViewMethods {
	focus(): void;
	blur(): void;
	clear(): void;
	isFocused(): boolean;
}

export type NitroMultiLineTextInputView = HybridView<
	NitroMultiLineTextInputViewProps,
	NitroMultiLineTextInputViewMethods
>;
