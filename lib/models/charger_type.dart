/// [APT-Prj/api/_lib/defaults.js] chargerTypes 와 동일.
class ChargerType {
  const ChargerType({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultCount,
    required this.badgeClass,
  });

  final String id;
  final String name;
  final String description;
  final int defaultCount;
  final String badgeClass;
}

const List<ChargerType> chargerTypes = <ChargerType>[
  ChargerType(
    id: 'fast50',
    name: '50kW 급속',
    description: 'B1 1면 / B2 2면',
    defaultCount: 3,
    badgeClass: 'fast',
  ),
  ChargerType(
    id: 'slow7',
    name: '7kW 완속',
    description: 'B1 2면 / B2 9면',
    defaultCount: 11,
    badgeClass: 'mid',
  ),
  ChargerType(
    id: 'slow3',
    name: '3kW 완속',
    description: 'B1 2면 / B2 12면',
    defaultCount: 14,
    badgeClass: 'slow',
  ),
];

ChargerType? chargerTypeById(String id) {
  for (final t in chargerTypes) {
    if (t.id == id) return t;
  }
  return null;
}
