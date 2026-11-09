import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'lan.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.lan, required this.onClose});
  final Lan lan;
  final VoidCallback onClose;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Config cfg = widget.lan.config;
  late final name = TextEditingController(text: cfg.name);
  late final servers = [...cfg.servers];
  late int current = cfg.current;
  late LinkMode mode = cfg.mode;
  late bool boot = cfg.startWithWindows, auto = cfg.connectOnLaunch, tray = cfg.closeToTray, fixLan = cfg.fixLan, p2p = cfg.p2p;
  bool advanced = false, repairing = false;
  String? problem;
  int? copiedInvite;

  void copyInvite(int i) {
    Clipboard.setData(ClipboardData(text: Config.invite(servers[i])));
    setState(() => copiedInvite = i);
    Future.delayed(const Duration(milliseconds: 1400), () => mounted && copiedInvite == i ? setState(() => copiedInvite = null) : null);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> editServer([int? i]) async {
    final s = await showDialog<Server>(context: context, builder: (_) => ServerDialog(server: i == null ? null : servers[i]));
    if (s == null) return;
    setState(() {
      problem = null;
      if (i != null) {
        servers[i] = s;
      } else {
        servers.add(s);
        current = servers.length - 1;
      }
    });
  }

  void removeServer(int i) => setState(() {
        servers.removeAt(i);
        if (i < current || current >= servers.length) current = math.max(0, current - 1);
      });

  Future<void> save() async {
    final n = name.text.trim();
    final bad = servers.isEmpty ? 'Add a server.' : Config.checkName(n);
    if (bad != null) return setState(() => problem = bad);
    final relink = servers[current] != cfg.server || n != cfg.name || mode != cfg.mode || p2p != cfg.p2p;
    if (boot != cfg.startWithWindows) await Lan.setStartWithWindows(boot);
    cfg
      ..servers = servers
      ..current = current
      ..name = n
      ..mode = mode
      ..startWithWindows = boot
      ..connectOnLaunch = auto
      ..closeToTray = tray
      ..fixLan = fixLan
      ..p2p = p2p
      ..save();
    final lan = widget.lan;
    if (relink && lan.phase != Phase.off) {
      lan.stop();
      lan.connect();
    }
    lan.refresh();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> repair() async {
    setState(() => repairing = true);
    final bad = await widget.lan.reinstallAdapter();
    if (!mounted) return;
    setState(() {
      repairing = false;
      problem = bad == null ? null : 'Adapter: $bad';
    });
  }

  @override
  Widget build(BuildContext context) {
    final canLeave = cfg.ready;
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TitleBar(
          title: 'Settings',
          onClose: widget.onClose,
          leading: canLeave ? BarButton(tooltip: 'Back', icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()) : null,
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12), children: [
            Rise(child: _servers()),
            const SizedBox(height: 16),
            Rise(
              delay: const Duration(milliseconds: 60),
              child: field('YOUR NAME', name,
                  hint: 'player1',
                  help: 'English letters and digits. Friends see you by this name.',
                  onChanged: (_) => problem == null ? null : setState(() => problem = null)),
            ),
            const SizedBox(height: 16),
            Rise(
              delay: const Duration(milliseconds: 120),
              child: Material(
                color: C.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: C.line)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => advanced = !advanced),
                  child: SizedBox(
                    height: 44,
                    child: Row(children: [
                      const SizedBox(width: 14),
                      Expanded(child: Text('Advanced', style: sans(14, FontWeight.w600))),
                      AnimatedRotation(turns: advanced ? .5 : 0, duration: const Duration(milliseconds: 250), child: const Icon(Icons.expand_more_rounded, color: C.muted)),
                      const SizedBox(width: 12),
                    ]),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: advanced ? _advanced() : const SizedBox(width: double.infinity),
            ),
            if (problem != null) ...[
              const SizedBox(height: 14),
              Text(problem!, style: sans(13, FontWeight.w500, C.danger)),
            ],
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.lineSoft))),
          child: buttons(onCancel: canLeave ? () => Navigator.of(context).pop() : null, onSave: save),
        ),
      ]),
    );
  }

  Widget _servers() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('SERVERS', style: caps(12)),
        const SizedBox(height: 6),
        Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: C.line)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final (i, s) in servers.indexed)
              Semantics(
                selected: i == current,
                child: InkWell(
                  onTap: () => setState(() => current = i),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 4),
                    child: Row(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: i == current ? C.accent : C.edge),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('${s.host}:${s.port}', overflow: TextOverflow.ellipsis, style: mono(13, FontWeight.w500, i == current ? C.text : C.muted)),
                      ),
                      IconButton(
                        tooltip: copiedInvite == i ? 'Invite link copied' : 'Copy invite link',
                        icon: Icon(copiedInvite == i ? Icons.check_rounded : Icons.link_rounded, size: 18, color: copiedInvite == i ? C.accent : C.muted),
                        onPressed: () => copyInvite(i),
                      ),
                      IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_rounded, size: 16, color: C.muted), onPressed: () => editServer(i)),
                      IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline_rounded, size: 18, color: C.muted), onPressed: () => removeServer(i)),
                    ]),
                  ),
                ),
              ),
            if (servers.isNotEmpty) const Divider(height: 1, color: C.lineSoft),
            InkWell(
              onTap: editServer,
              child: SizedBox(
                height: 44,
                child: Row(children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.add_rounded, size: 18, color: C.accent),
                  const SizedBox(width: 8),
                  Text('Add server', style: sans(14, FontWeight.w600, C.accent)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text('Tap one to connect to it. Send friends its invite link, or paste one you got into Add server.', style: sans(12, FontWeight.w400, C.muted)),
      ]);

  Widget _advanced() => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('CONNECTION', style: caps(12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: C.field, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Row(children: [
              for (final m in LinkMode.values)
                Expanded(
                  child: Semantics(
                    selected: mode == m,
                    child: GestureDetector(
                      onTap: () => setState(() => mode = m),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: mode == m ? C.accent : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                          child: Text(m.name.toUpperCase().replaceFirst('AUTO', 'Auto'), style: sans(13, FontWeight.w700, mode == m ? C.bg : C.muted)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(
            switch (mode) {
              LinkMode.auto => 'UDP first; switches to TCP if your network blocks UDP.',
              LinkMode.udp => 'Lowest ping. Fails on networks that block UDP.',
              LinkMode.tcp => 'Works almost everywhere, but lag spikes on packet loss.',
            },
            style: sans(12, FontWeight.w400, C.muted),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
            child: Column(children: [
              _switch('Start with Windows', 'Opens in the tray when you log in.', boot, (v) => setState(() => boot = v)),
              _switch('Connect on launch', 'Joins the server as soon as the app starts.', auto, (v) => setState(() => auto = v)),
              _switch('Close to tray', 'The X button hides the window; quit from the tray.', tray, (v) => setState(() => tray = v)),
              _switch('Fix LAN discovery', 'Puts FeriLAN first so games see LAN servers.', fixLan, (v) => setState(() => fixLan = v)),
              _switch('Direct connection (P2P)', 'Lower ping when your networks allow it; otherwise stays on the server. UDP only.', p2p, (v) => setState(() => p2p = v)),
            ]),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: widget.lan,
            builder: (_, _) {
              final ready = widget.lan.adapterReady;
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.edge)),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: ready == true ? C.accent : ready == false ? C.amber : C.muted)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Virtual adapter “$adapterName”', style: sans(13, FontWeight.w600)),
                      Text(
                        repairing ? 'Reinstalling…' : ready == true ? 'TAP driver installed · ready' : ready == false ? 'Not installed yet — made on first connect' : 'Checking…',
                        style: sans(12, FontWeight.w400, C.muted),
                      ),
                    ]),
                  ),
                  OutlinedButton(
                    onPressed: repairing ? null : repair,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      side: const BorderSide(color: C.edge),
                      foregroundColor: C.text,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Reinstall', style: sans(12, FontWeight.w500)),
                  ),
                ]),
              );
            },
          ),
        ]),
      );

  Widget _switch(String title, String hint, bool value, ValueChanged<bool> onChanged) => MergeSemantics(
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: sans(14, FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(hint, style: sans(12, FontWeight.w400, C.muted)),
                ]),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: C.bg,
                activeTrackColor: C.accent,
                inactiveThumbColor: C.muted,
                inactiveTrackColor: C.edge,
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ]),
          ),
        ),
      );
}

