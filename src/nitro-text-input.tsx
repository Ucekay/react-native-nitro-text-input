import React from "react";
import type {
	InputModeOptions,
	ReturnKeyTypeAndroid,
	TextInputProps,
	TextStyle,
	ViewProps,
} from "react-native";
import { Platform, processColor, StyleSheet } from "react-native";
import type { HybridView } from "react-native-nitro-modules";
import type {
	DefaultHybridViewProps,
	WrapFunctionsInObjects,
} from "react-native-nitro-modules/src";
import { NativeNitroMultiLineTextInput } from "./native-nitro-multi-line-text-input";
import { NativeNitroTextInput } from "./native-nitro-text-input";
import type { NitroMultiLineTextInputViewProps } from "./specs/multi-line-text-input-view.nitro";
import type {
	NitroTextInputViewMethods,
	NitroTextInputViewProps,
	ReturnKeyType,
	TextAttributes,
} from "./specs/text-input-view.nitro";

type NativeSingleLineTextInputProps = WrapFunctionsInObjects<
	DefaultHybridViewProps<
		HybridView<NitroTextInputViewProps, NitroTextInputViewMethods>
	> &
	NitroTextInputViewProps
> &
	ViewProps;

type NativeMultiLineTextInputProps = WrapFunctionsInObjects<
	DefaultHybridViewProps<
		HybridView<NitroMultiLineTextInputViewProps, NitroTextInputViewMethods>
	> &
	NitroMultiLineTextInputViewProps
> &
	ViewProps & {
		onContentSizeChange?: (width: number, height: number) => void;
		scrollEnabled?: boolean;
	}

// Base props interface (without ref)



export interface NitroTextInputSingleLineProps
	extends Omit<
		NativeSingleLineTextInputProps,
		| "onInitialHeightMeasured"
		| "onBlurred"
		| "onEditingEnded"
		| "onEditingSubmitted"
		| "onFocused"
		| "onKeyPressed"
		| "onSelectionChanged"
		| "onTouchBegan"
		| "onTouchEnded"
		| "onTextChanged"
		| "placeholderTextColor"
		| "returnKeyType"
		| "selectionColor"
		| "style"
		| "hybridRef"
	> {
	multiline?: false;
	enterKeyHint?: "done" | "next" | "search" | "send" | "go" | "enter";
	inputMode?: InputModeOptions;
	onBlur?: () => void;
	onChangeText?: (text: string) => void;
	onEndEditing?: (text: string) => void;
	onSubmitEditing?: (text: string) => void;
	onSelectionChange?: (selection: { start: number; end: number }) => void;
	onPressIn?: (
		pageX: number,
		pageY: number,
		locationX: number,
		locationY: number,
		timestamp: number,
	) => void;
	onPressOut?: (
		pageX: number,
		pageY: number,
		locationX: number,
		locationY: number,
		timestamp: number,
	) => void;
	onFocus?: () => void;
	onKeyPress?: (key: string) => void;
	placeholderTextColor?: TextInputProps["placeholderTextColor"] | undefined;
	ref?: React.RefObject<NitroTextInputViewMethods | null>;
	returnKeyType?: Exclude<
		TextInputProps["returnKeyType"],
		ReturnKeyTypeAndroid
	>;
	selectionColor?: TextInputProps["selectionColor"] | undefined;
	style?: TextInputProps["style"];
}

export interface NitroTextInputMultiLineProps
	extends Omit<
		NativeMultiLineTextInputProps,
		| "onInitialHeightMeasured"
		| "onBlurred"
		| "onContentSizeChanged"
		| "onEditingEnded"
		| "onEditingSubmitted"
		| "onFocused"
		| "onKeyPressed"
		| "onSelectionChanged"
		| "onTouchBegan"
		| "onTouchEnded"
		| "onTextChanged"
		| "placeholderTextColor"
		| "returnKeyType"
		| "selectionColor"
		| "style"
		| "hybridRef"
	> {
	multiline: true;
	onContentSizeChange?: (width: number, height: number) => void;
	scrollEnabled?: boolean;
	enterKeyHint?: "done" | "next" | "search" | "send" | "go" | "enter";
	inputMode?: InputModeOptions;
	onBlur?: () => void;
	onChangeText?: (text: string) => void;
	onEndEditing?: (text: string) => void;
	onSubmitEditing?: (text: string) => void;
	onSelectionChange?: (selection: { start: number; end: number }) => void;
	onPressIn?: (
		pageX: number,
		pageY: number,
		locationX: number,
		locationY: number,
		timestamp: number,
	) => void;
	onPressOut?: (
		pageX: number,
		pageY: number,
		locationX: number,
		locationY: number,
		timestamp: number,
	) => void;
	onFocus?: () => void;
	onKeyPress?: (key: string) => void;
	placeholderTextColor?: TextInputProps["placeholderTextColor"] | undefined;
	ref?: React.RefObject<NitroTextInputViewMethods | null>;
	returnKeyType?: Exclude<
		TextInputProps["returnKeyType"],
		ReturnKeyTypeAndroid
	>;
	selectionColor?: TextInputProps["selectionColor"] | undefined;
	style?: TextInputProps["style"];
}

