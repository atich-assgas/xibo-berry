# Configuração privada

O [plano da CLI](../PLANO-FLASH-RASPBERRIES.md) prevê flash, rede e deploy no
mesmo fluxo, com confirmações independentes para apagar cartão e aplicar DHCP.
Novas variáveis e o adaptador de credenciais estão apenas planejados; não
foram acrescentados ao `.env` ou às ferramentas de infraestrutura nesta etapa.

O único arquivo de variáveis do operador é `.env`, na raiz do projeto.
O único modelo é `.example.env`; seus valores são vazios. Em instalação
nova, copie o modelo e preencha o arquivo privado. Não sobrescreva o `.env`
de uma instalação existente nem altere a senha do banco já inicializado.

| Seção                           | Variáveis                                                        |
| ------------------------------- | ---------------------------------------------------------------- |
| DHCP                            | `DHCP_USERNAME`, `DHCP_PASSWORD`, `DHCP_SERVER`                  |
| Wi-Fi dos Berries               | `BERRY_WIFI_PASSWORD`                                            |
| CMS: banco e administrador      | `XIBO_DB_PASSWORD`, `XIBO_ADMIN_USERNAME`, `XIBO_ADMIN_PASSWORD` |
| CMS: identificação e telemetria | `XIBO_SERVER_NAME`, `XIBO_USAGE_REPORT`                          |
| Player: conexão                 | `XIBO_CMS_URL`, `XIBO_CMS_KEY`                                   |
| Player: OAuth opcional          | `XIBO_API_CLIENT_ID`, `XIBO_API_CLIENT_SECRET`                   |

As atribuições atuais não usam aspas. Se um valor futuro contiver espaços,
interpolação com `$` ou outras particularidades do formato dotenv, conferir
a leitura em cada consumidor antes de aplicar.

O Compose lê o `.env` automaticamente e mapeia apenas as variáveis do CMS
para os nomes exigidos pelas imagens. As credenciais DHCP e Wi-Fi não são
injetadas nos containers. Não imprimir `docker compose config` sem `--quiet`,
pois a configuração renderizada contém valores privados.

Os scripts `scripts/dhcp/` leem os nomes `DHCP_*` do `.env` da raiz por padrão.
O projeto `ti` possui configuração independente e não foi alterado; arquivos
legados dele podem usar nomes diferentes e não são intercambiáveis diretamente.

O `configs/apply.sh` do player lê apenas as quatro variáveis de conexão e
OAuth `XIBO_*`. Pode selecionar outro arquivo com `XIBO_ENV_FILE` ou receber
variáveis exportadas. Ele não executa o conteúdo do arquivo como shell.
Não copiar o `.env` completo para um Berry: o dispositivo recebe somente sua
configuração de player, sem senhas do DHCP, do Wi-Fi ou do administrador CMS.

Credenciais de FOG e roteadores foram retiradas por não terem uso no projeto.
Não registrar valores privados em guias, exemplos, logs ou arquivos versionados.
Os testes usam exclusivamente valores fictícios.
