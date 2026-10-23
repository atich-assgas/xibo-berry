# Alterações para os Berries

Este clone é a fonte única do player adaptado. Base upstream: tag `v0.7.22`,
commit `9e843c02caf1a6b2f708bda11a6fa84ffd36bd55`.
As alterações locais precisam ser versionadas no Git deste clone antes de
distribuir por um remoto; clonar apenas a tag pública não as inclui.

## Correções integradas

- `xiboplayer/server/package.json` e `package-lock.json`: proxy e PWA fixos
  em `0.7.15`, conforme o piloto. Os manifestos PWA e lockfiles pnpm
  legados foram removidos; usar npm no diretório `xiboplayer/server/`.
- `xiboplayer/stop-player.cjs`: encerra somente Chromium do usuário atual
  com o perfil exato do player. Confere identidade do processo antes de
  sinalizar, tenta SIGTERM e usa SIGKILL apenas como fallback.
- O diretório de dados respeita `XDG_DATA_HOME`, como o launcher.
- `xiboplayer/xiboplayer-chromium.service`: executa a limpeza na parada e
  após a parada, inclusive quando Chromium escapou para outro escopo systemd.
- `xiboplayer/berry-xiboplayer.service`: unidade para executar diretamente
  de `%h/xiboplayer-pilot`, sem copiar helpers para fora do projeto.
- DEB e RPM incluem o helper e instalam dependências pelo lockfile com `npm ci`.
  Os pacotes de fontes também levam o helper e o lockfile.

Não foram alterados o código do CMS, a rede dos Berries ou suas instalações
em execução. Ajustes do dashboard continuam documentados no guia operacional.

## Testes

Na pasta deste clone:

```bash
node --test tests/*.test.cjs
bats tests/launch-kiosk.bats
bash -n build-deb.sh build-rpm.sh xiboplayer/launch-kiosk.sh
```

A suíte Node não exige Chromium nem sinaliza processos reais: verifica a
seleção de perfis e simula a fronteira `/proc` para testar a parada com
segurança. A suíte Bats requer Bash, Bats e jq. O CI executa ambas.
O helper é Linux; testes locais no Windows não substituem o teste visual
de start, stop, restart e reboot em um Berry de homologação.

O helper das unidades fornecidas atende à instância padrão `chromium`.
Não reutilizar essas instruções de parada para `--instance=NAME`: instâncias
nomeadas exigem uma unidade e um encerramento específicos para seu perfil.

## Deploy

Seguir [o guia dos Berries](../docs/XIBO-CHROMIUM-BERRY-01.md), que transfere
esta árvore de código. Não copiar `.env`, caches ou perfis Chromium.
O serviço antigo de um Berry já instalado continua igual até um deploy
explícito; a reorganização local não o atualiza.

Os scripts upstream de empacotamento dependem de `scripts/packaging/`, que
não veio nesta tag clonada. É necessário obter as bibliotecas upstream
compatíveis ou fornecer `PKG_LIB_DEB`/`PKG_LIB_RPM` antes de gerar pacotes.
Builds DEB/RPM devem ser validados no Linux antes da distribuição.
