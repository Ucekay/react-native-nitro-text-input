# Style Properties Test for NitroTextInput

This document describes how to test the newly implemented style properties for NitroTextInput.

## Implemented Style Properties

### Layout Properties
- `width`: number - Sets the width of the text input
- `height`: number - Sets the height of the text input  
- `minWidth`: number - Sets the minimum width
- `maxWidth`: number - Sets the maximum width
- `minHeight`: number - Sets the minimum height
- `maxHeight`: number - Sets the maximum height

### Margin Properties
- `margin`: number - Sets all margins
- `marginTop`: number - Sets top margin
- `marginRight`: number - Sets right margin
- `marginBottom`: number - Sets bottom margin
- `marginLeft`: number - Sets left margin

### Padding Properties
- `padding`: number - Sets all padding
- `paddingTop`: number - Sets top padding
- `paddingRight`: number - Sets right padding
- `paddingBottom`: number - Sets bottom padding
- `paddingLeft`: number - Sets left padding

### Position Properties
- `position`: "absolute" | "relative" - Sets positioning mode
- `top`: number - Sets top position offset
- `right`: number - Sets right position offset
- `bottom`: number - Sets bottom position offset
- `left`: number - Sets left position offset

## Test Example

The example app in `example/App.tsx` has been updated to demonstrate these properties:

```tsx
// Width & Height Test
<NitroTextInput
  placeholder="Width & Height Test"
  width={300}
  height={50}
  style={{
    backgroundColor: "#f0f0f0",
    borderWidth: 1,
    borderColor: "#ccc",
    textAlign: "center"
  }}
/>

// Margin Test
<NitroTextInput
  placeholder="Margin Test"  
  margin={20}
  style={{
    backgroundColor: "#e0e0ff",
    borderWidth: 1,
    borderColor: "#0000cc"
  }}
/>

// Padding Test
<NitroTextInput
  placeholder="Padding Test"
  padding={15}
  style={{
    backgroundColor: "#ffe0e0",
    borderWidth: 1,
    borderColor: "#cc0000"
  }}
/>

// Specific Padding Test
<NitroTextInput
  placeholder="Specific Padding"
  paddingLeft={30}
  paddingRight={10}
  paddingTop={20}
  paddingBottom={5}
  style={{
    backgroundColor: "#e0ffe0",
    borderWidth: 1,
    borderColor: "#00cc00"
  }}
/>

// Position Test
<NitroTextInput
  placeholder="Position Test"
  position="relative"
  top={10}
  left={20}
  style={{
    backgroundColor: "#ffffe0",
    borderWidth: 1,
    borderColor: "#cccc00"
  }}
/>
```

## Implementation Details

### iOS Implementation
The style properties are implemented in `ios/HybridTextInputView.swift`:

1. **Property Declarations**: Each style property is declared with a `didSet` observer that calls `applyLayoutStyles()`
2. **Layout Application**: The `applyLayoutStyles()` method applies:
   - Width/height constraints using Auto Layout
   - Padding using leftView/rightView for horizontal and textRect overrides for vertical
   - Margin by adjusting the frame
   - Position using transforms (relative) or frame positioning (absolute)

3. **CustomTextField Extensions**: Extended to support vertical padding through textRect overrides

### Generated Code
- TypeScript definitions are automatically generated
- C++ bridge code handles prop passing
- Swift protocol includes all new properties
- ViewConfig includes validation for all properties

## Testing

To test the implementation:

1. Navigate to the example directory: `cd example`
2. Install dependencies: `npm install` 
3. Run on iOS: `npm run ios`
4. Observe the different text inputs with various style properties applied

## Notes

- All measurements are in logical pixels (pt)
- Position properties work within the parent container
- Padding affects text positioning within the input
- Margin affects the input's position relative to its container
- The implementation follows React Native's style system conventions