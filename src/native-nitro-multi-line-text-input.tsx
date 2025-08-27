import { getHostComponent } from "react-native-nitro-modules";
import ViewConfig from "../nitrogen/generated/shared/json/NitroMultiLineTextInputViewConfig.json";
import type {
  NitroMultiLineTextInputViewMethods,
  NitroMultiLineTextInputViewProps,
} from "./specs/multi-line-text-input-view.nitro";

/**
 * The native Nitro multi-line text input view.
 */
export const NativeNitroMultiLineTextInput = getHostComponent<
  NitroMultiLineTextInputViewProps,
  NitroMultiLineTextInputViewMethods
>("NitroMultiLineTextInputView", () => ViewConfig);

export type NativeNitroMultiLineTextInputRef = {
  current?: NitroMultiLineTextInputViewMethods | null;
};