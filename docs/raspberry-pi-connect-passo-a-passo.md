# Raspberry Pi `berry-01` — acesso remoto pelo Raspberry Pi Connect

Este documento registra o procedimento que funcionou para acessar o Raspberry Pi
sem monitor ou adaptador micro-HDMI.

## Histórico e automação planejada

Os IPs e resultados abaixo pertencem às sessões registradas, não comprovam
o estado atual de uma placa. Para uma nova instalação, seguir o
[plano da CLI](../PLANO-FLASH-RASPBERRIES.md), que inclui entrada na rede:
identificação, reserva Wi-Fi, aprovação DHCP, renovação e validação real de
Internet, CMS e SSH antes do player. A CLI ainda não está implementada.
Vínculo Pi Connect continua independente e pode exigir confirmação no navegador.

## Resultado histórico

- Hostname: `berry-01`
- Usuário Linux: `berry`
- Raspberry Pi Connect: habilitado e vinculado à conta Raspberry Pi
- Interface usada para Internet: `wlan0`
- Rede Wi-Fi: `UFFS-Equipamentos`
- IP observado no Wi-Fi: `172.20.109.15`
- Gateway do Wi-Fi: `172.20.111.254`
- Servidor DHCP usado como ponte SSH em troubleshooting: `SERVIDOR_DHCP`

O acesso web é feito em:

```text
https://connect.raspberrypi.com
```

O Raspberry Pi Connect gera uma URL de verificação durante o comando `signin`.
Essa URL deve ser aberta no navegador para vincular o dispositivo à conta
Raspberry Pi.

## 1. Gravar o cartão com o Raspberry Pi Imager

No Raspberry Pi Imager:

1. Selecione o Raspberry Pi OS Bookworm ou posterior.
2. Configure o hostname como `berry-01`.
3. Crie o usuário `berry`.
4. Defina a senha do usuário.
5. Configure o Wi-Fi `UFFS-Equipamentos` com a senha correta.
6. Em acesso remoto, ative o SSH.
7. Selecione autenticação por chave pública.
8. Use a chave pública correspondente a:

```text
C:\Users\Administrador\.ssh\id_ed25519
```

O arquivo usado no Windows para autenticar é a chave privada:

```text
C:\Users\Administrador\.ssh\id_ed25519
```

Não copie a chave privada para o Raspberry Pi nem a coloque no DHCP.

## 2. Localizar o Raspberry no DHCP

Mantenha o `.env` privado na raiz deste projeto, criado a partir de
`.example.env`. Não registrar seus valores neste guia.
As variáveis necessárias são:

```env
DHCP_USERNAME=
DHCP_PASSWORD=
DHCP_SERVER=
```

Execute no PowerShell:

```powershell
.\scripts\dhcp\listar-conexoes-dhcp.ps1 -EnvFile ".\.env" -Horas 2
```

O hostname pode aparecer em duas interfaces. No caso observado:

```text
eth0  -> e4:5f:01:35:b8:2b -> 172.20.69.233
wlan0 -> e4:5f:01:35:b8:2d -> 172.20.109.15
```

O IP `172.20.109.15` foi o endereço que respondeu na porta SSH quando o Wi-Fi
`UFFS-Equipamentos` estava ativo.

## 3. Conectar por SSH diretamente

Quando a porta TCP/22 estiver acessível a partir do computador local, use o IP
do Wi-Fi diretamente:

```powershell
ssh -o ConnectTimeout=10 -i "$env:USERPROFILE\.ssh\id_ed25519" berry@172.20.109.15
```

Esse é o método preferencial. A verificação realizada no ambiente confirmou
`172.20.109.15:22` acessível diretamente.

## 4. Método alternativo de troubleshooting via DHCP

Se o computador local não conseguir alcançar diretamente `172.20.109.15`, use
`SERVIDOR_DHCP` como salto SSH:

```powershell
ssh -o ConnectTimeout=10 -J USUARIO_DHCP@SERVIDOR_DHCP -i "$env:USERPROFILE\.ssh\id_ed25519" berry@172.20.109.15
```

Esse método alternativo usa:

- a credencial de `USUARIO_DHCP` somente no salto DHCP;
- a chave pessoal `id_ed25519` para o usuário `berry` no Raspberry.

