class AiEngine {
  /// Simple local AI insights - no network required
  static Map<String, dynamic> analyzeTransactions(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) return {'insight': 'Belum ada data transaksi'};

    double totalRevenue = 0;
    int totalTx = transactions.length;
    Map<String, double> byChannel = {};
    Map<String, int> byHour = {};

    for (final tx in transactions) {
      totalRevenue += (tx['final_amount'] ?? 0).toDouble();
      final channel = tx['channel'] ?? 'offline';
      byChannel[channel] = (byChannel[channel] ?? 0) + 1;
      final hour = DateTime.parse(tx['created_at'] ?? DateTime.now().toIso8601String()).hour.toString();
      byHour[hour] = (byHour[hour] ?? 0) + 1;
    }

    final peakHour = byHour.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final topChannel = byChannel.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'total_revenue': totalRevenue,
      'total_transactions': totalTx,
      'avg_transaction': totalTx > 0 ? totalRevenue / totalTx : 0,
      'peak_hour': peakHour,
      'top_channel': topChannel,
      'insight': _generateInsight(totalRevenue, totalTx, peakHour, topChannel),
    };
  }

  static String _generateInsight(double rev, int tx, String hour, String channel) {
    final buffer = StringBuffer();
    buffer.writeln('Total pendapatan: Rp ${rev.toStringAsFixed(0)}');
    buffer.writeln('Jumlah transaksi: $tx');
    buffer.writeln('Jam tersibuk: $hour:00');
    buffer.writeln('Channel terbanyak: $channel');
    return buffer.toString();
  }

  static List<String> getRecommendations(Map<String, dynamic> analysis) {
    final recs = <String>[];
    final hour = int.tryParse(analysis['peak_hour']?.toString() ?? '0') ?? 0;
    if (hour >= 11 && hour <= 14) recs.add('Siapkan stok ekstra saat jam makan siang');
    if (hour >= 17 && hour <= 20) recs.add('Tambahan karyawan shift sore direkomendasikan');
    if ((analysis['avg_transaction'] ?? 0) < 20000) recs.add('Pertimbangkan bundling produk untuk naikkan nilai transaksi');
    return recs;
  }
}