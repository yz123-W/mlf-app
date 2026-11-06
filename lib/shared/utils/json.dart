/// 统一 JSON 取值工具。
///
/// 后端字段类型不稳定（int / num / string 混用），各 API/模型文件此前各自实现
/// `_asInt` / `_asString` / `_rows`，此处收口为一处，避免行为不一致。
library;

/// 取整数，兼容 int / num / string，无法解析时返回 [fallback]。
int asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// 取字符串，`null` 时返回 [fallback]。
String asString(Object? value, {String fallback = ''}) =>
    value == null ? fallback : value.toString();

/// 取可空字符串，`null` 或空串返回 `null`。
String? asNullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

/// 把任意值转为 `List<Map<String, dynamic>>`，非列表 / 非对象元素直接忽略。
List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is List) {
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}

/// 取分页响应中的 `rows`。
List<Map<String, dynamic>> rowsOf(Map<String, dynamic> res) => asMapList(res['rows']);
