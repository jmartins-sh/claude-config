# claude-config

Configuração pessoal do [Claude Code](https://code.claude.com), portável entre Windows, Linux e macOS.

O repositório tem duas funções:

1. **Marketplace de plugins.** O plugin `jmartins-tools` reúne skills, agents, commands e hooks próprios. O Claude Code o instala e o atualiza sozinho.
2. **Configuração de usuário.** `config/settings.json` e `config/CLAUDE.md` guardam as preferências portáveis. Os scripts de instalação mesclam esses arquivos com a configuração local de `~/.claude`.

> **Atenção:** este repositório é público. Não versione credenciais, tokens, o bloco `autoMode` nem detalhes internos de empresa ou de projetos.

## Estrutura

```
claude-config/
├── .claude-plugin/
│   └── marketplace.json          # transforma o repositório em marketplace "jmartins-sh"
├── plugins/
│   └── jmartins-tools/           # plugin próprio
│       ├── .claude-plugin/
│       │   └── plugin.json
│       └── skills/
│           └── config-sync/      # /jmartins-tools:config-sync
├── config/
│   └── settings.json             # preferências portáveis (mescladas em ~/.claude/settings.json)
├── skills.json                   # skills de terceiros instaladas via `npx skills`
├── install.ps1                   # instalação no Windows
└── install.sh                    # instalação no Linux e no macOS
```

## Instalação em uma máquina nova

Pré-requisitos: Git, Claude Code e acesso SSH ao GitHub. Para instalar as skills de `skills.json`, também é preciso Node.js (`npx`). No Linux e no macOS, o script usa ainda o `jq`.

**Windows (PowerShell):**

```powershell
git clone git@github.com:jmartins-sh/claude-config.git $HOME\code\claude-config
cd $HOME\code\claude-config
.\install.ps1 -DryRun   # mostra o resultado sem alterar nada
.\install.ps1
```

Se o PowerShell bloquear o script, rode `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

**Linux / macOS:**

```bash
git clone git@github.com:jmartins-sh/claude-config.git ~/code/claude-config
cd ~/code/claude-config
./install.sh --dry-run
./install.sh
```

Em seguida, abra o Claude Code. Ele lê `enabledPlugins` e `extraKnownMarketplaces` e instala os plugins.

### O que os scripts fazem

| Etapa | Comportamento |
|-------|---------------|
| `settings.json` | Mescla `config/settings.json` com `~/.claude/settings.json`. Objetos são mesclados recursivamente, listas ganham os itens que faltam e valores simples do repositório prevalecem. **Chaves que só existem na máquina, como `autoMode`, são preservadas.** |
| `CLAUDE.md` | Se `config/CLAUDE.md` existir, copia o arquivo para `~/.claude/CLAUDE.md`. |
| Skills de terceiros | Instala cada item de `skills.json` com `npx skills add` e pula as skills que já estão instaladas. |
| Segurança | Antes de alterar um arquivo, grava uma cópia em `~/.claude/backups/<arquivo>.<data>.bak`. |

A variável `CLAUDE_CONFIG_DIR` muda o diretório de destino, o que é útil para testes.

## Onde cada coisa fica

| Item | Local |
|------|-------|
| Skill própria | `plugins/jmartins-tools/skills/<nome>/SKILL.md` |
| Subagent | `plugins/jmartins-tools/agents/<nome>.md` |
| Slash command | `plugins/jmartins-tools/commands/<nome>.md` |
| Hook | `plugins/jmartins-tools/hooks/hooks.json` (use `${CLAUDE_PLUGIN_ROOT}` nos caminhos) |
| Servidor MCP | `plugins/jmartins-tools/.mcp.json` (segredos via variável de ambiente) |
| Plugin de terceiros | `enabledPlugins` e `extraKnownMarketplaces` em `config/settings.json` |
| Skill de terceiros sem plugin | `skills.json` (apenas a origem, nunca uma cópia) |
| Preferência portável | `config/settings.json` |
| Instruções globais | `config/CLAUDE.md` |
| Configuração específica da máquina | Somente em `~/.claude/settings.json` local, fora do repositório |

A skill `/jmartins-tools:config-sync` descreve esse fluxo dentro do Claude Code.

## Atualizando

- **Alterei o plugin:** aumente `version` em `plugin.json`, faça commit e push. Em cada máquina, rode `/plugin marketplace update jmartins-sh`.
- **Alterei `config/` ou `skills.json`:** faça commit e push. Em cada máquina, rode `git pull` e o script de instalação.
- **Teste local do plugin antes do push:** `claude --plugin-dir ./plugins/jmartins-tools`.

## Portabilidade

- Hooks e scripts executados pelo Claude Code devem funcionar em todos os sistemas. Prefira Node.js ou Python a `bash` e PowerShell.
- Não use caminhos absolutos. No plugin, use `${CLAUDE_PLUGIN_ROOT}`.
- Regras de permissão como `Bash(...)` valem para a ferramenta Bash. No Windows, o Claude Code também pode usar a ferramenta PowerShell, que tem regras próprias.
