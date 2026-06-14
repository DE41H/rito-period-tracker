import 'dart:io';

import 'package:buritto/models/discharge.dart';
import 'package:buritto/models/flow.dart';
import 'package:buritto/models/mood.dart';
import 'package:buritto/models/phase.dart';
import 'package:buritto/models/sex.dart';
import 'package:buritto/models/sleep.dart';
import 'package:buritto/models/stress.dart';
import 'package:buritto/models/symptom.dart';
import 'package:statistics/statistics.dart';

void main() {
  for (final (profile, seed) in [
    ('normal', _normalSeed),
    ('pcos', _pcosSeed),
  ]) {
    stdout.write('Building $profile... ');
    final monitor = _buildMonitor(seed);
    final path = 'assets/population/network_$profile.json';
    File(path).writeAsStringSync(monitor.toJsonEncoded(pretty: true));
    stdout.write('saved ($path)\n');
  }
}

BayesEventMonitor _buildMonitor(List<List<String>> seed) {
  final monitor = BayesEventMonitor('cycleMonitor');

  for (final v in Flow.values) {
    monitor.notifyEvent(['FLOW=${v.name.toUpperCase()}']);
  }
  for (final v in Discharge.values) {
    monitor.notifyEvent(['DISCHARGE=${v.name.toUpperCase()}']);
  }
  for (final v in Stress.values) {
    monitor.notifyEvent(['STRESS=${v.name.toUpperCase()}']);
  }
  for (final v in Sleep.values) {
    monitor.notifyEvent(['SLEEP=${v.name.toUpperCase()}']);
  }
  for (final v in Sex.values) {
    monitor.notifyEvent(['SEX=${v.name.toUpperCase()}']);
  }
  for (final v in Phase.values) {
    monitor.notifyEvent(['PREV_PHASE=${v.name.toUpperCase()}']);
  }
  for (final v in Flow.values) {
    monitor.notifyEvent(['PREV_FLOW=${v.name.toUpperCase()}']);
  }
  for (final s in Symptom.values) {
    monitor.notifyEvent(['SYMPTOM_${s.name.toUpperCase()}=TRUE']);
    monitor.notifyEvent(['SYMPTOM_${s.name.toUpperCase()}=FALSE']);
  }
  for (final m in Mood.values) {
    monitor.notifyEvent(['MOOD_${m.name.toUpperCase()}=TRUE']);
    monitor.notifyEvent(['MOOD_${m.name.toUpperCase()}=FALSE']);
  }

  const temporal = {'PHASE', 'PREV_PHASE', 'PREV_FLOW'};
  for (final compact in seed) {
    monitor.notifyEvent(compact.where((e) => temporal.contains(e.split('=').first.toUpperCase())).toList());
  }

  return monitor;
}


const _normalSeed = <List<String>>[
  // cycle 1
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_headache=true','MOOD_irritable=true'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=medium','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','SLEEP=excellent'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true','SLEEP=excellent'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true','MOOD_happy=true','SLEEP=excellent'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','MOOD_highLibido=true','MOOD_happy=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_ovulationPain=true','MOOD_highLibido=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_fatigue=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_fatigue=true','MOOD_anxious=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_irritable=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_irritable=true','MOOD_depressed=true','STRESS=high','SLEEP=poor'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_headache=true','MOOD_anxious=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_fatigue=true','MOOD_depressed=true','SLEEP=poor'],
  ['PHASE=luteal','FLOW=light','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_tenderBreasts=true','MOOD_exhausted=true'],
  // cycle 2
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=light','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_headache=true','MOOD_irritable=true'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true','SYMPTOM_bloating=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=medium','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true','SLEEP=excellent'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true','MOOD_happy=true','SLEEP=excellent'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_ovulationPain=true','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=watery','PREV_PHASE=ovulatory','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_headache=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_anxious=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_acne=true','MOOD_irritable=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_headache=true','MOOD_depressed=true','MOOD_anxious=true','STRESS=high','SLEEP=poor'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_fatigue=true','MOOD_depressed=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_tenderBreasts=true','MOOD_exhausted=true','SLEEP=poor'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_headache=true','SYMPTOM_acne=true','MOOD_irritable=true','MOOD_exhausted=true'],
  // cycle 3
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_bloating=true','MOOD_irritable=true'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=light','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=light','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','SYMPTOM_headache=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','SLEEP=excellent'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true','SLEEP=excellent'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true','MOOD_happy=true','SLEEP=excellent'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','MOOD_highLibido=true','MOOD_happy=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_fatigue=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_fatigue=true','SYMPTOM_headache=true','MOOD_anxious=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','MOOD_irritable=true','MOOD_anxious=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_depressed=true','MOOD_irritable=true','STRESS=high','SLEEP=poor'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_headache=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_depressed=true'],
  ['PHASE=luteal','FLOW=light','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_tenderBreasts=true','MOOD_exhausted=true','SLEEP=poor'],
  // cycle 4
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=light','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','MOOD_exhausted=true'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_headache=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','MOOD_irritable=true'],
  ['PHASE=menstrual','FLOW=light','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=light','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true','SLEEP=excellent'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=light','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=follicular','PREV_FLOW=light','MOOD_highLibido=true','MOOD_happy=true','SLEEP=excellent'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','MOOD_highLibido=true','MOOD_happy=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_ovulationPain=true','MOOD_highLibido=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_headache=true','MOOD_irritable=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_irritable=true','MOOD_depressed=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_headache=true','MOOD_anxious=true','MOOD_depressed=true','STRESS=high','SLEEP=poor'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_fatigue=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_bloating=true','MOOD_depressed=true','MOOD_irritable=true','SLEEP=poor'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_exhausted=true'],
  // cycle 5
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','MOOD_irritable=true'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true','SYMPTOM_bloating=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=medium','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true','SLEEP=excellent'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true','MOOD_happy=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_ovulationPain=true','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_irritable=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_fatigue=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_headache=true','MOOD_anxious=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_anxious=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_bloating=true','MOOD_irritable=true','MOOD_depressed=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_headache=true','MOOD_exhausted=true','MOOD_anxious=true','STRESS=high','SLEEP=poor'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_fatigue=true','MOOD_depressed=true','SLEEP=poor'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_tenderBreasts=true','MOOD_exhausted=true','SLEEP=poor'],
  ['PHASE=luteal','FLOW=light','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_headache=true','SYMPTOM_bloating=true','MOOD_irritable=true'],
  // extra 10 days
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=light','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_headache=true','MOOD_irritable=true'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=medium','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
];

