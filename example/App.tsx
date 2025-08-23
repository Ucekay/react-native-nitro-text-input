import { StatusBar } from 'expo-status-bar'
import {
  DynamicColorIOS,
  Platform,
  PlatformColor,
  StyleSheet,
  TextInput,
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
        keyboardAppearance="default"
        maxLength={12}
        onChangeText={(text) => console.log(text)}
        onFocus={() => console.log('focused')}
        onKeyPress={(key) => console.log(`Key pressed: ${key}`)}
        onSelectionChange={({ start, end }) =>
          console.log(`Selection changed: ${start} - ${end}`)
        }
        onSubmitEditing={(text) => console.log(`Submitted: ${text}`)}
        placeholder="Nitro Text Input 🔥"
        placeholderTextColor={
          Platform.OS === 'ios'
            ? DynamicColorIOS({
                light: PlatformColor('systemBlueColor'),
                dark: 'gray',
              })
            : '#00f'
        }
        secureTextEntry={false}
        style={{ width: '100%' }}
      />
      <TextInput
        clearButtonMode="always"
        placeholder="React Native Text Input"
        enablesReturnKeyAutomatically
        maxLength={12}
        placeholderTextColor={'red'}
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
