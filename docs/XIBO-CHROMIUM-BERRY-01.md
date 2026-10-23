# Xibo CMS e Chromium no Berry 01

Registro operacional do piloto realizado em 19/10/2026. Não contém senhas,
chave de conexão do CMS nem conteúdo de `.env`.

O [plano da CLI](../PLANO-FLASH-RASPBERRIES.md) amplia o rollout de novas placas:
flash, identificação, reserva Wi-Fi, aprovação DHCP, renovação e validação de
rede antecedem o deploy. O piloto histórico não é prova de que uma nova placa
já está liberada na rede. A CLI ainda não está implementada e os registros
de funcionamento abaixo não substituem a homologação de cada dispositivo.

## Código integrado no repositório

A partir da reorganização de 21/10/2026, o código fica em
`xiboplayer-chromium/`, na raiz. Consulte
[as alterações e os testes](../xiboplayer-chromium/BERRY.md).
O procedimento abaixo usa esse código, não os antigos artefatos de
`xibo/deploy/`.
As seções históricas descrevem o piloto; a implantação existente no Berry
não foi alterada automaticamente e ainda pode usar o helper em
`~/.local/lib/xibo/`.

## Guia para próximos agentes: implantar em outros Berries

Esta seção é o procedimento de referência. As seções posteriores registram
o histórico do piloto, incluindo tentativas que não devem ser repetidas.
Esta edição documenta a implantação; não instala nada nos outros Berries.

### Escopo, pré-requisitos e limites

- Confirmar placa, MAC, IP e cartão antes de agir; hostname acompanha o cartão.
- Usar Raspberry Pi OS de 64 bits com desktop e Chromium. O piloto usou
  Debian/Raspberry Pi OS 13, Wayland/labwc, usuário `berry` e Node `20.19.2`.
- A versão observada do Chromium foi `155.0.8059.79`. Os pacotes APT não estão
  congelados neste repositório; registrar versões e imagem do OS de cada
  destino.
- Exigir fonte adequada e monitor detectado; não ignorar subtensão.
- Preservar Wi-Fi, SSH e Pi Connect. Não reinstalar o OS nem clonar o cartão
  inteiro do piloto para criar outros players.
- Se houver Anthias ou outro player, pedir autorização específica antes de
  desativá-lo. Não iniciar dois players em quiosque na mesma sessão gráfica.
- Para DHCP, seguir `DHCP.md` e a skill `uffs-dhcp-operator`; esta implantação
  não exige alterar reservas ou reiniciar o servidor DHCP.
- Tratar como piloto: HTML funcionou, mas vídeo, offline e reboot não foram
  validados. A falha de parada e sua correção estão descritas abaixo.

Não declarar o rollout concluído só porque o serviço ficou `active`.

### Entradas obrigatórias por dispositivo

| Entrada | Regra |
| --- | --- |
| IP SSH | Confirmar o IP e MAC reais no inventário |
| Usuário Linux | Os comandos e o serviço deste guia pressupõem `berry` |
| URL do CMS | IP ou DNS alcançável pelo Berry, nunca `localhost` do PC |
| Chave do CMS | Reutilizar a chave existente, por canal seguro |
| Nome do player | Único, por exemplo `berry-tv-campus-03` |
| Layout | Publicado e atribuído ao display no CMS |

Não gerar uma nova chave global do CMS para cada Raspberry. Isso pode invalidar
os players já implantados. Não copiar identidade SSH, sessão do Pi Connect,
perfil Chromium, cache ou arquivos de identificação de outro dispositivo.

### Artefatos que devem acompanhar o deploy

| Arquivo neste repositório | Destino/uso |
| --- | --- |
| `xiboplayer-chromium/xiboplayer/server/package.json` | Manifesto npm efetivo do piloto |
| `xiboplayer-chromium/xiboplayer/server/package-lock.json` | Dependências com versões e integridade |
| `xiboplayer-chromium/xiboplayer/berry-xiboplayer.service` | Unidade systemd de usuário do piloto |
| `xiboplayer-chromium/xiboplayer/stop-player.cjs` | Encerramento restrito ao perfil Chromium do player |
| Este documento | Configuração do CMS, operação e critérios de aceite |

Os manifestos foram copiados do Berry 01 após fixar proxy e PWA em `0.7.15`.
Não contêm o `config.json` privado nem a chave do CMS. Usar os dois juntos;
não substituir `npm ci` por `npm update` ou instalar `latest` no rollout.

O wrapper do piloto está no commit:

```text
9e843c02caf1a6b2f708bda11a6fa84ffd36bd55
```

