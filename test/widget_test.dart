// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:slimeice/main.dart';

void main() {
  testWidgets('Music player smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SlimeIce());

    // Verify that the app title is present.
    expect(find.text('史莱姆冰'), findsOneWidget);

    // Verify that songs are displayed.
    expect(find.text('Song 1 - Artist A'), findsWidgets);
    expect(find.text('Song 2 - Artist B'), findsOneWidget);

    // Verify play button is present.
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
