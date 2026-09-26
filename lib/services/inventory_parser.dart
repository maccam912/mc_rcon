/// Reads the SNBT list returned by `data get entity <player> Inventory`.
///
/// Parsing tokens instead of rewriting the response preserves quoted component
/// keys, JSON custom names, typed arrays, and numbers embedded in item lore.
class InventoryParser {
  static List<Map<String, dynamic>> parse(String response) {
    const prefix = ' has the following entity data:';
    final prefixPosition = response.indexOf(prefix);
    final source =
        (prefixPosition < 0
                ? response
                : response.substring(prefixPosition + prefix.length))
            .trim();
    if (!source.startsWith('[')) {
      throw const FormatException('The server did not return inventory data.');
    }
    final reader = _SnbtReader(source);
    final result = reader.readValue();
    reader.skipWhitespace();
    if (reader.position != reader.source.length || result is! List) {
      throw const FormatException('Incomplete or invalid inventory data.');
    }
    return result.map((entry) {
      if (entry is! Map<String, dynamic> || entry['id'] is! String) {
        throw const FormatException('Invalid item in inventory data.');
      }
      return entry;
    }).toList();
  }
}

class _SnbtReader {
  final String source;
  int position = 0;
  int _depth = 0;

  _SnbtReader(this.source);

  Never _fail() =>
      throw FormatException('Invalid SNBT inventory data', source, position);

  void skipWhitespace() {
    while (position < source.length && source[position].trim().isEmpty) {
      position++;
    }
  }

  bool _consume(String token) {
    skipWhitespace();
    if (position < source.length && source[position] == token) {
      position++;
      return true;
    }
    return false;
  }

  dynamic readValue() {
    skipWhitespace();
    if (position >= source.length || ++_depth > 128) _fail();
    try {
      switch (source[position]) {
        case '{':
          return _readCompound();
        case '[':
          return _readList();
        case '"':
        case "'":
          return _readQuoted();
        default:
          final token = _readBare();
          if (token == 'true') return true;
          if (token == 'false') return false;
          final number = token.replaceFirst(RegExp(r'[bBsSlLfFdD]$'), '');
          return num.tryParse(number) ?? token;
      }
    } finally {
      _depth--;
    }
  }

  Map<String, dynamic> _readCompound() {
    position++;
    final result = <String, dynamic>{};
    if (_consume('}')) return result;
    do {
      skipWhitespace();
      if (position >= source.length) _fail();
      final key = source[position] == '"' || source[position] == "'"
          ? _readQuoted()
          : _readBare(isKey: true);
      if (!_consume(':')) _fail();
      result[key] = readValue();
      if (_consume('}')) return result;
      if (!_consume(',')) _fail();
    } while (true);
  }

  List<dynamic> _readList() {
    position++;
    skipWhitespace();
    // Typed byte/int/long arrays occur in custom data and attribute UUIDs.
    if (position + 1 < source.length &&
        'BIL'.contains(source[position]) &&
        source[position + 1] == ';') {
      position += 2;
    }
    final result = <dynamic>[];
    if (_consume(']')) return result;
    do {
      result.add(readValue());
      if (_consume(']')) return result;
      if (!_consume(',')) _fail();
    } while (true);
  }

  String _readBare({bool isKey = false}) {
    skipWhitespace();
    final start = position;
    while (position < source.length) {
      final char = source[position];
      if (char.trim().isEmpty ||
          ',]}'.contains(char) ||
          (isKey && char == ':')) {
        break;
      }
      position++;
    }
    if (position == start) _fail();
    return source.substring(start, position);
  }

  String _readQuoted() {
    final quote = source[position++];
    final result = StringBuffer();
    while (position < source.length) {
      var char = source[position++];
      if (char == quote) return result.toString();
      if (char == r'\') {
        if (position >= source.length) _fail();
        char = source[position++];
        const escapes = {'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f'};
        if (char == 'u' || char == 'x') {
          final length = char == 'u' ? 4 : 2;
          if (position + length > source.length) _fail();
          final code = int.tryParse(
            source.substring(position, position + length),
            radix: 16,
          );
          if (code == null) _fail();
          result.writeCharCode(code);
          position += length;
          continue;
        }
        result.write(escapes[char] ?? char);
      } else {
        result.write(char);
      }
    }
    _fail();
  }
}
