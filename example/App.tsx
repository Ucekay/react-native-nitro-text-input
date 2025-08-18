import { StatusBar } from 'expo-status-bar'
import { StyleSheet, TextInput, View } from 'react-native'
import { NitroTextInput } from 'react-native-nitro-text-input'

export default function App() {
  return (
    <View style={styles.container}>
      <TextInput autoCapitalize="sentences" placeholder="こんばんは！" />
      <NitroTextInput
        autoCapitalize="words"
        autoCorrect
        placeholder="こんにちは！"
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
  },
})