Não é necessário colocar a chave de `USUARIO_DHCP` no Raspberry.

## 5. Conectar o Wi-Fi pelo NetworkManager

Para executar comandos remotamente com segurança, siga também
[`BERRY-SSH-OPERACAO.md`](BERRY-SSH-OPERACAO.md). Use o cabo Ethernet e o UUID
do perfil; não remova um perfil Wi-Fi ativo sem uma rota Ethernet confirmada.

Não apague e recrie o perfil automaticamente. Primeiro liste os perfis, escolha
o UUID ativo e renove-o pelo cabo Ethernet. O Wi-Fi deve aparecer em `wlan0` e
a rota para `1.1.1.1` deve indicar `dev wlan0`. O procedimento copiável está
em [`BERRY-SSH-OPERACAO.md`](BERRY-SSH-OPERACAO.md).

## 6. Testar a Internet antes do Raspberry Pi Connect

Ainda no Raspberry:

```bash
curl -4 -I --connect-timeout 10 --max-time 15 https://api.connect.raspberrypi.com/up
```

O teste bem-sucedido retornou `HTTP/2 200`. Se houver timeout, a rota ainda
está passando pela Ethernet/portal ou a VLAN não liberou a saída HTTPS.

## 7. Ativar e vincular o Raspberry Pi Connect

No Raspberry, como usuário `berry`:

```bash
rpi-connect on
```

Depois:

```bash
rpi-connect signin
```

O comando exibe uma URL semelhante a:

```text
https://connect.raspberrypi.com/verify/XXXX-XXXX
```

Abra a URL em um navegador, entre na conta Raspberry Pi e confirme a
criação/vinculação do dispositivo.

Depois, abra:

```text
https://connect.raspberrypi.com
```

O dispositivo `berry-01` deverá aparecer no painel. O Connect permite acesso
remoto pelo navegador, incluindo shell remoto; o compartilhamento de tela
depende de uma sessão gráfica compatível ativa.

## 8. Diagnóstico do Raspberry Pi Connect

```bash
rpi-connect status
```

```bash
rpi-connect doctor
```

O resultado esperado inclui sucesso para:

```text
Communication with Raspberry Pi Connect WebSocket server
Communication with Raspberry Pi Connect API
Authentication with Raspberry Pi Connect API
```

## 9. Liberação de rede necessária

Em redes restritivas, libere tráfego de saída do Raspberry para:

```text
api.connect.raspberrypi.com TCP/443
ws.connect.raspberrypi.com TCP/443
```

Para STUN/TURN:

```text
stun.raspberrypi.com UDP/3478
turn1.raspberrypi.com UDP/3478, UDP/443, UDP/49152-65535
turn2.raspberrypi.com UDP/3478, UDP/443, UDP/49152-65535
turn3.raspberrypi.com UDP/3478, UDP/443, UDP/49152-65535
```

Também podem ser necessários TCP `3478` e `443` para `turn1`, `turn2` e `turn3`.

Não é necessário abrir portas de entrada nem configurar port forwarding para o
Raspberry Pi Connect.

## 10. Observação sobre a reserva DHCP

O Raspberry possui MACs diferentes para Ethernet e Wi-Fi. A reserva DHCP precisa
usar o MAC da interface que será utilizada:

```text
eth0:  e4:5f:01:35:b8:2b
wlan0: e4:5f:01:35:b8:2d
```

O registro anterior atribuía à reserva Wi-Fi do Berry 01 o MAC Ethernet
`e4:5f:01:35:b8:2b`, em contradição com a interface Wi-Fi identificada acima,
`e4:5f:01:35:b8:2d`. Não usar esse histórico como confirmação do servidor.
Consultar o inventário em `BERRIES.md`, ler os MACs da própria placa e obter
o `dhcpd.conf` atual antes de preparar qualquer alteração de reserva.
Esta correção documental não consultou nem alterou o DHCP de produção.

Uma reserva DHCP apenas fixa o IP; ela não substitui a autenticação de portal
cativo nem libera automaticamente a saída para a Internet.

## Fontes

- [Raspberry Pi Connect — documentação oficial](https://www.raspberrypi.com/documentation/services/connect.html)
- [Raspberry Pi Connect — troubleshooting oficial](https://www.raspberrypi.com/documentation/services/connect.html)
