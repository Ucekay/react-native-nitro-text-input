export { NitroTextInput } from "./nitro-text-input";
export type {
	NitroTextInputViewMethods,
	NitroTextInputViewProps,
} from "./specs/text-input-view.nitro";
export type {
	NitroMultiLineTextInputViewMethods,
	NitroMultiLineTextInputViewProps,
} from "./specs/multi-line-text-input-view.nitro";

import type { HybridRef } from "react-native-nitro-modules";
import type {
	NitroTextInputViewMethods,
	NitroTextInputViewProps,
} from "./specs/text-input-view.nitro";
import type {
	NitroMultiLineTextInputViewMethods,
	NitroMultiLineTextInputViewProps,
} from "./specs/multi-line-text-input-view.nitro";

// 便利な型エイリアスとして提供
export type NitroTextInputRef = HybridRef<
	NitroTextInputViewProps,
	NitroTextInputViewMethods
>;

export type NitroMultiLineTextInputRef = HybridRef<
	NitroMultiLineTextInputViewProps,
	NitroMultiLineTextInputViewMethods
>;
