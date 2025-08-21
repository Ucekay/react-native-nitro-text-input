import { StatusBar } from 'expo-status-bar'
import {
  type NativeSyntheticEvent,
  StyleSheet,
  TextInput,
  type TextInputEndEditingEventData,
  View,
} from 'react-native'
import { NitroTextInput } from 'react-native-nitro-text-input'

export default function App() {
  return (
    <View style={styles.container}>
      <NitroTextInput
        allowFontScaling
        autoCapitalize="words"
        autoCorrect
        autoFocus={true}
        caretHidden={false}
        clearButtonMode="while-editing"
        clearTextOnFocus={false}
        contextMenuHidden={false}
        defaultValue=""
        editable
        enablesReturnKeyAutomatically
        maxLength={12}
        onChangeText={(text) => console.log(text)}
        onPressOut={(pageX, pageY, locationX, locationY, timestamp) =>
          console.log(
            `Pressed out at (${pageX}, ${pageY}) - (${locationX}, ${locationY}) at ${timestamp}`
          )
        }
        placeholder="Nitro Text Input🔥"
      />
      <TextInput
        clearButtonMode="always"
        placeholder="React Native Text Input"
        enablesReturnKeyAutomatically
        maxLength={12}
        style={{ width: '100%' }}
      />
      <StatusBar style="auto" />
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 32,
  },
})
