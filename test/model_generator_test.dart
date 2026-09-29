import 'package:dart_model_convert/src/model_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DartModelGenerator', () {
    final generator = DartModelGenerator();

    test('generates the BookingResponse structure with safe defaults', () {
      final result = generator.generate(
        rootClassName: 'BookingResponse',
        json: {
          'code': 200,
          'status': 'success',
          'data': {
            'pagination': {
              'total': 58,
              'per_page': 20,
              'current_page': 1,
              'last_page': 3,
            },
            'rows': [
              {
                'id': '1234',
                'booking_no': 'BR-001234',
                'is_special_request': true,
                'special_request_expiry': {
                  'expiry_duration': 3,
                  'expiry_unit': 'hour',
                },
              },
            ],
          },
        },
      );

      expect(result.classCount, 5);
      expect(result.code, contains('class BookingResponse'));
      expect(result.code, contains('final Booking data;'));
      expect(result.code, contains('class Pagination'));
      expect(result.code, contains('final List<Row> rows;'));
      expect(result.code, contains("id: _string(json['id'])"));
      expect(result.code, contains("total: _int(json['total'])"));
      expect(
        result.code,
        contains("isSpecialRequest: _bool(json['is_special_request'])"),
      );
      expect(
        result.code,
        contains(
          "SpecialRequestExpiry.fromJson(_map(json['special_request_expiry']))",
        ),
      );
    });

    test('supports strings, integers, doubles, booleans, maps, and lists', () {
      final result = generator.generate(
        rootClassName: 'Example',
        json: {
          'name': null,
          'count': 2,
          'ratio': 1.5,
          'enabled': false,
          'metadata': <String, dynamic>{},
          'scores': [1, 2.5, null],
        },
      );

      expect(result.code, contains('final String name;'));
      expect(result.code, contains('final int count;'));
      expect(result.code, contains('final double ratio;'));
      expect(result.code, contains('final bool enabled;'));
      expect(result.code, contains('final Map<String, dynamic> metadata;'));
      expect(result.code, contains('final List<double> scores;'));
      expect(result.code, contains("metadata: _map(json['metadata'])"));
      expect(
        result.code,
        contains(
          "scores: (json['scores'] as List? ?? []).map(_double).toList()",
        ),
      );
    });

    test('merges fields found in later list objects', () {
      final result = generator.generate(
        rootClassName: 'PeopleResponse',
        json: {
          'people': [
            {'name': 'Ada'},
            {'name': 'Grace', 'active': true},
          ],
        },
      );

      expect(result.code, contains('class People'));
      expect(result.code, contains('final String name;'));
      expect(result.code, contains('final bool active;'));
    });

    test('sanitizes identifiers and Dart reserved words', () {
      final result = generator.generate(
        rootClassName: '123 response',
        json: {'class': 'value', 'first-name': 'Ada'},
      );

      expect(result.code, contains('class Model123Response'));
      expect(result.code, contains('final String classValue;'));
      expect(result.code, contains('final String firstName;'));
    });

    test('rejects unsupported root values', () {
      expect(
        () => generator.generate(json: 12, rootClassName: 'Value'),
        throwsFormatException,
      );
    });

    test('generates a valid empty root class', () {
      final result = generator.generate(json: {}, rootClassName: 'Empty');

      expect(result.classCount, 1);
      expect(result.code, contains('class Empty'));
      expect(result.code, contains('Empty();'));
      expect(result.code, contains('factory Empty.fromJson'));
    });
  });
}
