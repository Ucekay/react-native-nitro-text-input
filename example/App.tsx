import { StatusBar } from "expo-status-bar";
import { useRef } from "react";
import { Button, StyleSheet, Text, TextInput, View } from "react-native";
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
				style={{
					borderWidth: 1,
					borderColor: "gray",
					borderRadius: 8,
					padding: 10,
					width: "100%",
					fontSize: 17,
				}}
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
				onChangeText={(text: string) => console.log(text)}
				onFocus={() => {
					console.log("focused");
				}}
				onKeyPress={(key: string) => console.log(`Key pressed: ${key}`)}
				onSelectionChange={({ start, end }: { start: number; end: number }) =>
					console.log(`Selection changed: ${start} - ${end}`)
				}
				onSubmitEditing={(text: string) => console.log(`Submitted: ${text}`)}
				placeholder="Nitro Text Input 🔥"
				secureTextEntry={false}
				selectTextOnFocus={false}
				showSoftInputOnFocus={true}
				spellCheck={true}
				submitBehavior="blurAndSubmit"
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
