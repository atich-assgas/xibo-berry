# Berries

Os endereços abaixo são registros do inventário; IPs Ethernet temporários
devem ser confirmados antes do uso. O [plano da CLI](../PLANO-FLASH-RASPBERRIES.md)
prevê atualizar apenas o dispositivo identificado e verificado, sem copiar
MACs do histórico ou marcar conectividade como aprovada apenas pela reserva.

Inventário dos Raspberry Pis. Como a rede Wi-Fi dos equipamentos não aceita
SSH diretamente do computador local, use o servidor DHCP como salto SSH.

| Berry                | MAC `wlan0`         | IP Wi-Fi reservado | IP Ethernet temporário | Comando SSH via salto                                    |
| -------------------- | ------------------- | ------------------ | ---------------------- | -------------------------------------------------------- |
| `berry-tv-campus-01` | `e4:5f:01:35:b8:2d` | `172.20.111.237`   | `172.20.69.233`        | `ssh -J USUARIO_DHCP@SERVIDOR_DHCP berry@172.20.111.237` |
| `berry-tv-campus-02` | `e4:5f:01:20:11:2a` | `172.20.111.238`   | `172.20.68.136`        | `ssh -J USUARIO_DHCP@SERVIDOR_DHCP berry@172.20.111.238` |

Os exemplos usam `USUARIO_DHCP` e `SERVIDOR_DHCP` como marcadores; substitua
pelos valores privados `DHCP_USERNAME` e `DHCP_SERVER` do `.env`.

## Acesso SSH

Substitua `usuario_dhcp` pelo valor de `DHCP_USERNAME` do `.env` seguro:

```powershell
ssh -J usuario_dhcp@SERVIDOR_DHCP berry@172.20.111.237
ssh -J usuario_dhcp@SERVIDOR_DHCP berry@172.20.111.238
```

| Papel       | Endereço         | Uso                   |
| ----------- | ---------------- | --------------------- |
| Salto DHCP  | `SERVIDOR_DHCP`  | Primeiro salto do SSH |
| Berry 01    | `172.20.111.237` | Destino Wi-Fi         |
| Berry 02    | `172.20.111.238` | Destino Wi-Fi         |
| Ethernet 01 | `172.20.69.233`  | Recuperação com cabo  |
| Ethernet 02 | `172.20.68.136`  | Recuperação com cabo  |

## Atualizar os IPs temporários

Execute a consulta somente leitura antes de usar os comandos acima:

```powershell
.\scripts\dhcp\listar-conexoes-dhcp.ps1 -EnvFile ".\.env" -Hostname "berry" -Horas 24
```

Se o salto não alcançar o IP Wi-Fi, use temporariamente o IP Ethernet para
renovar o Wi-Fi e investigar a rede. Consulte `BERRY-SSH-OPERACAO.md`.

Não armazenar senhas, chaves privadas ou credenciais neste arquivo.
