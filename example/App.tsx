import { StatusBar } from "expo-status-bar";
import { useRef } from "react";
import { Button, StyleSheet, View } from "react-native";
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
				style={{ width: "100%" }}
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
