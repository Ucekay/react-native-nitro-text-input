import { StatusBar } from "expo-status-bar";
import { useRef, useState } from "react";
import {
	Button,
	DynamicColorIOS,
	Platform,
	PlatformColor,
	StyleSheet,
	Text,
	TextInput,
	View,
} from "react-native";
import {
	NitroTextInput,
	type NitroTextInputRef,
} from "react-native-nitro-text-input";

export default function App() {
	const ref = useRef<NitroTextInputRef>(null);
	const [isFocused, setIsFocused] = useState(false);

	const checkFocusStatus = () => {
		const focused = ref.current?.isFocused() ?? false;
		setIsFocused(focused);
		console.log("Focus status:", focused);
	};

	const handleFocus = () => {
		ref.current?.focus();
		checkFocusStatus();
	};

	const handleBlur = () => {
		ref.current?.blur();
		checkFocusStatus();
	};

	const handleClear = () => {
		ref.current?.clear();
	};

	return (
		<View style={styles.container}>
			<NitroTextInput
				allowFontScaling
				autoCapitalize="none"
				autoCorrect
				autoFocus={false}
				caretHidden={false}
				clearButtonMode="while-editing"
				clearTextOnFocus={false}
				contextMenuHidden={false}
				editable
				enablesReturnKeyAutomatically
				keyboardAppearance="default"
				maxLength={12}
				onBlur={() => {
					console.log("blurred");
					checkFocusStatus();
				}}
				onChangeText={(text) => console.log(text)}
				onFocus={() => {
					console.log("focused");
					checkFocusStatus();
				}}
				onKeyPress={(key) => console.log(`Key pressed: ${key}`)}
				onSelectionChange={({ start, end }) =>
					console.log(`Selection changed: ${start} - ${end}`)
				}
				onSubmitEditing={(text) => console.log(`Submitted: ${text}`)}
				placeholder="Nitro Text Input 🔥"
				placeholderTextColor={
					Platform.OS === "ios"
						? DynamicColorIOS({
								light: PlatformColor("systemBlueColor"),
								dark: "gray",
							})
						: "#00f"
				}
				selectionColor={
					Platform.OS === "ios"
						? DynamicColorIOS({
								light: PlatformColor("systemGreenColor"),
								dark: "green",
							})
						: "#0f0"
				}
				secureTextEntry={false}
				selectTextOnFocus={false}
				showSoftInputOnFocus={true}
				spellCheck={true}
				submitBehavior="blurAndSubmit"
				textAlign="center"
				style={{ width: "100%" }}
				ref={ref}
			/>

			<Text style={styles.statusText}>
				Focus Status: {isFocused ? "✅ Focused" : "❌ Not Focused"}
			</Text>

			<View style={styles.buttonContainer}>
				<Button title="Focus" onPress={handleFocus} />
				<Button title="Blur" onPress={handleBlur} />
				<Button title="Clear" onPress={handleClear} />
				<Button title="Check Focus" onPress={checkFocusStatus} />
			</View>

			<TextInput
				autoFocus={false}
				clearButtonMode="always"
				maxLength={12}
				placeholder="React Native Text Input"
				enablesReturnKeyAutomatically
				spellCheck={false}
				style={{ width: "100%" }}
			/>
			<StatusBar style="auto" />
		</View>
	);
}

const styles = StyleSheet.create({
	container: {
		flex: 1,
		backgroundColor: "#fff",
		alignItems: "center",
		justifyContent: "center",
		gap: 20,
		padding: 20,
	},
	statusText: {
		fontSize: 18,
		fontWeight: "bold",
		textAlign: "center",
	},
	buttonContainer: {
		flexDirection: "row",
		gap: 10,
		flexWrap: "wrap",
		justifyContent: "center",
	},
});
