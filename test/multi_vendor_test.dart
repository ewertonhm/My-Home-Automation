import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_home_automation/models/unified_device.dart';
import 'package:my_home_automation/services/device_manager_provider.dart';
import 'package:my_home_automation/services/smartthings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('DeviceManagerProvider model and service initialization', () async {
    final provider = DeviceManagerProvider();
    provider.stService.updateConfig(const SmartThingsConfig(patToken: 'mock_token'));

    const lgAc = UnifiedDevice(
      id: 'lg_1',
      rawId: 'raw_lg_1',
      name: 'Ar Escritório',
      vendor: DeviceVendor.lg,
      type: DeviceType.airConditioner,
      isPowerOn: false,
    );

    const stTv = UnifiedDevice(
      id: 'st_1',
      rawId: 'raw_st_1',
      name: 'Samsung QN85BA',
      vendor: DeviceVendor.samsung,
      type: DeviceType.tv,
      isPowerOn: false,
    );

    expect(lgAc.isPowerOn, isFalse);
    expect(stTv.isPowerOn, isFalse);
    expect(provider.isStConnected, isTrue);
  });
}
