// ignore_for_file: deprecated_member_use
// window_manager and tray_manager 0.6/0.8 mark their 0.5.x-style API (legacy.dart) deprecated; it is the documented bridge.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/legacy.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'config.dart';
import 'home.dart';
import 'lan.dart';
import 'settings_page.dart';
import 'widgets.dart';

/// Set once the app is up; a second launch (say, a clicked invite link) hands its arguments here.
void Function(List<String> args)? _onSecondLaunch;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowsSingleInstance.ensureSingleInstance(
    args,
    "FeriLAN-asdkJHASKDJHwuh12e14124i",
    onSecondWindow: (arguments) => _onSecondLaunch?.call(arguments),
  );
  await windowManager.ensureInitialized();
  // requireCreate: Windows shows toasts only for apps with a Start menu shortcut
  await localNotifier.setup(appName: 'FeriLAN', shortcutPolicy: ShortcutPolicy.requireCreate);
  final lan = Lan(Config.load());
  // the logon task (Start with Windows) passes --tray
  final hidden = args.contains('--tray');
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(size: Size(420, 720), center: true, title: 'FeriLAN', titleBarStyle: TitleBarStyle.hidden, backgroundColor: C.bg),
    () async {
      if (hidden) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    },
  );
  await windowManager.setResizable(false);
  await windowManager.setMaximizable(false);
  await windowManager.setPreventClose(true);
  runApp(FeriLAN(lan: lan, args: args));
  if (lan.config.ready && lan.config.connectOnLaunch) lan.connect();
}

class FeriLAN extends StatefulWidget {
  const FeriLAN({super.key, required this.lan, this.args = const []});
  final Lan lan;
  final List<String> args;

  @override
  State<FeriLAN> createState() => _FeriLANState();
}

class _FeriLANState extends State<FeriLAN> with WindowListener, TrayListener {
  final _nav = GlobalKey<NavigatorState>();
  String _menuState = '';
  Phase _was = Phase.off;

  Lan get lan => widget.lan;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    trayManager.setIcon('assets/tray.ico');
    lan.addListener(_syncTray);
    lan.addListener(_notifyPhase);
    _syncTray();
    _onSecondLaunch = _openInvite;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInvite(widget.args));
  }

  /// An invite link in [args]: asks first, since anyone can send one, then joins that server.
  Future<void> _openInvite(List<String> args) async {
    final s = args.map(Config.parseInvite).nonNulls.firstOrNull;
    if (s == null) return;
    await _show();
    final ctx = _nav.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.line)),
        title: Text('Join this server?', style: sans(16, FontWeight.w700)),
        content: Text('${s.host}:${s.port}\n\nPlayers on it can reach your PC over the LAN. Join only servers from friends.',
            style: sans(13, FontWeight.w400, C.muted).copyWith(height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text('Cancel', style: sans(14, FontWeight.w600, C.muted))),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: Text('Join', style: sans(14, FontWeight.w700, C.bg))),
        ],
      ),
    );
    if (ok != true) return;
    lan.join(s);
    // no name yet: a Settings page opened before the join holds the old server list, so open a fresh one
    if (!lan.config.ready) _openSettings();
  }

  void _openSettings() => _nav.currentState
    ?..popUntil((r) => r.isFirst)
    ..push(MaterialPageRoute(builder: (_) => SettingsPage(lan: lan, onClose: _close)));

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    lan.removeListener(_syncTray);
    lan.removeListener(_notifyPhase);
    _onSecondLaunch = null;
    super.dispose();
  }

  /// The tray's tooltip and menu follow the connection; rebuilt only when what they show changes.
  void _syncTray() {
    final on = lan.phase == Phase.on, busy = lan.phase == Phase.connecting;
    final status = on ? 'Connected · ${lan.pingMs ?? '…'} ms' : busy ? 'Connecting…' : 'Disconnected';
    final key = '${lan.phase}|${lan.myIp}';
    trayManager.setToolTip('FeriLAN — $status');
    if (key == _menuState) return;
    _menuState = key;
    trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'open', label: 'Open FeriLAN'),
      MenuItem(key: 'toggle', label: on || busy ? 'Disconnect' : 'Connect', disabled: !lan.config.ready),
      MenuItem(key: 'copy', label: lan.myIp == null ? 'Copy my IP' : 'Copy my IP   ${lan.myIp}', disabled: lan.myIp == null),
      MenuItem.separator(),
      MenuItem(key: 'settings', label: 'Settings'),
      MenuItem(key: 'quit', label: 'Quit FeriLAN'),
    ]));
  }

  void _notify(String title, String body) => LocalNotification(title: title, body: body).show();

  /// A toast when the link comes up or goes down; the UDP-to-TCP retry is silent.
  void _notifyPhase() {
    final was = _was, now = lan.phase, host = lan.config.server?.host ?? '';
    _was = now;
    if (now == was) return;
    if (now == Phase.on) {
      _notify('Connected', lan.myIp == null ? host : '$host · your LAN IP ${lan.myIp}');
    } else if (now == Phase.off && lan.error != null) {
      _notify(was == Phase.on ? 'Connection lost' : "Couldn't connect", lan.error!);
    } else if (now == Phase.off && was == Phase.on) {
      _notify('Disconnected', 'You left $host.');
    }
  }

  void _notifyStillRunning(String where) => _notify(
        'FeriLAN is still running',
        '${lan.phase == Phase.on ? 'Still connected to ${lan.config.server?.host}.' : 'Not connected.'} Open it from the $where.',
      );

  Future<void> _show() async {
    await windowManager.show();
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    lan.dispose(); // kills feri-edge.exe
    await trayManager.destroy();
    await windowManager.destroy();
    exit(0);
  }

  void _close() {
    if (!lan.config.closeToTray) {
      _quit();
      return;
    }
    windowManager.hide();
    _notifyStillRunning('tray icon');
  }

  @override
  void onWindowClose() => _close();

  @override
  void onWindowMinimize() => _notifyStillRunning('taskbar');

  @override
  void onTrayIconMouseDown() => _show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem item) {
    switch (item.key) {
      case 'open':
        _show();
      case 'toggle':
        lan.toggle();
      case 'copy':
        if (lan.myIp != null) Clipboard.setData(ClipboardData(text: lan.myIp!));
      case 'settings':
        _show();
        _openSettings();
      case 'quit':
        _quit();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FeriLAN',
        navigatorKey: _nav,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: C.bg,
          colorScheme: const ColorScheme.dark(primary: C.accent, onPrimary: C.bg, surface: C.surface, onSurface: C.text, error: C.danger),
          fontFamily: 'SpaceGrotesk',
          tooltipTheme: TooltipThemeData(
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.line)),
            textStyle: sans(12),
          ),
          textSelectionTheme: TextSelectionThemeData(cursorColor: C.accent, selectionColor: C.accent.withValues(alpha: .3)),
        ),
        home: Home(lan: lan, onClose: _close),
      );
}
