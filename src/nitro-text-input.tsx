import React from "react";
import type { InputModeOptions, TextInputProps, ViewProps } from "react-native";
import { Platform, processColor, StyleSheet } from "react-native";
import type { HybridView } from "react-native-nitro-modules";
import type {
	DefaultHybridViewProps,
	WrapFunctionsInObjects,
} from "react-native-nitro-modules/src";
import { NativeNitroTextInput } from "./native-nitro-text-input";
import type {
	NitroTextInputViewMethods,
	NitroTextInputViewProps,
	ReturnKeyType,
} from "./specs/text-input-view.nitro";

type NativeTextInputProps = WrapFunctionsInObjects<
	DefaultHybridViewProps<
		HybridView<NitroTextInputViewProps, NitroTextInputViewMethods>
	> &
		NitroTextInputViewProps
> &
	ViewProps;
// Base props interface (without ref)
export interface NitroTextInputBaseProps
	extends Omit<
		NativeTextInputProps,
		| "onInitialHeightMeasured"
		| "onBlurred"
		| "onTextChanged"
		| "onEditingEnded"
		| "onEditingSubmitted"
		| "onTauchBegan"
		| "onTouchEnded"
		| "onSelectionChanged"
		| "onFocused"
		| "onKeyPressed"
		| "placeholderTextColor"
		| "selectionColor"
		| "hybridRef"
	> {
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
	enterKeyHint?: "done" | "next" | "search" | "send" | "go" | "enter";
	selectionColor?: TextInputProps["selectionColor"] | undefined;
	ref?: React.RefObject<NitroTextInputViewMethods | null>;
}

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
			return [
				// Preserve original user-provided style(s)
				style,
				// Apply measured height only when height isn't explicitly set
				{ height: measuredInitialHeight, width: "100%" as const },
			];
		}
		return [style, { width: "100%" as const }];
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

	const filterUnsupportedReturnKeyType = (
		keyType: ReturnKeyType | undefined,
	): ReturnKeyType | undefined => {
		const supportedKeys: ReturnKeyType[] = [
			"go",
			"google",
			"join",
			"next",
			"route",
			"search",
			"send",
			"yahoo",
			"done",
			"emergency-call",
		];
		return keyType && supportedKeys.includes(keyType as ReturnKeyType)
			? (keyType as ReturnKeyType)
			: undefined;
	};

	const resolvedReturnKeyType =
		enterKeyHint != null
			? mapEnterKeyHintToReturnKeyType(enterKeyHint)
			: filterUnsupportedReturnKeyType(returnKeyType);

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

	return (
		<NativeNitroTextInput
			{...others}
			keyboardType={getKeyboardTypeFromInputMode()}
			placeholderTextColor={toProcessedColor(placeholderTextColor)}
			returnKeyType={resolvedReturnKeyType}
			selectionColor={toProcessedColor(selectionColor)}
			showSoftInputOnFocus={shouldShowSoftInput}
			// Hybrid ref for method access
			hybridRef={{
				f: (view) => {
					if (propsRef) {
						propsRef.current = view;
					}
				},
			}}
			// Event handlers
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
	);
}
