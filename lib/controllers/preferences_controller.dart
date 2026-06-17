import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marispeaks/helpers/dialog_helper.dart';
import 'package:marispeaks/i18n/app_languages.dart';
import 'package:marispeaks/config/theme_config.dart';

class PreferencesController extends GetxController {
  // Singleton instance
  static PreferencesController instance = Get.find();

  final RxBool isDarkMode = false.obs;
  final Rx<Locale> locale = Rx(const Locale('en'));
  final Rxn<String> chatWallpaperPath = Rxn();
  final Rxn<String> groupWallpaperPath = Rxn();
  final RxBool isAudioEnabled = true
      .obs; // ✅ Default ON (Bluetooth Call/PTT Mode to avoid breaking calls)

  final String _defaultLocale = 'en';

  // SharedPreferences keys
  static const String _themeModeKey = 'theme_mode';
  static const String _localeKey = 'locale';
  static const String _chatWallpaperKey = 'chat_wallpaper';
  static const String _audioEnabledKey = 'audio_enabled';

  @override
  void onInit() {
    _loadThemeMode();
    _loadLocale();
    _loadAudioEnabled();

    // Watchers
    ever(locale, (Locale value) {
      _saveLocale(value);
      Get.updateLocale(value);
    });

    ever(isDarkMode, (bool value) {
      _changeTheme(value);
    });

    ever(isAudioEnabled, (bool value) {
      saveAudioEnabled(value);
    });

    super.onInit();
  }

  /// ============================
  /// THEME
  /// ============================
  void _updateSystemOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      getSystemOverlayStyle(isDarkMode.value),
    );
  }

  void _changeTheme(bool isDark) {
    isDarkMode.value = isDark;
    Get.changeThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
    _updateSystemOverlay();
    _saveThemeMode(isDark);
  }

  Future<void> _saveThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeModeKey, isDark);
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeModeKey);
    isDarkMode.value = isDark ?? false;
    _updateSystemOverlay();
  }

  /// ============================
  /// LOCALE
  /// ============================
  void _updateLocale(String langCode) {
    locale.value = Locale(langCode.split('_').first);
  }

  Future<void> _saveLocale(Locale newLocale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, newLocale.toString());
  }

  bool _isLocaleSupported(String locale) {
    return AppLanguages().keys.containsKey(locale);
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);

    if (savedLocale == null) {
      final deviceLocale = Get.deviceLocale;
      final isSupported = _isLocaleSupported(deviceLocale.toString());
      _updateLocale(isSupported ? deviceLocale.toString() : _defaultLocale);
    } else {
      final isSupported = _isLocaleSupported(savedLocale);
      _updateLocale(isSupported ? savedLocale : _defaultLocale);
    }
  }

  /// ============================
  /// LANGUAGE NAME
  /// ============================
  Map<String, String> get language =>
      AppLanguages().keys[locale.value.toString()] ?? {};

  String get langName => language['lang_name'] ?? '';

  /// ============================
  /// AUDIO MODE (Agora Bluetooth)
  /// ============================
  Future<void> saveAudioEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_audioEnabledKey, enabled);
  }

  Future<void> _loadAudioEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_audioEnabledKey);
    isAudioEnabled.value = enabled ?? true; // Default ON
  }

  /// ============================
  /// CHAT WALLPAPER
  /// ============================
  Future<void> setChatWallpaper() async {
    final wallpaper = await DialogHelper.showPickImageDialog();
    if (wallpaper == null) return;
    chatWallpaperPath.value = wallpaper.path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatWallpaperKey, wallpaper.path);
  }

  Future<void> removeChatWallpaper() async {
    chatWallpaperPath.value = null;
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_chatWallpaperKey);
  }

  Future<void> getChatWallpaperPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_chatWallpaperKey);
    if (path == null) return;
    if (File(path).existsSync()) {
      chatWallpaperPath.value = path;
    }
  }

  /// ============================
  /// GROUP WALLPAPER
  /// ============================
  Future<void> setGroupWallpaper(String groupId) async {
    final wallpaper = await DialogHelper.showPickImageDialog();
    if (wallpaper == null) return;
    groupWallpaperPath.value = wallpaper.path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(groupId, wallpaper.path);
  }

  Future<void> removeGroupWallpaper(String groupId) async {
    groupWallpaperPath.value = null;
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(groupId);
  }

  Future<void> getGroupWallpaperPath(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(groupId);
    if (path == null) return;
    if (File(path).existsSync()) {
      groupWallpaperPath.value = path;
    }
  }
}
