enum _ValueKind {
  nullValue,
  string,
  integer,
  decimal,
  boolean,
  object,
  list,
  map,
}

class GeneratorResult {
  const GeneratorResult({required this.code, required this.classCount});
  final String code;
  final int classCount;
}

class DartModelGenerator {
  GeneratorResult generate({
    required Object? json,
    required String rootClassName,
  }) {
    final rootName = _className(rootClassName, fallback: 'ApiResponse');
    if (json is Map) {
      final models = <String, _Shape>{};
      final root = _Shape.object({
        for (final entry in json.entries)
          entry.key.toString(): _shapeFromValue(entry.value),
      });
      _collectModel(rootName, root, models, isRoot: true);
      return GeneratorResult(
        code: _renderModels(models),
        classCount: models.length,
      );
    }
    if (json is List) {
      final item = _shapeForList(json);
      if (item.kind != _ValueKind.object) {
        throw const FormatException('A root JSON array must contain objects.');
      }
      final models = <String, _Shape>{};
      _collectModel(rootName, item, models, isRoot: true);
      final helper =
          '''List<$rootName> ${_fieldName(rootName)}ListFromJson(dynamic json) {
  return (json as List? ?? [])
      .whereType<Map>()
      .map((item) => $rootName.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

''';
      return GeneratorResult(
        code: '$helper${_renderModels(models)}',
        classCount: models.length,
      );
    }
    throw const FormatException(
      'The JSON root must be an object or an array of objects.',
    );
  }

  void _collectModel(
    String name,
    _Shape shape,
    Map<String, _Shape> models, {
    required bool isRoot,
  }) {
    if (shape.kind != _ValueKind.object) return;
    models[name] = models[name] == null ? shape : _merge(models[name]!, shape);
    for (final entry in shape.properties.entries) {
      final child = entry.value;
      if (child.kind == _ValueKind.object) {
        _collectModel(
          _nestedClassName(
            parentName: name,
            jsonKey: entry.key,
            isRoot: isRoot,
          ),
          child,
          models,
          isRoot: false,
        );
      } else if (child.kind == _ValueKind.list &&
          child.item?.kind == _ValueKind.object) {
        _collectModel(
          _className(_singular(entry.key)),
          child.item!,
          models,
          isRoot: false,
        );
      }
    }
  }

