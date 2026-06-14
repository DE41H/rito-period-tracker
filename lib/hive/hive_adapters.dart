import 'package:buritto/models/discharge.dart';
import 'package:buritto/models/flow.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/models/message.dart';
import 'package:buritto/models/mood.dart';
import 'package:buritto/models/phase.dart';
import 'package:buritto/models/sex.dart';
import 'package:buritto/models/sleep.dart';
import 'package:buritto/models/stress.dart';
import 'package:buritto/models/symptom.dart';
import 'package:hive_ce/hive.dart';

@GenerateAdapters(<AdapterSpec<dynamic>>[
  AdapterSpec<Log>(),
  AdapterSpec<Flow>(),
  AdapterSpec<Symptom>(),
  AdapterSpec<Discharge>(),
  AdapterSpec<Mood>(),
  AdapterSpec<Sleep>(),
  AdapterSpec<Stress>(),
  AdapterSpec<Message>(),
  AdapterSpec<Phase>(),
  AdapterSpec<Sex>(),
])
part 'hive_adapters.g.dart';