/// Adds a server, or edits [server]; pops the checked Server, or null on cancel.
class ServerDialog extends StatefulWidget {
  const ServerDialog({super.key, this.server});
  final Server? server;

  @override
  State<ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<ServerDialog> {
  late final host = TextEditingController(text: widget.server?.host);
  late final port = TextEditingController(text: '${widget.server?.port ?? 9393}');
  late final password = TextEditingController(text: widget.server?.password);
  bool hidePass = true;
  String? problem;

  @override
  void dispose() {
    for (final c in [host, port, password]) {
      c.dispose();
    }
    super.dispose();
  }

  void save() {
    final h = host.text.trim(), p = port.text.trim(), pw = password.text.trim();
    final bad = Config.checkServer(host: h, port: p, password: pw);
    if (bad != null) return setState(() => problem = bad);
    Navigator.of(context).pop<Server>((host: h, port: int.parse(p), password: pw));
  }

  void clear(String _) => problem == null ? null : setState(() => problem = null);

  /// A pasted invite link fills all three fields.
  void hostChanged(String text) {
    final s = Config.parseInvite(text);
    if (s != null) {
      host.text = s.host;
      port.text = '${s.port}';
      password.text = s.password;
    }
    clear(text);
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: C.surface,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.line)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.server == null ? 'Add server' : 'Edit server', style: sans(16, FontWeight.w700)),
            const SizedBox(height: 16),
            field('SERVER', host, hint: 'lan.example.com', help: 'Domain or IP, or paste an invite link here.', onChanged: hostChanged),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 100, child: field('PORT', port, hint: '9393', onChanged: clear)),
              const SizedBox(width: 12),
              Expanded(
                child: field(
                  'PASSWORD',
                  password,
                  obscure: hidePass,
                  onChanged: clear,
                  suffix: IconButton(
                    tooltip: hidePass ? 'Show password' : 'Hide password',
                    icon: Icon(hidePass ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: C.muted),
                    onPressed: () => setState(() => hidePass = !hidePass),
                  ),
                ),
              ),
            ]),
            if (problem != null) ...[
              const SizedBox(height: 12),
              Text(problem!, style: sans(13, FontWeight.w500, C.danger)),
            ],
            const SizedBox(height: 20),
            buttons(onCancel: () => Navigator.of(context).pop(), onSave: save),
          ]),
        ),
      );
}

Widget field(String label, TextEditingController c, {String? hint, String? help, bool obscure = false, Widget? suffix, ValueChanged<String>? onChanged}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: caps(12)),
      const SizedBox(height: 6),
      TextField(
        controller: c,
        obscureText: obscure,
        style: mono(14, FontWeight.w500),
        cursorColor: C.accent,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: mono(14, FontWeight.w400, const Color(0xFF6B7A89)),
          filled: true,
          fillColor: C.field,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.edge)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.accent, width: 1.5)),
        ),
      ),
      if (help != null) ...[
        const SizedBox(height: 6),
        Text(help, style: sans(12, FontWeight.w400, C.muted)),
      ],
    ]);

/// Cancel (left out when [onCancel] is null) and Save, side by side.
Widget buttons({VoidCallback? onCancel, required VoidCallback onSave}) => Row(children: [
      if (onCancel != null) ...[
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              side: const BorderSide(color: C.edge),
              foregroundColor: C.text,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Cancel', style: sans(14, FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: FilledButton(
          onPressed: onSave,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: C.accent,
            foregroundColor: C.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Save', style: sans(14, FontWeight.w700, C.bg)),
        ),
      ),
    ]);
