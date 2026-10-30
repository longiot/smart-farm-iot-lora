import 'package:shared_preferences/shared_preferences.dart';

class ThresholdManager {
  static ThresholdManager? _instance;
  static ThresholdManager get instance => _instance!;

  static Future<void> init() async {
    _instance = ThresholdManager._();
    await _instance!._load();
  }

  ThresholdManager._();

  // Defaults
  double tempHigh  = 35.0;
  double tempLow   = 15.0;
  double humHigh   = 90.0;
  double humLow    = 40.0;
  double lightHigh = 50000.0;
  double lightLow  = 1000.0;
  double soilHigh  = 80.0;
  double soilLow   = 30.0;

  // Device names
  String dev1Name = 'Thiết bị 1';
  String dev2Name = 'Thiết bị 2';
  String dev3Name = 'Thiết bị 3';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    tempHigh  = p.getDouble('tempHigh')  ?? tempHigh;
    tempLow   = p.getDouble('tempLow')   ?? tempLow;
    humHigh   = p.getDouble('humHigh')   ?? humHigh;
    humLow    = p.getDouble('humLow')    ?? humLow;
    lightHigh = p.getDouble('lightHigh') ?? lightHigh;
    lightLow  = p.getDouble('lightLow')  ?? lightLow;
    soilHigh  = p.getDouble('soilHigh')  ?? soilHigh;
    soilLow   = p.getDouble('soilLow')   ?? soilLow;
    dev1Name  = p.getString('dev1Name')  ?? dev1Name;
    dev2Name  = p.getString('dev2Name')  ?? dev2Name;
    dev3Name  = p.getString('dev3Name')  ?? dev3Name;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('tempHigh',  tempHigh);
    await p.setDouble('tempLow',   tempLow);
    await p.setDouble('humHigh',   humHigh);
    await p.setDouble('humLow',    humLow);
    await p.setDouble('lightHigh', lightHigh);
    await p.setDouble('lightLow',  lightLow);
    await p.setDouble('soilHigh',  soilHigh);
    await p.setDouble('soilLow',   soilLow);
    await p.setString('dev1Name',  dev1Name);
    await p.setString('dev2Name',  dev2Name);
    await p.setString('dev3Name',  dev3Name);
  }
}
