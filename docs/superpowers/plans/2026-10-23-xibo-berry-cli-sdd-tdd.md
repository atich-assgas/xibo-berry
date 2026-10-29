# CLI Xibo Berry — Implementation Plan SDD/TDD

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development para execução e revisão por tarefa;
> superpowers:test-driven-development para todo comportamento implementado.
> Os passos usam caixas de seleção para acompanhamento.

**Goal:** implementar a CLI de flash, entrada na rede e deploy de TVs conforme
a spec, incluindo distribuição segura e documentação reproduzível.

**Architecture:** CLI PowerShell com módulos pequenos, transporte remoto
isolado e estado por dispositivo. Imager grava imagem oficial homologada;
bootstrap Linux prepara acesso e player. DHCP tem preparação e aplicação
separadas, usando a infraestrutura existente de `ti`.

**Tech Stack:** PowerShell 7, Pester 5, Bash/Bats, OpenSSH, Posh-SSH,
Imager CLI, NetworkManager, ISC DHCP, Node/npm e systemd de usuário.

**Spec:** [design vinculante](../specs/2026-10-23-xibo-berry-cli-design.md).

Status: plano derivado em rascunho. Revisar e aprovar a spec antes de iniciar;
a aprovação do documento não aprova flash, DHCP, commits, push ou merge.
O [plano de origem](../../../PLANO-FLASH-RASPBERRIES.md) preserva o contexto;
em conflito, resolver contra a spec aprovada e registrar a decisão.

## Global Constraints

- Hostname `berry-tv-campus-NN`, sequência positiva com pelo menos dois dígitos.
- Privadas individuais nunca vão ao repo, `.env`, payload, ZIP ou Raspberry.
- Simulação padrão; gravar exige `-Execute` e confirmação da mídia revalidada.
- Não gravar disco de sistema/boot; verificar a escrita e o SHA256 da imagem.
- `All` para em `AwaitingDhcpApproval` se houver mudança DHCP a aplicar;
  reserva correta ou aplicação já confirmada permitem retomar sem reaplicar.
- Aplicar DHCP exige comando separado e aprovação dos hashes/target revisados.
- Nenhuma mudança automática em ACL, VLAN, switch, portal ou firewall.
- Configuração DHCP e backups completos ficam em `ti`, fora deste repo.
- Proxy/PWA `0.7.15`, lockfile e `npm ci`; preservar CMS e identidades existentes.
- `Accepted` exige homologação física, não somente testes simulados verdes.
- Rede e comandos remotos: timeout 15 segundos, máximo duas tentativas.
- Instalações demoradas têm limites próprios; não repetir mutações cegamente.
- Nenhum teste normal escreve em discos ou altera servidor real.
- Nenhuma versão/checksum ausente é inventada para preencher um manifesto.

## Review Focus

1. Troca de mídia mantendo o mesmo leitor: tarefa 4 invalida a continuidade.
2. Pública inválida ou vazamento de segredo: tarefas 1, 5 e 11 devem rejeitar.
3. Lease expirado/ilegível confundido com presença: tarefa 6 retorna evidência.
4. DHCP concorrente ou confirmação reaproveitada: tarefa 8 aborta a aplicação.
5. Falta de sessão, Internet ou hardware: tarefas 9, 10 e 12 mantêm pendências.

## Execução SDD e evidências TDD

- Antes de implementar, obter aprovação da spec e deste plano; verificar um
  worktree isolado, sem implementar diretamente na `main`.
- A execução é SDD: coordenador entrega uma tarefa a um implementador novo,
  que não delega subagentes. Não executar implementadores em paralelo.
- Após cada entrega, outro agente revisa conformidade com spec e qualidade.
  Ao fim, revisão integrada independente; autorrevisão não substitui revisão.
- Criar ledger privado em `.superpowers/sdd/`, com identidade do plano, estado,
  decisões, bases e commits/patches, tarefas, relatórios e resultados de revisão.
  Ler o ledger ao retomar; não repetir tarefa só porque o contexto compactou.
