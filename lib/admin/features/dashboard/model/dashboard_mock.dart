class TopProductStat {
  final String emoji;
  final String name;
  final double revenue;

  const TopProductStat({
    required this.emoji,
    required this.name,
    required this.revenue,
  });
}

class DashboardMock {
  DashboardMock._();

  static const weeklyRevenue = <double>[620, 540, 710, 830, 760, 910, 842];
  static const todayRevenue = 842.0;
  static const todayProfit = 214.0;
  static const todayTickets = 47;
  static const yesterdayRevenue = 760.0;

  static const topProducts = <TopProductStat>[
    TopProductStat(emoji: '🥜', name: 'Cacahuètes grillées', revenue: 214),
    TopProductStat(emoji: '🌰', name: 'Amandes décortiquées', revenue: 188),
    TopProductStat(emoji: '🥨', name: 'Pistaches grillées', revenue: 132),
    TopProductStat(emoji: '☕', name: 'Café torréfié Arabica', revenue: 96),
  ];
}
