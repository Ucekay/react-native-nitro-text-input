package com.margelo.nitro.nitrotextinput;

import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.module.model.ReactModuleInfoProvider;
import com.facebook.react.TurboReactPackage;
import com.facebook.react.uimanager.ViewManager;
import com.margelo.nitro.core.HybridObject;
import com.margelo.nitro.nitrotextinput.views.HybridNitroTextInputViewManager;
import com.margelo.nitro.nitrotextinput.views.HybridNitroMultiLineTextInputViewManager;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.function.Supplier;

public class NitroTextInputPackage extends TurboReactPackage {
  @Nullable
  @Override
  public NativeModule getModule(String name, ReactApplicationContext reactContext) {
    return null;
  }

  @Override
  public ReactModuleInfoProvider getReactModuleInfoProvider() {
    return () -> {
        return new HashMap<>();
    };
  }

  @Override
  public List<ViewManager> createViewManagers(@NonNull ReactApplicationContext reactContext) {
    List<ViewManager> viewManagers = new ArrayList<>();
    viewManagers.add(new HybridNitroTextInputViewManager());
    viewManagers.add(new HybridNitroMultiLineTextInputViewManager());
    return viewManagers;
  }

  static {
    NitroTextInputOnLoad.initializeNative();
  }
}
