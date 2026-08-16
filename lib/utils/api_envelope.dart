/// Helpers for the backend's response envelope.
///
/// Transit endpoints historically returned a flat list under `data`:
///   `{ "status": 200, "data": [ ... ] }`
/// and now wrap the payload one layer deeper:
///   `{ "status": 200, "data": { "count": N, "items": [ ... ] } }`
/// These helpers accept both shapes so parsing keeps working either way.
library;

/// Returns the item list from a decoded envelope, tolerating both the legacy
/// flat `data: [...]` and the nested `data: { "items": [...] }` shape.
/// Returns `const []` when neither shape matches.
List<dynamic> extractItems(Map<String, dynamic> decoded) {
  final data = decoded['data'];
  if (data is List) return data;
  if (data is Map<String, dynamic>) {
    final items = data['items'];
    if (items is List) return items;
    final nested = data['data'];
    if (nested is List) return nested;
  }
  return const [];
}

/// Returns the payload object wrapped by `data` (single-object endpoints such
/// as the schedule), falling back to the whole decoded map when there is no
/// wrapper.
Map<String, dynamic> unwrapData(Map<String, dynamic> decoded) {
  final data = decoded['data'];
  if (data is Map<String, dynamic>) return data;
  return decoded;
}
