# Operação SSH nos Berries

Procedimento curto para acessar os Berries pelo Wi-Fi usando o servidor DHCP
como salto e para recuperar o acesso pelo cabo quando necessário.

## Separação dos ambientes

- PowerShell local: iniciar o SSH com `ProxyJump`.
- Servidor DHCP: primeiro salto em `SERVIDOR_DHCP`.
- Berry: executar comandos Linux (`nmcli`, `ip`, `curl` e `sudo`).

Nunca enviar cmdlets PowerShell para um Berry ou comandos Linux para o
PowerShell local.

## Acesso normal pelo Wi-Fi

Use o usuário do Berry no destino e o usuário `DHCP_USERNAME` do `.env` no
salto. Não coloque a senha em comandos ou arquivos:

```powershell
ssh -J usuario_dhcp@SERVIDOR_DHCP berry@172.20.111.237
ssh -J usuario_dhcp@SERVIDOR_DHCP berry@172.20.111.238
```

## Recuperação pelo cabo

Use o IP Ethernet correspondente somente para renovar o Wi-Fi ou diagnosticar
um Berry que ainda não esteja acessível pelo salto:

| Berry | IP Ethernet     |
| ----- | --------------- |
| 01    | `172.20.69.233` |
| 02    | `172.20.68.136` |

```powershell
ssh berry@IP_ETH0
```

## Localizar interfaces e renovar o Wi-Fi

Consulte os leases com o script somente leitura:

```powershell
.\scripts\dhcp\listar-conexoes-dhcp.ps1 -EnvFile ".\.env" -Horas 24
```

Não confunda o MAC de `eth0` com o de `wlan0`. Para a reserva Wi-Fi, use o
MAC exibido pelo próprio Berry:

```bash
ip link show wlan0
cat /sys/class/net/wlan0/address
```

O hostname pode ter dois leases simultâneos, um por interface.

Antes de modificar a rede, confirme:

```bash
hostname
ip -br link
nmcli -t -f NAME,UUID,TYPE,DEVICE con show
ip route get 1.1.1.1
```

O IP Ethernet deve permanecer acessível durante a renovação.

Não remova e recrie um perfil que já está correto. Obtenha o UUID exato em
`nmcli` e renove-o pelo cabo:

```bash
sudo nmcli con down uuid UUID_WIFI
sudo nmcli con up uuid UUID_WIFI
ip -br addr show wlan0
ip route get 1.1.1.1
```

Se `sudo` solicitar senha, forneça a senha do usuário `berry` somente no
prompt interativo ou em `SecureString`; nunca coloque a senha no comando,
arquivo, log ou saída.

Se não houver autorização sudo, pare e peça a senha ao operador. Não tente
substituir por `sudo -n`, senha DHCP ou senha Wi-Fi.

## Validar Internet

O resultado deve indicar `dev wlan0`:

```bash
ip route get 1.1.1.1
curl -4 -I --connect-timeout 10 --max-time 15 https://api.connect.raspberrypi.com/up
```

Considere a etapa concluída somente com resposta HTTP bem-sucedida e rota
pela `wlan0`.

## Alteração de reserva DHCP

Antes de editar, compare o MAC de `wlan0` de cada Berry com o bloco atual do
`dhcpd.conf`. Altere somente o `hardware ethernet` correspondente, preserve
as duas reservas e valide o arquivo completo. Depois de aplicar, renove o
perfil Wi-Fi de cada Berry para obter o novo endereço; alterar a configuração
não força um cliente com lease antigo a trocar de IP imediatamente.

## Erros conhecidos

- `Set-SCPItem` nesta instalação não aceita `-PathType`; use `-Destination /tmp`
  com `-NewName dhcpd.conf`.
- O lease DHCP de uma interface pode continuar ativo até renovação; isso não
  prova que a reserva não funcionou.
- Não use o IP reservado para SSH antes de confirmar que o cliente renovou o
  lease. Mantenha a sessão pelo IP Ethernet.
