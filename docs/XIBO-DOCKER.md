# Xibo CMS no Docker

O Compose é o serviço principal e fica na raiz do projeto.
As variáveis são descritas em [Configuração privada](CONFIGURACAO.md).

| Caminho              | Finalidade                                |
| -------------------- | ----------------------------------------- |
| `docker-compose.yml` | Serviços do CMS, banco e auxiliares       |
| `.env`               | Configuração privada, ignorada pelo Git   |
| `.example.env`       | Modelo sem credenciais reais              |
| `shared/`            | Banco, biblioteca e arquivos persistentes |

Execute na raiz do repositório:

```powershell
docker compose config --quiet
docker compose up -d
docker compose ps
docker compose stop
docker compose start
```

Interface: <http://localhost:8080>. O Berry deve usar o IP ou DNS deste
computador, nunca `localhost`.

O nome do projeto Compose é explicitamente `xibo`, preservando a identidade
dos containers e da rede usados antes da reorganização. Os bind mounts agora
partem de `./shared/`, na raiz. Não rodar o Compose antigo em paralelo.

Na migração de `xibo/` para a raiz, parar os serviços antes de mover `shared/`
e recriar os containers para atualizar os bind mounts. Não copiar arquivos
MySQL com o banco em execução. Não usar `down -v`, apagar `shared/` ou
sobrescrever `.env` para resolver problemas de inicialização.

Para backup consistente, usar dump do banco e cópia da biblioteca conforme
o procedimento de administração do CMS; mover pastas não substitui backup.
As configurações do dashboard e o deploy dos players estão no
[guia operacional](XIBO-CHROMIUM-BERRY-01.md).