export type NitroTextInputBaseProps = NitroTextInputSingleLineProps | NitroTextInputMultiLineProps;

// Function overloads for type safety
export function NitroTextInput(inputProps: NitroTextInputMultiLineProps): React.JSX.Element;
export function NitroTextInput(inputProps: NitroTextInputSingleLineProps): React.JSX.Element;
export function NitroTextInput(inputProps: NitroTextInputBaseProps): React.JSX.Element;
export function NitroTextInput(inputProps: NitroTextInputBaseProps) {
	const { ref: propsRef, ...props } = inputProps;

	const [measuredInitialHeight, setMeasuredInitialHeight] = React.useState<
		number | undefined
	>(undefined);

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
		enterKeyHint,
		returnKeyType,
		selectionColor,
		showSoftInputOnFocus = true,
		...others
	} = props;

	const flattenedStyle = StyleSheet.flatten(style) ?? {};

	const hasExplicitHeight = flattenedStyle?.height != null;

	// Extract text attributes from style
	const extractTextAttributes = (styleObj: TextStyle): TextAttributes | undefined => {
		if (!styleObj) return undefined;

		const textAttributes: TextAttributes = {};
		let hasTextAttributes = false;

		// Text decoration line
		if (styleObj.textDecorationLine) {
			textAttributes.textDecorationLine = styleObj.textDecorationLine;
			hasTextAttributes = true;
		}

		// Text decoration style
		if (styleObj.textDecorationStyle) {
			textAttributes.textDecorationStyle = styleObj.textDecorationStyle;
			hasTextAttributes = true;
		}

		// Text decoration color
		if (styleObj.textDecorationColor) {
			const processed = processColor(styleObj.textDecorationColor);
			if (processed != null) {
				textAttributes.textDecorationColor =
					typeof processed === "number" ? processed : JSON.stringify(processed);
				hasTextAttributes = true;
			}
		}

		// Font properties
		if (styleObj.fontSize && typeof styleObj.fontSize === "number") {
			textAttributes.fontSize = styleObj.fontSize;
			hasTextAttributes = true;
		}

		if (styleObj.fontWeight) {
			textAttributes.fontWeight = styleObj.fontWeight;
			hasTextAttributes = true;
		}

		if (styleObj.fontStyle) {
			textAttributes.fontStyle = styleObj.fontStyle;
			hasTextAttributes = true;
		}

		if (styleObj.letterSpacing && typeof styleObj.letterSpacing === "number") {
			textAttributes.letterSpacing = styleObj.letterSpacing;
			hasTextAttributes = true;
		}

		if (styleObj.lineHeight && typeof styleObj.lineHeight === "number") {
			textAttributes.lineHeight = styleObj.lineHeight;
			hasTextAttributes = true;
		}

		// Text align
		if (styleObj.textAlign) {
			// Map React Native textAlign values to TextAlignAttributes
			const mapTextAlign = (
				align: string,
			): "auto" | "left" | "right" | "center" | "justify" | undefined => {
				switch (align) {
					case "left":
						return "left";
					case "right":
						return "right";
					case "center":
						return "center";
					case "justify":
						return "justify";
					case "auto":
						return "auto";
					default:
						return undefined;
				}
			};
			textAttributes.textAlign = mapTextAlign(styleObj.textAlign);
			hasTextAttributes = true;
		}

		// Font variant
		if (styleObj.fontVariant && Array.isArray(styleObj.fontVariant)) {
			textAttributes.fontVariant = styleObj.fontVariant;
			hasTextAttributes = true;
		}

		// Text color
		if (styleObj.color) {
			const processed = processColor(styleObj.color);
			if (processed != null) {
				textAttributes.color =
					typeof processed === "number" ? processed : JSON.stringify(processed);
				hasTextAttributes = true;
			}
		}

		// Text shadow properties
		if (styleObj.textShadowColor) {
			const processed = processColor(styleObj.textShadowColor);
			if (processed != null) {
				textAttributes.textShadowColor =
					typeof processed === "number" ? processed : JSON.stringify(processed);
				hasTextAttributes = true;
			}
		}

		if (
			styleObj.textShadowOffset &&
			typeof styleObj.textShadowOffset === "object"
		) {
			textAttributes.textShadowOffset = styleObj.textShadowOffset;
			hasTextAttributes = true;
		}

		if (
			styleObj.textShadowRadius &&
			typeof styleObj.textShadowRadius === "number"
		) {
			textAttributes.textShadowRadius = styleObj.textShadowRadius;
			hasTextAttributes = true;
		}

		// Writing direction
		if (styleObj.writingDirection) {
			textAttributes.writingDirection = styleObj.writingDirection;
			hasTextAttributes = true;
		}

		// User select
		if (styleObj.userSelect) {
			textAttributes.userSelect = styleObj.userSelect;
			hasTextAttributes = true;
		}

		return hasTextAttributes ? textAttributes : undefined;
	};

	// Calculate vertical padding for height adjustment
	const calculateVerticalPadding = (styleObj: any): number => {
		if (!styleObj) return 0;

		let top = 0;
		let bottom = 0;

		// Start with base padding value
		if (styleObj.padding !== undefined) {
			top = styleObj.padding;
			bottom = styleObj.padding;
		}

		// Apply paddingVertical
		if (styleObj.paddingVertical !== undefined) {
			top = styleObj.paddingVertical;
			bottom = styleObj.paddingVertical;
		}

		// Individual padding properties take highest priority
		if (styleObj.paddingTop !== undefined) {
			top = styleObj.paddingTop;
		}
		if (styleObj.paddingBottom !== undefined) {
			bottom = styleObj.paddingBottom;
		}

		return top + bottom;
	};

	// Remove all properties that are handled natively via textAttributes
	const removeNativeHandledPropsFromStyle = (styleObj: TextStyle) => {
		if (!styleObj) return styleObj;

		const {
			// Text attributes (handled natively via textAttributes)
			textDecorationLine, // eslint-disable-line @typescript-eslint/no-unused-vars
			textDecorationStyle, // eslint-disable-line @typescript-eslint/no-unused-vars
			textDecorationColor, // eslint-disable-line @typescript-eslint/no-unused-vars
			fontSize, // eslint-disable-line @typescript-eslint/no-unused-vars
			fontWeight, // eslint-disable-line @typescript-eslint/no-unused-vars
			fontStyle, // eslint-disable-line @typescript-eslint/no-unused-vars
			fontVariant, // eslint-disable-line @typescript-eslint/no-unused-vars
			letterSpacing, // eslint-disable-line @typescript-eslint/no-unused-vars
			lineHeight, // eslint-disable-line @typescript-eslint/no-unused-vars
			textAlign, // eslint-disable-line @typescript-eslint/no-unused-vars
			color, // eslint-disable-line @typescript-eslint/no-unused-vars
			textShadowColor, // eslint-disable-line @typescript-eslint/no-unused-vars
			textShadowOffset, // eslint-disable-line @typescript-eslint/no-unused-vars
			textShadowRadius, // eslint-disable-line @typescript-eslint/no-unused-vars
			writingDirection, // eslint-disable-line @typescript-eslint/no-unused-vars
			userSelect, // eslint-disable-line @typescript-eslint/no-unused-vars
			// Keep all layout properties (margin, position, padding, width/height) for JS-side handling
			...filteredStyle
		} = styleObj;

		return filteredStyle;
	};

	const textAttributes = extractTextAttributes(flattenedStyle);
	const filteredStyle = removeNativeHandledPropsFromStyle(flattenedStyle);

	// Map inputMode to keyboardType
	const getKeyboardTypeFromInputMode = () => {
		if (!inputMode) return keyboardType;

		switch (inputMode) {
			case "text":
				return "default";
			case "decimal":
				return "decimal-pad";
			case "numeric":
				return "number-pad";
			case "tel":
				return "phone-pad";
			case "search":
				return Platform.OS === "ios" ? "web-search" : "default";
			case "email":
				return "email-address";
			case "url":
				return "url";
			case "none":
				return keyboardType; // Keep original keyboardType for 'none'
			default:
				return keyboardType;
		}
	};

	// Handle showSoftInputOnFocus for inputMode 'none'
	const shouldShowSoftInput =
		props.inputMode === "none" ? false : showSoftInputOnFocus;

	const composedStyle = () => {
		if (!hasExplicitHeight && measuredInitialHeight != null) {
			// Calculate vertical padding on each render
			const verticalPadding = calculateVerticalPadding(flattenedStyle);
			const adjustedHeight = measuredInitialHeight + verticalPadding;
			return [
				// Preserve original user-provided style(s) but without native-handled props
				filteredStyle,
				// Apply measured height with padding adjustment
				{ height: adjustedHeight, alignSelf: "stretch" as const },
			];
		}
		return [filteredStyle, { alignSelf: "stretch" as const }];
	};

	const handleInitialHeightMeasured = (height: number) => {
		setMeasuredInitialHeight(height);
	};

	const mapEnterKeyHintToReturnKeyType = (
		hint: TextInputProps["enterKeyHint"],
	): ReturnKeyType | undefined => {
		switch (hint) {
			case "done":
				return "done";
			case "next":
				return "next";
			case "search":
				return "search";
			case "send":
				return "send";
			case "go":
				return "go";
			case "enter":
				return "done";
			default:
				return undefined;
		}
	};

	const resolvedReturnKeyType =
		enterKeyHint != null
			? mapEnterKeyHintToReturnKeyType(enterKeyHint)
			: returnKeyType;

	const toProcessedColor = (
		color:
			| TextInputProps["placeholderTextColor"]
			| TextInputProps["selectionColor"]
			| undefined,
	): number | string | undefined => {
		const processed = processColor(color ?? undefined);
		if (processed == null) return undefined;
		return typeof processed === "number"
			? processed
			: JSON.stringify(processed);
	};

	// Determine which component to use based on multiline prop
	const isMultiLine = others.multiline === true;
	const Component = isMultiLine
		? NativeNitroMultiLineTextInput
		: NativeNitroTextInput;

	const handleContentSizeChanged = (_width: number, height: number) => {
		// Additional logic for multi-line content size changes can be added here
		// For now, we'll just update the measured height for multi-line views
		if (isMultiLine && !hasExplicitHeight) {
			setMeasuredInitialHeight(height);
		}
	};

	// Prepare callback objects - both components use wrapped callbacks
	const callbackProps = {
		// Event handlers (wrapped in { f: ... } for both single-line and multi-line)
		onBlurred: { f: onBlur },
		onTextChanged: { f: onChangeText },
		onEditingEnded: { f: onEndEditing },
		onEditingSubmitted: { f: onSubmitEditing },
		onSelectionChanged: {
			f: (start: number, end: number) => onSelectionChange?.({ start, end }),
		},
		onTouchBegan: { f: onPressIn },
		onTouchEnded: { f: onPressOut },
		onFocused: { f: onFocus },
		onKeyPressed: { f: onKeyPress },
		onInitialHeightMeasured: { f: handleInitialHeightMeasured },
		// Multi-line specific callback
		...(isMultiLine
			? { onContentSizeChanged: { f: handleContentSizeChanged } }
			: {}),
	};

	return (
		<Component
			{...others}
			keyboardType={getKeyboardTypeFromInputMode()}
			placeholderTextColor={toProcessedColor(placeholderTextColor)}
			returnKeyType={resolvedReturnKeyType}
			selectionColor={toProcessedColor(selectionColor)}
			showSoftInputOnFocus={shouldShowSoftInput}
			textAttributes={textAttributes}
			// Hybrid ref for method access
			hybridRef={{
				f: (view) => {
					if (propsRef) {
						propsRef.current = view;
					}
				},
			}}
			// Event handlers
			{...callbackProps}
			style={composedStyle()}
		/>
	);
}
