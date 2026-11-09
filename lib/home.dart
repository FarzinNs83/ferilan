import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'about_page.dart';
import 'lan.dart';
import 'log_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.lan, required this.onClose});
  final Lan lan;
  final VoidCallback onClose;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String _copied = '';
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (!widget.lan.config.ready) WidgetsBinding.instance.addPostFrameCallback((_) => openSettings());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> copy(String ip) async {
    await Clipboard.setData(ClipboardData(text: ip));
    setState(() => _copied = ip);
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 1400), () => mounted ? setState(() => _copied = '') : null);
  }

  void openSettings() => _open(SettingsPage(lan: widget.lan, onClose: widget.onClose));

  void _open(Widget page) => Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, a, _, child) {
          final t = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
          return FadeTransition(opacity: t, child: SlideTransition(position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(t), child: child));
        },
      ));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.lan,
        builder: (context, _) {
          final lan = widget.lan;
          final on = lan.phase == Phase.on, busy = lan.phase == Phase.connecting;
          final status = on
              ? 'Connected · ${lan.overTcp ? 'TCP' : 'UDP'}'
              : busy
                  ? (lan.overTcp ? 'Trying TCP…' : 'Connecting…')
                  : 'Disconnected';
          return Scaffold(
            backgroundColor: C.bg,
            body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TitleBar(
                title: 'FeriLAN',
                onClose: widget.onClose,
                actions: [
                  BarButton(tooltip: 'Log', icon: Icons.receipt_long_rounded, onTap: () => _open(LogPage(lan: lan, onClose: widget.onClose))),
                  BarButton(tooltip: 'About', icon: Icons.info_outline_rounded, onTap: () => _open(AboutPage(onClose: widget.onClose))),
                  BarButton(tooltip: 'Settings', icon: Icons.tune_rounded, onTap: openSettings),
                ],
              ),
              const SizedBox(height: 14),
              Center(child: ConnectButton(on: on, busy: busy, onTap: lan.toggle)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Blink(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: on ? C.accent : busy ? C.amber : const Color(0xFF5B6B7B)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(status, style: sans(20, FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: _serverPicker(lan)),
                const SizedBox(width: 10),
                SizedBox(height: 12, child: PingBars(live: !lan.serverDown && lan.pingMs != null)),
                const SizedBox(width: 8),
                Text(
                  lan.serverDown ? 'unreachable' : '${lan.pingMs ?? '…'} ms',
                  style: mono(12, FontWeight.w500, lan.serverDown ? C.danger : C.text),
                ),
              ]),
              if (lan.history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: PingChart(samples: lan.history, slots: Lan.historyLength),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: lan.error != null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0x1FFF8A8A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x55FF8A8A))),
                          child: SelectableText(lan.error!, style: sans(12.5, FontWeight.w500, C.danger).copyWith(height: 1.45)),
                        ),
                      )
                    : on && lan.myIp != null
                        ? Rise(child: _myIp(lan.myIp!))
                        : const SizedBox(width: double.infinity),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(children: [
                  Text('ONLINE', style: caps(13)),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: lan.players.isEmpty ? C.lineSoft : C.accent, borderRadius: BorderRadius.circular(99)),
                    child: Text('${lan.players.length}', style: sans(12, FontWeight.w700, lan.players.isEmpty ? C.muted : C.bg)),
                  ),
                ]),
              ),
              Expanded(
                child: lan.players.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Text(lan.config.ready ? 'Nobody is on yet.' : 'Set the server in Settings.', style: sans(13, FontWeight.w400, C.muted)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: lan.players.length,
                        itemBuilder: (_, i) => Rise(
                          key: ValueKey(lan.players[i].ip),
                          delay: Duration(milliseconds: 60 * i),
                          child: _player(lan.players[i], lan.players[i].ip == lan.myIp),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
            ]),
          );
        },
      );

  /// The current server; with more than one saved, a menu to switch (the connection follows).
  Widget _serverPicker(Lan lan) {
    final cfg = lan.config, many = cfg.servers.length > 1;
    return PopupMenuButton<int>(
      enabled: many,
      tooltip: 'Switch server',
      color: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: C.line)),
      onSelected: lan.useServer,
      itemBuilder: (_) => [
        for (final (i, s) in cfg.servers.indexed)
          PopupMenuItem(
            value: i,
            child: Text('${s.host}:${s.port}', style: mono(13, FontWeight.w500, i == cfg.current ? C.accent : C.text)),
          ),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(cfg.server?.host ?? '', overflow: TextOverflow.ellipsis, style: mono(12, FontWeight.w400, C.muted))),
        if (many) const Icon(Icons.expand_more_rounded, size: 16, color: C.muted),
      ]),
    );
  }

  Widget _myIp(String ip) => Container(
        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('YOUR LAN IP', style: caps(11)),
              const SizedBox(height: 2),
              SelectableText(ip, style: mono(20, FontWeight.w500)),
            ]),
          ),
          FilledButton.icon(
            onPressed: () => copy(ip),
            style: FilledButton.styleFrom(
              backgroundColor: C.accent,
              foregroundColor: C.bg,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(_copied == ip ? Icons.check_rounded : Icons.copy_rounded, size: 16),
            label: Text(_copied == ip ? 'Copied' : 'Copy', style: sans(13, FontWeight.w700, C.bg)),
          ),
        ]),
      );

  Widget _player(Player p, bool you) => InkWell(
        onTap: () => copy(p.ip),
        borderRadius: BorderRadius.circular(10),
        hoverColor: const Color(0xFF151D28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: you ? C.accent : C.lineSoft, borderRadius: BorderRadius.circular(10)),
              child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase(), style: sans(14, FontWeight.w700, you ? C.bg : C.text)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(you ? '${p.name}  (you)' : p.name, style: sans(14, FontWeight.w600)),
                Text(p.ip, style: mono(12, FontWeight.w400, C.muted)),
              ]),
            ),
            Tooltip(
              message: "Copy ${p.name}'s IP",
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _copied == p.ip
                    ? Text('Copied', key: const ValueKey('c'), style: sans(12, FontWeight.w600, C.accent))
                    : const Icon(Icons.copy_rounded, key: ValueKey('i'), size: 16, color: C.muted),
              ),
            ),
            const SizedBox(width: 6),
          ]),
        ),
      );
}
