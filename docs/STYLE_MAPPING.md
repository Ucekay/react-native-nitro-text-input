# Style Mapping in NitroTextInput

The NitroTextInput component now automatically maps React Native text style properties to native TextAttributes for optimal text rendering performance.

## Automatic Style Mapping

When you provide a `style` prop to NitroTextInput, the component automatically extracts text-specific styling properties and converts them to the native TextAttributes format:

```tsx
import { NitroTextInput } from 'react-native-nitro-text-input';

function MyComponent() {
  return (
    <NitroTextInput
      placeholder="Type here..."
      style={{
        fontSize: 18,
        fontWeight: 'bold',
        color: '#333',
        textAlign: 'center',
        letterSpacing: 1,
        lineHeight: 24,
        textDecorationLine: 'underline',
        textDecorationColor: '#007AFF',
        textDecorationStyle: 'solid',
        fontStyle: 'italic',
        // Non-text styles are preserved for layout
        width: '100%',
        backgroundColor: 'white',
        borderWidth: 1,
      }}
    />
  );
}
```

## Supported Text Style Properties

The following React Native text style properties are automatically mapped to TextAttributes:

- `color` - Text color (processed with React Native's `processColor`)
- `fontSize` - Font size in points
- `fontStyle` - Font style ('normal' | 'italic')
- `fontWeight` - Font weight (string or number)
- `letterSpacing` - Letter spacing in points
- `lineHeight` - Line height in points
- `textAlign` - Text alignment ('auto' | 'left' | 'right' | 'center' | 'justify')
- `textDecorationColor` - Text decoration color (processed with `processColor`)
- `textDecorationLine` - Text decoration line ('none' | 'underline' | 'line-through' | 'underline line-through')
- `textDecorationStyle` - Text decoration style ('solid' | 'double' | 'dotted' | 'dashed')

## Manual Usage

You can also manually use the style mapping function if needed:

```tsx
import { mapStyleToTextAttributes, type TextAttributes } from 'react-native-nitro-text-input';

const textStyle = {
  fontSize: 16,
  color: 'red',
  fontWeight: 'bold',
};

const textAttributes: TextAttributes | undefined = mapStyleToTextAttributes(textStyle);
// Result: { fontSize: 16, color: 0xFFFF0000, fontWeight: 'bold' }
```

## Performance Benefits

By mapping styles to TextAttributes, the component can leverage native text rendering optimizations while maintaining full compatibility with React Native's styling API.