- O brief de cada agente contém a tarefa e os contratos que ela consome,
  constraints vinculantes e caminhos de spec/relatório. Não copiar a conversa.
- Para cada teste: mostrar RED pelo comportamento ausente, não por erro de
  fixture; implementar o mínimo, mostrar GREEN, refatorar e repetir a suíte.
- Mockar apenas fronteiras: disco, rede, SSH, processos e relógio. Testar
  parsers/geradores reais contra fixtures, nunca apenas grep no código-fonte.
- Registrar comando, ambiente, exit code, resumo e testes não executados.
  Dados de teste são fictícios; processos e arquivos temporários ficam isolados.
- Revisões e correções seguem a skill SDD, com o diff da tarefa inteira,
  não apenas o último commit. Findings fora de escopo ficam no ledger.
- Checkpoint por tarefa: um commit local só se previamente autorizado;
  sem essa autorização, manter patch identificável e obter permissão antes de
  entrar num fluxo SDD que dependa de commits. Push/merge não são implícitos.
- Operações físicas, aplicação DHCP e outras ações sensíveis continuam exigindo
  confirmação mesmo durante uma execução SDD autorizada.

## Mapa de entregas e dependências

1. Configuração, nomenclatura e públicas: base para todo o restante.
2. Dependências e doctor: consome 1; bloqueia operação incompatível.
3. Imagem e adapter Imager: consome 2; valida baseline.
4. Segurança de disco e estado: consome 1 a 3; ainda sem flash físico.
5. Payload/primeiro boot e writer: consome 3 e 4; teste físico autorizado.
6. Transporte, evidências e wrappers: consome 1 e estado de 4.
7. Preparação DHCP: consome identidade de 6; sem aplicação.
8. Aplicação DHCP aprovada: consome 7.
9. Aceite de rede: consome 6 e resultado/no-op de 7/8.
10. Provisionamento do player: consome 9.
11. Distribuição segura: consome entregas de código e configuração pública.
12. Guias, homologação e aceite: depende de todas as anteriores.

## Task 1: configuração, hostname e múltiplas públicas

**Files:** criar `scripts/common/Configuration.psm1`,
`scripts/access/AuthorizedKeys.psm1`, `scripts/flash/devices.example.json`,
`tests/common/Configuration.Tests.ps1` e
`tests/access/AuthorizedKeys.Tests.ps1`; manter `.example.env` único.

**Interfaces:**

- `Read-BerryConfig([string]$EnvFile) -> hashtable` privada e efêmera.
- `Get-NextBerryHostname([string[]]$ExistingNames) -> string`.
- `Read-AuthorizedPublicKeys([string[]]$Paths) -> object[]`, cada item com
  `Type`, `PublicMaterial`, `Fingerprint`, `Comment`.
- `Get-AuthorizedKeyChange($Existing, $Requested, $Action) -> object` com
  conjuntos de inclusão/remoção e bloqueio de perda do último acesso.

- [ ] **RED:** criar a seguinte expectativa e casos de chaves inválidas,
  duplicadas por conteúdo, privada disfarçada de `.pub` e lista vazia.

```powershell
It 'continua a sequencia DHCP existente' {
    Get-NextBerryHostname -ExistingNames @(
        'berry-tv-campus-01', 'berry-tv-campus-02'
    ) | Should -BeExactly 'berry-tv-campus-03'
}
```

- [ ] Executar Pester nos dois diretórios novos; comprovar falha esperada.
- [ ] Implementar contratos reais: sequência acima de 99, prefixo exato,
  limite 63, sanitização de erros e deduplicação pelo material criptográfico.
  Não serializar o hashtable privado nem sobrescrever públicas desconhecidas.
- [ ] **GREEN:** testar `99 -> 100`, nomes genéricos, colisão, erro `.env`
  sem valor bruto e revogação que preserve outra identidade funcional.
- [ ] Revisar contrato e qualidade; registrar checkpoint TDD no ledger.

## Task 2: dependências, serviços e preflight reproduzível

