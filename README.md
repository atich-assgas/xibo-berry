# Projeto berry

Documentação e ferramentas para Raspberry Pis usados em telas de informes da UFFS.

## Organização

- [Inventário e SSH](docs/BERRIES.md).
- [Flash, rede e Raspberry Pi Connect](docs/raspberry-pi-connect-passo-a-passo.md).
- [Operação SSH nos Berries](docs/BERRY-SSH-OPERACAO.md).
- [Operação segura do DHCP](docs/DHCP.md).
- [Deploy e operação do Xibo Chromium](docs/XIBO-CHROMIUM-BERRY-01.md).
- [Alterações no player](xiboplayer-chromium/BERRY.md).
- [Plano da CLI: flash, rede e player](PLANO-FLASH-RASPBERRIES.md).

A CLI ainda é uma proposta, não uma ferramenta disponível. O plano inclui
descoberta de interfaces, reserva DHCP Wi-Fi, confirmação antes de aplicar,
validação de Internet/SSH e deploy. Reserva DHCP não substitui liberação de rede.

| Pasta | Conteúdo |
| --- | --- |
| `xiboplayer-chromium/` | Código upstream e nossas correções integradas |
| `docs/` | Guias de instalação, DHCP, inventário e operação |
| `docs/evidencias/` | Capturas usadas na documentação |
| `scripts/dhcp/` | Consultas PowerShell somente leitura |
| `shared/` | Dados locais persistentes do CMS, fora do Git |

O serviço principal é `docker-compose.yml`, na raiz, com `.env` privado.
O projeto Compose mantém o nome `xibo` para preservar a identidade dos serviços.
Consulte [a operação do CMS Docker](docs/XIBO-DOCKER.md).

A configuração fica apenas no `.env` privado da raiz. O único modelo é
`.example.env`, com nomes ALL CAPS, valores vazios e seções por serviço.
Consulte [as variáveis e seu uso](docs/CONFIGURACAO.md).

`AGENTS.md` permanece na raiz com as regras operacionais.
Execute os comandos PowerShell dos guias a partir da raiz deste projeto.

O player mantém seu histórico upstream em `xiboplayer-chromium/.git` nesta
máquina. O repositório principal também versiona os arquivos completos do
player, sem depender de submódulo ou de um remoto privado. O histórico Git
interno não é incluído no commit principal.

Não versionar credenciais, chaves privadas, leases ou configurações de produção.
Os dados do Docker ficam em `shared/`; não executar `docker compose down -v`.
