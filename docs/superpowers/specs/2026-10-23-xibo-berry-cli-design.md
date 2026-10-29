# Especificação da CLI Xibo Berry

Status: rascunho para aprovação. Nenhuma implementação está autorizada por
este documento. Origem: [plano consolidado](../../../PLANO-FLASH-RASPBERRIES.md).

## 1. Intenção e resultados

Preparar Raspberry Pis destinados exclusivamente a TVs, desde um cartão novo
até reprodução pelo Xibo, com operação simples e diagnóstico baseado em fatos.
Outro operador ou agente de IA deve reproduzir o processo somente com o repo,
documentação, hardware e acessos autorizados, sem histórico desta conversa.

O roteiro do zero inclui preparar o CMS pelo Compose existente, como etapa
documentada e confirmada pelo operador, não uma nova etapa automática da CLI.
O doctor valida o CMS; a expansão somente verifica e reutiliza sua instalação.
Não há criação/reinicialização implícita de containers pelo fluxo de flash.

Dois caminhos obrigatórios: implantar ambiente do zero e acrescentar Berries
a um CMS existente. Ambos usam as mesmas etapas por dispositivo; a expansão
não reinstala o banco nem redefine chaves globais ou configurações da frota.

## 2. Decisões e alternativas

Abordagem adotada no plano de origem: imagem oficial desktop arm64, Imager CLI
e bootstrap por dispositivo, coordenados por PowerShell 7 no Windows.
Imagem própria em Linux é alternativa futura, com custo de outro pipeline.
Clonar um cartão de produção é rejeitado: duplica identidade e estado privado.

O usuário escolheu várias chaves públicas individuais, não uma privada de setor.
SDD nesta entrega significa Subagent-Driven Development: implementador novo por
tarefa, revisão de conformidade e qualidade, depois revisão integrada final.
TDD rege cada comportamento implementado: RED, GREEN e REFACTOR.

## 3. Limites de autorização

São quatro autorizações diferentes: implementar código, apagar uma mídia
identificada, aplicar um candidato DHCP validado e publicar commits/artefatos.
Uma não substitui as demais. A disponibilidade de um SD de teste não autoriza
selecionar outro disco nem alterar o servidor DHCP.

A execução SDD só começa após aprovação desta spec e revisão do plano derivado.
Mudanças de código acontecem em worktree isolado. Permissão para commits locais
deve ser definida no início; push e merge permanecem separados.
Não criar dependências, instalar ferramentas ou executar flash nesta entrega
documental. Validação física ocorre apenas após preflight e confirmação do alvo.

## 4. Requisitos vinculantes

- R01: uma CLI Windows, um cartão e um Berry por execução; simulação padrão.
- R02: não gravar sistema/boot, destino desconhecido ou identidade divergente.
- R03: revalidar destino antes da escrita e manter verificação do Imager.
- R04: imagem oficial desktop arm64 fixada por versão, URL e SHA256 homologados.
- R05: hostname `berry-tv-campus-NN`, prefixo literal, sequência positiva
  com pelo menos dois dígitos; após `99`, usar `100`, sem truncar.
- R06: sequência e unicidade conferidas no inventário e DHCP atual;
  nomes existentes não são renomeados automaticamente.
- R07: ao menos uma pública válida; privadas individuais nunca saem do titular.
- R08: não enviar `.env`, credenciais administrativas ou sessão de outro Pi.
- R09: somente leitura é padrão para descoberta e diagnóstico de rede.
- R10: reserva usa o MAC Wi-Fi real, não o Ethernet ou inferência por OUI/IP.
- R11: preparar, aplicar e verificar DHCP são etapas separadas.
- R12: somente candidato validado e revisado pode receber aprovação humana;
  alteração da base/candidato invalida a aprovação.
- R13: preservar reservas e leases alheios; operação idempotente correta é no-op.
- R14: manter Ethernet durante renovação do UUID Wi-Fi exato.
- R15: comprovar IP, rota Wi-Fi, DNS, HTTPS, CMS e SSH pelo caminho permitido.
- R16: sem mudança automática de VLAN, switch, ACL, portal ou firewall.
- R17: player integrado do repo, proxy/PWA `0.7.15`, lockfile e `npm ci`.
- R18: não alterar CMS existente, identidade de display ou Pi Connect alheios.
- R19: documentar e verificar dependências, versões, serviços e modos opcionais.
- R20: documentação final reescrita, numerada e validada para os dois caminhos.
- R21: ZIP por allowlist, sem `.env`, privadas, `.git`, volumes ou backups.
- R22: relatório não contém senhas, tokens, hashes de senha ou payload privado.

As regras operacionais de sudo, simulação e retomada nas seções 6 e 8 são
propostas de fechamento do agente após revisão técnica, sujeitas à aprovação
do usuário junto com esta spec.

