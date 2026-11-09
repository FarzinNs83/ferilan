import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lan.dart';
import 'widgets.dart';

/// Everything the last connects did, to see why one fails; Copy gives the whole log to paste to a friend.
class LogPage extends StatelessWidget {
  const LogPage({super.key, required this.lan, required this.onClose});
  final Lan lan;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TitleBar(
            title: 'Log',
            onClose: onClose,
            leading: BarButton(tooltip: 'Back', icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
            actions: [
              BarButton(tooltip: 'Copy all', icon: Icons.copy_rounded, onTap: () => Clipboard.setData(ClipboardData(text: lan.log.join('\n')))),
              BarButton(tooltip: 'Clear', icon: Icons.delete_outline_rounded, onTap: lan.clearLog),
            ],
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: lan,
              builder: (context, _) => lan.log.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Nothing yet. Press connect and come back here.', style: sans(13, FontWeight.w400, C.muted)),
                    )
                  : SelectionArea(
                      // reversed so the newest line sits at the bottom and stays in view
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: lan.log.length,
                        itemBuilder: (_, i) {
                          final l = lan.log[lan.log.length - 1 - i];
                          final bad = l.contains('FAILED') || l.contains('ERROR') || l.contains('WARNING') || l.contains('failed');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(l, style: mono(10.5, FontWeight.w400, bad ? C.danger : l.contains('---') ? C.accent : C.text)),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ]),
      );
}
