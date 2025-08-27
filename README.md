# React Native Nitro Text Input

A high-performance text input component for React Native, built with Nitro Modules for optimal native performance.

## Features

- 🚀 **High Performance**: Built with Nitro Modules for direct native bindings
- 📝 **Single & Multi-line Support**: Both single-line and multi-line text inputs
- 📱 **Cross Platform**: iOS and Android support
- 🎨 **Rich Styling**: Full text styling and customization options
- 📏 **Line Control**: Control the number of visible lines in multi-line inputs
- ⌨️ **Keyboard Management**: Comprehensive keyboard configuration
- 🔍 **Selection Control**: Precise text selection and cursor management

## Installation

```bash
npm install react-native-nitro-text-input
# or
yarn add react-native-nitro-text-input
```

### iOS Setup

Run `pod install` in your `ios/` directory.

### Android Setup

No additional setup required.

## Usage

### Basic Single-line Input

```tsx
import { NitroTextInput } from 'react-native-nitro-text-input';

function App() {
  return (
    <NitroTextInput
      style={{ borderWidth: 1, padding: 10 }}
      placeholder="Enter text here..."
      onChangeText={(text) => console.log(text)}
    />
  );
}
```

### Multi-line Input with Line Limit

```tsx
import { NitroTextInput } from 'react-native-nitro-text-input';

function App() {
  return (
    <NitroTextInput
      multiline={true}
      numberOfLines={4}
      style={{ 
        borderWidth: 1, 
        padding: 10, 
        minHeight: 100,
        textAlignVertical: 'top' 
      }}
      placeholder="Enter multiple lines here..."
      onChangeText={(text) => console.log(text)}
      onContentSizeChange={(width, height) => {
        console.log(`Content size: ${width}x${height}`);
      }}
    />
  );
}
```

## Props

### Core Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `multiline` | `boolean` | `false` | Enable multi-line text input |
| `numberOfLines` | `number` | `undefined` | Maximum number of lines to display before scrolling |
| `placeholder` | `string` | `undefined` | Placeholder text when input is empty |
| `defaultValue` | `string` | `undefined` | Initial text value |
| `maxLength` | `number` | `undefined` | Maximum number of characters allowed |
| `editable` | `boolean` | `true` | Whether the input is editable |

### numberOfLines Property

The `numberOfLines` prop controls how many lines of text are visible before the text input becomes scrollable. This is particularly useful for multi-line inputs.

**Behavior:**
- When `numberOfLines` is set, the text input will grow to accommodate text up to the specified number of lines
- Once the text exceeds the line limit, the input becomes vertically scrollable
- Setting `numberOfLines={0}` or omitting the prop allows unlimited lines without scrolling
- Only works when `multiline={true}`

**Examples:**

```tsx
// Fixed 3-line input
<NitroTextInput 
  multiline={true}
  numberOfLines={3}
  placeholder="Max 3 visible lines..."
/>

// Unlimited lines (scrollable from start)
<NitroTextInput 
  multiline={true}
  placeholder="Unlimited lines..."
/>

// Single line (equivalent to multiline={false})
<NitroTextInput 
  numberOfLines={1}
  placeholder="Single line only..."
/>
```

### Keyboard Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `keyboardType` | `KeyboardType` | `'default'` | Type of keyboard to display |
| `keyboardAppearance` | `KeyboardAppearance` | `'default'` | Keyboard color scheme |
| `returnKeyType` | `ReturnKeyType` | `'default'` | Return key appearance |
| `autoCapitalize` | `AutoCapitalize` | `'sentences'` | Auto-capitalization behavior |
| `autoCorrect` | `boolean` | `true` | Enable auto-correction |
| `spellCheck` | `boolean` | `true` | Enable spell checking |

### Styling Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `textAlign` | `TextAlign` | `'natural'` | Text alignment |
| `allowFontScaling` | `boolean` | `true` | Allow system font scaling |
| `maxFontSizeMultiplier` | `number` | `undefined` | Maximum font scaling multiplier |
| `textAttributes` | `TextAttributes` | `undefined` | Advanced text styling |

### Event Props

| Prop | Type | Description |
|------|------|-------------|
| `onFocus` | `() => void` | Called when input gains focus |
| `onBlur` | `() => void` | Called when input loses focus |
| `onChangeText` | `(text: string) => void` | Called when text changes |
| `onSelectionChange` | `(start: number, end: number) => void` | Called when selection changes |
| `onKeyPress` | `(key: string) => void` | Called when a key is pressed |
| `onSubmitEditing` | `(text: string) => void` | Called when editing is submitted |
| `onContentSizeChange` | `(width: number, height: number) => void` | Called when content size changes (multi-line only) |

## Methods

Access these methods using a ref:

```tsx
const inputRef = useRef<NitroTextInputRef>(null);

// Methods
inputRef.current?.focus();     // Focus the input
inputRef.current?.blur();      // Remove focus
inputRef.current?.clear();     // Clear the text
inputRef.current?.isFocused(); // Check if focused
```

## Advanced Examples

### Auto-expanding Text Area

```tsx
const [height, setHeight] = useState(40);

<NitroTextInput
  multiline={true}
  numberOfLines={4}
  style={{ 
    height: Math.max(40, height),
    borderWidth: 1,
    padding: 10 
  }}
  onContentSizeChange={(width, height) => {
    setHeight(height);
  }}
  placeholder="Auto-expanding up to 4 lines..."
/>
```

### Chat Input with Send Button

```tsx
const [message, setMessage] = useState('');

<View style={{ flexDirection: 'row', alignItems: 'flex-end' }}>
  <NitroTextInput
    multiline={true}
    numberOfLines={3}
    style={{ 
      flex: 1,
      borderWidth: 1,
      borderRadius: 20,
      paddingHorizontal: 15,
      paddingVertical: 10,
      maxHeight: 100
    }}
    value={message}
    onChangeText={setMessage}
    placeholder="Type a message..."
    submitBehavior="newline"
  />
  <TouchableOpacity 
    onPress={() => {
      console.log('Send:', message);
      setMessage('');
    }}
    style={{ marginLeft: 10, padding: 10 }}
  >
    <Text>Send</Text>
  </TouchableOpacity>
</View>
```

## Platform-specific Notes

### iOS
- Uses `UITextView` for multi-line inputs with `NSTextContainer.maximumNumberOfLines`
- Supports all iOS text input features and keyboard types
- Full Dynamic Type support for accessibility

### Android
- Uses `EditText` with `maxLines` and scrolling configuration
- Handles line limits through `setLines()` and `setMaxLines()`
- Supports material design keyboard behaviors

## Performance

This library is built with Nitro Modules, providing:
- Direct native bridge communication
- Zero-copy string passing
- Optimized view updates
- Native-level performance for all operations

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests for any improvements.

## License

MIT