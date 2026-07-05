import 'package:batterie/app.dart';
import 'package:batterie/constants/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Energy Health tab shell', (WidgetTester tester) async {
    await tester.pumpWidget(const EnergyHealthApp());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.youTab), findsOneWidget);
    expect(find.text(AppStrings.othersTab), findsOneWidget);
    expect(find.text(AppStrings.newsTab), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
