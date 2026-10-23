# Operação DHCP

## Automação planejada

O [plano da CLI](../PLANO-FLASH-RASPBERRIES.md) integra a entrada dos Berries
na rede ao fluxo de flash e deploy. A preparação é separada da aplicação:
descobrir o MAC Wi-Fi real, obter a configuração atual, preparar a reserva,
validar e revisar o diff. Só então pedir confirmação para aplicar e reiniciar.
A CLI não foi implementada; os procedimentos manuais abaixo continuam válidos.
Validar também IP efetivo, rota Wi-Fi, DNS, HTTPS, CMS e SSH direto ou via salto.
Não presumir que uma reserva libere Internet ou comunicação entre VLANs.

## Repositório de infraestrutura

Os artefatos de infraestrutura permanecem no repositório anterior:

`C:\Users\Administrador\Desktop\projetos\ti`

Antes de executar comandos DHCP:

```powershell
Set-Location "C:\Users\Administrador\Desktop\projetos\ti"
```

## Consulta de conexões

O script somente leitura está neste projeto. Ele usa `DHCP_USERNAME`,
`DHCP_PASSWORD` e `DHCP_SERVER` de um `.env` seguro:

```powershell
Set-Location "C:\Users\Administrador\Desktop\projetos\berry"
.\scripts\dhcp\listar-conexoes-dhcp.ps1 -EnvFile ".\.env" -Hostname "berry-02" -Horas 2
```

O módulo `Posh-SSH` precisa estar instalado. O parâmetro `-Hostname` filtra o
dispositivo; `-Horas` aceita valores entre 1 e 168.

Para atualizar o estado dos Berries sem alterar nada, execute o script somente
leitura e envie a saída para atualização do `BERRIES.md`:

```powershell
.\scripts\dhcp\atualizar-estados-berries.ps1 -EnvFile ".\.env" -Horas 2
```

Para procurar um Berry específico:

```powershell
.\scripts\dhcp\atualizar-estados-berries.ps1 -EnvFile ".\.env" -Hostnames "berry-02" -Horas 2
```

## Alterações de configuração

Para editar, formatar, validar ou aplicar `dhcpd.conf`, siga primeiro:

- `C:\Users\Administrador\Desktop\projetos\ti\README.md`
- `C:\Users\Administrador\Desktop\projetos\ti\iscdhcp\README.md`

Use `$uffs-dhcp-operator` para o fluxo. Obtenha sempre a configuração atual do
servidor antes de inspecionar ou editar, crie backup local, altere somente o
escopo solicitado, formate, valide localmente e revise o diff completo.

No Posh-SSH instalado, envie o arquivo assim:

```powershell
Set-SCPItem -ComputerName $DHCP_SERVER -Credential $credential -Path $localConfig -Destination /tmp -NewName dhcpd.conf -AcceptKey -Force
```

O Posh-SSH instalado não possui o parâmetro `-PathType`; não o inclua.

No servidor, use um shell SSH interativo para executar `sudo`;
`Invoke-SSHCommand` sem terminal não funciona. Valide
`/etc/dhcp/dhcpd.conf.test` com `dhcpd -t`. Se a validação passar e o diff
tiver somente a mudança solicitada, pare e pergunte ao usuário se deseja aplicar
a configuração e reiniciar `isc-dhcp-server`. Não reinicie automaticamente.

## Convenção para reservas das TVs

Mantenha todas as reservas dos Berries entre os marcadores
`# INICIO_BERRIES_TVS_CAMPUS` e `# FIM_BERRIES_TVS_CAMPUS`. Cada TV deve ter um
divisor individual no formato abaixo, para facilitar a localização com `grep`:

```text
# --- berry-tv-campus-01 | TV do campus | 172.20.111.237 ---
host berry-tv-campus-01 {
  fixed-address 172.20.111.237;
  hardware ethernet aa:bb:cc:dd:ee:ff;
}

# --- berry-tv-campus-02 | TV do campus | 172.20.111.238 ---
host berry-tv-campus-02 {
  fixed-address 172.20.111.238;
  hardware ethernet aa:bb:cc:dd:ee:ff;
}
```

Use uma linha `# ---` por Berry, incluindo o identificador, a TV/local e o IP
reservado. Não reutilize IP ou MAC de outro item e revise o diff para confirmar
que somente o item solicitado foi alterado.

Não copiar para este projeto `dhcpd.conf`, leases, logs de produção ou
credenciais.

Para comandos executados nos Raspberry Pis, consulte `BERRY-SSH-OPERACAO.md`.
