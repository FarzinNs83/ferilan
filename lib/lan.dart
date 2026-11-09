import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'config.dart';

const adapterName = 'FeriLAN';
const edgeExe = 'feri-edge.exe';

enum Phase { off, connecting, on }

typedef Player = ({String name, String ip});

/// Runs feri-edge.exe (n2n) and keeps the FeriLAN adapter, the player list and the ping up to date.
class Lan extends ChangeNotifier {
  Lan(this.config) {
    // an edge left over from a crash would hold the adapter
    Process.runSync('taskkill', ['/F', '/IM', edgeExe]);
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    refresh();
    checkAdapter();
  }

  Config config;

  Phase phase = Phase.off;
  bool overTcp = false;
  String? myIp, error, lastLine;
  int? pingMs;
  bool serverDown = false;
  bool? adapterReady;
  List<Player> players = [];

  /// What happened while connecting, newest last: the app's own steps plus every line feri-edge.exe prints.
  final List<String> log = [];
  static const logLength = 1000;

  /// The last [historyLength] pings to the server, oldest first; null is a check that got no answer.
  final List<int?> history = [];
  static const historyLength = 40; // 2 minutes at one check per 3 s

  Process? _edge;
  Timer? _poll, _fallback;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void _log(String l) {
    final pass = config.server?.password ?? '';
    final t = DateTime.now().toIso8601String().substring(11, 19);
    log.add('$t  ${pass.isEmpty ? l : l.replaceAll(pass, '***')}'); // the log gets sent to friends; keep the password out
    if (log.length > logLength) log.removeAt(0);
  }

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  final _bin = '${File(Platform.resolvedExecutable).parent.path}\\bin';