Esse commit corresponde à tag observada `v0.7.22`. O lockfile preserva a
resolução npm do piloto; a reprodução também depende de os artefatos externos
continuarem disponíveis. Ainda não há mirror offline nem imagem de OS fixada.

### Passo 1: verificar o destino sem alterar a rede

Entrar com SSH pelo caminho acessível, seguindo `BERRIES.md`. No Berry:

```bash
whoami
hostname
cat /sys/class/net/wlan0/address
uname -m
cat /etc/os-release
command -v chromium
kmsprint
vcgencmd get_throttled
curl -I --connect-timeout 5 http://172.20.69.241:8080/login
```

Substituir a URL de exemplo pelo endereço atual do CMS. Se o servidor não for
alcançável, resolver o caminho de rede antes de instalar. Se o OS não tiver
desktop, não presumir que o procedimento serve sem uma etapa adicional.

### Passo 2: conferir o CMS uma única vez

Reutilizar a instalação Docker e conferir as alterações detalhadas neste MD:

1. Biblioteca em `/var/www/cms/library/` e chave global existente.
2. Tipo de download `Apache`, com X-Sendfile disponível no container.
3. Perfil Linux com janela `00:00` até `23:59`.
4. Layout de teste publicado.

Essas opções são globais ou compartilhadas. Não redefini-las indiscriminadamente
para cada novo Berry. Fazer backup do CMS antes de mudanças que afetem a frota.
Não editar o código do CMS: o piloto utilizou somente seu dashboard.

### Passo 3: instalar os pré-requisitos

Executar no Berry, como `berry`, informando a senha sudo no prompt interativo:

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  nodejs npm git jq curl chromium
```

Não executar upgrade geral nem autoremove.

### Passo 4: transferir o código integrado e instalar dependências

Não clonar apenas a tag upstream: ela não contém nossas correções.
No PowerShell do PC, na raiz deste projeto, transferir o código integrado.
O destino deve ser novo; o comando remoto recusa sobrescrever um diretório.

```powershell
$berryIp = 'IP_DO_NOVO_BERRY'
$berryTarget = "berry@${berryIp}"
ssh -J USUARIO_DHCP@SERVIDOR_DHCP $berryTarget `
  'test ! -e ~/xiboplayer-pilot && mkdir ~/xiboplayer-pilot'
if ($LASTEXITCODE -ne 0) { throw 'Destino existente ou SSH indisponível' }
scp -r -J USUARIO_DHCP@SERVIDOR_DHCP `
  xiboplayer-chromium/xiboplayer "${berryTarget}:/home/berry/xiboplayer-pilot/"
```

A pasta transferida contém launcher, helper, unidade e manifestos integrados.
Não transferir `.env`, perfil Chromium ou identidade de outro Berry.

No Berry:

```bash
cd /home/berry/xiboplayer-pilot/xiboplayer/server
npm ci --omit=dev --ignore-scripts --no-audit --no-fund
npm list @xiboplayer/proxy @xiboplayer/pwa --depth=0
```

Os dois pacotes devem estar em `0.7.15`. Se `npm ci` falhar, preservar o erro
e o lockfile; não instalar `latest` nem relaxar a integridade.

### Passo 5: criar a configuração privada sem registrar a chave

Executar em terminal interativo no Berry, como `berry`. O exemplo cria um
arquivo novo e recusa sobrescrever uma configuração existente. Alterar a URL
e o nome único antes de executar; digitar a chave somente no prompt oculto.

```bash
read -r -p 'URL do CMS: ' XIBO_CMS_URL
export XIBO_CMS_URL
export XIBO_DISPLAY_NAME='berry-tv-campus-03'
read -r -s -p 'Chave existente do CMS: ' XIBO_CMS_KEY
printf '\n'
export XIBO_CMS_KEY
umask 077
node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { XIBO_CMS_URL, XIBO_CMS_KEY, XIBO_DISPLAY_NAME } = process.env;
if (!XIBO_CMS_URL || !XIBO_CMS_KEY || !XIBO_DISPLAY_NAME) {
  throw new Error('URL, chave e nome do display são obrigatórios');
}
const dir = path.join(os.homedir(), '.config/xiboplayer/chromium');
fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
const config = {
  cmsUrl: XIBO_CMS_URL,
  cmsKey: XIBO_CMS_KEY,
  displayName: XIBO_DISPLAY_NAME,
  allowShellCommands: false,
  preventSleep: false,
  relaxSslCerts: 'false'
};
fs.writeFileSync(path.join(dir, 'config.json'),
  JSON.stringify(config, null, 2) + '\n', { mode: 0o600, flag: 'wx' });
