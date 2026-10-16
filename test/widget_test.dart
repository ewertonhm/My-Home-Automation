import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_home_automation/main.dart';
import 'package:my_home_automation/services/device_manager_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DeviceManagerProvider(),
        child: const MyHomeAutomationApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.text('Nenhuma conta conectada'), findsOneWidget);
    expect(find.text('Configurar Conexões'), findsOneWidget);
  });
}
