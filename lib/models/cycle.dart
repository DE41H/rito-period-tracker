class Cycle {
  final DateTime start;
  final DateTime end;
  final Duration periodLength;
  final bool isIrregular;

  const Cycle({
    required this.start,
    required this.end,
    required this.periodLength,
    this.isIrregular = false,
  });
}