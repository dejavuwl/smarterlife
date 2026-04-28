import 'package:flutter_test/flutter_test.dart';
import 'package:smarterlife/widgets/metric_card.dart';
import 'package:flutter/material.dart';

void main() {
  group('MetricCard', () {
    testWidgets('displays label and value', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MetricCard(label: '当前体重', value: '72.5 kg'),
          ),
        ),
      );

      expect(find.text('当前体重'), findsOneWidget);
      expect(find.text('72.5 kg'), findsOneWidget);
    });
  });
}
