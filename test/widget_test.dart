import 'package:batterie/app.dart';
import 'package:batterie/constants/app_strings.dart';
import 'package:batterie/pages/profile/profile_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Energy Health tab shell', (WidgetTester tester) async {
    ProfileStore.instance.onboardingComplete.value = true;

    await tester.pumpWidget(const EnergyHealthApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.stacked_line_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsWidgets);
  });
}
