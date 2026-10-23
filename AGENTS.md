# Instruções operacionais do projeto berry

Este projeto documenta Raspberry Pis usados como players de sinalização digital.

## Antes de trabalhar

- Leia `README.md`, `docs/BERRIES.md` e, quando aplicável,
  `docs/raspberry-pi-connect-passo-a-passo.md`.
- Para qualquer tarefa DHCP, use `$uffs-dhcp-operator`, leia `docs/DHCP.md` e
  trabalhe no repositório `C:\Users\Administrador\Desktop\projetos\ti`.
- Para otimizar este arquivo ou outro arquivo de contexto, use
  `$agents-md-optimizer`.
- Sempre valide os arquivos Markdown alterados com a extensão Markdownlint do VS
  Code antes de concluir a tarefa; use o CLI `markdownlint` quando estiver
  disponível.

## Regras não negociáveis

- Consultas DHCP são somente leitura por padrão; não editar, aplicar ou
  reiniciar sem solicitação explícita.
- Nunca remover ou alterar leases, reservas ou dispositivos fora do escopo.
- Antes de alterar `dhcpd.conf`, obter a versão atual do servidor, criar
  backup, formatar, validar com `dhcpd -t` e revisar o diff completo.
- Depois de `dhcpd -t` passar, perguntar explicitamente se o usuário quer
  aplicar a configuração e reiniciar `isc-dhcp-server`.
- Não registrar senhas, tokens, chaves privadas ou conteúdo de `.env`; não usar
  `root` diretamente no SSH quando houver conta individual.

## Gotchas e convenções

- Caminhos legados na skill DHCP: os scripts agora estão em `scripts/dhcp/`
  e os guias em `docs/`; adapte os caminhos sem alterar o fluxo da skill.

- “Está no DHCP” significa presença no `dhcpd.conf` atual do servidor, não
  apenas lease ativo ou histórico.
- O upload Posh-SSH usa `-Destination /tmp -NewName dhcpd.conf`; esta
  instalação não possui `-PathType`.
- `sudo` no servidor exige `New-SSHShellStream` com
  `Invoke-SSHStreamExpectSecureAction`; nunca inserir senha em comandos ou
  logs.
- Comandos enviados ao servidor são Linux: use `grep`, `tail` e `systemctl`,
  não cmdlets PowerShell.
- O `.env` privado deste projeto reúne as variáveis locais; não alterar o
  `.env` independente do repositório `ti`. Scripts de consulta aceitam
  `-EnvFile`, `-Hostname` e `-Horas` de 1–168.
- IPs DHCP são temporários; confirme `docs/BERRIES.md` e a configuração atual
  antes de conectar. SSH direto é preferível ao salto pelo servidor DHCP.
- Comandos no Berry devem seguir `docs/BERRY-SSH-OPERACAO.md`: entrar pelo IP
  Ethernet, usar `sudo` em terminal interativo e renovar o perfil Wi-Fi por
  UUID; não apagar um perfil Wi-Fi que já esteja funcionando.
