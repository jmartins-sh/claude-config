#!/usr/bin/env bash
# Aplica a configuracao deste repositorio ao Claude Code local (Linux e macOS).
#
# 1. Mescla config/settings.json com ~/.claude/settings.json:
#    - objetos sao mesclados recursivamente;
#    - listas recebem os itens do repositorio que ainda nao existem;
#    - valores simples do repositorio substituem os locais;
#    - chaves que so existem localmente (por exemplo, autoMode) sao preservadas.
# 2. Copia config/CLAUDE.md, se existir.
# 3. Instala as skills de terceiros listadas em skills.json (requer Node.js/npx).
# Antes de alterar qualquer arquivo, grava uma copia em ~/.claude/backups.
#
# Uso: ./install.sh [--dry-run] [--skip-skills]
# Requer: jq

set -euo pipefail

DRY_RUN=0
SKIP_SKILLS=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --skip-skills) SKIP_SKILLS=1 ;;
    *) echo "Opcao desconhecida: $arg" >&2; exit 2 ;;
  esac
done

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
BACKUP_DIR="$CLAUDE_DIR/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }

backup_file() {
  if [ -f "$1" ]; then
    mkdir -p "$BACKUP_DIR"
    local dest="$BACKUP_DIR/$(basename "$1").$STAMP.bak"
    cp "$1" "$dest"
    echo "    copia de seguranca: $dest"
  fi
}

command -v jq >/dev/null 2>&1 || { echo "Erro: jq nao encontrado. Instale-o (apt install jq / brew install jq)." >&2; exit 1; }

# 1. settings.json
step "Mesclando settings.json"
REPO_SETTINGS="$REPO_DIR/config/settings.json"
LOCAL_SETTINGS="$CLAUDE_DIR/settings.json"
[ -f "$LOCAL_SETTINGS" ] && BASE="$LOCAL_SETTINGS" || BASE=<(echo '{}')

MERGED="$(jq -s '
  def merge(a; b):
    if (a | type) == "object" and (b | type) == "object" then
      reduce (b | keys_unsorted[]) as $k (a; .[$k] = (if has($k) then merge(.[$k]; b[$k]) else b[$k] end))
    elif (a | type) == "array" and (b | type) == "array" then
      reduce b[] as $x (a; if any(.[]; . == $x) then . else . + [$x] end)
    else b end;
  merge(.[0]; .[1])
' "$BASE" "$REPO_SETTINGS")"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "$MERGED"
else
  mkdir -p "$CLAUDE_DIR"
  backup_file "$LOCAL_SETTINGS"
  printf '%s\n' "$MERGED" > "$LOCAL_SETTINGS"
  echo "    gravado: $LOCAL_SETTINGS"
fi

# 2. CLAUDE.md
if [ -f "$REPO_DIR/config/CLAUDE.md" ]; then
  step "Copiando CLAUDE.md"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "    copiaria para $CLAUDE_DIR/CLAUDE.md"
  else
    backup_file "$CLAUDE_DIR/CLAUDE.md"
    cp "$REPO_DIR/config/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  fi
fi

# 3. Skills de terceiros
if [ "$SKIP_SKILLS" -eq 0 ]; then
  step "Instalando skills de terceiros (skills.json)"
  jq -r '.skills[] | "\(.name)\t\(.source)"' "$REPO_DIR/skills.json" | while IFS=$'\t' read -r name source; do
    if [ -d "$CLAUDE_DIR/skills/$name" ]; then
      echo "    ja instalada: $name"
    elif ! command -v npx >/dev/null 2>&1; then
      echo "    aviso: npx nao encontrado; instale o Node.js e rode: npx skills add $source --skill $name -g -a claude-code -y" >&2
    elif [ "$DRY_RUN" -eq 1 ]; then
      echo "    instalaria: $name ($source)"
    else
      npx -y skills add "$source" --skill "$name" -g -a claude-code -y </dev/null || echo "    aviso: falha ao instalar $name" >&2
    fi
  done
fi

step "Concluido. Abra o Claude Code para que ele instale os plugins listados em enabledPlugins."
