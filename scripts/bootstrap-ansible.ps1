# Bootstrap Ansible connectivity on a Windows node
# Run ONCE as Administrator via Proxmox console (or any out-of-band access).
#
# This script ONLY enables WinRM so Ansible can connect. No prompts, no
# interaction — safe for automated provisioning (Terraform, cloud-init, etc.)
#
# Everything else (SSH, firewall, auto-logon, power, lock screen) is managed
# by the win_base role: ansible-playbook playbooks/site.yml --limit <hostname>
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File bootstrap-ansible.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== Bootstrap Ansible ===" -ForegroundColor Cyan

# --- WinRM ---
Write-Host "`n[1/2] Enabling WinRM..." -ForegroundColor Yellow
Set-Service -Name WinRM -StartupType Automatic
Start-Service WinRM
winrm quickconfig -quiet 2>$null
Set-Item WSMan:\localhost\Service\Auth\Negotiate -Value $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# --- Verify ---
Write-Host "[2/2] Verifying..." -ForegroundColor Yellow

$winrm = Get-Service WinRM
$listening = netstat -an | Select-String ":5985.*LISTENING"

Write-Host "`n=== Status ===" -ForegroundColor Cyan
Write-Host "WinRM: $($winrm.Status) $(if($listening){'(port 5985 listening)'}else{'(port 5985 NOT listening)'})"
Write-Host "IP:    $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike '127.*'}).IPAddress -join ', ')"

if (-not $listening) {
    Write-Host "`nERROR: WinRM not listening. Check firewall." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Ready for Ansible ===" -ForegroundColor Green
Write-Host "Next:"
Write-Host "  1. Add this node to inventories/<env>/hosts.yml"
Write-Host "  2. ansible-playbook playbooks/site.yml --limit <hostname>"
