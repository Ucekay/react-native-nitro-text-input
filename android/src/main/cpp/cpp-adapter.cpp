#include <jni.h>
#include "NitroTextInputOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::nitrotextinput::initialize(vm);
}