## 5. Contratos de dados

`Device`, persistível sem segredos: `Hostname`, `Username`, `DisplayName`,
`PublicKeyPaths` (array), `PublicKeyFingerprints` (array), `Serial`,
`EthernetMac`, `WifiMac`, `EthernetIp`, `WifiIp`, `VerifiedHostKey`.
Campos observados começam nulos, nunca são inventados no arquivo de exemplo.
O usuário Linux inicial é `berry`, compatível com o deploy atual.
Local físico é metadado separado; não integrar SSSD/AD/LDAP neste lote.

`DiskTarget`: `Number`, `UniqueId`, `SerialNumber`, `Size`, `BusType`,
`IsBoot`, `IsSystem`. A identidade composta une identificador, serial e tamanho;
número ou letra isolados não bastam. Sem identidade inequívoca, abortar.
Identificadores do leitor USB podem permanecer iguais após trocar a mídia:
monitorar desconexão/troca e exigir nova seleção se a continuidade for perdida.

`Evidence`: `Check`, `Status`, `ObservedAtUtc`, `Source`, `DeviceSerial`,
`InterfaceMac`, `DetailCode`, `NextAction`; status `Passed`, `Failed`,
`Unknown` ou `NotApplicable`. Texto bruto não prova sucesso.
Toda coleta remota tem timeout de 15 segundos e no máximo duas tentativas,
exceto comandos de instalação explicitamente classificados como demorados.
Timeout/autenticação negada produzem `Unknown` ou `Failed`, nunca dispositivo
ausente por inferência. Falha de certificado não recebe retry inseguro.

`DhcpPlan`, relatório público: `PlanId`, `Hostname`, `WifiMac`, `Address`,
`Subnet`, `BaseHash`, `CandidateHash`, `ValidationStatus`.
Configuração completa, diff e backups ficam em área privada de `ti`.
`Approval` vincula plano, hashes, alvo e confirmação explícita do operador;
não basta recuperar um booleano de arquivo ou usar `-ConfirmErase`.

`RunState`: `SchemaVersion=1`, `RunId` (GUID), `Stage`, `Device`, hashes de
imagem/código e evidências sanitizadas. Escrita atômica, sem segredos;
alteração de identidade requer nova avaliação, não avanço silencioso.

## 6. Interface e estados

Entrada: `scripts/flash/flash-berry.ps1`. Aceita `-DeviceFile` ou entradas
`-Hostname` e `-SshPublicKeyPath` (array), `-DiskNumber` apenas para flash,
`-Stage`, `-RunId`, `-InfrastructureRepo`, `-Execute`, `-ConfirmErase` e
`-EnableDesktopAutologin`. Campos contraditórios exigem confirmação.
Sem nome/chaves, pedir somente o que falta; não escolher chaves automaticamente.
Autologin é opt-in com alerta de acesso físico; não fixar DISPLAY/Wayland.

Etapas: `Flash`, `DiscoverNetwork`, `PrepareDhcp`, `ApplyDhcp`, `VerifyNetwork`,
`DeployPlayer`, `All`. Sem `-Execute`, simular por cálculo e leitura dos
artefatos já existentes; emitir resumo apenas em stdout, sem persistir estado,
baixar imagem, gerar payload, conectar remotamente ou enviar candidato.
Sem dados atuais suficientes, emitir pendência, não presumir validação.
Com `-Execute`, download, cache, estado e arquivos de preparação são permitidos
no escopo autorizado. `PrepareDhcp -Execute` pode obter, enviar e validar o
candidato temporário, mas não substituir a configuração ativa ou reiniciar.
Um resultado positivo de leitura não autoriza aplicação.
Exit codes: `0` etapa concluída/simulada, `2` entrada inválida, `3` dependência
ausente/incompatível, `4` exige operador, `5` falha de execução/verificação.
Conclusão da simulação deve estar identificada como tal no relatório.

Estados: `Planned`, `FlashVerified`, `AwaitingFirstBoot`, `IdentityVerified`,
`DhcpPrepared`, `AwaitingDhcpApproval`, `DhcpApplied`, `NetworkVerified`,
`PlayerConfigured`, `Accepted`; `NeedsOperator` preserva a etapa pendente.
`All` termina em `AwaitingDhcpApproval` sempre que existir mudança DHCP a
aplicar; nunca chama `ApplyDhcp` por conta própria. Reserva já correta é no-op
e permite seguir para verificação de rede. Após aplicação explícita,
`All -RunId` revalida o mesmo dispositivo e a reserva atual e continua nas
etapas pendentes sem refazer flash ou repetir a aplicação. Qualquer nova
divergência que exija escrita volta à preparação e aprovação independente.
Retomada exige o mesmo dispositivo e revalida evidências mutáveis.
`Accepted` depende de confirmação de homologação, não apenas processo ativo.

