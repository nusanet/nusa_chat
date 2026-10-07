/// Formatting helpers for chat timestamps.
class DateHelper {
  const DateHelper._();

  /// `HH:mm` in local time, as shown under every bubble (e.g. "10:10").
  static String formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Parses the server `created_at` (ISO 8601, or MySQL `yyyy-MM-dd HH:mm:ss` treated as UTC).
  static DateTime? tryParseServerDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.contains('T') ? value : '${value.replaceFirst(' ', 'T')}Z';
    return DateTime.tryParse(normalized);
  }
}