NODE
unset XIBO_CMS_KEY XIBO_CMS_URL XIBO_DISPLAY_NAME
```

Não ativar `set -x`, gravar a sessão ou imprimir variáveis privadas. O exemplo
não inclui a porta DevTools temporária, URLs de autorização ou logs de debug.
Em automação, usar o mecanismo de segredos do ambiente, não uma senha literal
no script. A configuração permanece fora do Git.

### Passo 6: instalar e iniciar a unidade de usuário

No Berry, verificar que a sessão gráfica pertence a `berry`:

```bash
systemctl --user show-environment | grep -E 'DISPLAY|WAYLAND_DISPLAY'
systemctl --user is-active graphical-session.target
mkdir -p /home/berry/.config/systemd/user
node --check /home/berry/xiboplayer-pilot/xiboplayer/stop-player.cjs
install -m 644 /home/berry/xiboplayer-pilot/xiboplayer/berry-xiboplayer.service \
  /home/berry/.config/systemd/user/berry-xiboplayer.service
systemd-analyze --user verify \
  /home/berry/.config/systemd/user/berry-xiboplayer.service
systemctl --user daemon-reload
systemctl --user enable --now berry-xiboplayer.service
```

Não usar `sudo systemctl --user`. Não definir `DISPLAY=:0` ou
`WAYLAND_DISPLAY=wayland-0` às cegas se o ambiente estiver ausente.
Investigar login gráfico, importação do ambiente e login automático do destino.
O arquivo de unidade usa o diretório pessoal via `%h` e não contém IP,
chave ou identidade do player; a identidade vem do `config.json`.

### Passo 7: autorizar, atribuir conteúdo e verificar

1. Aguardar o novo nome aparecer em Players no CMS.
2. Conferir que não está reutilizando o registro de outro Raspberry.
3. Editar o display, ativar `Authorizar display?` e salvar.
4. Selecionar um layout publicado como padrão e salvar.
5. Conferir no monitor ou Pi Connect que aparece o conteúdo desse layout.
6. Registrar nome, MAC, IP, versão e layout atribuído no inventário.

Os IDs `1` e `2` deste histórico pertencem ao piloto. Não fixar esses IDs
em scripts para outros CMS ou confundir ID do layout com ID do display.

### Passo 8: aceite obrigatório antes de expandir a frota

- Registro único, autorizado e atualizado no CMS.
- HTTP local 200 e conteúdo visível; não apenas processo em execução.
- Atualização de conteúdo pelo CMS, medida em pelo menos um ciclo de polling.
- Reprodução de imagens e vídeos usados na operação real.
- Reinício do Berry, entrada automática no desktop e retorno do player.
- Interrupção da rede/CMS e comportamento offline, sem apagar cache.
- `stop`, `start` e `restart`, verificando janela e processos a cada etapa.
- Pi Connect e SSH preservados, sem porta DevTools exposta.
- Alimentação estável e ausência de novos alertas de subtensão.

Registrar data, resultado e falhas por dispositivo. Não marcar como aprovado
um teste que não foi executado. Essas verificações adicionais ainda não foram
concluídas no piloto original.

### Correção do ciclo de vida do Chromium

Após o piloto, o operador executou `stop`, mas a janela permaneceu aberta.
A inspeção confirmou `MainPID=0`, serviço em `failed` e Chromium órfão com o
perfil do Xibo. O contorno aplicado foi parar a unidade, encerrar somente o
processo principal confirmado desse perfil e executar `reset-failed`.
Depois foram confirmados `inactive/dead` e ausência dos processos do perfil.

O contorno inicial foi manual. Depois, com autorização do operador, foi
implementada uma correção no pacote de implantação deste repositório.

Causa confirmada em `/proc/PID/cgroup`: o Chromium cria seu próprio
`app-org.chromium.Chromium-PID.scope`, fora do cgroup da unidade Xibo.
Encerrar apenas os processos da unidade não é suficiente.
Neste Chromium, `/proc/PID/cmdline` também pode conter um título de processo
reescrito como texto único, em vez dos argumentos separados por NUL.

Correção, sem patch no código upstream:

- `stop-player.cjs` inspeciona `/proc` e seleciona somente processos do usuário
  atual, com executável Chromium/Chrome e o perfil exato
  `~/.local/share/xiboplayer/chromium`.
- Reconhece argumentos normais e o título de processo reescrito, sem aceitar
  um sufixo de perfil ou o perfil de outro usuário como correspondência.
- Confere novamente a identidade e o instante de criação do PID antes de
  enviar sinais, reduzindo o risco de sinalizar um PID que foi reutilizado.
- Primeiro envia SIGTERM ao navegador principal e aguarda até cinco segundos.
  Se necessário, envia SIGKILL somente aos processos restantes desse perfil
  e aguarda mais dois segundos. Falha se eles continuarem detectados.
- A unidade chama o helper por `ExecStop` e `ExecStopPost`.
- `KillMode` mudou de `mixed` para `control-group`; o helper cobre o scope
  separado do navegador e o systemd encerra os demais processos da unidade.
- `TimeoutStopSec` mudou de 15 para 30 segundos.

O helper é obrigatório: transferi-lo e instalá-lo antes da unidade atualizada.
Não copiar apenas o `.service` para outro Raspberry.
O caminho do perfil é calculado pelo home do usuário; o script não aceita
um alvo arbitrário por argumento e não usa `killall chromium`.

O teste da unidade antiga reproduziu `stop` deixando o navegador aberto.
Também foram executados nove casos de seleção de perfil, incluindo formatos
normais, título reescrito e rejeição de perfis diferentes.
Os resultados do teste de ciclo de vida no dispositivo devem acompanhar
cada implantação; reboot e operação prolongada permanecem etapas separadas.

Validação executada no Berry 01 em 19/10/2026:

| Teste | Resultado |
| --- | --- |
| `start` → navegador em scope separado → `stop` | Sem processos do perfil |
| `start` → `restart` | PID principal novo, sem reutilizar o anterior |
| `stop` após o reinício | `inactive/dead`, `Result=success`, sem navegador |

O teste terminou com `LIFECYCLE_PASS` e o player foi deixado parado.
Isso não comprova os testes separados de reboot, offline ou vídeo.

No Berry 01, foi preservada a unidade anterior como
`berry-xiboplayer.service.before-profile-stop`, no diretório
`/home/berry/.config/systemd/user/`. Esse backup contém a falha conhecida;
só reverter para ele durante diagnóstico controlado, depois de parar
e confirmar o encerramento do player.

### O que foi e não foi modificado

- Nenhum patch no código-fonte do Xibo CMS ou do player upstream.
- Dashboard do CMS alterado conforme o inventário completo abaixo.
- `package.json` e lockfile do clone alterados para fixar dependências.
- `config.json` privado e unidade systemd de usuário criados pelo agente.
- Processos órfãos encerrados manualmente, restritos ao perfil do piloto.
- Helper de encerramento e referências `ExecStop`/`ExecStopPost` adicionados
  neste repositório e implantados no Berry 01, sem modificar o upstream.

## Resultado verificado

O Berry 01 registrou-se no CMS, recebeu autorização e reproduziu o layout
`Berry 01 - Teste Xibo`. A captura do desktop confirmou o texto
“Berry 01 / Conteúdo enviado pelo Xibo CMS / Teste de conexão e reprodução”.

O teste usa um widget HTML de 400 × 600 pixels, posicionado em um layout
1920 × 1080; as áreas pretas ao redor são esperadas neste layout de teste.
Não foi feita validação prolongada, de vídeo ou de recuperação após reboot.

## Ambiente

| Componente | Identificação |
| --- | --- |
| CMS | Docker neste PC, imagem `ghcr.io/xibosignage/xibo-cms:release-4.5.3` |
| Painel local | `http://localhost:8080` |
| CMS acessível pelo Berry | `http://172.20.69.241:8080` |
| Placa física | Berry 01, MAC Wi-Fi `e4:5f:01:35:b8:2d` |
| IP do Berry | `172.20.111.237` |
| Usuário Linux | `berry` |
| Nome cadastrado no CMS | `berry-tv-campus-01` |
| Player | Comunitário, `xiboplayer/xiboplayer-chromium` |
| Código clonado | `/home/berry/xiboplayer-pilot`, tag `v0.7.22` |
| SDK efetivo | `@xiboplayer/proxy@0.7.15` e `@xiboplayer/pwa@0.7.15` |
| Serviço de usuário | `berry-xiboplayer.service` |

