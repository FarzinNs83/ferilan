import 'package:feri_host/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? server({String host = 'lan.example.com', String port = '9393', String password = 'Ab3_x-yz'}) =>
      Config.checkServer(host: host, port: port, password: password);

  test('accepts a domain or an IP, a port and a password', () {
    expect(server(), isNull);
    expect(server(host: '203.0.113.10'), isNull);
    expect(server(password: 'a' * 19), isNull);
    expect(Config.checkName('player1'), isNull);
  });

  test('rejects what would break feri-edge.exe arguments', () {
    expect(server(host: ''), isNotNull);
    expect(server(host: 'lan.example.com:9393'), isNotNull);
    expect(server(host: 'a b'), isNotNull);
    expect(server(port: 'x'), isNotNull);
    expect(server(port: '0'), isNotNull);
    expect(server(port: '65535'), isNotNull); // the player list needs port + 1
    expect(server(password: ''), isNotNull);
    expect(server(password: 'short'), isNotNull);
    expect(server(password: 'a' * 20), isNotNull); // n2n community names stop at 19
    expect(server(password: 'has space'), isNotNull);
    expect(server(password: 'S3cret!#'), isNotNull);
    expect(Config.checkName(''), isNotNull);
    expect(Config.checkName('فرزین'), isNotNull);
    expect(Config.checkName('a-name-way-too-long'), isNotNull);
  });

  test('an invite link round-trips and rejects anything else', () {
    const s = (host: 'lan.example.com', port: 9393, password: 'Ab3_x-yz');
    expect(Config.parseInvite(Config.invite(s)), s);
    expect(Config.parseInvite('  ${Config.invite(s)}\n'), s);
    expect(Config.parseInvite('lan.example.com'), isNull);
    expect(Config.parseInvite('https://join?host=a.com&port=9393&pass=Ab3_x-yz'), isNull);
    expect(Config.parseInvite('ferilan://join?host=a.com&port=9393'), isNull);
    expect(Config.parseInvite('ferilan://join?host=a.com&port=9393&pass=bad%20pass'), isNull);
  });
}
