# Automação de flash e provisionamento dos Berries — Implementation Plan

Este é o material consolidado de origem. A organização formal para execução
SDD/TDD está nos rascunhos abaixo, que aguardam aprovação antes de implementar:

- [Spec](docs/superpowers/specs/2026-10-23-xibo-berry-cli-design.md).
- [Plano SDD/TDD](docs/superpowers/plans/2026-10-23-xibo-berry-cli-sdd-tdd.md).

Os contratos refinados de sudo, simulação, CMS inicial e retomada estão na spec.
Em caso de conflito, revisar o material de origem contra a spec aprovada.

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans para executar este plano tarefa por tarefa.
> Use as caixas de seleção para acompanhar o progresso.

**Goal:** automatizar flash, entrada na rede e deploy de novos Berries por CLI,
com confirmações independentes antes de apagar mídia e aplicar DHCP.

**Architecture:** PowerShell 7 no Windows coordena o Raspberry Pi Imager CLI.
Uma imagem oficial limpa recebe configuração exclusiva por dispositivo e um
bootstrap compatível com essa imagem. Após o primeiro boot, a mesma CLI
identifica interfaces, prepara a reserva DHCP e verifica a conectividade antes
de instalar o player. O servidor DHCP continua sendo operado pelo fluxo de `ti`.

**Tech Stack:** PowerShell 7, Pester 5, Raspberry Pi Imager CLI, Raspberry Pi OS
arm64 com desktop, Bash, OpenSSH, Posh-SSH, NetworkManager, ISC DHCP,
formatador `iscdhcp`, Node.js, npm e systemd de usuário.

**Spec:** os requisitos e as decisões propostas estão nas seções abaixo deste
documento, baseados nos guias atuais do repositório. Este arquivo é uma proposta
para revisão, não autorização para gravar discos ou alterar infraestrutura.

## Escopo e decisões propostas

- Implementar primeiro para Windows, um cartão e um Berry por execução.
- Usar imagem oficial com desktop: o player atual depende de sessão gráfica.
- Fixar versão, URL e SHA256 da imagem depois de testar um Raspberry reserva.
- Reutilizar a imagem baixada e verificada, não baixar novamente por cartão.
- Personalizar hostname, usuário e conjunto de chaves públicas por dispositivo.
- Usar uma chave privada individual por pessoa, nunca uma privada compartilhada.
- Receber nome e chave na CLI ou no cadastro, sem exigir escolhas na GUI.
- Reescrever os scripts de diagnóstico para usar evidências estruturadas e
  a identidade definida no flash, com fluxo curto e retomável para o operador.
- Entregar dependências, serviços e verificações reproduzíveis a outro operador
  ou agente de IA, sem depender desta máquina ou do histórico da conversa.
- Usar o `.env` existente como única fonte privada de variáveis do operador.
- Para operações de infraestrutura, usar as credenciais autorizadas de `ti`,
  sem copiar, renomear ou sobrescrever seu `.env` independente.
- Integrar descoberta, reserva Wi-Fi e validação de rede na mesma CLI.
- Primeiro acessar pelo cabo; usar o MAC real da interface Wi-Fi na reserva.
- Instalar o player a partir de uma versão identificada do código deste repo.
- Tratar Pi Connect e autorização do display como etapas verificáveis separadas.
- Encerrar com guias reescritos e numerados para instalação do zero e expansão.
- Não executar este plano automaticamente após sua criação.

Alternativas consideradas:

1. Imagem oficial e bootstrap: recomendada, separa OS, identidade e aplicação.
2. Imagem personalizada construída em Linux: reduz o tempo de instalação,
   mas exige outro pipeline; considerar somente depois do piloto.
3. Clonar o cartão de um Berry em produção: não adotar, pois duplica estado,
   credenciais e identidade e dificulta reproduzir as alterações.

Essas são escolhas propostas pelo agente, ainda sujeitas à revisão do usuário.

## Global Constraints

- Nunca apagar um disco selecionado automaticamente ou apenas por letra.
- Recusar discos de sistema/boot, destinos ambíguos e identidade desconhecida.
- A operação padrão é simulação; gravação exige `-Execute` e confirmação.
- Confirmar identidade e capacidade imediatamente antes de chamar o gravador.
- Manter verificação de escrita do Imager; não usar `--disable-verify`.
- Não elevar privilégios silenciosamente; explicar quando requer administrador.
- Não imprimir senhas, chaves, hashes de senha ou conteúdo do `.env`.
- Não copiar `.env`, chave SSH privada ou credenciais administrativas ao Berry.
- Não copiar host keys SSH, perfil Chromium ou sessão Pi Connect de outro Pi.
- Não modificar `shared/`, containers CMS ou instalações dos Berries atuais.
- Preparar e validar DHCP não autoriza aplicar nem reiniciar o serviço.
- Aplicar DHCP somente em etapa própria, após confirmação explícita do diff.
- Não alterar switches, VLANs, ACLs, portal ou firewall automaticamente.
- Preservar proxy/PWA em `0.7.15` e instalar pelo `package-lock.json` com `npm ci`.
- Só considerar pronto após teste visual, parada, reinício e reboot.
- Não criar commits, publicar artefatos ou iniciar rollout sem solicitação.
- Simplificar a experiência, não os controles de disco, identidade e DHCP.

## Review Focus

1. Cartão removido ou substituído entre seleção e gravação: abortar sem escrever.
2. Wi-Fi com espaços, aspas ou `$`: preservar o valor sem executar shell.
3. Falha de rede no primeiro boot: registrar estado sem marcar instalação pronta.
4. Reexecução sobre player existente: não trocar identidade nem sobrescrever chave.
5. Versão do Imager ou imagem incompatível: falhar antes de alterar o cartão.
6. Hostname com dois leases: distinguir Ethernet de Wi-Fi pelo MAC da placa.
7. IP ocupado ou pool dinâmico: recusar a reserva, sem tratar ping como prova.
8. Configuração DHCP alterada após revisão: invalidar a aprovação anterior.
9. Reserva aplicada sem acesso real: testar rota, DNS, HTTPS, CMS e SSH.
10. Rede exige cadastro adicional: reportar pendência e pedir autorização.

Cada condição deve ter teste na tarefa responsável, além da homologação física.

## Arquivos previstos e responsabilidades

