import { StatusBar } from "expo-status-bar";
import { useRef, useState } from "react";
import { Button, ScrollView, StyleSheet, Text, View } from "react-native";
import {
	NitroTextInput,
	type NitroTextInputRef,
} from "react-native-nitro-text-input";

export default function App() {
	const singleLineRef = useRef<NitroTextInputRef>(null);
	const multiLineRef = useRef<NitroTextInputRef>(null);
	const [currentInputType, setCurrentInputType] = useState<"single" | "multi">(
		"single",
	);

	const activeRef =
		currentInputType === "single" ? singleLineRef : multiLineRef;

	const handleFocus = () => {
		activeRef.current?.focus();
	};

	const handleBlur = () => {
		activeRef.current?.blur();
	};

	const handleClear = () => {
		activeRef.current?.clear();
	};

	return (
		<ScrollView scrollEnabled={false} contentContainerStyle={styles.container}>
			<Text style={styles.title}>React Native Nitro Text Input</Text>

			<Text style={styles.sectionTitle}>Single Line Text Input</Text>
			<NitroTextInput
				ref={singleLineRef}
				style={styles.singleLineInput}
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
				maxLength={100}
				multiline={false}
				onBlur={() => {
					console.log("Single-line blurred");
				}}
				onChangeText={(text: string) => console.log("Single-line text:", text)}
				onFocus={() => {
					console.log("Single-line focused");
					setCurrentInputType("single");
				}}
				onKeyPress={(key: string) =>
					console.log(`Single-line key pressed: ${key}`)
				}
				onSelectionChange={({ start, end }: { start: number; end: number }) =>
					console.log(`Single-line selection: ${start} - ${end}`)
				}
				onSubmitEditing={(text: string) =>
					console.log(`Single-line submitted: ${text}`)
				}
				placeholder="Single-line Nitro Text Input 🔥"
				secureTextEntry={false}
				selectTextOnFocus={false}
				showSoftInputOnFocus={true}
				spellCheck={true}
				submitBehavior="blurAndSubmit"
			/>

			<Text style={styles.sectionTitle}>Multi-Line Text Input</Text>
			<NitroTextInput
				ref={multiLineRef}
				style={styles.multiLineInput}
				allowFontScaling
				autoCapitalize="sentences"
				autoCorrect
				autoFocus={false}
				contextMenuHidden={false}
				editable
				keyboardAppearance="default"
				maxLength={500}
				multiline={true}
				numberOfLines={2}
				scrollEnabled={true}
				onBlur={() => {
					console.log("Multi-line blurred");
				}}
				onChangeText={(text: string) => console.log("Multi-line text:", text)}
				onFocus={() => {
					console.log("Multi-line focused");
					setCurrentInputType("multi");
				}}
				onKeyPress={(key: string) =>
					console.log(`Multi-line key pressed: ${key}`)
				}
				onSelectionChange={({ start, end }: { start: number; end: number }) =>
					console.log(`Multi-line selection: ${start} - ${end}`)
				}
				onSubmitEditing={(text: string) =>
					console.log(`Multi-line submitted: ${text}`)
				}
				onContentSizeChange={(width: number, height: number) =>
					console.log(`Multi-line content size: ${width}x${height}`)
				}
				placeholder="Multi-line Nitro Text Input 🔥&#10;Type multiple lines here..."
				secureTextEntry={false}
				selectTextOnFocus={false}
				showSoftInputOnFocus={true}
				spellCheck={true}
				submitBehavior="newline"
			/>

			<View style={styles.buttonContainer}>
				<Button title="Focus" onPress={handleFocus} />
				<Button title="Blur" onPress={handleBlur} />
				<Button title="Clear" onPress={handleClear} />
			</View>

			<StatusBar style="auto" />
		</ScrollView>
	);
}

const styles = StyleSheet.create({
	container: {
		flexGrow: 1,
		backgroundColor: "#fff",
		alignItems: "center",
		gap: 15,
		padding: 20,
	},
	title: {
		fontSize: 24,
		fontWeight: "bold",
		textAlign: "center",
		marginBottom: 20,
		marginTop: 50,
	},
	sectionTitle: {
		fontSize: 18,
		fontWeight: "600",
		textAlign: "center",
		marginTop: 20,
		marginBottom: 10,
	},
	singleLineInput: {
		borderWidth: 1,
		borderColor: "#007AFF",
		borderRadius: 8,
		padding: 12,
		width: "100%",
		fontSize: 16,
		backgroundColor: "#F8F9FA",
	},
	multiLineInput: {
		overflow: "hidden",
		color: "#00f",
		textDecorationLine: "underline",
		textDecorationStyle: "dashed",
		textDecorationColor: "#000",
		textShadowColor: "#888",
		textShadowOffset: { width: 1, height: 1 },
		textShadowRadius: 1,
		borderWidth: 1,
		borderColor: "#34C759",
		borderRadius: 8,
		padding: 12,
		width: "100%",
		fontSize: 16,
		backgroundColor: "#F8F9FA",
		minHeight: 100,
		maxHeight: 200,
		textAlignVertical: "top",
	},
	statusText: {
		fontSize: 16,
		fontWeight: "500",
		textAlign: "center",
		color: "#666",
		marginTop: 10,
	},
	buttonContainer: {
		flexDirection: "row",
		gap: 10,
		flexWrap: "wrap",
		justifyContent: "center",
		marginTop: 15,
	},
});
