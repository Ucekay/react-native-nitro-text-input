import { StatusBar } from "expo-status-bar";
import { useRef } from "react";
import { Button, StyleSheet, Text, View } from "react-native";
import {
	NitroTextInput,
	type NitroTextInputRef,
} from "react-native-nitro-text-input";

export default function App() {
	const ref = useRef<NitroTextInputRef>(null);

	const handleFocus = () => {
		ref.current?.focus();
	};

	const handleBlur = () => {
		ref.current?.blur();
	};

	const handleClear = () => {
		ref.current?.clear();
	};

	return (
		<View style={styles.container}>
			<Text style={styles.title}>NitroTextInput Style Properties Test</Text>

			{/* Test basic layout properties */}
			<NitroTextInput
				placeholder="Width & Height Test"
				width={300}
				height={50}
				style={{
					backgroundColor: "#f0f0f0",
					borderWidth: 1,
					borderColor: "#ccc",
					textAlign: "center",
				}}
			/>

			{/* Test margin properties */}
			<NitroTextInput
				placeholder="Margin Test"
				margin={20}
				style={{
					backgroundColor: "#e0e0ff",
					borderWidth: 1,
					borderColor: "#0000cc",
				}}
			/>

			{/* Test padding properties */}
			<NitroTextInput
				placeholder="Padding Test"
				padding={15}
				style={{
					backgroundColor: "#ffe0e0",
					borderWidth: 1,
					borderColor: "#cc0000",
				}}
			/>

			{/* Test specific padding */}
			<NitroTextInput
				placeholder="Specific Padding"
				paddingLeft={30}
				paddingRight={10}
				paddingTop={20}
				paddingBottom={5}
				style={{
					backgroundColor: "#e0ffe0",
					borderWidth: 1,
					borderColor: "#00cc00",
				}}
			/>

			{/* Test position properties */}
			<NitroTextInput
				placeholder="Position Test"
				position="relative"
				top={10}
				left={20}
				style={{
					backgroundColor: "#ffffe0",
					borderWidth: 1,
					borderColor: "#cccc00",
				}}
			/>

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
				maxLength={50}
				onBlur={() => {
					console.log("blurred");
				}}
				onChangeText={(text) => console.log(text)}
				onFocus={() => {
					console.log("focused");
				}}
				onKeyPress={(key) => console.log(`Key pressed: ${key}`)}
				onSelectionChange={({ start, end }) =>
					console.log(`Selection changed: ${start} - ${end}`)
				}
				onSubmitEditing={(text) => console.log(`Submitted: ${text}`)}
				placeholder="Type here..."
				secureTextEntry={false}
				selectTextOnFocus={false}
				showSoftInputOnFocus={true}
				spellCheck={true}
				submitBehavior="blurAndSubmit"
				textAlign="center"
				style={{
					width: "100%",
					color: "red",
					fontWeight: "600",
					fontSize: 21,
					textDecorationLine: "underline",
					textDecorationStyle: "dashed",
					fontStyle: "italic",
					textShadowColor: "#00000080",
					textShadowOffset: { width: 0, height: 1 },
					textShadowRadius: 1,
				}}
				ref={ref}
			/>

			<View style={styles.buttonContainer}>
				<Button title="Focus" onPress={handleFocus} />
				<Button title="Blur" onPress={handleBlur} />
				<Button title="Clear" onPress={handleClear} />
			</View>
			<StatusBar style="auto" />
		</View>
	);
}

const styles = StyleSheet.create({
	container: {
		flex: 1,
		backgroundColor: "#fff",
		alignItems: "center",
		justifyContent: "flex-start",
		gap: 15,
		padding: 20,
	},
	title: {
		fontSize: 20,
		fontWeight: "bold",
		textAlign: "center",
		marginBottom: 20,
		marginTop: 50,
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