- `scripts/flash/flash-berry.ps1`: entrada CLI, simulação e sequência de execução.
- `scripts/flash/FlashBerry.psm1`: descoberta, validação, imagem e payload.
- `scripts/flash/raspios-image.json`: versão, URL, arquitetura e SHA256 públicos.
- `scripts/flash/devices.example.json`: modelo de dispositivos, sem credenciais.
- `scripts/flash/templates/firstboot.sh`: bootstrap mínimo, sem segredos reais.
- `scripts/flash/templates/player.service`: unidade de provisionamento one-shot.
- `scripts/provision/provision-player.sh`: instalação idempotente do player.
- `scripts/network/NetworkBerry.psm1`: identidade da placa, conexão e testes.
- `scripts/dhcp/DhcpEnrollment.psm1`: adaptador para o fluxo seguro de `ti`.
- `scripts/flash/BerryWorkflow.psm1`: etapas e retomada sem repetir flash.
- `scripts/setup/dependencies.lock.json`: dependências e fontes homologadas.
- `scripts/setup/doctor-berry.ps1`: preflight e relatório de pré-requisitos.
- `scripts/setup/install-prerequisites.ps1`: instalação local autorizada.
- `scripts/common/Configuration.psm1`: leitura privada compartilhada do `.env`.
- `scripts/access/AuthorizedKeys.psm1`: validação e gestão de chaves públicas.
- `ssh/authorized-keys/`: chaves públicas aprovadas, sem material privado.
- `scripts/dhcp/listar-conexoes-dhcp.ps1`: reescrever consulta com filtros exatos.
- `scripts/dhcp/atualizar-estados-berries.ps1`: reescrever relatório por evidência.
- `tests/flash/FlashBerry.Tests.ps1`: testes Windows sem gravação física.
- `tests/network/NetworkBerry.Tests.ps1`: conexões e diagnósticos simulados.
- `tests/dhcp/DhcpEnrollment.Tests.ps1`: fixtures DHCP, sem servidor real.
- `tests/setup/Dependencies.Tests.ps1`: versões, descoberta e instalação opt-in.
- `tests/provision/`: testes Linux isolados, com dados fictícios.
- `docs/FLASH-CLI.md`: uso, recuperação e checklist do operador.
- `docs/REDE-CLI.md`: cadastro na rede, aprovação DHCP e diagnóstico.
- `.example.env`, `.gitignore`, `README.md`: descoberta e proteção dos artefatos.

Não mover o código de `xiboplayer-chromium/` nem reabrir a organização do repo.

## Contratos de entrada e saída

O cadastro local de dispositivos será JSON, com `Hostname`, `Username`,
`DisplayName` e `PublicKeyPaths`. Não conterá senhas, IP reservado inventado ou
identidade de outro player. O arquivo público de exemplo terá marcadores.
O hostname é o nome Linux escolhido para o Berry, não o usuário SSH nem o nome
do layout. `DisplayName` pode acompanhar o hostname, mas continua um campo
distinto. `PublicKeyPaths` é uma lista de arquivos públicos `.pub` aprovados,
um por pessoa/identidade autorizada; cada privada fica no PC do seu titular
ou no agente SSH. Exigir ao menos uma chave válida antes de gravar.
Após o primeiro contato, registrar separadamente `EthernetMac`, `WifiMac`,
`EthernetIp`, `WifiIp`, serial da placa e fingerprint SSH confirmado.
Esses campos são evidências coletadas, não valores inventados no modelo.
Não assumir que `eth0` e `wlan0` existirão com esses nomes em qualquer imagem.

Novas variáveis propostas, somente se necessárias, na mesma `.example.env`:

- `BERRY_WIFI_SSID`: SSID, sem valor concreto na documentação.
- `BERRY_WIFI_COUNTRY`: domínio regulatório explícito.
- `BERRY_TIMEZONE`: fuso configurável.

Reutilizar `BERRY_WIFI_PASSWORD`, `XIBO_CMS_URL` e `XIBO_CMS_KEY` existentes.
OAuth não é pré-requisito. Não criar senha padrão compartilhada entre a frota.
Se for necessária senha local, pedir por prompt seguro ou definir um fluxo
explícito de credencial por dispositivo; nunca usar a senha do DHCP.

Interface proposta:

```powershell
.\scripts\flash\flash-berry.ps1 -DeviceFile CAMINHO_JSON -DiskNumber NUMERO
```

Essa chamada apenas simula. A gravação acrescenta `-Execute` e
`-ConfirmErase "ERASE:IDENTIDADE_EXIBIDA"`; nunca oferecer um exemplo com
número de disco real. Autologin gráfico exige a opção separada
`-EnableDesktopAutologin`, com explicação de seu impacto de segurança.

O nome e a chave também podem ser informados diretamente:

```powershell
.\scripts\flash\flash-berry.ps1 -Hostname NOME_BERRY `
  -SshPublicKeyPath CAMINHO_CHAVE_PUB -DiskNumber NUMERO
