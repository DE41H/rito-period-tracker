import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/providers/settings_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:provider/provider.dart';

class PcosSwitch extends StatelessWidget {
  const PcosSwitch({super.key});

  void _onChanged(final bool val, BuildContext context) {
    HiveDatabase().settings.put('hasPcos', val);
    context.read<SettingsProvider>().reseed(val);
  }

  @override
  Widget build(BuildContext context) {
    final isReseeding = context.select<SettingsProvider, bool>((s) => s.isReseeding);

    return ListTile(
      title: const Text(
        'Having Pcos',
        style: TextStyle(
          fontSize: 20,
          color: Colors.black,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isReseeding) const CupertinoActivityIndicator(),
          ValueListenableBuilder(
            valueListenable: HiveDatabase().settings.listenable(keys: ['hasPcos']),
            builder: (context, value, child) {
              return CupertinoSwitch(
                value: value.get('hasPcos', defaultValue: false) as bool,
                onChanged: isReseeding ? null : (val) => _onChanged(val, context),
                activeTrackColor: Colors.black,
              );
            }
          ),
        ],
      ),
    );
  }
}
