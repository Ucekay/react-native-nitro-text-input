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
        onBlur={() => console.log('Blurred')}
        onChangeText={(text) => console.log(text)}
        onEndEditing={(text) => console.log(text)}
        onPressIn={(
          pageX: number,
          pageY: number,
          locationX: number,
          locationY: number
        ) =>
          console.log(
            `Pressed at (${pageX}, ${pageY}) - (${locationX}, ${locationY})`
          )
        }
        placeholder="Nitro Text Input🔥"
      />
      <TextInput
        clearButtonMode="always"
        placeholder="React Native Text Input"
        enablesReturnKeyAutomatically
        maxLength={12}
        onBlur={() => console.log('Blurred')}
        onEndEditing={(e: NativeSyntheticEvent<TextInputEndEditingEventData>) =>
          console.log(e.nativeEvent.text)
        }
        onPressIn={(e) =>
          console.log(
            `Pressed at (${e.nativeEvent.pageX}, ${e.nativeEvent.pageY}) - (${e.nativeEvent.locationX}, ${e.nativeEvent.locationY})`
          )
        }
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