O IP deste PC pode mudar. O Berry precisa alcançar esse endereço e porta;
`localhost` no Raspberry aponta para o Raspberry, não para o PC do CMS.
Não foi necessário alterar firewall, switches, DHCP ou reservas neste piloto.
O Berry 02 e seu Anthias não foram alterados.

## Todas as alterações manuais no dashboard do CMS

As alterações abaixo foram feitas pelo Playwright, usando a conta indicada
em `.env`. Nenhuma credencial deve ser copiada para este documento.

### Administração → Configurações → Configurações

| Campo | Antes no formulário | Depois |
| --- | --- | --- |
| Localização Biblioteca | Vazio | `/var/www/cms/library/` |
| Chave de conexão com o servidor | Vazia | Nova chave gerada; valor omitido |

A biblioteca aponta para o volume Docker gravável por `www-data`.
A chave permite autenticar o player com o CMS.

A primeira tentativa de salvar a chave falhou porque o diretório da biblioteca
estava vazio. A mensagem foi “O diretório da biblioteca não esta com permissão
de escrita”. Após preencher o caminho existente, a configuração foi salva.
Não foi necessário executar `chmod` ou `chown` no container.

A chave também foi armazenada no arquivo privado de configuração do player,
com permissão `600`, no Raspberry. Ela é diferente da senha de login do painel.

