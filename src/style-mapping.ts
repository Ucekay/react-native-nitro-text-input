import type { TextStyle } from "react-native";
import { processColor } from "react-native";
import type { TextAttributes } from "./specs/text-input-view.nitro";

/**
 * Maps React Native text style properties to TextAttributes format
 */
export function mapStyleToTextAttributes(style: TextStyle | undefined): TextAttributes | undefined {
	if (!style) return undefined;

	const textAttributes: TextAttributes = {};

	// Map color
	if (style.color !== undefined) {
		const processed = processColor(style.color);
		if (processed != null) {
			textAttributes.color = typeof processed === "number" 
				? processed 
				: JSON.stringify(processed);
		}
	}

	// Map fontSize
	if (style.fontSize !== undefined) {
		textAttributes.fontSize = style.fontSize;
	}

	// Map fontStyle
	if (style.fontStyle !== undefined) {
		textAttributes.fontStyle = style.fontStyle;
	}

	// Map fontWeight
	if (style.fontWeight !== undefined) {
		textAttributes.fontWeight = style.fontWeight;
	}

	// Map letterSpacing
	if (style.letterSpacing !== undefined) {
		textAttributes.letterSpacing = style.letterSpacing;
	}

	// Map lineHeight
	if (style.lineHeight !== undefined) {
		textAttributes.lineHeight = style.lineHeight;
	}

	// Map textAlign
	if (style.textAlign !== undefined) {
		// Map React Native textAlign to TextAttributes textAlign
		switch (style.textAlign) {
			case 'auto':
				textAttributes.textAlign = 'auto';
				break;
			case 'left':
				textAttributes.textAlign = 'left';
				break;
			case 'right':
				textAttributes.textAlign = 'right';
				break;
			case 'center':
				textAttributes.textAlign = 'center';
				break;
			case 'justify':
				textAttributes.textAlign = 'justify';
				break;
		}
	}

	// Map textDecorationColor
	if (style.textDecorationColor !== undefined) {
		const processed = processColor(style.textDecorationColor);
		if (processed != null) {
			textAttributes.textDecorationColor = typeof processed === "number" 
				? processed 
				: JSON.stringify(processed);
		}
	}

	// Map textDecorationLine
	if (style.textDecorationLine !== undefined) {
		textAttributes.textDecorationLine = style.textDecorationLine;
	}

	// Map textDecorationStyle
	if (style.textDecorationStyle !== undefined) {
		textAttributes.textDecorationStyle = style.textDecorationStyle;
	}

	// Return undefined if no text attributes were set
	return Object.keys(textAttributes).length > 0 ? textAttributes : undefined;
}