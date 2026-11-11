import 'dart:io';

import 'package:flutter/material.dart';

import 'widgets.dart';

const appVersion = '1.0.1'; // keep in step with pubspec.yaml and installer/FeriLAN.iss
const repoUrl = 'https://github.com/FarzinNs83/feri-lan';

/// What the app is, how to play, and what it does and does not do yet.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TitleBar(
            title: 'About',
            onClose: onClose,
            leading: BarButton(tooltip: 'Back', icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 20), children: [
              Rise(
                child: Column(children: [
                  const Logo(size: 64),
                  const SizedBox(height: 12),
                  Text('FeriLAN', style: sans(22, FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('version $appVersion', style: mono(12, FontWeight.w400, C.muted)),
                  const SizedBox(height: 10),
                  Text('Play LAN games with friends over the internet, through your own server.',
                      textAlign: TextAlign.center, style: sans(13, FontWeight.w400, C.muted).copyWith(height: 1.5)),
                ]),
              ),
              const SizedBox(height: 24),
              Rise(
                delay: const Duration(milliseconds: 60),
                child: _section('HOW TO PLAY', [
                  'Connect to the same server as your friends.',
                  "Host a LAN game — friends find it in the game's LAN list, or join your IP.",
                  'Tap a player to copy their IP.',
                  'Invite a friend with the link button next to a server in Settings.',
                ], Icons.arrow_forward_rounded, C.accent),
              ),
              const SizedBox(height: 16),
              Rise(
                delay: const Duration(milliseconds: 120),
                child: _section('WHAT IT DOES', [
                  'A virtual LAN: games see each other as on one switch, LAN list included.',
                  'Traffic is encrypted with the server password.',
                  'UDP first, TCP when your network blocks UDP.',
                  'Several servers, and invite links to share them.',
                  'Ping and loss to the server over the last 2 minutes.',
                  'Optional direct connection (P2P) between players, falling back to the server.',
                ], Icons.check_rounded, C.accent),
              ),
              const SizedBox(height: 16),
              Rise(
                delay: const Duration(milliseconds: 180),
                child: _section('NOT YET', [
                  'Windows only.',
                  'Ping and loss are to the server, not to each player.',
                  'A VPN on your PC blocks the connection: turn it off or exclude the server.',
                  "Some games may not show up in the LAN list; join by IP instead.",
                ], Icons.remove_rounded, C.muted),
              ),
              const SizedBox(height: 24),
              Rise(
                delay: const Duration(milliseconds: 240),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('SUPPORT', style: caps(12)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
                    child: Column(children: [
                      _link(Icons.campaign_rounded, 'Telegram channel', '@farzin_the_tech_guy', 'https://t.me/farzin_the_tech_guy'),
                      const Divider(height: 1, color: C.lineSoft),
                      _link(Icons.send_rounded, 'Message me on Telegram', '@feri_ns83', 'https://t.me/feri_ns83'),
                      const Divider(height: 1, color: C.lineSoft),
                      _link(Icons.code_rounded, 'Source and releases', 'GitHub', repoUrl),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      );

  Widget _link(IconData icon, String title, String sub, String url) => InkWell(
        onTap: () => Process.run('explorer', [url]),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(icon, size: 18, color: C.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: sans(14, FontWeight.w600)),
                Text(sub, style: mono(12, FontWeight.w400, C.muted)),
              ]),
            ),
            const Icon(Icons.open_in_new_rounded, size: 16, color: C.muted),
          ]),
        ),
      );

  Widget _section(String title, List<String> lines, IconData icon, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: caps(12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
          child: Column(children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 14, color: color)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l, style: sans(13, FontWeight.w400).copyWith(height: 1.45))),
                ]),
              ),
          ]),
        ),
      ]);
}
