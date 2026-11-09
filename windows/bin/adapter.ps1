# Makes the FeriLAN virtual adapter (TAP-Windows, from .\tap) when it is missing, and lets players through the firewall on it.
# Run as admin by the installer and by FeriLAN.exe before it connects.
$ErrorActionPreference = 'Stop'
$name = 'FeriLAN'
if (-not (Get-NetAdapter -Name $name -ErrorAction SilentlyContinue)) {
  $tap = Join-Path $PSScriptRoot 'tap'
  $before = @(Get-NetAdapter -InterfaceDescription 'TAP-Windows Adapter V9*' | ForEach-Object Name)
  & "$tap\devcon.exe" install "$tap\OemVista.inf" tap0901 | Out-Null
  for ($i = 0; $i -lt 15; $i++) {
    $a = Get-NetAdapter -InterfaceDescription 'TAP-Windows Adapter V9*' | Where-Object { $before -notcontains $_.Name } | Select-Object -First 1
    if ($a) { Rename-NetAdapter -Name $a.Name -NewName $name; break }
    Start-Sleep 1
  }
  if (-not $a) { throw 'TAP-Windows driver did not install' }
}
# A hosted game gets the friend's LAN query only if the firewall lets it in, and the rule Windows made when the game
# first ran often covers just the Public profile (FeriLAN is Private) or nothing at all. So: everything in, on this adapter only.
# Remade each time: the rule binds to the adapter that exists now, and a Reinstall makes a new one.
Remove-NetFirewallRule -Name 'FeriLAN-In' -ErrorAction SilentlyContinue
New-NetFirewallRule -Name 'FeriLAN-In' -DisplayName 'FeriLAN players' -Direction Inbound -InterfaceAlias $name -Action Allow | Out-Null
# P2P: a friend's first hole-punch packet can arrive before ours goes out, so let the edge take UDP in on the real network card.
# Safe enough: it drops anything not encrypted with the server password (-H).
Remove-NetFirewallRule -Name 'FeriLAN-P2P' -ErrorAction SilentlyContinue
New-NetFirewallRule -Name 'FeriLAN-P2P' -DisplayName 'FeriLAN direct connection' -Direction Inbound -Protocol UDP -Program (Join-Path $PSScriptRoot 'feri-edge.exe') -Action Allow | Out-Null
