# Windows Render Node Bootstrap
# Run as Administrator on each Windows VM via Proxmox console.
# Enables SSH + WinRM for Ansible management + auto-logon for GPU tasks.
#
# After running this script, add the node to inventory/hosts.yml and run:
#   ansible-playbook playbooks/site.yml --limit <hostname>

$ErrorActionPreference = "Stop"

Write-Host "=== Render Node Setup ===" -ForegroundColor Cyan

# --- SSH Setup ---
Write-Host "`n[1/7] Enabling OpenSSH Server..." -ForegroundColor Yellow
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

# --- WinRM Setup ---
Write-Host "[2/7] Enabling WinRM..." -ForegroundColor Yellow
Set-Service -Name WinRM -StartupType Automatic
Start-Service WinRM
winrm quickconfig -quiet 2>$null
Set-Item WSMan:\localhost\Service\Auth\Negotiate -Value $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord

# --- Network Profile ---
Write-Host "[3/7] Setting network to Private..." -ForegroundColor Yellow
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# --- Firewall Rules ---
Write-Host "[4/7] Configuring firewall..." -ForegroundColor Yellow

# SSH
New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -Profile Any -ErrorAction SilentlyContinue

# WinRM
New-NetFirewallRule -Name 'WinRM-HTTP-In-TCP' -DisplayName 'WinRM HTTP' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 5985 -Profile Any -ErrorAction SilentlyContinue

# Ping
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 -Action Allow -Direction Inbound -Profile Any -ErrorAction SilentlyContinue

# --- Auto-Logon Setup ---
Write-Host "[5/7] Configuring auto-logon..." -ForegroundColor Yellow
Write-Host "       (Required for GPU-accelerated tasks that need interactive session)" -ForegroundColor Gray

$username = $env:USERNAME
$credential = Get-Credential -UserName $username -Message "Enter password for auto-logon (stored in registry)"
$password = $credential.GetNetworkCredential().Password

$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $winlogonPath -Name AutoAdminLogon -Value "1"
Set-ItemProperty -Path $winlogonPath -Name DefaultUserName -Value $username
Set-ItemProperty -Path $winlogonPath -Name DefaultPassword -Value $password
Set-ItemProperty -Path $winlogonPath -Name DefaultDomainName -Value ""

# --- Disable Lock Screen ---
Write-Host "[6/7] Disabling lock screen..." -ForegroundColor Yellow
$personalizationPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
if (-not (Test-Path $personalizationPath)) {
    New-Item -Path $personalizationPath -Force | Out-Null
}
Set-ItemProperty -Path $personalizationPath -Name NoLockScreen -Value 1 -Type DWord

# --- Verify ---
Write-Host "[7/7] Verifying..." -ForegroundColor Yellow

$sshd = Get-Service sshd
$winrm = Get-Service WinRM
$sshPort = netstat -an | Select-String ":22.*LISTENING"
$winrmPort = netstat -an | Select-String ":5985.*LISTENING"
$autologon = Get-ItemProperty $winlogonPath -Name AutoAdminLogon -ErrorAction SilentlyContinue

Write-Host "`n=== Status ===" -ForegroundColor Cyan
Write-Host "SSH:       $($sshd.Status) $(if($sshPort){'(port 22 listening)'}else{'(port 22 NOT listening)'})"
Write-Host "WinRM:     $($winrm.Status) $(if($winrmPort){'(port 5985 listening)'}else{'(port 5985 NOT listening)'})"
Write-Host "Auto-logon: $(if($autologon.AutoAdminLogon -eq '1'){"Enabled for $username"}else{'NOT enabled'})"
Write-Host "IP:        $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike '127.*'}).IPAddress -join ', ')"

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "  1. Add this node to inventory/hosts.yml"
Write-Host "  2. ansible-playbook playbooks/site.yml --limit <hostname>"
