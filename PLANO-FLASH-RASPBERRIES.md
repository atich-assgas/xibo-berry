# Automação de flash e provisionamento dos Berries — Implementation Plan

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
- Personalizar hostname, usuário e chave pública SSH por dispositivo.
- Usar o `.env` existente como única fonte privada de variáveis do operador.
- Para operações de infraestrutura, usar as credenciais autorizadas de `ti`,
  sem copiar, renomear ou sobrescrever seu `.env` independente.
- Integrar descoberta, reserva Wi-Fi e validação de rede na mesma CLI.
- Primeiro acessar pelo cabo; usar o MAC real da interface Wi-Fi na reserva.
- Instalar o player a partir de uma versão identificada do código deste repo.
- Tratar Pi Connect e autorização do display como etapas verificáveis separadas.
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
- `tests/flash/FlashBerry.Tests.ps1`: testes Windows sem gravação física.
- `tests/network/NetworkBerry.Tests.ps1`: conexões e diagnósticos simulados.
- `tests/dhcp/DhcpEnrollment.Tests.ps1`: fixtures DHCP, sem servidor real.
- `tests/provision/`: testes Linux isolados, com dados fictícios.
- `docs/FLASH-CLI.md`: uso, recuperação e checklist do operador.
- `docs/REDE-CLI.md`: cadastro na rede, aprovação DHCP e diagnóstico.
- `.example.env`, `.gitignore`, `README.md`: descoberta e proteção dos artefatos.

Não mover o código de `xiboplayer-chromium/` nem reabrir a organização do repo.

## Contratos de entrada e saída

O cadastro local de dispositivos será JSON, com `Hostname`, `Username`,
`DisplayName` e `PublicKeyPath`. Não conterá senhas, IP reservado inventado ou
identidade de outro player. O arquivo público de exemplo terá marcadores.
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

A mesma entrada recebe `-Stage`: `Flash`, `DiscoverNetwork`, `PrepareDhcp`,
`ApplyDhcp`, `VerifyNetwork`, `DeployPlayer` ou `All`.
Recebe também `-RunId` para retomada e `-InfrastructureRepo` para localizar
o repositório `ti`; não duplicar as ferramentas de infraestrutura em `berry`.
Sem `-Execute`, apenas simular. `-ConfirmErase` é exclusivo do flash e não
vale como aprovação DHCP. `All` deve parar em `AwaitingDhcpApproval` e exigir
uma chamada separada de `ApplyDhcp` com confirmação humana após validação.

Estados propostos: `Planned`, `FlashVerified`, `AwaitingFirstBoot`,
`IdentityVerified`, `DhcpPrepared`, `AwaitingDhcpApproval`, `DhcpApplied`,
`NetworkVerified`, `PlayerConfigured` e `Accepted`.
Falhas ou liberações adicionais ficam em `NeedsOperator`; nunca promover uma
etapa somente porque a anterior retornou zero. O estado persistido não contém
credenciais, diff completo do servidor ou arquivo DHCP de produção.

Saída pública: identificador da execução, etapa, imagem/hash, identidade do
destino e resultado. Nunca incluir payload privado ou valores de credenciais.

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

**Interfaces:** `Get-BerryIdentity($Connection)` retorna serial, hostname,
interfaces, MACs, endereços, fingerprint SSH e UUID do perfil Wi-Fi.
`Get-BerryConnection($Device, $Evidence)` seleciona acesso direto ou salto,
sem desabilitar verificação de identidade SSH.

- [ ] Testar `DistinguishTwoLeases`, `RejectWrongBoard`, `RejectMacMismatch`,
  `RejectUnverifiedHostKey` e `ResumeWithoutReflashing` antes da implementação.
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
