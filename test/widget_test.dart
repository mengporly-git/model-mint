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
    expect(find.text('1 classes'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Root class'), findsNothing);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(3));
    expect(fields.last.controller!.text, contains('class Response'));
    expect(fields.last.controller!.text, contains('final String greeting;'));
    expect(fields.last.controller!.text, isNot(contains('int _int(')));
    final nameField = find.byWidget(fields.first);
    for (final field in [fields[1], fields.last]) {
      final span = field.controller!.buildTextSpan(
        context: tester.element(find.byWidget(field)),
        style: field.style,
        withComposing: false,
      );
      expect(span.toPlainText(), field.controller!.text);
      final colors = <Color>{};
      span.visitChildren((child) {
        if (child is TextSpan && child.style?.color != null) {
          colors.add(child.style!.color!);
        }
        return true;
      });
      expect(colors.length, greaterThan(2));
    }
    final jsonField = find.byWidget(fields[1]);
    expect(
      tester.getTopLeft(nameField).dy,
      lessThan(tester.getTopLeft(jsonField).dy),
    );
    expect(tester.getSize(nameField).width, greaterThan(148));
  });
}
