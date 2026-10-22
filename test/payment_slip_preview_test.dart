import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as images;
import 'package:rental_facility_management/main.dart' as app;

void main() {
  testWidgets('missing JPG bytes load before preview; failure can retry', (tester) async {
    final bill = app.MonthlyBill(id: 'test', facilityId: 'facility',
      tenantId: 'tenant', month: DateTime(2026, 10), rentAmount: 0,
      electricityAmount: 0, waterAmount: 0, internetAmount: 0,
      slipFileName: 'proof.JPG ');
    final first = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(app.RentalStoreScope(store: app.RentalStore(),
      child: MaterialApp(home: Builder(builder: (context) =>
      TextButton(onPressed: () => app.showPaymentSlipAttachmentDialog(context, bill,
        loadAttachment: () async {
          if (++calls == 1) return first.future;
          bill.slipBytes = Uint8List.fromList(images.encodeJpg(images.Image(width: 2, height: 2)));
          return true;
        }), child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    first.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_rounded), findsNothing);
    expect(calls, 2);
  });
}