**Files:** criar `scripts/setup/Dependencies.psm1`,
`scripts/setup/doctor-berry.ps1`, `scripts/setup/dependencies.lock.json`,
`scripts/setup/install-prerequisites.ps1` e
`tests/setup/Dependencies.Tests.ps1`; atualizar `.example.env` só com novos
nomes necessários: SSID, país e fuso, sempre com valores vazios.

**Interfaces:** `Test-BerryDependencies([string]$Profile, $Manifest, $Probe)`
retorna itens conforme campos do doctor na spec. Profiles: `Operator`,
`Berry`, `Infrastructure`, `Tests`. `$Probe` é fronteira injetável de detecção.
`Install-BerryPrerequisites($Manifest, [string]$Profile, [bool]$Execute)`
instala somente no host operador, depois de autorização explícita.

- [ ] **RED:** testar ausência de Imager, Posh-SSH incompatível,
  ferramenta opcional ausente e proibição de mutação pelo doctor.
- [ ] Rodar `Invoke-Pester -Path tests/setup -CI -Output Detailed`; registrar RED.
- [ ] Implementar inventário com origem, pacote, ambiente, versão, privilégio,
  detecção e remediação; incluir todos os serviços e dependências da spec §10.
  Manifesto não homologado retorna pendência, não um lock fictício.
- [ ] **GREEN:** doctor em fixtures funciona sem rede; instalador não toca
  servidor DHCP ou CMS. Homologar posteriormente versões/digests e acessos
  privados sem alterar tags/serviços ativos na fase de inventário.
- [ ] Testar `ExistingCmsIsReadOnly` e documentar a implantação inicial do CMS
  pelo Compose como etapa confirmada pelo operador, fora da CLI de flash.
- [ ] Revisar e registrar checkpoint, fontes e limitações APT/npm.

## Task 3: imagem verificada e capabilities do Imager

**Files:** criar `scripts/flash/Image.psm1`,
`scripts/flash/raspios-image.json`, `scripts/flash/Imager.psm1` e
`tests/flash/Image.Tests.ps1`.

**Interfaces:** `Get-VerifiedImage($Manifest, [string]$CacheDirectory)`
retorna `Path`, `Sha256`, `Version`, `Architecture`.
`Get-ImagerCapabilities([string]$Executable)` retorna versão e flags reais;
nenhuma dessas funções grava dispositivos.

- [ ] **RED:** testar conteúdo adulterado, download parcial, imagem errada
  e versão sem customização suportada; usar apenas arquivos pequenos fictícios.
- [ ] Rodar Pester `tests/flash/Image.Tests.ps1` e registrar falha esperada.
- [ ] Implementar download temporário, hash, promoção atômica ao cache e probe
  do executável por argumentos, sem shell interpolado. Fixar imagem somente
  depois de verificar origem e compatibilidade com o hardware de homologação.
- [ ] **GREEN:** cache correto é reutilizado, incorreto nunca é gravado;
  manifesto sem URL/versão/hash homologados bloqueia execução.
- [ ] Revisar e registrar baseline. Se o Imager estiver ausente, solicitar
  instalação local, sem interpretar a permissão de usar SD como essa autorização.

## Task 4: seleção segura, CLI e estado de retomada

**Files:** criar `scripts/flash/FlashBerry.psm1`,
`scripts/flash/BerryWorkflow.psm1`, `scripts/flash/flash-berry.ps1`,
`tests/flash/DiskSafety.Tests.ps1` e `tests/flash/Workflow.Tests.ps1`.

**Interfaces:** `Get-FlashTargets() -> object[]` conforme `DiskTarget`.
`Assert-FlashTarget($Target, $ExpectedIdentity) -> object` ou erro.
`Save-BerryRun([string]$Path, $State)` grava `RunState` atomicamente.
`Get-BerryNextStage($State, [string]$RequestedStage) -> string` não faz IO remoto.

- [ ] **RED:** testar sistema/boot, ambiguidade, troca de mídia/leitor,
  falta de confirmação, estado adulterado e `All` parando antes de aplicar.
