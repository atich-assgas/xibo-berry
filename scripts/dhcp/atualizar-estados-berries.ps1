[CmdletBinding()]
param(
    [string]$EnvFile = (Join-Path $PSScriptRoot '..\..\.env'),
    [ValidateRange(1, 168)]
    [int]$Horas = 6,
    [string[]]$Hostnames = @('berry', 'berry-02', 'berry-tv-campus-01', 'berry-matheus')
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

$envValues = Read-DotEnv -Path $EnvFile
foreach ($required in @('DHCP_USERNAME', 'DHCP_PASSWORD', 'DHCP_SERVER')) {
    if (-not $envValues.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($envValues[$required])) {
        throw "Variável obrigatória ausente no .env: $required"
    }
}
if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    throw 'O módulo Posh-SSH não está instalado. Instale com: Install-Module Posh-SSH -Scope CurrentUser'
}
Import-Module Posh-SSH -ErrorAction Stop

$wantedPattern = (($Hostnames | ForEach-Object {
    if ($_ -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]*$') { throw "Hostname inválido: $_" }
    [regex]::Escape($_)
}) -join '|')

$securePassword = ConvertTo-SecureString $envValues.DHCP_PASSWORD -AsPlainText -Force
$credential = [pscredential]::new($envValues.DHCP_USERNAME, $securePassword)
$session = $null
$remoteCommand = @"
set -o pipefail
echo "META|server|`$(hostname)"
echo "META|time|`$(date '+%F %T %Z')"
echo 'EVENTS|begin'
journalctl -u isc-dhcp-server --since "$Horas hours ago" --no-pager -o short-iso 2>/dev/null \
  | grep -Eai 'DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPNAK|$wantedPattern' || true
echo 'EVENTS|end'
echo 'LEASES|begin'
if [ -r /var/lib/dhcp/dhcpd.leases ]; then
  awk -v wanted='$wantedPattern' '
    /^lease[[:space:]]/ {
      if (ip != "" && keep) print "LEASE|" ip "|" mac "|" host "|" state "|" ends "|" relay
      ip=`$2; mac=""; host=""; state=""; ends=""; relay=0; keep=0
    }
    /hardware ethernet/ { mac=`$3; gsub(/;/, "", mac) }
    /client-hostname/ { host=`$2; gsub(/[";]/, "", host); if (tolower(host) ~ wanted) keep=1 }
    /^[[:space:]]*binding state[[:space:]]/ { state=`$3; gsub(/;/, "", state) }
    /^[[:space:]]*ends[[:space:]]/ { ends=`$3 " " `$4; gsub(/;/, "", ends) }
    /option agent.circuit-id/ { relay=1 }
    /hardware ethernet/ && tolower(`$3) ~ /b8:27:eb|e4:5f:01|dc:a6:32|d8:3a:dd|2c:cf:67|b0:be:76|88:a2:9e|28:cd:c1/ { keep=1 }
    /^}/ {
      if (ip != "" && keep) print "LEASE|" ip "|" mac "|" host "|" state "|" ends "|" relay
      ip=""
    }
  ' /var/lib/dhcp/dhcpd.leases
else
  echo 'LEASES|unreadable'
fi
echo 'LEASES|end'
"@

try {
    $session = New-SSHSession -ComputerName $envValues.DHCP_SERVER -Credential $credential -AcceptKey -ConnectionTimeout 10 -ErrorAction Stop
    $result = Invoke-SSHCommand -SessionId $session.SessionId -Command $remoteCommand
    if ($result.ExitStatus -ne 0) {
        throw "Consulta remota falhou (status $($result.ExitStatus)): $($result.Error)"
    }
    $output = @($result.Output)
}
finally {
    if ($session) { Remove-SSHSession -SessionId $session.SessionId | Out-Null }
    $securePassword.Dispose()
    $credential = $null
}

$server = $output | Where-Object { $_ -like 'META|server|*' } | Select-Object -First 1
$events = @($output | Where-Object { $_ -and $_ -notmatch '^(META|EVENTS|LEASES)\|' -and $_ -notlike 'LEASE|*' })
$leases = @($output | Where-Object { $_ -like 'LEASE|*' })

Write-Host "Servidor DHCP: $server"
Write-Host "Hostnames procurados: $($Hostnames -join ', ')"
Write-Host "Janela consultada: últimas $Horas hora(s)"
Write-Host ''
Write-Host 'Eventos DHCP:' -ForegroundColor Cyan
if ($events) { $events | ForEach-Object { Write-Host $_ } } else { Write-Host '(nenhum evento encontrado)' }
Write-Host ''
Write-Host 'Leases encontrados:' -ForegroundColor Cyan
if ($leases) {
    foreach ($lease in $leases) {
        $parts = $lease -split '\|', 7
        $interface = if ($parts[6] -eq '1') { 'Ethernet' } elseif ($parts[1] -match '^172\.20\.(10[4-9]|11[01])\.') { 'Wi-Fi provável' } else { 'Não determinado' }
        Write-Host ("IP={0} | MAC={1} | Hostname={2} | Estado={3} | Fim={4} | Interface={5}" -f $parts[1], $parts[2], $parts[3], $parts[4], $parts[5], $interface)
    }
} else {
    Write-Warning 'Nenhum lease correspondente foi encontrado.'
}
Write-Host ''
Write-Host 'Este script é somente leitura: não altera dhcpd.conf, leases, política de acesso nem o serviço DHCP.' -ForegroundColor Green
