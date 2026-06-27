class ScanEntry {
  final int id;
  final int productId;
  final DateTime scannedAt;

  const ScanEntry({
    required this.id,
    required this.productId,
    required this.scannedAt,
  });

  factory ScanEntry.fromMap(Map<String, dynamic> map) {
    return ScanEntry(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      scannedAt: DateTime.parse(map['scanned_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'scanned_at': scannedAt.toIso8601String(),
  };

  /// Friendly date string — e.g. "Today 14:32" / "Yesterday 09:10" / "12 Jun 08:45"
  String get displayTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(scannedAt.year, scannedAt.month, scannedAt.day);
    final hm =
        '${scannedAt.hour.toString().padLeft(2, '0')}:'
        '${scannedAt.minute.toString().padLeft(2, '0')}';

    if (day == today) return 'Today $hm';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $hm';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${scannedAt.day} ${months[scannedAt.month - 1]} $hm';
  }
}
