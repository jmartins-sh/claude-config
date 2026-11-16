---
name: config-sync
description: Guia para levar uma configuracao, skill, agent, command ou hook da maquina local para o repositorio claude-config.
disable-model-invocation: true
---

# Sincronizar configuracao com o repositorio claude-config

Use este fluxo quando o usuario quiser salvar no repositorio algo que hoje existe apenas na maquina local.

## 1. Localizar o repositorio

Procure o clone de `jmartins-sh/claude-config`. O local padrao e `~/code/claude-config`. Se nao encontrar, pergunte ao usuario.

## 2. Decidir onde o item deve ficar

| Item | Destino no repositorio |
|------|------------------------|
| Skill escrita pelo usuario | `plugins/jmartins-tools/skills/<nome>/SKILL.md` |
| Subagent | `plugins/jmartins-tools/agents/<nome>.md` |
| Slash command | `plugins/jmartins-tools/commands/<nome>.md` |
| Hook | `plugins/jmartins-tools/hooks/hooks.json` (scripts ao lado, referenciados com `${CLAUDE_PLUGIN_ROOT}`) |
| Servidor MCP | `plugins/jmartins-tools/.mcp.json` (segredos sempre via variavel de ambiente) |
| Skill de terceiros | Entrada em `skills.json` (origem e nome), nunca uma copia |
| Plugin de terceiros | `enabledPlugins` e `extraKnownMarketplaces` em `config/settings.json` |
| Preferencia portavel | Chave em `config/settings.json` |
| Instrucoes globais | `config/CLAUDE.md` |

## 3. Verificar antes de gravar

- Nao copie `autoMode`, caminhos absolutos da maquina, credenciais, tokens ou detalhes internos da organizacao. O repositorio e publico.
- Hooks e scripts precisam funcionar em Windows e em Linux.
- Ao alterar o plugin, aumente `version` em `plugins/jmartins-tools/.claude-plugin/plugin.json`.

## 4. Publicar

Mostre o `git diff` ao usuario e so faca commit e push com a confirmacao dele. Depois, em cada maquina, rode `/plugin marketplace update jmartins-sh` ou o script de instalacao.
