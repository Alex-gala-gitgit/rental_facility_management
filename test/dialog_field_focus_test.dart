import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';

void main() {
  testWidgets('focused dialog field scrolls into the visible area',
      (tester) async {
    final fieldKey = GlobalKey();
    final controller = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 700),
                  TextField(
                    key: fieldKey,
                    onTap: () => keepDialogFieldVisible(fieldKey),
                  ),
                  const SizedBox(height: 160),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(controller.offset, 0);
    keepDialogFieldVisible(fieldKey);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    expect(tester.getBottomLeft(find.byKey(fieldKey)).dy, lessThan(360));
  });
}