  String _renderModels(Map<String, _Shape> models) {
    final buffer = StringBuffer();
    var index = 0;
    for (final entry in models.entries) {
      if (index > 0) buffer.writeln();
      buffer.write(_renderClass(entry.key, entry.value, isRoot: index == 0));
      index++;
    }
    final usedHelpers = <String>{};
    void collectHelpers(_Shape shape) {
      switch (shape.kind) {
        case _ValueKind.integer:
          usedHelpers.add('_int');
        case _ValueKind.decimal:
          usedHelpers.add('_double');
        case _ValueKind.boolean:
          usedHelpers.add('_bool');
        case _ValueKind.object:
        case _ValueKind.map:
          usedHelpers.add('_map');
        case _ValueKind.list:
          collectHelpers(shape.item ?? _Shape.string());
        case _ValueKind.nullValue:
        case _ValueKind.string:
          usedHelpers.add('_string');
      }
    }

    for (final model in models.values) {
      for (final field in model.properties.values) {
        collectHelpers(field);
      }
    }
    if (usedHelpers.contains('_string')) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('String _string(dynamic value) {')
        ..writeln("  if (value == null) return '';")
        ..writeln('  return value.toString();')
        ..writeln('}');
    }
    if (usedHelpers.contains('_int')) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('int _int(dynamic value) {')
        ..writeln('  if (value is int) return value;')
        ..writeln('  if (value is num) return value.toInt();')
        ..writeln("  return int.tryParse(value?.toString() ?? '') ?? 0;")
        ..writeln('}');
    }
    if (usedHelpers.contains('_double')) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('double _double(dynamic value) {')
        ..writeln('  if (value is num) return value.toDouble();')
        ..writeln("  return double.tryParse(value?.toString() ?? '') ?? 0.0;")
        ..writeln('}');
    }
    if (usedHelpers.contains('_bool')) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('bool _bool(dynamic value) {')
        ..writeln('  if (value is bool) return value;')
        ..writeln('  if (value is num) return value != 0;')
        ..writeln(
          "  final text = value?.toString().trim().toLowerCase() ?? '';",
        )
        ..writeln("  return text == 'true' || text == '1' || text == 'yes';")
        ..writeln('}');
    }
    if (usedHelpers.contains('_map')) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('Map<String, dynamic> _map(dynamic value) {')
        ..writeln('  if (value is! Map) return <String, dynamic>{};')
        ..writeln('  return Map<String, dynamic>.from(value);')
        ..writeln('}');
    }
    return buffer.toString().trimRight();
  }

  String _renderClass(String name, _Shape shape, {required bool isRoot}) {
    final fields = shape.properties.entries.toList();
    final buffer = StringBuffer()..writeln('class $name {');
    for (final field in fields) {
      buffer.writeln(
        '  final ${_dartType(field.value, name, field.key, isRoot)} ${_fieldName(field.key)};',
      );
    }
    if (fields.isNotEmpty) buffer.writeln();
    if (fields.isEmpty) {
      buffer.writeln('  $name();');
    } else if (fields.length <= 2) {
      buffer.writeln(
        '  $name({${fields.map((e) => 'required this.${_fieldName(e.key)}').join(', ')}});',
      );
    } else {
      buffer.writeln('  $name({');
      for (final field in fields) {
        buffer.writeln('    required this.${_fieldName(field.key)},');
      }
      buffer.writeln('  });');
    }
    buffer
      ..writeln()
      ..writeln('  factory $name.fromJson(Map<String, dynamic> json) {')
      ..writeln('    return $name(');
    for (final field in fields) {
      buffer.writeln(
        '      ${_fieldName(field.key)}: ${_decoder(field.value, name, field.key, isRoot)},',
      );
    }
    buffer
      ..writeln('    );')
      ..writeln('  }')
      ..writeln('}');
    return buffer.toString().trimRight();
  }

  String _dartType(_Shape shape, String parent, String key, bool isRoot) {
    switch (shape.kind) {
      case _ValueKind.integer:
        return 'int';
      case _ValueKind.decimal:
        return 'double';
      case _ValueKind.boolean:
        return 'bool';
      case _ValueKind.object:
        return _nestedClassName(
          parentName: parent,
          jsonKey: key,
          isRoot: isRoot,
        );
      case _ValueKind.map:
        return 'Map<String, dynamic>';
      case _ValueKind.list:
        return 'List<${_listItemType(shape.item ?? _Shape.string(), key)}>';
      case _ValueKind.nullValue:
      case _ValueKind.string:
        return 'String';
    }
  }

  String _listItemType(_Shape item, String key) {
    switch (item.kind) {
      case _ValueKind.integer:
        return 'int';
      case _ValueKind.decimal:
        return 'double';
      case _ValueKind.boolean:
        return 'bool';
      case _ValueKind.object:
        return _className(_singular(key));
      case _ValueKind.map:
        return 'Map<String, dynamic>';
      case _ValueKind.list:
        return 'List<${_listItemType(item.item ?? _Shape.string(), key)}>';
      case _ValueKind.nullValue:
      case _ValueKind.string:
        return 'String';
    }
  }

  String _decoder(_Shape shape, String parent, String key, bool isRoot) {
    final access = "json['${key.replaceAll("'", "\\'")}']";
    switch (shape.kind) {
      case _ValueKind.integer:
        return '_int($access)';
      case _ValueKind.decimal:
        return '_double($access)';
      case _ValueKind.boolean:
        return '_bool($access)';
      case _ValueKind.map:
        return '_map($access)';
      case _ValueKind.object:
        final type = _nestedClassName(
          parentName: parent,
          jsonKey: key,
          isRoot: isRoot,
        );
        return '$type.fromJson(_map($access))';
      case _ValueKind.list:
        return _listDecoder(shape.item ?? _Shape.string(), key, access);
      case _ValueKind.nullValue:
      case _ValueKind.string:
        return '_string($access)';
    }
  }

  String _listDecoder(_Shape item, String key, String access) {
    final prefix = '($access as List? ?? [])';
    switch (item.kind) {
      case _ValueKind.integer:
        return '$prefix.map(_int).toList()';
      case _ValueKind.decimal:
        return '$prefix.map(_double).toList()';
      case _ValueKind.boolean:
        return '$prefix.map(_bool).toList()';
      case _ValueKind.object:
        final type = _className(_singular(key));
        return '$prefix\n          .whereType<Map>()\n          .map((item) => $type.fromJson(_map(item)))\n          .toList()';
      case _ValueKind.map:
        return '$prefix.whereType<Map>().map(_map).toList()';
      case _ValueKind.list:
        return '$prefix.whereType<List>().map((item) => ${_listDecoder(item.item ?? _Shape.string(), key, 'item')}).toList()';
      case _ValueKind.nullValue:
      case _ValueKind.string:
        return '$prefix.map(_string).toList()';
    }
  }

  _Shape _shapeFromValue(Object? value) {
    if (value == null) return _Shape.nullValue();
    if (value is bool) return _Shape.boolean();
    if (value is int) return _Shape.integer();
    if (value is double || value is num) return _Shape.decimal();
    if (value is String) return _Shape.string();
    if (value is List) return _Shape.list(_shapeForList(value));
    if (value is Map) {
      if (value.isEmpty) return _Shape.map();
      return _Shape.object({
        for (final e in value.entries)
          e.key.toString(): _shapeFromValue(e.value),
      });
    }
    return _Shape.string();
  }

  _Shape _shapeForList(List<dynamic> values) {
    if (values.isEmpty) return _Shape.string();
    var shape = _shapeFromValue(values.first);
    for (final value in values.skip(1)) {
      shape = _merge(shape, _shapeFromValue(value));
    }
    return shape.kind == _ValueKind.nullValue ? _Shape.string() : shape;
  }

  _Shape _merge(_Shape left, _Shape right) {
    if (left.kind == _ValueKind.nullValue) return right;
    if (right.kind == _ValueKind.nullValue) return left;
    if (left.kind == right.kind) {
      if (left.kind == _ValueKind.object) {
        final merged = <String, _Shape>{...left.properties};
        for (final entry in right.properties.entries) {
          merged[entry.key] = merged[entry.key] == null
              ? entry.value
              : _merge(merged[entry.key]!, entry.value);
        }
        return _Shape.object(merged);
      }
      if (left.kind == _ValueKind.list) {
        return _Shape.list(_merge(left.item!, right.item!));
      }
      return left;
    }
    final kinds = {left.kind, right.kind};
    if (kinds.every(
      (kind) => kind == _ValueKind.integer || kind == _ValueKind.decimal,
    )) {
      return _Shape.decimal();
    }
    return _Shape.string();
  }

  String _nestedClassName({
    required String parentName,
    required String jsonKey,
    required bool isRoot,
  }) {
    if (isRoot && jsonKey == 'data' && parentName.endsWith('Response')) {
      final base = parentName.substring(0, parentName.length - 8);
      if (base.isNotEmpty) return base;
    }
    return _className(jsonKey);
  }

  String _singular(String value) {
    final lower = value.toLowerCase();
    if (lower.endsWith('ies') && value.length > 3) {
      return '${value.substring(0, value.length - 3)}y';
    }
    if (lower.endsWith('sses')) return value.substring(0, value.length - 2);
    if (lower.endsWith('s') && !lower.endsWith('ss') && value.length > 1) {
      return value.substring(0, value.length - 1);
    }
    return '${value}Item';
  }

  String _className(String value, {String fallback = 'Model'}) {
    final words = value
        .trim()
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((word) => word.isNotEmpty);
    var result = words
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join();
    if (result.isEmpty) result = fallback;
    if (RegExp(r'^[0-9]').hasMatch(result)) result = 'Model$result';
    return _reserved.contains(result) ? '${result}Model' : result;
  }

  String _fieldName(String value) {
    final pascal = _className(value, fallback: 'value');
    final result = '${pascal[0].toLowerCase()}${pascal.substring(1)}';
    return _reserved.contains(result) ? '${result}Value' : result;
  }
}

class _Shape {
  const _Shape._(this.kind, {this.properties = const {}, this.item});
  factory _Shape.nullValue() => const _Shape._(_ValueKind.nullValue);
  factory _Shape.string() => const _Shape._(_ValueKind.string);
  factory _Shape.integer() => const _Shape._(_ValueKind.integer);
  factory _Shape.decimal() => const _Shape._(_ValueKind.decimal);
  factory _Shape.boolean() => const _Shape._(_ValueKind.boolean);
  factory _Shape.map() => const _Shape._(_ValueKind.map);
  factory _Shape.object(Map<String, _Shape> properties) =>
      _Shape._(_ValueKind.object, properties: properties);
  factory _Shape.list(_Shape item) => _Shape._(_ValueKind.list, item: item);
  final _ValueKind kind;
  final Map<String, _Shape> properties;
  final _Shape? item;
}

const _reserved = <String>{
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'while',
  'with',
  'yield',
};