const _pcosSeed = <List<String>>[
  // cycle 1 — 35 days: 6 menstrual, 20 follicular, 3 ovulatory, 6 luteal
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_headache=true','SYMPTOM_acne=true','MOOD_irritable=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_acne=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_depressed=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_headache=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_fatigue=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_headache=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=light','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=light','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_bloating=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_anxious=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_ovulationPain=true','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_ovulationPain=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_irritable=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_acne=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','MOOD_depressed=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_headache=true','SYMPTOM_acne=true','MOOD_anxious=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_fatigue=true','MOOD_irritable=true','MOOD_depressed=true','STRESS=high','SLEEP=poor'],
  ['PHASE=luteal','FLOW=light','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_tenderBreasts=true','MOOD_exhausted=true','SLEEP=poor'],
  // cycle 2
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=light','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_exhausted=true'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_periodCramps=true','SYMPTOM_acne=true'],
  ['PHASE=menstrual','FLOW=light','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=light','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_headache=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_fatigue=true','MOOD_irritable=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true','MOOD_depressed=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=light','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=light','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_bloating=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_anxious=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=creamy','PREV_PHASE=ovulatory','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=watery','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_ovulationPain=true','MOOD_highLibido=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_irritable=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_irritable=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_headache=true','SYMPTOM_fatigue=true','MOOD_depressed=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=luteal','FLOW=light','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','MOOD_irritable=true','SLEEP=poor'],
  // cycle 3
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=light','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_headache=true','SYMPTOM_acne=true','MOOD_irritable=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','MOOD_exhausted=true'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_acne=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true','SYMPTOM_bloating=true'],
  ['PHASE=menstrual','FLOW=light','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_acne=true','MOOD_depressed=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=light','SYMPTOM_fatigue=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_fatigue=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_headache=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=light','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=light','SYMPTOM_bloating=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_anxious=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=watery','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_ovulationPain=true','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_irritable=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','MOOD_depressed=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_headache=true','MOOD_anxious=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_bloating=true','MOOD_irritable=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_fatigue=true','MOOD_depressed=true','MOOD_exhausted=true','SLEEP=poor'],
  ['PHASE=luteal','FLOW=light','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_exhausted=true','SLEEP=poor'],
  // cycle 4
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=light','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_headache=true','MOOD_irritable=true'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_periodCramps=true','SYMPTOM_acne=true'],
  ['PHASE=menstrual','FLOW=light','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true','MOOD_exhausted=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=light','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_headache=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_fatigue=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=light','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=light','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_bloating=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=creamy','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_happy=true','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_anxious=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=watery','PREV_PHASE=follicular','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','MOOD_highLibido=true'],
  ['PHASE=ovulatory','FLOW=none','DISCHARGE=eggwhite','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_ovulationPain=true','MOOD_highLibido=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=ovulatory','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','MOOD_happy=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_anxious=true','STRESS=medium'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=creamy','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_tenderBreasts=true','SYMPTOM_bloating=true','MOOD_irritable=true'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_headache=true','SYMPTOM_acne=true','MOOD_anxious=true','STRESS=high'],
  ['PHASE=luteal','FLOW=none','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_acne=true','SYMPTOM_bloating=true','MOOD_depressed=true','MOOD_irritable=true','STRESS=high','SLEEP=poor'],
  ['PHASE=luteal','FLOW=light','DISCHARGE=sticky','PREV_PHASE=luteal','PREV_FLOW=none','SYMPTOM_bloating=true','SYMPTOM_tenderBreasts=true','MOOD_exhausted=true','SLEEP=poor'],
  // extra 10 days
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=luteal','PREV_FLOW=light','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_bloating=true','SYMPTOM_acne=true','MOOD_exhausted=true','STRESS=high','SLEEP=poor'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_exhausted=true','STRESS=high'],
  ['PHASE=menstrual','FLOW=heavy','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_headache=true','SYMPTOM_acne=true','MOOD_irritable=true'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=sticky','PREV_PHASE=menstrual','PREV_FLOW=heavy','SYMPTOM_periodCramps=true','SYMPTOM_acne=true','MOOD_irritable=true','STRESS=medium'],
  ['PHASE=menstrual','FLOW=medium','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_fatigue=true','SYMPTOM_acne=true'],
  ['PHASE=menstrual','FLOW=light','DISCHARGE=creamy','PREV_PHASE=menstrual','PREV_FLOW=medium','SYMPTOM_acne=true','MOOD_depressed=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=menstrual','PREV_FLOW=light','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=dry','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_fatigue=true','SYMPTOM_acne=true','MOOD_anxious=true'],
  ['PHASE=follicular','FLOW=none','DISCHARGE=sticky','PREV_PHASE=follicular','PREV_FLOW=none','SYMPTOM_acne=true','MOOD_anxious=true'],
];
