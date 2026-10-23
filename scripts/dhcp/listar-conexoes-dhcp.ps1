[CmdletBinding()]
param(
    [string]$EnvFile = (Join-Path $PSScriptRoot '..\..\.env'),
    [int]$Horas = 6,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9.-]*$')]
    [string]$Hostname = 'berry-matheus'
)

$ErrorActionPreference = 'Stop'

function Read-DotEnv {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Arquivo .env não encontrado: $Path"
    }
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -notmatch '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            throw "Linha inválida no .env; conteúdo omitido por segurança"
        }
        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $values[$name] = $value
    }
    return $values
}

function Invoke-ReadOnlyDhcpQuery {
    param(
        [Parameter(Mandatory)]$Session,
        [Parameter(Mandatory)][string]$Command
    )
    $result = Invoke-SSHCommand -SessionId $Session.SessionId -Command $Command
    if ($result.ExitStatus -ne 0) {
        throw "Consulta remota falhou (status $($result.ExitStatus)): $($result.Error)"
    }
    return $result.Output
}

$envValues = Read-DotEnv -Path $EnvFile
foreach ($required in @('DHCP_USERNAME', 'DHCP_PASSWORD', 'DHCP_SERVER')) {
    if (-not $envValues.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($envValues[$required])) {
        throw "Variável obrigatória ausente no .env: $required"
    }
}
if ($Horas -lt 1 -or $Horas -gt 168) {
    throw 'Horas deve estar entre 1 e 168.'
}
if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    throw 'O módulo Posh-SSH não está instalado. Instale com: Install-Module Posh-SSH -Scope CurrentUser'
}
Import-Module Posh-SSH -ErrorAction Stop

$securePassword = ConvertTo-SecureString $envValues.DHCP_PASSWORD -AsPlainText -Force
$credential = [pscredential]::new($envValues.DHCP_USERNAME, $securePassword)
$session = $null

$remoteCommand = @"
set -o pipefail
since="$Horas hours ago"
echo "META|server|`$(hostname)"
echo "META|time|`$(date '+%F %T %Z')"
echo 'EVENTS|begin'
journalctl -u isc-dhcp-server --since "`$since" --no-pager -o short-iso 2>/dev/null \
  | grep -Eai 'DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPNAK|$Hostname|raspberry|unknown|client-hostname' || true
for file in /var/log/syslog /var/log/daemon.log; do
  if [ -r "`$file" ]; then
    tail -n 20000 "`$file" | grep -Eai 'dhcpd.*(DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPNAK|$Hostname|raspberry|unknown|client-hostname)' || true
  fi
done
echo 'EVENTS|end'
echo 'LEASES|begin'
if [ -r /var/lib/dhcp/dhcpd.leases ]; then
  awk '
    /^lease[[:space:]]/ { block=`$0 ORS; keep=0; next }
    block != "" {
      block=block `$0 ORS
      low=tolower(`$0)
      if (low ~ /client-hostname|hardware ethernet/ && low ~ /$Hostname|raspberry|b8:27:eb|e4:5f:01|dc:a6:32|d8:3a:dd|2c:cf:67|b0:be:76|88:a2:9e|28:cd:c1/) { keep=1 }
      if (`$0 ~ /^}/) { if (keep) printf "%s", block; block=""; keep=0 }
    }
  ' /var/lib/dhcp/dhcpd.leases
else
  echo 'LEASES|unreadable'
fi
echo 'LEASES|end'
"@

try {
    $session = New-SSHSession -ComputerName $envValues.DHCP_SERVER -Credential $credential -AcceptKey -ConnectionTimeout 10 -ErrorAction Stop
    $output = @(Invoke-ReadOnlyDhcpQuery -Session $session -Command $remoteCommand)
}
finally {
    if ($session) { Remove-SSHSession -SessionId $session.SessionId | Out-Null }
    $securePassword.Dispose()
    $credential = $null
}

$events = @($output | Where-Object { $_ -notmatch '^META\|' -and $_ -notmatch '^EVENTS\|' -and $_ -notmatch '^LEASES\|' })
$leases = @($output | Where-Object { $_ -match '(^lease\s|client-hostname|hardware ethernet|ends\s)' })
$serverLine = $output | Where-Object { $_ -match '^META\|server\|' } | Select-Object -First 1

Write-Host "Servidor DHCP: $serverLine"
Write-Host "Janela consultada: últimas $Horas hora(s)"
Write-Host ''
if (-not $events -and -not $leases) {
    Write-Warning 'Nenhuma conexão/evento Raspberry ou berry-matheus foi encontrado na janela consultada.'
    Write-Host 'Para ampliar a janela: .\scripts\dhcp\listar-conexoes-dhcp.ps1 -EnvFile ".\.env" -Horas 24'
    exit 0
}
Write-Host 'Eventos DHCP encontrados:' -ForegroundColor Cyan
if ($events) { $events | ForEach-Object { Write-Host $_ } } else { Write-Host '(nenhum evento nos logs)' }
Write-Host ''
Write-Host 'Blocos de lease relacionados:' -ForegroundColor Cyan
if ($leases) { $leases | ForEach-Object { Write-Host $_ } } else { Write-Host '(nenhum lease correspondente)' }
Write-Host ''
Write-Host 'Este script é somente leitura: não altera dhcpd.conf, leases, política de acesso nem o serviço DHCP.' -ForegroundColor Green