- [ ] Executar Pester nas duas suítes; simulação não pode chamar writer.
- [ ] Implementar CLI e exit codes da spec §6, estado v1 e retomada por GUID.
  Tokens `ERASE:<identidade>` são gerados para o alvo corrente e valem só para
  flash. Sem `-Execute`, não criar payload privado nem disparar operação remota.
- [ ] **GREEN:** `DiskNumber` é opcional fora de `Flash`; mudanças de serial,
  tamanho ou continuidade invalidam o alvo. `NeedsOperator` preserva a etapa
  pendente. Estado em disco não contém configuração privada.
- [ ] Testar `DryRunWritesNothing`, `DryRunDoesNotConnect`,
  `ExistingReservationContinuesWithoutApproval`,
  `ResumeAfterDhcpDoesNotReflash` e `ChangedReservationRequiresNewApproval`.
  Cache, payload, estado e uploads só podem ser criados com `-Execute`.
- [ ] Revisar e registrar checkpoint. A exceção não pode ser um parâmetro para
  habilitar disco de sistema ou um aceite automático de hostname conflitante.

## Task 5: payload e gravação autorizada

**Files:** criar `scripts/flash/Payload.psm1`,
`scripts/flash/templates/firstboot.sh`,
`scripts/flash/templates/player.service`,
`tests/flash/Payload.Tests.ps1`, `tests/provision/firstboot.bats`;
modificar writer em `Imager.psm1` e coordenador.

**Interfaces:** `New-BerryPayload($Device, $Image, $PrivateConfig, $WorkDirectory)`
retorna caminhos privados e resumo sanitizado; `Remove-BerryPayload($Path)`
restringe remoção ao diretório da execução.
`Invoke-BerryFlash($Image, $Payload, $ExpectedTarget)` retorna `RunId`,
`ExitCode`, `WriteVerified`; não promove para rede ou player aceitos.

- [ ] **RED:** testar Wi-Fi com espaços/aspas/dólar, múltiplas públicas,
  erro do gravador e limpeza em `finally`; rodar bootstrap em Linux isolado.
- [ ] Executar Pester e Bats; corrigir erros de fixture antes de aceitar RED.
- [ ] Implementar customização somente no mecanismo comprovado da tarefa 3.
  Gerar usuário, SSH e NetworkManager; chaves de host são geradas no destino.
  Sem `.env` completo, privadas, credenciais DHCP ou senha sudo em argumentos.
- [ ] Testar senha local recebida por prompt seguro: só o hash temporário
  necessário chega ao bootstrap. A ausência dessa senha não habilita SSH por
  senha ou sudo irrestrito; operações posteriores que precisem dela pausam.
- [ ] **GREEN:** nome escolhido persiste no boot, duas identidades autenticam
  e chave desconhecida não entra; permissões SSH e usuário corretos.
- [ ] Para teste físico: pedir confirmação da identidade atual do SD de teste,
  reconsultar discos e só então executar writer elevado, com verificação.
  Sem imagem homologada ou Imager disponível, registrar bloqueio sem gravar.
  Verificar boot exige Raspberry e console/monitor, não somente cartão no PC.
- [ ] Revisar resultados físicos versus simulados e registrar checkpoint.

## Task 6: transporte, leases e scripts de consulta confiáveis

**Files:** criar `scripts/common/Transport.psm1`,
`scripts/dhcp/LeaseEvidence.psm1`, `scripts/network/NetworkBerry.psm1`,
`tests/network/Identity.Tests.ps1`, `tests/dhcp/LeaseEvidence.Tests.ps1`;
reescrever os dois `.ps1` existentes em `scripts/dhcp/` como wrappers.

**Interfaces:** `Get-BerryConnection($Device, $Evidence) -> object`;
`Get-BerryIdentity($Connection) -> object` com fatos da placa;
`ConvertFrom-DhcpLeases([string]$Text, [datetime]$NowUtc) -> object[]`;
`Get-BerryLeaseEvidence($Records, [string]$Hostname, [string]$Mac) -> Evidence[]`.
`Invoke-BerrySsh($Connection, [string]$Operation, [hashtable]$Arguments)`
retorna `ExitCode`, `Stdout`, `Stderr`; logs externos sempre redigidos.

