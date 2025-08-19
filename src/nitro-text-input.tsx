// biome-ignore lint/correctness/noUnusedImports: Needed for JSX runtime
import React from "react";
import type { HostComponent } from "react-native";
import { StyleSheet } from "react-native";
import { NativeNitroTextInput } from "./native-nitro-text-input";

type ReactProps<T> = T extends HostComponent<infer P> ? P : never;
type NativeTextInputProps = ReactProps<typeof NativeNitroTextInput>;
export interface NitroTextInputProps
	extends Omit<NativeTextInputProps, "onInitialHeightMeasured"> {}

export function NitroTextInput(props: NitroTextInputProps) {
	const [measuredInitialHeight, setMeasuredInitialHeight] = React.useState<
		number | undefined
	>(undefined);

	const flattenedStyle = StyleSheet.flatten(props.style) ?? {};

	const hasExplicitHeight = flattenedStyle?.height != null;

	const composedStyle = () => {
		if (!hasExplicitHeight && measuredInitialHeight != null) {
			return [
				// Preserve original user-provided style(s)
				props.style,
				// Apply measured height only when height isn't explicitly set
				{ height: measuredInitialHeight, width: "100%" as const },
			];
		}
		return [props.style, { width: "100%" as const }];
	};

	const handleInitialHeightMeasured = (height: number) => {
		setMeasuredInitialHeight(height);
	};

	return (
		<NativeNitroTextInput
			{...props}
			style={composedStyle()}
			onInitialHeightMeasured={{ f: handleInitialHeightMeasured }}
		/>
	);
}