```

Campos fornecidos na CLI preenchem o cadastro dessa execução. Se contradisserem
um cadastro já existente para a mesma placa, pedir confirmação e não alterar
o cadastro silenciosamente. Se faltarem nome ou chave, solicitar somente essas
entradas; não selecionar automaticamente a primeira chave encontrada.
Exibir nome, usuário e fingerprint da chave pública no resumo de confirmação.
Validar formato, existência e unicidade do hostname e o conteúdo público da
chave, não apenas sua extensão. Não enviar a chave privada ao Imager ou ao Pi.
O gerador escreve essas escolhas no mecanismo de customização homologado:
não há necessidade de repeti-las na interface gráfica do Raspberry Pi Imager.

Na reconexão, usar a identidade privada correspondente por agente SSH ou caminho
local selecionado, preservando prompts de passphrase. Distinguir a chave do
operador autorizada para login da host key gerada pelo Raspberry.

### Acesso SSH por pessoa e distribuição do projeto

- Cada pessoa gera e protege seu próprio par, preferencialmente com passphrase.
  O procedimento deve explicar como obter a pública sem revelar a privada.
- A CLI aceita uma lista em `-SshPublicKeyPath`, valida cada pública e grava
  o conjunto aprovado em `authorized_keys` da conta de manutenção do Berry.
  Mostrar todos os fingerprints selecionados, não somente o do operador atual.
- Públicas aprovadas podem acompanhar o projeto em `ssh/authorized-keys/`;
  não incluir privadas, passphrases ou uma privada codificada em base64 no `.env`.
  Validar o conteúdo real de cada arquivo, não confiar na extensão `.pub`.
- Adicionar ou revogar chaves em Berries existentes exige ação explícita, diff
  por fingerprint e confirmação. Não sobrescrever chaves desconhecidas nem
  remover o último acesso funcional sem uma alternativa testada.
- A conta Linux de manutenção pode continuar sendo `berry` neste primeiro
  fluxo; isso não cria contas individuais nem rastreabilidade completa por
  pessoa. Contas individuais e integração SSSD/AD/LDAP ficam fora deste lote.
- Não copiar a configuração de autenticação institucional do servidor DHCP.
  O acesso dele por SSSD/grupo é independente do acesso aos Berries.
- Preparar ZIP por lista de arquivos permitidos, não compactar a pasta inteira.
  Excluir `.env`, privadas, `.git`, `shared/`, backups e payloads temporários;
  incluir somente código, documentação, modelos vazios e públicas aprovadas.
  O `.gitignore` não protege uma compactação feita pelo Explorador do Windows.
- Credenciais necessárias ao operador são entregues separadamente por canal
  seguro e com escopo adequado. Receber o ZIP não concede acesso ao DHCP ou CMS.
- Validar com duas identidades: ambas acessam com suas privadas distintas;
  revogar uma não impede a outra, e uma chave não cadastrada é recusada.

### Padrão de nomes dos Berries

Todos os Berries deste projeto são destinados a televisões. Adotar o padrão
já usado no `dhcpd.conf`: `berry-tv-campus-NN`, com prefixo literal fixo.

- Consulta somente leitura ao servidor em 23/10/2026 confirmou as reservas
  `berry-tv-campus-01` e `berry-tv-campus-02`. Esses nomes não são legados nem
  precisam migrar para outro formato.
- `NN` é um sequencial positivo, com pelo menos dois dígitos: `01`, `02`,
  `03` e assim por diante; acima de `99`, usar `100`, sem truncar ou reutilizar.
- O próximo candidato após os registros consultados seria
  `berry-tv-campus-03`, não uma reserva criada ou disponibilidade garantida.
  Consultar novamente configuração e inventário antes de confirmar cada nome.
- Não acrescentar campus abreviado, prédio, setor ou local ao hostname.
  A localização física da TV é um campo separado do inventário e pode compor
  uma descrição amigável, sem mudar a identidade da placa.
- A CLI propõe o próximo sequencial disponível e mostra o resultado ao
  operador. O usuário pode informar um sequencial válido, sujeito à verificação
  de colisões; o arquivo local sozinho não comprova disponibilidade.
- Usar o hostname como nome da reserva DHCP e `DisplayName` inicial, mantendo
  usuário SSH, nome do layout, serial e MAC como campos distintos.
- Validar prefixo exato, sequência positiva, unicidade e limite de 63 caracteres.
  Não aceitar nomes novos como `berry1`, `berry-01` ou `raspberrypi`.
- Preservar nomes e reservas existentes. Não renomear placas, reservas ou
  displays em operação automaticamente; qualquer alteração exige autorização.

A mesma entrada recebe `-Stage`: `Flash`, `DiscoverNetwork`, `PrepareDhcp`,
`ApplyDhcp`, `VerifyNetwork`, `DeployPlayer` ou `All`.
Recebe também `-RunId` para retomada e `-InfrastructureRepo` para localizar
o repositório `ti`; não duplicar as ferramentas de infraestrutura em `berry`.
Sem `-Execute`, apenas simular. `-ConfirmErase` é exclusivo do flash e não
vale como aprovação DHCP. Com mudança a aplicar, `All` deve parar em
`AwaitingDhcpApproval` e exigir chamada separada de `ApplyDhcp` com confirmação
humana após validação. Reserva correta é no-op; uma retomada após aplicação
aprovada revalida a rede sem regravar cartão ou reaplicar a mesma reserva.

Estados propostos: `Planned`, `FlashVerified`, `AwaitingFirstBoot`,
`IdentityVerified`, `DhcpPrepared`, `AwaitingDhcpApproval`, `DhcpApplied`,
`NetworkVerified`, `PlayerConfigured` e `Accepted`.
Falhas ou liberações adicionais ficam em `NeedsOperator`; nunca promover uma
etapa somente porque a anterior retornou zero. O estado persistido não contém
credenciais, diff completo do servidor ou arquivo DHCP de produção.

Saída pública: identificador da execução, etapa, imagem/hash, identidade do
destino e resultado. Nunca incluir payload privado ou valores de credenciais.

## Tarefa 0: dependências e serviços reproduzíveis

**Arquivos:** manifesto em `scripts/setup/`, preflight, instalador opt-in,
testes de setup e a etapa documental de pré-requisitos.

**Interfaces:** `doctor-berry.ps1 -Profile PERFIL` aceita `Operator`, `Berry`,
`Infrastructure` ou `Tests`; perfis remotos exigem conexão identificada.
Retorna por item `Name`, `Role`, `Required`, `ExpectedVersion`,
`DetectedVersion`, `Source`, `Status` e `Remediation`, sem segredos.
O preflight não instala, atualiza, reinicia nem libera tráfego.

### Inventário obrigatório a consolidar

- Host operador: PowerShell 7, Git, OpenSSH Client, ferramentas Storage/CIM
  usadas na descoberta de disco e Raspberry Pi Imager CLI.
- Módulos PowerShell: `Posh-SSH` com cmdlets e parâmetros compatíveis com
  este ambiente; `Pester` 5 no perfil de testes. Registrar versões testadas.
- CMS: Docker Engine/Desktop e Compose v2; serviços `cms-web`, `cms-db`,
  `cms-xmr`, `cms-memcached` e `cms-quickchart`, com volumes e portas reais.
  Conferir imagens existentes: CMS `release-4.5.3`, MySQL `8.4`, XMR `1.3`,
  `memcached:alpine` e QuickChart sem tag explícita. Resolver e registrar
  digests homologados; não alegar reprodutibilidade com tags mutáveis apenas.
- Serviços internos da imagem CMS: identificar Apache/PHP, suporte X-Sendfile,
  tarefas agendadas e demais processos exigidos pela imagem em uso. Não os
  instalar separadamente no Windows; documentar o que o container já fornece.
- Berry: imagem desktop arm64, Bash, NetworkManager/`nmcli`, `iproute2`,
  resolução DNS, OpenSSH Server, systemd, sessão gráfica Wayland/labwc e seu
  gerenciador de login, Chromium, Node.js, npm, `jq`, `curl`, Git e certificados.
  Registrar o pacote que fornece cada comando e o que já vem na imagem.
- Player: launcher, servidor HTTP/proxy local, helper de parada e unidade
  `berry-xiboplayer.service`. Proxy e PWA em `0.7.15`, lockfile e dependências
  transitivas instalados por `npm ci`; registrar porta e dependência da sessão.
- Infraestrutura: OpenSSH e `isc-dhcp-server` já administrados em `ti`, acesso
  sudo interativo, formatador `iscdhcp` e validador `dhcpd -t`, inclusive os
  includes requeridos. Não copiar chaves/includes de produção para este repo.
- Opcionais/diagnóstico: Pi Connect, `kmsprint`, `vcgencmd`, `grim`, ferramentas
  X11 ou `unclutter` citadas pelo launcher; indicar quando se aplicam a Wayland
  ou X11 e não torná-las obrigatórias sem necessidade do caminho escolhido.
- Testes/build: Node test runner, Pester, Bash, Bats, jq e Markdownlint;
  para gerar DEB/RPM, ferramentas próprias e bibliotecas `scripts/packaging/`
  ausentes da tag clonada, obtidas de fonte/versionamento verificáveis.
  GitHub CLI e automação de navegador são opcionais, não requisitos do player.

### Critérios e implementação do inventário

- [ ] Percorrer scripts, unidades, Compose, manifestos/lockfiles, guias locais
  e materiais upstream realmente usados. Mapear cada dependência à fonte e
  classificar como runtime, setup, infraestrutura existente, teste ou opcional.
- [ ] Não instalar tudo que é citado indiscriminadamente. Recursos de FOG, AD,
  PXE ou outros exemplos sem relação com este fluxo ficam fora, com justificativa.
- [ ] Registrar ambiente, arquitetura, versão/digest homologado, origem oficial,
  comando de instalação, detecção, arquivos, usuário e privilégio necessário.
  Não inventar versões ausentes; resolver e homologar antes de fechar o lock.
- [ ] Inventariar também serviços: unidade/container, escopo sistema/usuário,
  usuário executor, portas/fluxos de rede, dependências, persistência e comandos
  de start, stop, enable, verificação e recuperação. Não imprimir configurações
  privadas nem habilitar serviços remotos implicitamente.
- [ ] Testar `DetectMissingDependency`, `RejectIncompatiblePoshSsh`,
  `DoctorNeverMutates`, `OptionalToolDoesNotBlockRuntime` e
  `InstallRequiresExplicitConsent`, com falha antes da implementação.
- [ ] Implementar preflight e instalação local opt-in, com escopo/versões
  explícitos. Instalação em Raspberry pertence ao bootstrap; mudanças no
  servidor DHCP continuam sob aprovação própria, não no instalador do host.
- [ ] Documentar licenças, acesso aos repositórios privados e dependências de
  Internet. Apontar limitações de disponibilidade APT/npm; registrar a baseline
  não significa que uma reconstrução futura seja idêntica byte a byte.
- [ ] Testar em perfil limpo de operador/VM e ambiente Linux apropriado, sem
  aproveitar silenciosamente ferramentas já presentes nesta máquina.

## Tarefa 1: descoberta e bloqueios de gravação

**Arquivos:** criar os dois arquivos PowerShell de flash e seus testes Pester.

**Interfaces:** `Get-FlashTargets` retorna objetos com `Number`, `UniqueId`,
`SerialNumber`, `Size`, `BusType`, `IsBoot` e `IsSystem`.
`Assert-FlashTarget($Target, $ExpectedIdentity)` retorna o destino validado
ou lança erro; não formata, monta nem grava o dispositivo.

- [ ] Escrever testes `RejectSystemDisk`, `RejectAmbiguousTarget`,
  `RejectChangedIdentity` e `DryRunNeverInvokesWriter`.
- [ ] Confirmar falhas com chamadas ao gravador interceptadas pelo Pester.
- [ ] Implementar descoberta com `Get-Disk` e validação por identidade composta.
  Não confiar somente em `BusType`, tamanho ou rótulo do volume.
- [ ] Implementar CLI com simulação padrão, `SupportsShouldProcess` e token
  explícito. Não oferecer opção para escrever no disco de sistema.
- [ ] Executar `Invoke-Pester -Path tests/flash -Output Detailed`.
  Esperado: testes verdes, nenhuma chamada real ao Imager.
- [ ] Preparar checkpoint revisável; criar commit somente se solicitado.

## Tarefa 2: imagem fixada e compatibilidade do Imager

**Arquivos:** modificar `FlashBerry.psm1`; criar `raspios-image.json`.

**Interfaces:** `Get-VerifiedImage($Manifest, $CacheDirectory)` retorna
`Path`, `Sha256`, `Version` e `Architecture` apenas após verificar o arquivo.
`Get-ImagerCapabilities($Executable)` retorna versão e opções suportadas.

- [ ] Testar `RejectChecksumMismatch`, `RejectUnsupportedImager`,
  `RejectWrongArchitecture` e `ReuseOnlyVerifiedCache` com arquivos fictícios.
- [ ] Rodar os testes e confirmar falha antes da implementação.
- [ ] Detectar o executável e consultar `--version` e a ajuda CLI sem gravação.
- [ ] Escolher uma imagem oficial desktop arm64 compatível com as placas
  reais da frota. Registrar versão e checksum verificados, sem usar `latest`.
- [ ] Implementar download temporário, hash e promoção ao cache só após sucesso.
  Arquivo parcial nunca pode ser usado como imagem válida.
- [ ] Manter cache e artefatos locais fora do Git; documentar espaço necessário.
- [ ] Rodar a suíte Pester; exigir retorno diferente de zero para incompatibilidade.

## Tarefa 3: personalização segura do primeiro boot

**Arquivos:** templates de flash, `FlashBerry.psm1`, `.example.env`,
`devices.example.json` e testes Windows/Linux.

**Interfaces:** `New-BerryPayload($Device, $Image, $PrivateConfig, $WorkDirectory)`
retorna caminhos de arquivos privados e um resumo público sem valores secretos.
`Remove-BerryPayload($WorkDirectory)` remove apenas os artefatos dessa execução.

- [ ] Testar `UniqueHostnameAndPublicKey`, `RejectPrivateKeyInput`,
  `NoInfrastructureSecretsInPayload` e `PreserveWifiSpecialCharacters`.
- [ ] Confirmar falhas com dados fictícios; testar o script gerado em Linux
  isolado, verificando resultado, não apenas procurando trechos no texto.
- [ ] Validar hostname, usuário, chave pública e SSID antes de gerar arquivos.
- [ ] Testar `SelectedHostnameSurvivesFirstBoot`, `SelectedKeyAllowsLogin`,
  `PrivateKeyNeverLeavesOperator` e `MissingNameOrKeyRequestsInput`.
  Demonstrar que não é preciso configurar nome e chave novamente na GUI.
- [ ] Testar `TwoPeopleUseDistinctKeys`, `UnknownKeyIsRejected`,
  `PrivateKeyDisguisedAsPubIsRejected` e `EmptyAuthorizedKeySetIsRejected`.
- [ ] Implementar a gestão em `scripts/access/AuthorizedKeys.psm1`, com testes
  em `tests/access/AuthorizedKeys.Tests.ps1`; testar adição sem sobrescrever
  outras públicas e revogação sem remover o último acesso confirmado.
- [ ] Testar `RejectGenericHostname`, `RejectDuplicateHostname`,
  `RejectHostnameLongerThan63`, `SuggestNextTvSequence`,
  `RejectLocationInHostname`, `SequenceAbove99IsNotTruncated` e
  `ExistingDhcpNameIsNotAutomaticallyRenamed`.
- [ ] Fazer prova de compatibilidade da imagem selecionada: usar
  `--first-run-script` ou cloud-init apenas se suportado pelo conjunto testado.
  Não presumir que flags existentes no código upstream funcionam na versão local.
- [ ] Gerar configuração mínima de usuário, SSH por chave e NetworkManager.
  Não reutilizar receitas antigas de `wpa_supplicant.conf` sem validação.
- [ ] Gerar host keys SSH novas no destino. Não embutir identidade de display.
- [ ] Preparar arquivos privados em diretório temporário NTFS com acesso restrito.
  Evitar segredos em argumentos, transcrições PowerShell e logs de debug.
- [ ] Remover payloads do host em `finally`; no Pi, apagar o bootstrap sensível
  após configuração confirmada. Não prometer apagamento forense de memória flash.
- [ ] Documentar que a partição FAT de boot não oferece proteção por ACL NTFS;
  o cartão personalizado exige proteção física, sobretudo antes do primeiro boot.

## Tarefa 4: gravação controlada e relatório

**Arquivos:** entrada CLI, módulo, testes Pester e `docs/FLASH-CLI.md`.

**Interfaces:** `Invoke-BerryFlash($Image, $Payload, $ExpectedTarget)` chama
o Imager somente após nova validação do destino e devolve `ExitCode`,
`WriteVerified` e `RunId`; nunca declara o player pronto.

- [ ] Testar `MissingConfirmationNeverWrites`, `SwappedCardNeverWrites`,
  `FailedVerificationReturnsFailure` e `CleanupRunsAfterWriterFailure`.
- [ ] Ver os testes falharem antes de conectar o gravador ao fluxo.
- [ ] Exibir identidade, capacidade e aviso de perda total do conteúdo.
- [ ] Reconsultar o destino imediatamente antes da chamada ao Imager e
  abortar se houver qualquer divergência de identidade ou capacidade.
- [ ] Chamar o Imager elevado quando necessário, sem habilitar escrita em discos
  de sistema, sem desativar verificação e sem shell que interprete argumentos.
- [ ] Tratar exit code, verificação, ejeção e falhas de mídia separadamente.
- [ ] Gerar relatório sem segredos; indicar que a fase de boot ainda está pendente.
- [ ] Homologar em cartão descartável, com autorização explícita para aquele
  destino. Nenhum teste automatizado deve escolher um disco físico sozinho.

## Tarefa 5: primeiro acesso, identidade e descoberta de rede

**Arquivos:** `NetworkBerry.psm1`, `BerryWorkflow.psm1` e testes de rede.
Reescrever também os dois scripts existentes em `scripts/dhcp/`, mantendo
suas consultas somente leitura e os parâmetros públicos ainda documentados.
Eles serão consumidores dos mesmos módulos, não implementações divergentes.

**Interfaces:** `Get-BerryIdentity($Connection)` retorna serial, hostname,
interfaces, MACs, endereços, fingerprint SSH e UUID do perfil Wi-Fi.
`Get-BerryConnection($Device, $Evidence)` seleciona acesso direto ou salto,
sem desabilitar verificação de identidade SSH.

- [ ] Testar `DistinguishTwoLeases`, `RejectWrongBoard`, `RejectMacMismatch`,
  `RejectUnverifiedHostKey` e `ResumeWithoutReflashing` antes da implementação.
- [ ] Revisar parsers e comandos atuais: retirar leitura duplicada do `.env`,
  defaults de hostname antigos e buscas amplas que misturam equipamentos.
  Filtrar por hostname validado e MAC exato, com escaping antes de enviar shell.
- [ ] Retornar objetos/JSON estruturados para a CLI, com resumo humano separado:
  identidade, interface, IP, origem da evidência, horário e erro categorizado.
  Não usar apenas `Write-Host`, texto livre ou ausência de erro como diagnóstico.
- [ ] Distinguir lease ativo, expirado e histórico de reserva configurada.
  Tratar logs rotacionados, entradas incompletas, timeout e permissões ausentes;
  não transformar falta de leitura em ausência do dispositivo.
- [ ] Usar hostname, usuário, fingerprint público e `RunId` gerados no flash
  como ponto de partida, em vez de pedir repetidamente dados já confirmados.
  Dados previstos não substituem a leitura do MAC e da identidade na placa.
- [ ] Executar uma sequência curta e determinística: acesso inicial, identidade,
  associação, lease/IP, rota, DNS, HTTPS, CMS e SSH pelo caminho permitido.
  Retornar a camada da primeira falha, evidências e próxima ação segura.
  Retries limitados só para falhas transitórias, nunca reiniciar serviços
  indiscriminadamente como tentativa de diagnóstico.
- [ ] Manter o modo normal com um comando por etapa e informações suficientes
  para decidir; detalhes extras ficam em diagnóstico opt-in sem segredos.
  O flash programático elimina passos manuais repetidos, não as confirmações.
- [ ] Adicionar testes `ExactMacFilter`, `ExpiredLeaseIsNotCurrentIp`,
  `UnreadableLogsAreUnknown`, `MalformedOutputIsNotSuccess`,
  `CredentialsAreRedacted` e `LegacyWrappersUseSharedModules`.
- [ ] Descobrir candidatos por logs/leases somente leitura; o hostname sozinho
  não identifica placa nem interface. Correlacionar com serial e MACs do Pi.
- [ ] Usar Ethernet para o primeiro acesso e mantê-la durante mudanças Wi-Fi.
  Sem acesso confirmado, pausar e pedir ligação do cabo ou console local.
- [ ] Confirmar host key por canal confiável no primeiro acesso. Não aceitar
  chave alterada automaticamente nem apagar `known_hosts` para contornar erro.
- [ ] Coletar identidade com comandos Linux na placa; não executar comandos
  de rede do Berry no servidor DHCP ou cmdlets PowerShell no Linux.
- [ ] Ler IP, gateway, DNS, rotas e perfis NetworkManager sem imprimir a senha.
  Usar UUID exato; não apagar nem recriar um perfil Wi-Fi que já funciona.
- [ ] Confirmar que o perfil usa MAC estável compatível com a reserva. Detectar
  MAC aleatório e pedir decisão antes de mudar o perfil; não gerar reserva
  permanente a partir de uma identidade temporária.
- [ ] Registrar testes verdes em mocks/fixtures e repetir em placa reserva.

## Tarefa 6: preparação e validação da reserva DHCP

**Arquivos:** `DhcpEnrollment.psm1`, testes DHCP e `docs/REDE-CLI.md`.

**Interfaces:** `New-DhcpEnrollmentPlan($Identity, $InfrastructureContext)`
retorna hostname, MAC Wi-Fi, IP proposto, subnet, hash da configuração-base,
hash do candidato, caminhos privados dos artefatos em `ti` e validações.
Não aplica a configuração nem reinicia serviços.

- [ ] Escrever testes `RequireCurrentServerConfig`, `RejectDuplicateMacOrIp`,
  `RejectDynamicPoolAddress`, `PreserveOtherReservations`,
  `ExistingCorrectReservationIsNoOp` e `NoRestartDuringPreparation`.
- [ ] Confirmar falhas com fixtures que incluem as duas reservas já existentes.
- [ ] Validar acesso e ferramentas do repositório `ti`. Resolver as diferenças
  entre nomes locais ALL CAPS e o formato legado por adaptador em memória,
  sem mudar arquivos de credenciais. Nunca usar conta root diretamente.
- [ ] Obter a configuração atual do servidor antes de inspecionar ou editar;
  guardar backup datado da cópia local antes de substituí-la em `ti`.
- [ ] Separar presença no `dhcpd.conf` atual de lease ativo ou histórico.
- [ ] Determinar a subnet real e propor o próximo endereço após o maior fixo
  da mesma subnet, fora do pool dinâmico e sem conflito nas fontes disponíveis.
  Se a faixa estiver esgotada ou houver dúvida, parar; ping silencioso não
  comprova que um IP está livre. Não reutilizar IP/MAC dos Berries existentes.
- [ ] Criar somente a reserva do novo MAC Wi-Fi, com `fixed-address`, dentro
  dos marcadores das TVs e com divisor individual no padrão de `docs/DHCP.md`.
- [ ] Se já existir reserva correta, não duplicar nem reiniciar o DHCP.
  Se houver reserva divergente, apresentar a diferença e pedir direção.
- [ ] Formatar com as ferramentas de `iscdhcp`, validar localmente pelo fluxo
  documentado e revisar o diff completo, bloqueando mudanças fora do escopo.
- [ ] Enviar candidato com `Set-SCPItem -Destination /tmp -NewName dhcpd.conf`;
  não usar `-PathType`. Em sessão sudo interativa, preparar o arquivo de teste
  e executar `dhcpd -t -cf /etc/dhcp/dhcpd.conf.test`.
- [ ] Usar `New-SSHShellStream` e `Invoke-SSHStreamExpectSecureAction` com
  credencial segura; não inserir senha em comando, transcript ou relatório.
- [ ] Após validação positiva, mostrar diff por canal restrito e parar em
  `AwaitingDhcpApproval`. Configuração completa e backups permanecem em `ti`.

## Tarefa 7: aplicação DHCP com aprovação independente

**Arquivos:** adaptador DHCP, coordenador e testes de aprovação/concorrência.

**Interfaces:** `Apply-DhcpEnrollment($Plan, $Approval)` recebe uma aprovação
humana ligada aos hashes e ao alvo revisados, não apenas um booleano salvo.
Retorna o backup remoto criado, resultado da validação e estado do serviço.

- [ ] Testar `NoApprovalNeverApplies`, `EraseApprovalDoesNotApproveDhcp`,
  `RejectChangedServerConfig`, `RejectChangedCandidate` e
  `ServiceFailureDoesNotMarkApplied` antes da implementação.
- [ ] Exigir comando separado e confirmação explícita após o usuário revisar
  o diff e a validação. Não oferecer `-Force` ou `-Yes` para pular essa pausa.
- [ ] Reconsultar hash do servidor e do candidato; se divergirem dos revisados,
  invalidar aprovação, recalcular e exigir nova validação e confirmação.
- [ ] Antes de substituir a configuração ativa, criar backup remoto datado.
  Revalidar o candidato e impedir aplicação se houver erro ou concorrência
  conhecida; a comparação de hash não equivale a bloqueio de outros operadores.
- [ ] Aplicar somente o candidato aprovado, fazer `dhcpd -t` final e só então
  reiniciar `isc-dhcp-server`; verificar estado e logs antes de prosseguir.
- [ ] Em falha, não repetir reinícios indiscriminadamente. Apresentar o backup
  exato e procedimento validado de recuperação ao operador, sem sobrescrever
  alterações posteriores de terceiros ou fazer rollback cego.
- [ ] Registrar evidências mínimas sem credenciais nem cópia da configuração.

## Tarefa 8: renovação Wi-Fi, liberações e validação ponta a ponta

**Arquivos:** módulo de rede, coordenador, testes e `docs/REDE-CLI.md`.

**Interfaces:** `Test-BerryNetwork($Connection, $ExpectedReservation)` retorna
resultados independentes para associação, IP/MAC, rota, DNS, Internet,
CMS, SSH direto e SSH via salto. `NetworkVerified` exige a política abaixo.

- [ ] Testar `KeepEthernetDuringRenewal`, `RenewOnlySelectedWifiUuid`,
  `ReservationAloneIsNotConnectivity`, `CaptivePortalIsNotInternet`,
  `BlockedDirectSshUsesVerifiedJump` e `AdditionalApprovalStopsWorkflow`.
- [ ] Após aplicação, manter SSH Ethernet e renovar apenas o UUID Wi-Fi
  identificado, com sudo interativo. Não renovar todas as conexões ou remover
  perfil ativo. Confirmar no Pi o IP reservado e o MAC usados efetivamente.
- [ ] Checar `ip route get 1.1.1.1` com saída pela interface Wi-Fi esperada,
  além da resolução DNS e de uma requisição HTTPS com certificado validado.
  Recusar portal cativo, redirecionamento inesperado e resposta meramente local.
- [ ] Testar o CMS pela URL configurada, distinguindo alcance HTTP de registro
  e autorização do display. Testar downloads APT/npm sem alterar suas fontes.
- [ ] Testar TCP/22 e autenticação SSH pelo caminho real do operador: direto
  quando disponível e, se bloqueado entre VLANs, `ProxyJump` verificado.
  Não exigir SSH direto quando a política local permite somente o salto.
- [ ] Obter ou confirmar o procedimento institucional de cadastro/liberação
  adicional em wiki e documentação de `ti`, por acesso autorizado. Não inventar
  regras de switch, VLAN, ACL, portal, firewall ou allowlist por MAC.
- [ ] Se houver uma liberação adicional obrigatória, coletar diagnóstico e
  apontar sistema/responsável/ação pendente. Qualquer mudança nesses sistemas
  depende de escopo e autorização específicos; não contornar controles.
- [ ] Separar estado de rede de Pi Connect: verificar suas dependências quando
  solicitado, mas vínculo à conta continua exigindo confirmação no navegador.
- [ ] Homologar sem dependência do cabo, com operador presente e recuperação
  Ethernet disponível. Demonstrar que a retirada do cabo não derruba acesso
  pelo caminho Wi-Fi suportado nem acesso ao CMS e à Internet.
- [ ] Só após essas verificações permitir o deploy completo. Uma falha deve
  informar a camada afetada, sem sugerir que cadastrar DHCP resolverá tudo.

## Tarefa 9: provisionamento do player e retomada

**Arquivos:** `provision-player.sh`, unidade one-shot e testes Linux.
Reutilizar launcher, unidade de usuário, helper e manifestos do player existente.

**Interfaces:** `provision-player.sh --source DIRETORIO --user USUARIO`
consome um pacote de código verificado, registra versão/estado e retorna zero
somente após as verificações não visuais. Não recebe senhas na linha de comando.
Esta etapa depende de `NetworkVerified`. O primeiro boot pode preparar o
acesso e aguardar rede, sem iniciar um ciclo infinito de instalação incompleta.

- [ ] Testar `RetryAfterNetworkFailure`, `SecondRunPreservesPlayerIdentity`,
  `ExistingConfigIsNotOverwritten` e `GraphicalSessionMustBeAvailable`.
- [ ] Confirmar falhas em Linux isolado antes de implementar.
- [ ] Preparar pacote do código integrado com versão e hash; não usar apenas a
  tag upstream, que não contém nossas correções. Transporte não pode depender
  de acesso público ao repo ou de credenciais Git copiadas ao cartão.
- [ ] Instalar dependências e executar `npm ci` com o lockfile existente.
  Registrar versões observadas; não executar upgrade geral do OS.
- [ ] Executar tarefas privilegiadas no contexto autorizado do primeiro boot.
  Não criar `sudo` global sem senha para viabilizar a automação.
- [ ] Criar a configuração privada do player com permissões restritas e
  recusar sobrescrever identidades existentes sem autorização específica.
- [ ] Instalar a unidade de usuário sem fixar `DISPLAY=:0` ou nomes de Wayland.
  Só habilitar autologin mediante opção explícita; sem sessão gráfica, reportar
  pendência em vez de dizer que o quiosque está funcionando.
- [ ] Prever timeout e retomada após falha de DNS, APT, npm ou CMS. Não reinstalar
  o OS nem reiniciar indefinidamente como tentativa de recuperação.
- [ ] Manter autorização do display e vínculo Pi Connect separados; não copiar
  sessões nem ativar autoautorização OAuth implicitamente.

## Tarefa 10: homologação, documentação e liberação do lote

**Arquivos:** `docs/FLASH-CLI.md`, `README.md`, guias de provisionamento e testes.

- [ ] Documentar requisitos do host, simulação, confirmação e limpeza privada.
- [ ] Testar primeiro boot com Wi-Fi, SSH por chave e hostname exclusivos.
- [ ] Homologar reserva Wi-Fi por MAC real, aprovação DHCP e retomada sem
  regravar cartão ou repetir a alteração de infraestrutura.
- [ ] Distinguir no relatório: disco gravado, rede validada, display autorizado
  e reprodução visual aprovada; nenhum desses estados implica os demais.
- [ ] Confirmar que a URL do CMS é alcançável pelo Pi e não aponta ao seu loopback.
- [ ] Autorizar um display de teste sem alterar a chave global do CMS.
- [ ] Verificar vídeo HDMI, layout, atualização e comportamento sem rede.
- [ ] Testar start, stop, restart e reboot sem Chromium órfão ou outro player ativo.
- [ ] Repetir em segundo cartão para verificar independência de identidade.
- [ ] Registrar imagem, hashes, versão do player, modelo da placa e resultados,
  sem credenciais; separar claramente testes simulados de testes físicos.
- [ ] Rodar Pester, testes Linux, os testes Node já existentes e Markdownlint.
  Bats e builds DEB/RPM têm limitações locais já documentadas: preparar ambiente
  Linux apropriado, sem declarar essas verificações concluídas por inferência.
- [ ] Revisar diff e artefatos antes de liberar a execução em mais dispositivos.

## Tarefa 11: reescrita final e numeração dos guias operacionais

**Dependência:** concluir e homologar as etapas anteriores. Os guias finais
devem descrever comandos efetivamente implementados e testados, não a interface
proposta neste plano. Esta tarefa é obrigatória para concluir a implementação.

**Arquivos:** reescrever os guias operacionais em `docs/`, atualizar `README.md`
como índice e corrigir todas as referências afetadas por renomeação.
Manter inventário e histórico separados das instruções de instalação.

### Organização final prevista

Cada arquivo numerado representa uma etapa, com título e nome coerentes:

1. `docs/01-pre-requisitos.md`: hardware, host Windows, acessos e ferramentas.
2. `docs/02-configuracao-privada.md`: `.env`, chave pública e dados por placa.
3. `docs/03-cms-docker.md`: instalação inicial e validação do CMS existente.
4. `docs/04-flash-cartao.md`: seleção segura, simulação e gravação verificada.
5. `docs/05-primeiro-acesso.md`: primeiro boot, Ethernet e identidade da placa.
6. `docs/06-cadastro-rede-dhcp.md`: MAC Wi-Fi, reserva, validação e aprovação.
7. `docs/07-validacao-conectividade.md`: Wi-Fi, Internet, CMS e acesso SSH.
8. `docs/08-player-xibo.md`: deploy, registro, autorização e layout do display.
9. `docs/09-pi-connect.md`: ativação opcional e vínculo individual à conta.
10. `docs/10-homologacao.md`: HDMI, atualização, offline, reboot e aceite.
11. `docs/11-operacao-recuperacao.md`: manutenção, diagnóstico e recuperação.
12. `docs/12-adicionar-berries.md`: roteiro incremental usando as etapas comuns.

Os nomes são destinos planejados; não criar links para eles enquanto não
existirem. Preservar `docs/BERRIES.md` como inventário, fora da sequência.
Arquivar o relato do piloto em `docs/historico/`, com aviso de que não é o
procedimento atual. Preservar atribuições, fontes e evidências necessárias.

### Dois caminhos explícitos no README

- **Implantar do zero:** seguir as etapas 01 a 10 em ordem, sendo Pi Connect
  opcional; usar a etapa 11 para operação posterior. Configurar o CMS uma vez.
- **Adicionar mais Berries:** começar pela etapa 12, que valida o ambiente
  existente e aponta às etapas comuns necessárias para cada nova placa.
  Reutilizar CMS e chave global, criar identidade exclusiva e reserva própria,
  autorizar somente o novo display e homologar sem afetar os anteriores.
  Não reinstalar banco, redefinir senhas ou refazer configurações globais.

### Conteúdo e verificação obrigatórios

- [ ] Inventariar os guias atuais e mapear cada seção ao seu destino numerado,
  evitando perder instruções de segurança durante a consolidação.
- [ ] Reescrever as instruções conforme o comportamento final da CLI e suas
  versões homologadas. Remover tentativas obsoletas do caminho principal.
- [ ] Incorporar o manifesto de dependências, matriz de serviços e resultado do
  preflight na etapa 01. Um operador deve saber exatamente o que instalar no
  PC, no Pi e o que já precisa existir na infraestrutura.
- [ ] Explicar na etapa de flash como selecionar hostname, usuário e chave
  pública pela CLI, sem exigir as mesmas escolhas na GUI do Pi Imager.
- [ ] Documentar o padrão de hostname com exemplos fictícios e explicar como
  cadastrar várias públicas, revogar acesso e preparar ZIP sem dados privados.
- [ ] Testar o pacote de distribuição por allowlist, incluindo os casos
  `ZipExcludesEnvAndPrivateKeys` e `ZipIncludesApprovedPublicKeys`; inspecionar
  os membros do ZIP antes de permitir sua distribuição.
- [ ] Em cada etapa, informar objetivo, pré-requisitos, ambiente de execução,
  entradas, comandos, saída esperada, confirmação humana, recuperação e
  critério para avançar. Incluir links para a etapa anterior e a próxima.
- [ ] Diferenciar claramente PowerShell no PC, comandos no servidor DHCP e
  comandos no Berry, incluindo qual conta executa cada ação.
- [ ] Usar variáveis ALL CAPS e marcadores nos exemplos, nunca valores privados.
  Remeter ao único `.example.env` em vez de manter modelos duplicados.
- [ ] Manter uma única explicação detalhada por operação. A etapa 12 aponta
  para ela, sem duplicar procedimentos que possam divergir futuramente.
- [ ] Atualizar README, links internos, scripts e arquivos de contexto que
  referenciem nomes antigos; usar a skill de contexto se for necessário
  reestruturar `AGENTS.md`. Não alterar a skill DHCP externa implicitamente.
- [ ] Aplicar Markdownlint a todos os Markdown reescritos e verificar links,
  numeração, comandos e ausência de segredos ou referências quebradas.
- [ ] Percorrer o caminho do zero em ambiente de homologação e o caminho
  incremental em uma segunda placa, sem mudanças indevidas no CMS ou na frota.
  Registrar o que foi executado e o que ainda depende de autorização externa.
- [ ] Só marcar documentação concluída quando um operador conseguir seguir
  ambos os caminhos sem precisar consultar o histórico da conversa.
- [ ] Fazer uma passagem por outro operador ou agente de IA em ambiente limpo,
  usando somente o repositório, os guias e acessos fornecidos por canal seguro.
  Registrar lacunas; não pressupor skills pessoais, caminhos deste Windows,
  senhas conhecidas pelo agente anterior ou ferramentas instaladas à mão.

## Documentação retroativa e fontes de verdade

O fluxo planejado passa a incluir rede e DHCP na mesma CLI, sem eliminar a
aprovação humana. Atualizar referências anteriores que diziam que o cadastro
ficaria fora da automação. A CLI ainda não está implementada.

Preservar os registros históricos como históricos, sem promovê-los a estado
atual. No guia de Connect, há uma inconsistência entre o MAC Ethernet citado
e o MAC atribuído à reserva Wi-Fi do Berry 01; não usá-la para provisionar.
A placa e a configuração atual do servidor devem confirmar a associação.

Após cada operação comprovada, propor atualização de `docs/BERRIES.md` com
serial, hostname, MAC Wi-Fi, IP reservado, IP Ethernet temporário, caminho SSH,
data e resultado. Atualizar somente o dispositivo tratado; não registrar
senhas, chaves ou alegações de teste que não foi executado.

Na implementação, alinhar `README.md`, `docs/DHCP.md`,
`docs/BERRY-SSH-OPERACAO.md`, `docs/raspberry-pi-connect-passo-a-passo.md`,
`docs/CONFIGURACAO.md` e `docs/XIBO-CHROMIUM-BERRY-01.md`. Explicitar a ordem
flash, acesso inicial, identidade, reserva, aprovação, conectividade e player.

## Recuperação e limites

- Flash apaga o cartão; não existe rollback dos dados antigos sem backup prévio.
- Se imagem ou bootstrap falhar, coletar diagnóstico sem segredos e corrigir
  primeiro em homologação; regravar somente com nova confirmação de destino.
- Falha de provisionamento deve permitir retomada, preservando a identidade.
- Falha de DHCP não autoriza apagar leases, reservas alheias ou mudar ACLs.
- Sem autorização para aplicar DHCP, manter a reserva preparada e a execução
  pausada, com o cabo como rota de recuperação; não marcar rede como aprovada.
- Não desativar Anthias ou outro player encontrado sem autorização específica.
- Não expandir o plano para boot de rede, gravação paralela ou imagem própria
  antes de um piloto completo com imagem oficial e um cartão por vez.

## Referências

- [Guia de flash e Connect](docs/raspberry-pi-connect-passo-a-passo.md).
- [Deploy atual do player](docs/XIBO-CHROMIUM-BERRY-01.md).
- [Configuração privada](docs/CONFIGURACAO.md).
- [Operação DHCP](docs/DHCP.md).
- [Manual oficial do Imager](https://github.com/raspberrypi/rpi-imager/blob/main/doc/man/rpi-imager.1).
- [Opções CLI upstream](https://github.com/raspberrypi/rpi-imager/blob/main/src/cli.cpp).

As referências upstream explicam capacidades possíveis, não comprovam a versão
instalada. A tarefa 2 deve registrar as versões realmente testadas antes do flash.