- [ ] **RED:** fixture com duas interfaces e lease expirado deve manter o
  Wi-Fi atual separado do Ethernet; entrada ilegível/malformada é `Unknown`.
  Testar filtro exato com outro hostname semelhante e MAC diferente.
- [ ] Rodar Pester `tests/network` e `tests/dhcp`; guardar resultado RED.
- [ ] Implementar parsers reais e transporte com host key confiável,
  timeout 15 segundos e duas tentativas no máximo. Não usar `-AcceptKey`
  silencioso. O primeiro fingerprint vem de console ou registro confiável.
- [ ] **GREEN:** wrappers mantêm `-EnvFile`, `-Hostname`/`-Hostnames` e `-Horas`
  1 a 168; saída estruturada é padrão, resumo humano usa camada separada.
  Nenhum OUI/IP define interface como comprovada; erros não viram ausência.
- [ ] Revisar e registrar checkpoint; confirmar que consultas não renovam
  conexões, não alteram contas e não reiniciam serviços.

## Task 7: candidato DHCP, validação e pausa

**Files:** criar `scripts/dhcp/InfrastructureContext.psm1`,
`scripts/dhcp/DhcpEnrollment.psm1`,
`tests/dhcp/EnrollmentPlan.Tests.ps1`, fixtures sanitizadas e
`docs/REDE-CLI.md` provisório; integrar `PrepareDhcp` na CLI.

**Interfaces:** `Get-InfrastructureContext([string]$RepoPath)` resolve providers
e ferramentas de `ti`, sem escrever `.env`.
`New-DhcpEnrollmentPlan($Identity, $InfrastructureContext) -> DhcpPlan`.
`Test-DhcpCandidate($Plan, $InfrastructureContext) -> object` contém resultado
local/remoto e hashes; não tem autorização de aplicação.

- [ ] **RED:** testar pool dinâmico, IP/MAC duplicados, faixa esgotada,
  reserva correta como no-op e preservação das duas reservas existentes.
  Preparação validada deve continuar com zero chamadas de restart/aplicação.
- [ ] Rodar Pester `tests/dhcp/EnrollmentPlan.Tests.ps1`; registrar RED.
- [ ] Implementar fetch atual, backup local em `ti`, subnet/endereço,
  marcadores das TVs, formatter e validadores conforme o procedimento existente.
  Não produzir IP disponível só porque não respondeu ping.
- [ ] Enviar e validar candidato com os cmdlets e sudo interativo da spec §9;
  manter arquivos completos e diff fora do repo. Se a configuração externa
  ainda não estiver disponível, retornar pendência, sem converter em fixture.
- [ ] **GREEN:** diff com mudança alheia é bloqueado; todos os hashes, no-op
  e resultados de sintaxe são coerentes. Com mudança, aguardar aprovação;
  reserva já correta permite seguir para verificar rede, sem aplicar/reiniciar.
- [ ] Revisar e registrar checkpoint. Homologação em servidor real somente
  com autorização própria, mesmo sem reinício.

## Task 8: aplicação DHCP independente e recuperação

**Files:** criar `scripts/dhcp/DhcpApply.psm1`,
`tests/dhcp/DhcpApply.Tests.ps1`; integrar `ApplyDhcp` no coordenador.

**Interfaces:** `Request-DhcpApproval($Plan) -> Approval` depende de interação
humana atual; `Apply-DhcpEnrollment($Plan, $Approval, $InfrastructureContext)`
retorna backup remoto, validação final e status do serviço.

- [ ] **RED:** `All`, `-ConfirmErase`, `-Confirm:$false`, plano alterado,
  base alterada ou booleano persistido não autorizam aplicação.
  Testar validação final falhando: restart não deve ocorrer.
- [ ] Rodar Pester `tests/dhcp/DhcpApply.Tests.ps1`; guardar RED.
- [ ] Implementar chamada separada, revisão restrita do diff, confirmação,
  reconsulta dos hashes, backup remoto, aplicação, `dhcpd -t` e restart.
  Não oferecer `-Force`/`-Yes` que contorne a autorização.