### Administração → Configurações → Rede

| Campo | Antes | Depois |
| --- | --- | --- |
| Tipo de download de arquivo (`SENDFILE_MODE`) | `Off` | `Apache` |

Antes da alteração, a resposta `RequiredFiles` informava `httpDownloads="0"`
e downloads por XMDS. Depois passou a informar `httpDownloads="1"`.
O código do CMS associa downloads HTTP a `SENDFILE_MODE != Off`.

Antes de selecionar `Apache`, foram confirmados no container:

- Módulo `xsendfile_module` carregado.
- `XSendFile on` na configuração do site Apache.
- `XSendFilePath /var/www/cms/library` já configurado.

Foi alterado somente o campo no dashboard; a configuração do Apache não foi
editada. HTTPS, STS, proxy de rede e limites de armazenamento não foram
alterados.

### Players → Definições do Player → Linux → Rede

| Campo | Antes | Depois |
| --- | --- | --- |
| Inicial Update (`downloadStartWindow`) | `00:00` | `00:00`, mantido |
| Final Update (`downloadEndWindow`) | `00:00` | `23:59` |

Este foi o bloqueio decisivo observado no log:

```text
Outside download window, skipping downloads (next: 00:00:00)
```

O player interpreta início e fim iguais como janela vazia, não como 24 horas.
Foi usado o seletor de horário do dashboard: hora `23`, minuto `59`,
`Aplicar` e depois `Salvar`. O campo é somente leitura e não aceita digitação.

A alteração é no perfil Linux, portanto também afeta futuros players que
usem esse perfil. Entre 23:59 e 00:00 há um minuto fora da janela de downloads.
Não foi modificado o horário de funcionamento do display.

### Players → Players → berry-tv-campus-01 → Editar → Geral

- O registro foi criado automaticamente pelo player; não por cadastro manual.
- `Authorizar display?`: alterado de `Off` para `On` e salvo.
- `Layout padrão`: salvo com o layout de teste, depois renomeado para
  `Berry 01 - Teste Xibo`.
- Nome do player: `berry-tv-campus-01`.
- ID observado do display: `1`.
- O IP mostrado pelo CMS foi `172.21.0.1`, endereço visto através do Docker;
  não é o endereço SSH do Raspberry.

### Design → Layouts

Foi criado um único layout para comprovar o fluxo CMS → player:

- Nome inicial automático: `Sem título 2026-10-19 14:25:58`.
- Nome final: `Berry 01 - Teste Xibo`.
- ID de gerenciamento: `1`; o XMDS passou a entregar o layout publicado `2`.
- Resolução: 1920 × 1080, paisagem.
- Widget: `HTML (Embedded)`.
- Posição observada: esquerda `309`, topo `118`.
- Tamanho observado: largura `400`, altura `600`.
- Duração observada: 60 segundos.
- HTML de teste inserido pelo editor:

```html
<main style="height:100vh;display:flex;align-items:center;justify-content:center;background:#12334b;color:white;font-family:sans-serif;text-align:center">
  <div>
    <h1>Berry 01</h1>
    <p>Conteúdo enviado pelo Xibo CMS</p>
    <p>Teste de conexão e reprodução</p>
  </div>
</main>
```

Publicação: menu superior do designer → `Salvar Alterações` → confirmar
`Salvar Alterações` com publicação imediata. O status final foi `Published`.
Não foi criado um evento de agendamento: a reprodução usa o layout padrão.

### Consultas no dashboard que não alteraram configurações

Foram consultados Dashboard, Players, Layouts, Log e as abas de Configurações.
Também foram usados os botões `Atualizar` e `Apply Filter` para diagnóstico.
Não foram criados usuários, aplicações OAuth, comandos remotos ou campanhas.

## Instalação e alterações no Raspberry

### Dependências e código

Foram instalados `nodejs` e `npm` pelo APT, sem recomendações. `git`, `jq`
e Chromium já estavam presentes. O APT instalou as dependências desses pacotes;
não foi executado upgrade geral, autoremove ou reinstalação do sistema.