## 7. Responsabilidades dos módulos

- `common/Configuration`: ler `.env` sem source/eval, validar e redigir erros.
- `common/Transport`: executar operações autorizadas, limites e host keys.
- `setup`: manifesto de dependências, doctor de leitura e instalador opt-in.
- `access/AuthorizedKeys`: públicas, fingerprints, adição e revogação explícitas.
- `flash/FlashBerry`: discos, imagem verificada e adaptação ao Imager real.
- `flash/BerryWorkflow`: etapas, estado sanitizado e retomada.
- `network/NetworkBerry`: identidade e evidências de conectividade por camada.
- `dhcp/LeaseEvidence`: parsers exatos compartilhados pelos scripts existentes.
- `dhcp/DhcpEnrollment`: adapter para ferramentas e procedimentos de `ti`.
- `provision`: bootstrap e instalação idempotente do player em Linux.
- `distribution`: pacote de código com hash e ZIP de operador por allowlist.

Interfaces públicas e assinaturas por tarefa são fixadas no plano derivado.
Reusar os scripts de consulta como wrappers; remover defaults antigos e buscas
amplas. Não criar uma segunda implementação de infraestrutura fora de `ti`.

## 8. SSH, credenciais e primeiro acesso

Cada pessoa mantém sua privada e entrega somente a pública aprovada.
Deduplicar por material criptográfico, não por nome do arquivo ou comentário.
Permissões no Pi: diretório `.ssh` `700` e `authorized_keys` `600`, dono correto.
Uma revogação explícita não remove a última chave funcional sem alternativa.
Públicas existentes desconhecidas não são sobrescritas automaticamente.

Fingerprint de host é distinto da pública do operador. Confirmar o primeiro
por console/monitor ou canal de inventário previamente confiável; `ssh-keyscan`
sozinho não prova identidade. Sem canal confiável, pausar e instruir o operador.
Não apagar `known_hosts`, aceitar chave alterada ou desabilitar verificação.

O `.env` Berry tem variáveis ALL CAPS; `ti` mantém arquivo independente e
nomes legados. Resolver por provider em memória, sem reescrever seus arquivos.
Credenciais DHCP nunca chegam à placa. Wi-Fi e chave do CMS podem precisar
de configuração privada no destino; isso não permite copiar o `.env` completo.
NTFS temporário requer acesso restrito; FAT de boot não garante esse sigilo.
Remover artefatos em `finally`, sem prometer apagamento forense de flash.

No bootstrap autorizado, tarefas privilegiadas rodam no contexto root do
mecanismo oficial de primeiro boot, não por um login SSH root. Para manutenção
ou retomada que precise de sudo, pedir a senha local do usuário do Berry em
prompt seguro/`SecureString` e usar terminal interativo, sem armazená-la.
Se for preciso definir essa senha local no flash, recebê-la por prompt seguro
individual, não no `.env` compartilhado; o hash necessário ao bootstrap é
payload privado temporário. Não habilitar SSH por senha automaticamente.
Se não houver senha local utilizável ou o operador não a fornecer, pausar em
`NeedsOperator`; não criar sudo geral sem senha nem usar senha DHCP/Wi-Fi.

## 9. Fluxo de rede e DHCP

Primeiro boot cria acesso mínimo. Descoberta correlaciona leases/logs com
hostname e identidade da placa lida por SSH Ethernet. Distinguir leases
simultâneos, expirados e histórico; sem permissão para ler, retornar `Unknown`.
Detectar perfil com MAC aleatório antes de propor reserva permanente.

Preparação obtém configuração atual no servidor, preserva cópia local anterior
em `ti`, identifica subnet e pool e propõe endereço após o maior fixo da mesma
subnet. Se ocupado, em pool, sem faixa válida ou duvidoso, parar, não pular
automaticamente para um IP arbitrário. Ping silencioso não prova IP livre.
Manter os marcadores das TVs e divisor por Berry; no-op não reinicia serviço.

Formatar e validar conforme `ti`; revisar diff completo e executar
`dhcpd -t -cf /etc/dhcp/dhcpd.conf.test` no servidor. Upload instalado usa
`Set-SCPItem -Destination /tmp -NewName dhcpd.conf`, sem `-PathType`.
Sudo remoto usa `New-SSHShellStream` e
`Invoke-SSHStreamExpectSecureAction`, com `SecureString` e sem transcript secreto.

Após validação positiva, parar e pedir confirmação. A aplicação é comando
separado, revalida hashes e bloqueia candidato/base alterados. Confirmar com
o operador ausência de edição concorrente conhecida; hash não é lock global.
Criar backup remoto datado, aplicar, validar novamente, reiniciar e verificar.
Em falha, preservar evidências e apresentar recuperação, sem rollback cego.

