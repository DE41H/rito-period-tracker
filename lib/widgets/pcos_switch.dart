import 'package:buritto/extensions/pcos_switch.dart';
import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/providers/settings_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:provider/provider.dart';

class PcosSwitch extends StatelessWidget {
  const PcosSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SettingsProvider>();
    final isReseeding = context.select<SettingsProvider, bool>((s) => s.isReseeding);

    return ListTile(
      title: Text(
        'Having Pcos',
        style: context.comicText,
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
                onChanged: isReseeding ? null : (val) {
                  value.put('hasPcos', val);
                  provider.reseed(val);
                },
                activeTrackColor: Colors.black,
              );
            }
          ),
        ],
      ),
    );
  }
}
