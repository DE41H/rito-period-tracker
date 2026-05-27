class Log {
  final DateTime date;
  final Flow flow;
  final Set<Symptom> symptoms;
  final Mood? mood;
  final Discharge? discharge;
  final int? stress;
  final int? sleep;
  final String? notes;

  const Log({
    required this.date,
    required this.flow,
    this.symptoms = const {},
    this.mood,
    this.discharge,
    this.stress,
    this.sleep,
    this.notes,
  });
}

enum Flow {
  none(0),
  light(1),
  medium(2),
  heavy(3);

  final int value;
  const Flow(this.value);
}

enum Symptom {
  periodCramps(0),
  ovulationPain(1),
  tenderBreasts(2),
  headache(3),
  fatigue(4),
  bloating(5),
  acne(6);

  final int value;
  const Symptom(this.value);
}

enum Mood {
  happy(0),
  highLibido(1),
  irritable(2),
  anxious(3),
  depressed(4),
  exhausted(5);

  final int value;
  const Mood(this.value);
}

enum Discharge {
  dry(0),
  sticky(1),
  creamy(2),
  watery(3),
  eggwhite(4);

  final int value;
  const Discharge(this.value);
}