  Future<String?> _ps(String script) async {
    final r = await Process.run('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script]);
    return r.exitCode == 0 ? null : '${r.stderr}'.trim();
  }

  Future<void> checkAdapter() async {
    adapterReady = await _ps("Get-NetAdapter -Name '$adapterName' -ErrorAction Stop | Out-Null") == null;
    notifyListeners();
  }

  /// Our own TAP adapter, named FeriLAN; the installer makes it, this remakes it if it went missing.
  Future<String?> _ensureAdapter() async {
    final r = await Process.run('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '$_bin\\adapter.ps1']);
    return r.exitCode == 0 ? null : '${r.stderr}'.trim();
  }

  /// Removes the FeriLAN adapter and makes a fresh one.
  Future<String?> reinstallAdapter() async {
    stop();
    adapterReady = null;
    notifyListeners();
    final bad = await _ps('''
\$a = Get-NetAdapter -Name '$adapterName' -ErrorAction SilentlyContinue
if (\$a) { pnputil /remove-device \$a.PnPDeviceID | Out-Null }
''') ?? await _ensureAdapter();
    await checkAdapter();
    return bad;
  }

  /// Without these the game's LAN list goes out on the real network card and the firewall treats players as strangers.
  void _tuneAdapter() => _ps('''
Set-NetIPInterface -InterfaceAlias '$adapterName' -InterfaceMetric 1
for (\$i = 0; \$i -lt 30; \$i++) {
  try { Set-NetConnectionProfile -InterfaceAlias '$adapterName' -NetworkCategory Private -ErrorAction Stop; break } catch { Start-Sleep 1 }
}
''');

  void toggle() => phase == Phase.off ? connect() : stop();

  /// Switches to servers[i], moving the connection along if there is one.
  void useServer(int i) {
    if (i == config.current) return;
    config
      ..current = i
      ..save();
    players = [];
    history.clear();
    if (phase != Phase.off) {
      stop();
      connect();
    }
    refresh();
  }

  /// Adds [s] from an invite (or refreshes its password if already saved), switches to it and connects.
  void join(Server s) {
    final i = config.servers.indexWhere((o) => o.host == s.host && o.port == s.port);
    if (i < 0) {
      config.servers.add(s);
    } else {
      config.servers[i] = s;
    }
    final at = i < 0 ? config.servers.length - 1 : i;
    config.save();
    if (at == config.current && phase != Phase.off) stop(); // the password may have changed
    useServer(at);
    if (phase == Phase.off) connect();
  }

  Future<void> connect() => _start(tcp: config.mode == LinkMode.tcp);

  Future<void> _start({required bool tcp}) async {
    if (!config.ready) return;
    final s = config.server!;
    phase = Phase.connecting;
    overTcp = tcp;
    error = null;
    _log('--- connect to ${s.host}:${s.port} over ${tcp ? 'TCP' : 'UDP'} (mode ${config.mode.name}, p2p ${config.p2p})');
    notifyListeners();
    // a VPN or another TAP adapter here is the usual reason packets never reach the server
    final nics = await Process.run('powershell', ['-NoProfile', '-Command', r"Get-NetAdapter | ? Status -eq Up | % { $_.Name + ' | ' + $_.InterfaceDescription }"]);
    for (final l in '${nics.stdout}'.trim().split('\n')) {
      _log('adapter up: ${l.trim()}');
    }
    try {
      final ips = await InternetAddress.lookup(s.host);
      _log('${s.host} resolves to ${ips.map((a) => a.address).join(', ')}');
      // the adapter Windows really sends through: a VPN's TUN shows up here even when it hides from the list above
      final via = await Process.run('powershell', [
        '-NoProfile', '-Command',
        "Find-NetRoute -RemoteIPAddress '${ips.first.address}' | ? InterfaceAlias | select -First 1 | % { \$_.InterfaceAlias + ' from ' + \$_.IPAddress }",
      ]);
      _log('route to server goes out via: ${'${via.stdout}'.trim()}');
    } catch (e) {
      _log('DNS lookup of ${s.host} failed: $e');
    }
    if (phase != Phase.connecting) return; // stopped while we looked
    final bad = await _ensureAdapter();
    adapterReady = bad == null;
    _log(bad == null ? 'FeriLAN adapter ok' : 'FeriLAN adapter failed: $bad');
    if (bad != null) return _fail('The virtual adapter did not install:\n$bad');

    final args = [
        // the password is the community the supernode lets in (server/setup.sh) and the encryption key
        '-c', s.password,
        '-k', s.password,
        '-H', // headers encrypted too, so the password never crosses the network in the clear
        '-l', '${s.host}:${s.port}',
        '-I', config.name,
        '-d', adapterName,
        '-E', // multicast too: some games find LAN servers with it
        // -S1/-S2 keep everything on the server; without them n2n hole-punches to each player and falls back to the server.
        // Hole punching is UDP only, so TCP always goes through the server.
        if (tcp) '-S2' else if (!config.p2p) '-S1',
        '-v', // more detail for the log page
      ];
    _log('$edgeExe ${args.join(' ')}');
    final Process p;
    try {
      p = await Process.start('$_bin\\$edgeExe', args);
    } on ProcessException catch (e) {
      return _fail('$edgeExe did not start: ${e.message}');
    }
    _edge = p;
    for (final s in [p.stdout, p.stderr]) {
      s.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen((l) => _onLine(p, l));
    }
    p.exitCode.then((code) {
      _log('$edgeExe exited with code $code');
      if (_edge != p) return; // stopped on purpose
      _edge = null;
      _fail('Connection lost: ${lastLine ?? ''}');
    });
    _fallback = Timer(const Duration(seconds: 12), () {
      if (phase == Phase.on || _edge != p) return;
      // mobile networks sometimes block UDP: TCP is slower but gets through
      if (!tcp && config.mode == LinkMode.auto) {
        _log('no answer over UDP in 12 s, trying TCP');
        stop();
        _start(tcp: true);
        return;
      }
      _fail("Can't reach the server.\nIs a VPN on? Turn it off, or exclude the server from it (split tunneling).\nThen check your internet, the server address and its password.");
    });
  }

  void _onLine(Process p, String l) {
    if (_edge != p) return;
    _log(l);
    lastLine = l;
    final ip = RegExp(r'created local tap device IP: ([\d.]+)').firstMatch(l);
    if (ip != null) {
      myIp = ip[1];
      if (config.fixLan) _tuneAdapter();
    }
    if (l.contains('[OK]') && l.contains('>>> supernode')) {
      _fallback?.cancel();
      phase = Phase.on;
    }
    notifyListeners();
  }

  /// The error goes in before stop() notifies, so listeners see why it went off.
  void _fail(String msg) {
    _log('FAILED: $msg');
    error = msg;
    stop();
  }

  void stop() {
    _fallback?.cancel();
    final p = _edge;
    _edge = null;
    if (p != null) _log('stopping $edgeExe');
    p?.kill();
    phase = Phase.off;
    myIp = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!config.ready) return;
    final host = config.server!.host, port = config.server!.port + 1;
    int? ms;
    var list = <Player>[];
    try {
      // a TCP handshake is one round trip: close enough to ping, and ICMP needs no admin tricks
      final sw = Stopwatch()..start();
      final s = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      ms = sw.elapsedMilliseconds;
      s.destroy();
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final req = await c.get(host, port, '/');
      final body = await (await req.close()).transform(utf8.decoder).join().timeout(const Duration(seconds: 3));
      c.close();
      list = [
        for (final r in jsonDecode(body) as List) (name: '${r['name']}', ip: '${r['ip']}'),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      // only the change is logged, not every 3 s
      if (!serverDown && ms == null) _log('server check on $host:$port failed: $e');
    }
    if (serverDown && ms != null) _log('server check on $host:$port answers again ($ms ms)');
    pingMs = ms;
    history.add(ms);
    if (history.length > historyLength) history.removeAt(0);
    serverDown = ms == null;
    players = list;
    notifyListeners();
  }

  /// A logon task, not the Run key: Windows will not start an admin app from the Run key.
  static Future<void> setStartWithWindows(bool on) => on
      ? Process.run('schtasks', ['/Create', '/F', '/TN', 'FeriLAN', '/SC', 'ONLOGON', '/RL', 'HIGHEST', '/TR', '"${Platform.resolvedExecutable}" --tray'])
      : Process.run('schtasks', ['/Delete', '/F', '/TN', 'FeriLAN']);

  @override
  void dispose() {
    _poll?.cancel();
    stop();
    _disposed = true;
    super.dispose();
  }
}