- [ ] **GREEN:** falha de sintaxe, backup, acesso ou serviço não avança estado.
  Distinguir serviço já alterado de aplicação não iniciada no relatório.
  Recuperação apresenta backup e nova confirmação, sem rollback cego.
- [ ] Revisar e registrar checkpoint; teste real de restart depende de
  confirmação imediata do operador sobre o candidato específico.

## Task 9: renovação Wi-Fi e aceite de rede

**Files:** expandir `NetworkBerry.psm1`, coordenador e
`tests/network/Connectivity.Tests.ps1`; criar fixtures de respostas.

**Interfaces:** `Renew-BerryWifi($EthernetConnection, [string]$ProfileUuid)`
renova só o perfil confirmado; `Test-BerryNetwork($Connection, $Reservation)`
retorna `Evidence[]` para associação, IP/MAC, rota, DNS, HTTPS, CMS e SSH.
`Assert-BerryNetworkReady($Evidence)` permite avanço ou retorna pendência.

- [ ] **RED:** testar portal com HTTP 200, timeout, certificado inválido,
  rota por Ethernet, perfil errado e SSH direto bloqueado com salto válido.
- [ ] Testar `MissingBerrySudoPasswordNeedsOperator` e
  `SudoPromptDoesNotPersistSecret`. Senha é local ao Berry e fornecida por
  interação segura, não pela senha de Wi-Fi/DHCP ou pelo arquivo de estado.
- [ ] Executar Pester `tests/network/Connectivity.Tests.ps1`; registrar RED.
- [ ] Implementar ordem determinística com recuperação Ethernet, UUID real,
  IP observado e testes autenticados do caminho permitido. Não limpar perfil.
  Problema em switch/ACL/portal cria `NeedsOperator`, não mudança automática.
- [ ] **GREEN:** reserva configurada sem rede efetiva é rejeitada; salto
  válido satisfaz SSH se direto é vedado. Nenhum teste de alcance autoriza
  sozinho o display ou comprova XMR/Pi Connect.
- [ ] Após autorização, testar funcionamento sem cabo mantendo recuperação
  disponível. Revisar e registrar evidências físicas separadamente.

## Task 10: provisionamento idempotente do player

**Files:** criar `scripts/provision/provision-player.sh`,
`tests/provision/player.bats`; reutilizar código, helper e serviço de usuário
em `xiboplayer-chromium/xiboplayer/`. Não modificar o CMS para cada dispositivo.

**Interfaces:** `provision-player.sh --source DIRETORIO --user USUARIO`
consome código com versão/hash e arquivo privado mínimo com modo `600`.
Precondição: `NetworkVerified`; instalação não recebe senha pela linha de comando.

- [ ] **RED:** testar rede indisponível, ausência de sessão, segundo run,
  configuração existente e identidade preservada; fixtures sem segredo real.
- [ ] Executar Bats `tests/provision/player.bats` em Linux isolado; registrar RED.
- [ ] Implementar instalação mínima, `npm ci` com lock, configuração exclusiva,
  usuário dono e unidade ligada à sessão. Não supor usuário UID 1000, DISPLAY
  fixo ou Wayland fixo. Autologin só por opção explícita do operador.
- [ ] **GREEN:** sem sessão gráfica, retornar pendência; segunda execução não
  troca display/cache/config nem expõe DevTools. Helper de parada é instalado
  antes do serviço que depende dele; sem sudo geral sem senha.
- [ ] Rodar também as duas suítes Node existentes, Bats upstream e Bash syntax.
  Reportar dependências ausentes e testes não executados, sem afirmar sucesso.
- [ ] Revisar e registrar checkpoint; autorizar o novo display por fluxo
  separado, sem trocar a chave global do CMS ou copiar vínculo Pi Connect.

## Task 11: pacotes e ZIP por allowlist

