import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/reasoning_budget_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestHost(String modelId) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AssistantProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReasoningBudgetSheet(
                context,
                modelProvider: 'openai',
                modelId: modelId,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('reasoning budget sheet shows xhigh for supported GPT-5 models', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestHost('gpt-5.2'));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Extreme Reasoning'), findsOneWidget);
  });

  testWidgets(
    'reasoning budget sheet hides xhigh for unsupported GPT-5 models',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildTestHost('gpt-5.1'));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Extreme Reasoning'), findsNothing);
    },
  );
}
