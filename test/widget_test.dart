import 'package:dart_model_convert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the converter and generates the example', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ModelMintApp());
    await tester.pump();

    expect(find.text('ModelMint'), findsOneWidget);
    expect(find.text('JSON input'), findsOneWidget);
    expect(find.text('Generated models'), findsOneWidget);
    expect(find.text('5 classes'), findsOneWidget);

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(3));
    expect(fields.last.controller!.text, contains('class BookingResponse'));
    expect(fields.last.controller!.text, contains('class Row'));
  });
}