**Files:** criar `scripts/distribution/New-BerryPackage.ps1`,
`scripts/distribution/Package.psm1`, `tests/distribution/Package.Tests.ps1`;
atualizar `.gitignore` para caches, payloads e relatórios privados.

**Interfaces:** `New-PlayerCodePackage([string]$Source, [string]$Destination)`
retorna versão/hash do pacote sem perfis; `New-OperatorZip($Source, $Destination,
$ApprovedPublicKeys)` retorna manifesto público dos membros permitidos.

- [ ] **RED:** criar fixture com `.env`, privada disfarçada, `.git`, volumes,
  backup e pública aprovada. Abrir ZIP resultante e verificar membros reais.
- [ ] Executar Pester `tests/distribution/Package.Tests.ps1`; registrar RED.
- [ ] Implementar allowlist de código/docs/modelos e públicas verificadas;
  excluir por conteúdo material privado, sem confiar só no `.gitignore`.
  Impedir symlinks/junctions que escapem da árvore permitida.
- [ ] **GREEN:** duas execuções sobre mesma árvore produzem manifesto de
  conteúdo equivalente; alteração de código muda o hash. ZIP nunca concede
  acesso institucional por conter senha herdada do autor.
- [ ] Revisar e registrar checkpoint; nenhum upload ou envio a destinatário
  acontece automaticamente ao criar o pacote.

## Task 12: homologação, documentação numerada e entrega

**Files:** criar/reescrever os doze guias `docs/01-*.md` a `docs/12-*.md`
nomeados na tarefa 11 do plano de origem; atualizar README, links e inventário
somente com fatos comprovados. Histórico vai a `docs/historico/`.

**Interfaces:** roteiro de aceite produz registro sanitizado por requisito,
com `Passed`, `Failed`, `NotRun`, data e responsável; não executa hardware
sozinho. Documentação e comandos precisam corresponder à CLI entregue.

- [ ] Antes da homologação, elaborar checklist R01 a R22 e casos físicos:
  duas identidades, boot, Wi-Fi sem cabo, reserva, CMS, HDMI, atualização,
  imagens/vídeos, offline, start/stop/restart e reboot.
- [ ] No caminho do zero, preparar o CMS pelo Compose com confirmação própria.
  No incremental, comprovar que nenhum comando recriou serviços/banco ou
  alterou a chave global como efeito colateral de cadastrar outra placa.
- [ ] Executar com alvo confirmado; manter `NotRun` onde faltam Pi, monitor,
  sudo ou liberação institucional. Só SD no PC não satisfaz esses critérios.
- [ ] Reescrever guias com um passo por arquivo e seus pré-requisitos,
  contexto PC/servidor/Pi, entradas, resultado, confirmação e recuperação.
  README oferece instalação do zero e inclusão incremental sem duplicar receita.
- [ ] Validar links e Markdownlint; rodar toda a suíte Pester e as suítes Linux
  e Node. Corrigir regressões e registrar as limitações reais de build.
- [ ] Outro operador/agente percorre os dois caminhos em ambiente limpo;
  nenhuma skill pessoal ou caminho deste PC pode ser requisito oculto.
- [ ] Fazer revisão independente da integração completa; só depois registrar
  aceite final. Commit, merge, push e rollout dependem das autorizações definidas.

## Comandos de verificação durante a execução

```powershell
Invoke-Pester -Path tests -CI -Output Detailed
node --test xiboplayer-chromium/tests/*.test.cjs
npx --yes markdownlint-cli2 README.md "docs/**/*.md"
git diff --check
```

```bash
bats tests/provision
bats xiboplayer-chromium/tests/launch-kiosk.bats
bash -n scripts/provision/provision-player.sh
```

Esses comandos são futuros: não comprovam implementação nesta entrega.
Usar a versão homologada do lint na execução, em vez de depender de latest.
Testes de parser, mock e dry-run não substituem homologação física nem a
aprovação de um candidato DHCP real.

## Pendências para operação completa — 29/10/2026

Esta fase implementa e valida a solução localmente. O acesso padrão do CMS
no computador é `http://localhost:8080`, conforme o Compose existente.
No Raspberry Pi, `localhost` representa a própria placa; será necessário
definir o endereço alcançável do servidor. Não há chave CMS padrão presumida.

