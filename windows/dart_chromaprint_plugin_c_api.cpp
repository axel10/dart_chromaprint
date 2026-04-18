#include "include/dart_chromaprint/dart_chromaprint_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "dart_chromaprint_plugin.h"

void DartChromaprintPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  dart_chromaprint::DartChromaprintPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
