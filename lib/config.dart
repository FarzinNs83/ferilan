import 'dart:convert';
import 'dart:io';

enum LinkMode { auto, udp, tcp }

/// One relay server; the password is what server/setup.sh printed.
typedef Server = ({String host, int port, String password});

/// What the user sets in Settings, kept in %APPDATA%\FeriLAN\config.json.
class Config {
  Config({
    List<Server>? servers,
    this.current = 0,
    this.name = '',
    this.mode = LinkMode.auto,
    this.startWithWindows = false,
    this.connectOnLaunch = false,
    this.closeToTray = true,
    this.fixLan = true,
    this.p2p = false,
  }) : servers = servers ?? [];

  List<Server> servers;
  int current; // index into servers
  String name;
  LinkMode mode;
  bool startWithWindows;
  bool connectOnLaunch;
  bool closeToTray;
  bool fixLan;
  bool p2p; // direct to other players when NAT allows, else through the server

  Server? get server => current < servers.length ? servers[current] : null;

  bool get ready => server != null && name.isNotEmpty;

  static File get file => File('${Platform.environment['APPDATA']}\\FeriLAN\\config.json');

  static Config load() {
    try {
      final m = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Config(
        servers: [
          for (final s in m['servers'] as List? ?? []) (host: s['host'] as String, port: s['port'] as int, password: s['password'] as String),
        ],
        current: m['current'] as int? ?? 0,
        name: m['name'] as String? ?? '',
        mode: LinkMode.values.asNameMap()[m['mode']] ?? LinkMode.auto,
        startWithWindows: m['startWithWindows'] as bool? ?? false,
        connectOnLaunch: m['connectOnLaunch'] as bool? ?? false,
        closeToTray: m['closeToTray'] as bool? ?? true,
        fixLan: m['fixLan'] as bool? ?? true,
        p2p: m['p2p'] as bool? ?? false,
      );
    } catch (_) {
      return Config();
    }
  }

  void save() {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode({
      'servers': [
        for (final s in servers) {'host': s.host, 'port': s.port, 'password': s.password},
      ],
      'current': current,
      'name': name,
      'mode': mode.name,
      'startWithWindows': startWithWindows,
      'connectOnLaunch': connectOnLaunch,
      'closeToTray': closeToTray,
      'fixLan': fixLan,
      'p2p': p2p,
    }));
  }

  // The checks return null when fine; the values become feri-edge.exe arguments.

  static String? checkName(String name) =>
      RegExp(r'^[A-Za-z0-9_-]{1,15}$').hasMatch(name) ? null : 'Name: English letters, digits, _ and - (up to 15).';

  static String? checkServer({required String host, required String port, required String password}) {
    if (!RegExp(r'^[A-Za-z0-9.-]{1,253}$').hasMatch(host)) return 'Server: a domain like lan.example.com or an IP.';
    final p = int.tryParse(port);
    // the player list runs on port + 1
    if (p == null || p < 1 || p > 65534) return 'Port: a number from 1 to 65534.';
    // the password is the n2n community name, so 19 characters at most; same rule as server/setup.sh
    if (!RegExp(r'^[A-Za-z0-9_-]{6,19}$').hasMatch(password)) return 'Password: 6 to 19 English letters, digits, _ or -.';
    return null;
  }

  /// A link that holds everything a friend needs: ferilan://join?host=…&port=…&pass=…
  static String invite(Server s) => Uri(scheme: 'ferilan', host: 'join', queryParameters: {'host': s.host, 'port': '${s.port}', 'pass': s.password}).toString();

  /// The server in the invite link found in [text] (a pasted chat message works too), or null when there is no valid one;
  /// it comes from outside, so it is checked like typed input.
  static Server? parseInvite(String text) {
    final m = RegExp(r'ferilan://\S+', caseSensitive: false).firstMatch(text);
    final u = m == null ? null : Uri.tryParse(m[0]!);
    if (u == null || u.scheme != 'ferilan' || u.host != 'join') return null;
    final q = u.queryParameters;
    final host = q['host'] ?? '', port = q['port'] ?? '', pass = q['pass'] ?? '';
    return checkServer(host: host, port: port, password: pass) == null ? (host: host, port: int.parse(port), password: pass) : null;
  }
}
