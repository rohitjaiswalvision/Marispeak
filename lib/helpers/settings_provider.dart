import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  double _aisRange = 20;
  double _userRange = 10;
  String _speedFormat = "km/h";
  String _windFormat = "m/s";
  String _RangeFormat = "km's";
  String _tempUnit = "C";

  double get aisRange => _aisRange;
  double get userRange => _userRange;
  String get speedFormat => _speedFormat;
  String get windFormat => _windFormat;
  String get RangeFormat => _RangeFormat;
  String get tempUnit => _tempUnit;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _aisRange = prefs.getDouble('aisRange') ?? 20;
    _userRange = prefs.getDouble('userRange') ?? 10;
    _speedFormat = prefs.getString('speedFormat') ?? "km/h";
    _windFormat = prefs.getString('windFormat') ?? "km/h";
    _RangeFormat = prefs.getString('rangeFormat') ?? "km's";
    _tempUnit = prefs.getString('tempUnit') ?? "C";
    notifyListeners();
  }



  Future<void> setAisRange(double value) async {
    _aisRange = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('aisRange', value);
  }

  Future<void> setUserRange(double value) async {
    _userRange = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('userRange', value);
  }

  Future<void> setSpeedFormat(String format) async {
    _speedFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('speedFormat', format);
  }

  Future<void> setWindFormat(String format) async {
    _windFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('windFormat', format);
  }

  Future<void> settempUnit(String format) async {
    _tempUnit = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('tempUnit', format);
  }

  Future<void> setRangeFormat(String format) async {
    _RangeFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('rangeFormat', format);
  }
}