A implementação local foi concluída e revisada na branch
`feat/xibo-berry-cli`, em `.worktrees/xibo-berry-cli`. Execute os comandos a
partir desse diretório; o checkout principal preserva as edições anteriores.
Consulte o
[README da implementação](../../../.worktrees/xibo-berry-cli/README.md).

Validação final PowerShell: **365 testes aprovados, zero falhas**, com saída
`0` e resultados XML/JSON registrados. As suítes de código não alterado nesta
última correção registraram Node **17 aprovados** e Bats **21 aprovados e um
skip conhecido**. Markdownlint CLI validou os 25 documentos da entrega sem
erros. A revisão independente aprovou o escopo local com as limitações de
encerramento e limpeza descritas abaixo; isso não é homologação física.

- Configurar `XIBO_CMS_URL` e `XIBO_CMS_KEY` no `.env` privado, obtendo a chave
  do CMS existente sem trocá-la globalmente. Esses dois campos ainda estavam
  vazios na consulta de 29/10; nenhum valor secreto foi exibido.
- Disponibilizar HTTPS com certificado válido e DNS/rota acessíveis pelo Pi.
  O HTTP local de desenvolvimento não satisfaz o aceite de rede da CLI.
- Integrar a branch ao checkout principal quando desejado, preservando as
  edições já existentes. Até lá, utilizar a worktree indicada acima.
- Informar um `OpenSslPath` local confiável ao Flash e usar PowerShell 7.6.6
  ou posterior compatível. O Flash pausa se a senha local do Berry ficar vazia;
  a senha de Wi-Fi/DHCP não substitui a senha local de sudo.
- Homologar a imagem candidata e seu primeiro boot no Pi 4B. O download e os
  hashes foram verificados; gravação, boot e HDMI ainda não foram testados.
  O manifesto padrão permanece `NotHomologated` e bloqueia flash normal.
- Antes de gravar, revalidar cartão e imagem e confirmar o alvo específico.
  A presença do cartão USB de 63,86 GB não autoriza apagar seu conteúdo.
- Conferir a fingerprint SSH por console e testar as duas identidades
  individuais aprovadas. A chave privada permanece no computador do titular.
  Cadastrar separadamente os hosts no store Posh-SSH, após verificação manual;
  esse registro não substitui o pin SHA256 usado pelo OpenSSH.
- Obter a configuração DHCP atual, preparar a reserva do MAC Wi-Fi observado,
  validar o candidato e pedir confirmação específica antes de aplicar/reiniciar.
  Validar renovação por UUID, IP reservado e funcionamento sem o cabo.
- Validar DNS, HTTPS, CMS e SSH pelo caminho permitido. Liberações de rede
  institucional são pendências do operador, sem mudança automática de ACL/VLAN.
- Autorizar o display no CMS e testar imagens, vídeos, atualização de layout,
  offline, start/stop/restart e reboot. Validar XMR e Pi Connect separadamente.
- Registrar os resultados R01–R22 e físicos com data e responsável. Critérios
  físicos permanecem `NotRun`; testes automatizados não concedem `Accepted`.
- Após timeout ou interrupção abrupta de deploy, verificar se o worker acabou
  e inspecionar o alvo e a tentativa exatos antes de retomar. Pode permanecer
  `/tmp/berry-player-<id>/private.json`, com a chave CMS, em diretório privado.
  O ID não é persistido; sem associação segura, solicitar inspeção do operador.
  A expiração autônoma e a confirmação de limpeza após término forçado são
  melhorias pendentes. Não apagar diretórios por glob nem repetir mutações
  cegamente; falhas de encerramento mantêm o resultado como indeterminado.

Em 29/10, uma consulta somente leitura encontrou o Docker disponível e cinco
serviços Xibo ativos. Isso não comprova reprodução, registro do display ou XMR.
Nenhuma gravação de cartão, aplicação DHCP ou recriação do CMS foi executada
como parte desta implementação local.