```bash
sudo apt-get install -y --no-install-recommends nodejs npm
git clone --depth 1 --branch v0.7.22 --recurse-submodules \
  https://github.com/xiboplayer/xiboplayer-chromium.git \
  /home/berry/xiboplayer-pilot
cd /home/berry/xiboplayer-pilot/xiboplayer/server
npm install --omit=dev --ignore-scripts --no-audit --no-fund
```

O repositório Debian indicado no README retornou HTTP 404 em
`https://dl.xiboplayer.org/deb/xibo-players.sources`. Nenhum repositório APT
comunitário foi adicionado; foi usada a execução a partir do clone.

### Alinhamento de versões

Na instalação inicial, `@xiboplayer/pwa@0.7.22` continha uma interface
compilada que se identificava como SDK `0.7.15`. Também foram observados
formatos diferentes de acesso ao cache entre os componentes.

Para reduzir essa incompatibilidade, os pacotes foram fixados:

```bash
cd /home/berry/xiboplayer-pilot/xiboplayer/server
npm install --save-exact --ignore-scripts --no-audit --no-fund \
  @xiboplayer/proxy@0.7.15 @xiboplayer/pwa@0.7.15
```

Isso alterou `package.json` e `package-lock.json` nesse clone no Raspberry.
O checkout do wrapper continua em `v0.7.22`; não confundir com a versão efetiva
do SDK. A tag `v0.7.15` também foi buscada com `git fetch` para comparação.
O `server.js` entre essas duas tags diferia somente no texto do cabeçalho.
Não foi aplicado patch ao código do player.

O alinhamento de versões, isoladamente, não resolveu a tela preta: só depois
da correção da janela de downloads o log confirmou download e reprodução.

### Configuração privada do player

Arquivo: `/home/berry/.config/xiboplayer/chromium/config.json`, permissão `600`.

| Propriedade | Valor/configuração |
| --- | --- |
| `cmsUrl` | `http://172.20.69.241:8080` |
| `cmsKey` | Chave do CMS, omitida deste documento |
| `displayName` | `berry-tv-campus-01` |
| `allowShellCommands` | `false` |
| `preventSleep` | `false`, solicitado na configuração |
| `relaxSslCerts` | String `"false"`, para não ignorar erros de certificado |
| `extraBrowserFlags` | Diagnóstico temporário descrito abaixo |

A string `"false"` em `relaxSslCerts` foi usada porque o carregador do wrapper
usa `jq ... // empty`, que pode tratar o booleano `false` como ausente.
O mesmo detalhe exige revisar se `preventSleep: false` é respeitado pelo
wrapper.

### Início automático

Foi instalado o serviço de usuário a partir de
[`berry-xiboplayer.service`](../xiboplayer-chromium/xiboplayer/berry-xiboplayer.service)
, em:

```text
/home/berry/.config/systemd/user/berry-xiboplayer.service
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now berry-xiboplayer.service
```

O serviço usa `graphical-session.target`, executa o wrapper com `--server-dir`
apontando para o clone e tem `Restart=always`. A versão inicial do serviço usava
`Restart=on-failure`; foi alterada para recuperar também saídas normais do
Chromium.

Durante os testes, uma instância antiga do Chromium permaneceu aberta com o
perfil do piloto. Ela foi encerrada com SIGTERM, restrito a esse perfil,
para evitar que um novo processo reutilizasse a instância anterior.
Esse incidente levou à inclusão de `stop-player.cjs` na unidade de usuário,
conforme a seção de correção do ciclo de vida acima.

### Diagnóstico temporário ainda presente

No momento deste registro, `extraBrowserFlags` contém:

```text
--remote-debugging-port=9222 --remote-debugging-address=127.0.0.1
```

A porta foi confirmada em `127.0.0.1:9222`, não na rede externa. Foi usada
para consultar logs, respostas XMDS e estado da página pelo Chrome DevTools
Protocol. Remover esses flags e reiniciar o serviço após concluir o piloto.
Não deixar a porta aberta em `0.0.0.0`.

Também foi aberta a página local com `?logLevel=INFO` para diagnosticar a
reprodução. Esse nível foi usado para observar o bloqueio da janela de
downloads.
Não armazenar logs completos que possam conter a chave do CMS ou URLs assinadas.

## Evidências e limitações

Após as correções, os logs registraram:

```text
Download complete: player/api/v2/media/file/bundle.min.js
Layout 2 ready
Status: Playing layout 2
All widgets ready — starting layout timer
```

