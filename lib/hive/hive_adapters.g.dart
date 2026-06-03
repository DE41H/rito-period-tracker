// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class LogAdapter extends TypeAdapter<Log> {
  @override
  final typeId = 0;

  @override
  Log read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Log(
      date: fields[0] as DateTime,
      cycleDay: (fields[11] as num).toInt(),
      ovulating: fields[15] as bool,
      phase: fields[12] as Phase,
      flow: fields[1] as Flow,
      symptoms: fields[2] == null
          ? const {}
          : (fields[2] as Set).cast<Symptom>(),
      moods: fields[13] == null ? const {} : (fields[13] as Set).cast<Mood>(),
      discharge: fields[4] as Discharge?,
      stress: fields[5] as Stress?,
      sleep: fields[6] as Sleep?,
      sex: fields[14] as Sex?,
      notes: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Log obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.flow)
      ..writeByte(2)
      ..write(obj.symptoms)
      ..writeByte(4)
      ..write(obj.discharge)
      ..writeByte(5)
      ..write(obj.stress)
      ..writeByte(6)
      ..write(obj.sleep)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.cycleDay)
      ..writeByte(12)
      ..write(obj.phase)
      ..writeByte(13)
      ..write(obj.moods)
      ..writeByte(14)
      ..write(obj.sex)
      ..writeByte(15)
      ..write(obj.ovulating);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FlowAdapter extends TypeAdapter<Flow> {
  @override
  final typeId = 1;

  @override
  Flow read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Flow.none;
      case 1:
        return Flow.light;
      case 2:
        return Flow.medium;
      case 3:
        return Flow.heavy;
      default:
        return Flow.none;
    }
  }

  @override
  void write(BinaryWriter writer, Flow obj) {
    switch (obj) {
      case Flow.none:
        writer.writeByte(0);
      case Flow.light:
        writer.writeByte(1);
      case Flow.medium:
        writer.writeByte(2);
      case Flow.heavy:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlowAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SymptomAdapter extends TypeAdapter<Symptom> {
  @override
  final typeId = 2;

  @override
  Symptom read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Symptom.periodCramps;
      case 1:
        return Symptom.ovulationPain;
      case 2:
        return Symptom.tenderBreasts;
      case 3:
        return Symptom.headache;
      case 4:
        return Symptom.fatigue;
      case 5:
        return Symptom.bloating;
      case 6:
        return Symptom.acne;
      default:
        return Symptom.periodCramps;
    }
  }

  @override
  void write(BinaryWriter writer, Symptom obj) {
    switch (obj) {
      case Symptom.periodCramps:
        writer.writeByte(0);
      case Symptom.ovulationPain:
        writer.writeByte(1);
      case Symptom.tenderBreasts:
        writer.writeByte(2);
      case Symptom.headache:
        writer.writeByte(3);
      case Symptom.fatigue:
        writer.writeByte(4);
      case Symptom.bloating:
        writer.writeByte(5);
      case Symptom.acne:
        writer.writeByte(6);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymptomAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DischargeAdapter extends TypeAdapter<Discharge> {
  @override
  final typeId = 3;

  @override
  Discharge read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Discharge.dry;
      case 1:
        return Discharge.sticky;
      case 2:
        return Discharge.creamy;
      case 3:
        return Discharge.watery;
      case 4:
        return Discharge.eggwhite;
      default:
        return Discharge.dry;
    }
  }

  @override
  void write(BinaryWriter writer, Discharge obj) {
    switch (obj) {
      case Discharge.dry:
        writer.writeByte(0);
      case Discharge.sticky:
        writer.writeByte(1);
      case Discharge.creamy:
        writer.writeByte(2);
      case Discharge.watery:
        writer.writeByte(3);
      case Discharge.eggwhite:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DischargeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MoodAdapter extends TypeAdapter<Mood> {
  @override
  final typeId = 4;

  @override
  Mood read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Mood.happy;
      case 1:
        return Mood.highLibido;
      case 2:
        return Mood.irritable;
      case 3:
        return Mood.anxious;
      case 4:
        return Mood.depressed;
      case 5:
        return Mood.exhausted;
      default:
        return Mood.happy;
    }
  }

  @override
  void write(BinaryWriter writer, Mood obj) {
    switch (obj) {
      case Mood.happy:
        writer.writeByte(0);
      case Mood.highLibido:
        writer.writeByte(1);
      case Mood.irritable:
        writer.writeByte(2);
      case Mood.anxious:
        writer.writeByte(3);
      case Mood.depressed:
        writer.writeByte(4);
      case Mood.exhausted:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final typeId = 5;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      content: fields[0] as String,
      isInput: fields[1] == null ? true : fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.content)
      ..writeByte(1)
      ..write(obj.isInput);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SleepAdapter extends TypeAdapter<Sleep> {
  @override
  final typeId = 6;

  @override
  Sleep read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Sleep.poor;
      case 1:
        return Sleep.average;
      case 2:
        return Sleep.excellent;
      default:
        return Sleep.poor;
    }
  }

  @override
  void write(BinaryWriter writer, Sleep obj) {
    switch (obj) {
      case Sleep.poor:
        writer.writeByte(0);
      case Sleep.average:
        writer.writeByte(1);
      case Sleep.excellent:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StressAdapter extends TypeAdapter<Stress> {
  @override
  final typeId = 7;

  @override
  Stress read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Stress.low;
      case 1:
        return Stress.medium;
      case 2:
        return Stress.high;
      default:
        return Stress.low;
    }
  }

  @override
  void write(BinaryWriter writer, Stress obj) {
    switch (obj) {
      case Stress.low:
        writer.writeByte(0);
      case Stress.medium:
        writer.writeByte(1);
      case Stress.high:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PhaseAdapter extends TypeAdapter<Phase> {
  @override
  final typeId = 8;

  @override
  Phase read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Phase.menstrual;
      case 1:
        return Phase.follicular;
      case 2:
        return Phase.ovulatory;
      case 3:
        return Phase.luteal;
      default:
        return Phase.menstrual;
    }
  }

  @override
  void write(BinaryWriter writer, Phase obj) {
    switch (obj) {
      case Phase.menstrual:
        writer.writeByte(0);
      case Phase.follicular:
        writer.writeByte(1);
      case Phase.ovulatory:
        writer.writeByte(2);
      case Phase.luteal:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhaseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
