import 'package:ballys_reservation_app/models/guest_reservation_entryBallys.dart';

/// The airport fast-track a guest's package entitles them to. Ordered, so a
/// higher tier also covers everything below it — a Gold guest may still take
/// Silk Route.
enum AirportRouteTier { none, silk, gold }

const _inrCurrencies = {'IND', 'INR'};
const _usdCurrencies = {'USD'};

/// The tier a single package amount (e.g. `"IND 2,500,000"`, `"USD 10,000"`)
/// earns on its own:
///   * Gold — INR 10M and above, or USD 50,000 and above.
///   * Silk — INR 2.5M and above, or USD 10,000 and above.
/// Any other currency, or no amount at all, earns nothing.
AirportRouteTier routeTierForAmount(String packageAmount) {
  final text = packageAmount.trim().toUpperCase();
  final currency = RegExp(r'^[A-Z]+').stringMatch(text) ?? '';
  final value =
      double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

  if (_inrCurrencies.contains(currency)) {
    if (value >= 10000000) return AirportRouteTier.gold;
    if (value >= 2500000) return AirportRouteTier.silk;
  } else if (_usdCurrencies.contains(currency)) {
    if (value >= 50000) return AirportRouteTier.gold;
    if (value >= 10000) return AirportRouteTier.silk;
  }
  return AirportRouteTier.none;
}

/// Each guest's tier once shared packages are taken into account: everyone
/// sharing a package — directly through "Shared with", or through somebody
/// else on the same share — gets the best tier anyone in that group earns.
/// Returned in the same order as [guests].
List<AirportRouteTier> routeTiersForGuests(List<AccompanyingMember> guests) {
  final tiers = guests.map((g) => routeTierForAmount(g.packageAmount)).toList();

  // Guests are linked by BM number; one with no BM number can't be named in
  // anybody's "Shared with", so it only ever stands alone.
  final byMid = <String, List<int>>{};
  for (var i = 0; i < guests.length; i++) {
    final mid = guests[i].mid.trim();
    if (mid.isNotEmpty) byMid.putIfAbsent(mid, () => []).add(i);
  }

  final links = List.generate(guests.length, (_) => <int>{});
  for (var i = 0; i < guests.length; i++) {
    for (final mid in guests[i].sharedWith) {
      for (final j in byMid[mid.trim()] ?? const <int>[]) {
        if (j == i) continue;
        links[i].add(j);
        links[j].add(i);
      }
    }
  }

  final result = List<AirportRouteTier>.from(tiers);
  final seen = List<bool>.filled(guests.length, false);
  for (var start = 0; start < guests.length; start++) {
    if (seen[start]) continue;
    final group = <int>[];
    final stack = [start];
    seen[start] = true;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      group.add(i);
      for (final j in links[i]) {
        if (!seen[j]) {
          seen[j] = true;
          stack.add(j);
        }
      }
    }
    final best = group
        .map((i) => tiers[i])
        .reduce((a, b) => a.index >= b.index ? a : b);
    for (final i in group) {
      result[i] = best;
    }
  }
  return result;
}