A captura foi obtida com `grim` no desktop Wayland e copiada para
`docs/evidencias/berry-xibo-pilot.png`. Ela confirma a reprodução do HTML pelo
Chromium.
O HDMI foi detectado em 1920 × 1080 a 60 Hz durante o piloto.

Ainda foram observados:

- `fonts.css` com tamanho zero no CMS e HTTP 404 ao baixar; não impediu o teste.
- Falhas não críticas de `GetWeather` e geolocalização; não utilizadas pelo
  layout.
- `vcgencmd get_throttled` retornando `0x50005`, indicando subtensão ativa e
  throttling. Corrigir fonte/cabo de alimentação antes de operação contínua.
- Reprodução offline, reinício do Raspberry e atualização de layout ainda
  precisam de validação específica.
- XMR não foi configurado nem validado. Atualização imediata por push não foi
  comprovada; não confundir registro/polling XMDS com funcionamento do XMR.

## Operação e rollback do piloto

### Entrar no Raspberry

Entrar pelo PowerShell deste PC:

```powershell
ssh -J USUARIO_DHCP@SERVIDOR_DHCP berry@172.20.111.237
```

No Raspberry, sempre como `berry`, sem `sudo` para o serviço de usuário:

```bash
whoami
hostname
```

O usuário deve ser `berry`. Não executar os comandos `systemctl --user`
como `root`: eles precisam controlar a sessão gráfica do usuário correto.

### Parar, iniciar e reiniciar o player

```bash
# Parar a reprodução
systemctl --user stop berry-xiboplayer.service

# Iniciar a reprodução
systemctl --user start berry-xiboplayer.service

# Reiniciar depois de uma alteração ou para recuperar o player
systemctl --user restart berry-xiboplayer.service

# Consultar o estado e as mensagens recentes
systemctl --user status berry-xiboplayer.service
systemctl --user is-active berry-xiboplayer.service
```

`active` confirma que o serviço está executando, mas não comprova sozinho que
o conteúdo apareceu no monitor. Conferir também a tela e o status no CMS.

`stop` interrompe o serviço até um novo `start` ou ativação da sessão gráfica.
Não desativa seu início automático. Apesar de `Restart=always`, um `stop`
explícito não deve provocar reinício automático pelo systemd.

### Controlar o início automático

Para desativar o início automático e parar agora, sem apagar arquivos:

```bash
systemctl --user disable --now berry-xiboplayer.service
```

Para reativar o início automático e iniciar agora:

```bash
systemctl --user enable --now berry-xiboplayer.service
systemctl --user is-enabled berry-xiboplayer.service
```

O resultado esperado é `enabled`. O serviço está vinculado à sessão gráfica,
não apenas à inicialização do Linux. O início após reboot depende de o desktop
do usuário `berry` iniciar, normalmente pelo login automático já existente.
Esse ciclo completo de reboot ainda não foi validado no piloto.

Depois de editar o arquivo `.service`, recarregar e reiniciar:

```bash
systemctl --user daemon-reload
systemctl --user restart berry-xiboplayer.service
```

Depois de editar somente o `config.json` privado, basta reiniciar o serviço.
Não exibir esse JSON em capturas ou logs, pois contém a chave do CMS.

### Se o Chromium continuar aberto após parar

Com a unidade corrigida, isso é uma regressão a investigar, não o procedimento
normal de parada. Conferir primeiro se os dois artefatos foram implantados:

```bash
systemctl --user cat berry-xiboplayer.service
node --check /home/berry/xiboplayer-pilot/xiboplayer/stop-player.cjs
```

Devem existir `ExecStop` e `ExecStopPost` apontando para o helper e
`KillMode=control-group`. Depois de atualizar a unidade, executar
`systemctl --user daemon-reload`. Não iniciar outra instância enquanto
o navegador anterior continuar aberto.

Para aplicar manualmente o mesmo encerramento restrito ao perfil:

```bash
systemctl --user stop berry-xiboplayer.service
node /home/berry/xiboplayer-pilot/xiboplayer/stop-player.cjs
systemctl --user reset-failed berry-xiboplayer.service
```

O helper funciona mesmo com a unidade já inativa e Chromium órfão. Para
verificar com o mesmo filtro de identidade, sem imprimir argumentos privados:

```bash
node <<'NODE'
const os = require('node:os');
const path = require('node:path');
const helper = require(path.join(os.homedir(),
  'xiboplayer-pilot/xiboplayer/stop-player.cjs'));
const profile = path.join(os.homedir(), '.local/share/xiboplayer/chromium');
const remaining = helper.findProcesses(profile);
console.log(remaining.map(target => ({ pid: target.pid, main: target.main })));
process.exitCode = remaining.length ? 1 : 0;
NODE
```

