import 'package:hive_ce/hive.dart';

import 'package:buritto/models/log.dart';
import 'package:buritto/models/message.dart';

@GenerateAdapters([
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