Renovar apenas UUID Wi-Fi confirmado mantendo cabo. Verificar IP/MAC, rota
Wi-Fi, DNS, HTTPS sem portal cativo, CMS e autenticação SSH direta ou por salto.
Sem política institucional conhecida para uma liberação extra, informar
pendência com responsável/sistema, não inventar nem contornar controles.
Pi Connect e autorização do display continuam tendo confirmações próprias.

## 10. Imagem, serviços e reprodução

O doctor separa `Operator`, `Berry`, `Infrastructure`, `Tests` e opcionais.
Cobrir PowerShell/Storage/CIM, Git, OpenSSH, Imager, Posh-SSH, Pester, Docker
e Compose; no Pi, Bash, NetworkManager, iproute2, DNS, certificados, SSH,
systemd, desktop/login, Chromium, Node/npm, jq e curl. Detectar pacotes reais.
Pi Connect e ferramentas de vídeo são opcionais conforme o perfil.

CMS atual de referência: `cms-web`, `cms-db`, `cms-xmr`, `cms-memcached`,
`cms-quickchart`. Registrar digests, volumes, portas, Apache/PHP/X-Sendfile e
agendamentos da imagem, sem instalar essas dependências no Windows à parte.
Capturar versão/fonte de iscdhcp, includes do validador e ferramentas de build;
as bibliotecas de empacotamento ausentes não podem ser presumidas disponíveis.

A baseline exata da imagem, digests e módulos ainda precisa ser resolvida em
homologação. Manifesto incompleto bloqueia flash, sem fabricar checksums.
Raspberry Pi Imager deve demonstrar a customização suportada na versão local.
Não usar SDK/npm latest nem alterar globalmente os pacotes do OS.
Sem repositório APT congelado, não prometer reconstrução byte a byte.

Instalar player integrado com seu helper de parada e unidade de usuário.
Não expor DevTools. Só implantar após rede validada; dependências do bootstrap
que precisam de Internet aguardam essa etapa com timeout e retomada.
Não sobrescrever identidade/config existente nem habilitar sudo geral sem senha.
Downloads do CMS, polling, offline, HDMI e reboot são testes distintos de XMR.
XMR não pode ser declarado homologado apenas porque seu container está ativo.

## 11. Validação física e evidências

O operador disponibilizou um cartão para testes. Consulta local de leitura em
23/10/2026 encontrou uma mídia USB removível de aproximadamente 64 GB e o disco
do sistema separado. Isso não prova que a mídia está vazia nem fixa seu número
para a execução futura. Reconfirmar identidade, capacidade e autorização.
O Imager não foi localizado nos caminhos consultados; doctor deve resolver isso.

Teste físico mínimo: gravação verificada, primeiro boot em Pi reserva, duas
identidades SSH, Wi-Fi, reserva aprovada, funcionamento sem cabo, deploy,
layout/atualização, vídeo, offline, start/stop/restart e reboot.
Somente o cartão no PC não comprova boot, rede ou HDMI. Falta de placa/monitor
ou acesso institucional mantém esses critérios pendentes, nunca simulados.

## 12. Documentação final, distribuição e aceite

Reescrever guias numerados `01` a `12` conforme a tarefa final do plano de
origem: pré-requisitos, configuração, CMS, flash, acesso, DHCP, conectividade,
player, Pi Connect, homologação, operação e inclusão de mais Berries.
Cada guia traz ambiente, entradas, comando real, resultado, confirmação,
recuperação e links anterior/próximo. README apresenta os dois percursos.
Histórico e inventário ficam separados, sem perder evidências ou atribuições.

Aceite documental exige links e Markdownlint, percurso executado por outro
operador/agente em ambiente limpo e registro das limitações. Skills pessoais
ausentes não podem ficar como requisito oculto: documentar instalação/acesso
ou procedimento operacional equivalente, respeitando instruções do ambiente.
ZIP é inspeção por allowlist; pública aprovada é permitida, privada é negada
independentemente de extensão. Segredos são entregues por canal separado.

## 13. Não objetivos e bloqueios externos

Fora deste lote: imagem dourada, clonagem, boot PXE, flash paralelo, integração
de contas institucionais nos Pis, alterações automáticas de controle de rede,
reformulação do CMS e distribuição pública de configurações privadas.

Bloqueiam operação, não a escrita desta spec: ausência de versão homologada,
fingerprint confiável, sudo autorizado, formatter/validator ou evidência de
IP disponível; aprovação DHCP ausente; mídia ambígua; política institucional
não documentada. Resolver com o operador, sem inventar acessos.