O resultado esperado após parar é `[]` e código de saída zero.
Se o helper estiver ausente ou falhar, o procedimento manual abaixo é
somente contingência:

Se a janela do Chromium persistir, verificar se pertence ao perfil
`/home/berry/.local/share/xiboplayer/chromium` antes de encerrá-la.
Não matar indiscriminadamente outros navegadores ou serviços do usuário.

```bash
systemctl --user stop berry-xiboplayer.service
ps -eo pid,ppid,args | grep '[c]hromium.*xiboplayer/chromium'
```

Conferir o PID do processo principal cujo argumento `--user-data-dir` aponta
exatamente para o perfil acima. Somente depois de confirmar o PID:

```bash
kill -TERM PID_CONFIRMADO
```

`PID_CONFIRMADO` é um marcador: substituir pelo número verificado, sem copiar
PIDs antigos deste histórico. Não usar `killall chromium`.
Para voltar a reproduzir, executar `systemctl --user start` conforme acima.

### Diagnóstico rápido

No Berry, verificar serviço, servidor web local e conectividade com o CMS:

```bash
systemctl --user status berry-xiboplayer.service --no-pager -l
curl -I --connect-timeout 5 http://localhost:8766/player/
curl -I --connect-timeout 5 http://172.20.69.241:8080/login
kmsprint
vcgencmd get_throttled
```

O player local deve responder HTTP 200. O CMS deve responder sem timeout;
uma página de login acessível não significa que o player esteja autorizado.
Em `kmsprint`, conferir uma saída HDMI conectada e um modo de vídeo ativo.
`throttled=0x0` indica ausência dos alertas de alimentação e throttling
representados por essa consulta; `0x50005` exige revisar fonte e cabo.

Para consultar logs, quando disponíveis ao usuário:

```bash
journalctl --user -u berry-xiboplayer.service -n 50 --no-pager
```

No piloto, essa consulta chegou a retornar `No journal files were found`.
Isso não prova que o serviço esteja parado. Usar também
`systemctl --user status`.
Se necessário, consultar o journal do sistema com `sudo` interativo:

```bash
sudo journalctl -b _UID=1000 \
  _SYSTEMD_USER_UNIT=berry-xiboplayer.service -n 50 --no-pager
```

O UID observado de `berry` foi `1000`; conferir com `id -u` antes de reutilizar
esse filtro em outro dispositivo. Não publicar logs brutos: eles podem incluir
chaves, configurações privadas ou URLs assinadas.

No painel `http://localhost:8080`, conferir:

1. Players → `berry-tv-campus-01`: autorizado e com layout padrão correto.
2. Design → Layouts: layout publicado, não apenas salvo como rascunho.
3. Perfil Linux → Rede: janela de download `00:00` até `23:59`.
4. Configurações → Rede: tipo de download `Apache`.
5. O PC com Docker continua ligado e com o mesmo IP configurado no player.

Não reinstalar o player, limpar seu cache ou atualizar pacotes como primeira
tentativa: primeiro localizar a falha com as verificações acima.

### Raspberry Pi Connect para acesso remoto ao desktop

O Pi Connect é independente do serviço Xibo. Para ativar e consultar:

```bash
rpi-connect on
rpi-connect status
```

Se aparecer `Signed in: no`, iniciar a vinculação:

```bash
rpi-connect signin
```

Abrir a URL de verificação gerada e autorizar na conta Raspberry Pi.
Não reutilizar URLs antigas nem registrá-las permanentemente neste arquivo.
Depois de autorizar, confirmar novamente com `rpi-connect status`.
Se necessário, executar `rpi-connect doctor` para diagnosticar a conexão.

Na reativação realizada após o piloto, o serviço iniciou, mas a autorização
da conta ainda dependia da confirmação do operador no navegador.
Não confundir “serviço iniciado” com “conta vinculada”.

### Reverter o piloto

Antes de reverter alterações do CMS, verificar se outros players já dependem
delas. Em especial, não trocar a chave de conexão sem atualizar seus clientes.
Não é necessário remover a biblioteca, apagar o layout ou excluir o display
para simplesmente interromper o piloto.

## Referências

- [Player comunitário e instalação](https://github.com/xiboplayer/xiboplayer-chromium)
- [Configuração do player](https://github.com/xiboplayer/xiboplayer-chromium/blob/main/CONFIG.md)
- [Guia do projeto comunitário](https://www.xiboplayer.org/docs/getting-started/quick-start)

Este player não é o player oficial mantido pela Xibo Signage. Não atualizar
CMS ou SDK sem repetir o teste de compatibilidade no Berry 01.
