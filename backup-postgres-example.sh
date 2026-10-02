#!/bin/bash
set -o pipefail

# Diretório base do script
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

# Carregar variáveis do .env se existir
if [ -f "$BASE_DIR/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$BASE_DIR/.env" 2>/dev/null || true
    set +a
fi

# Diretório para os arquivos de backup
FILES_DIR="$BASE_DIR/files"
mkdir -p "$FILES_DIR"

TIMESTAMP=$(date +%d-%m-%y-%H-%M-%S)
PG_USER="${PG_USER:-postgres}"
PG_HOST="${PG_HOST:-127.0.0.1}"
PG_PORT="${PG_PORT:-5432}"
PG_CONTAINER="${PG_CONTAINER:-financial-db}"

echo "=========================================================="
echo "Iniciando processo de backup: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================================="

# Verifica se o PostgreSQL está rodando em container Docker ou via host
IS_DOCKER=false
if command -v docker &> /dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -wq "$PG_CONTAINER"; then
    IS_DOCKER=true
    echo "[INFO] Ambiente detectado: Container Docker '$PG_CONTAINER'"
else
    echo "[INFO] Ambiente detectado: Conexão direta ($PG_HOST:$PG_PORT)"
fi

# Obter a lista de bancos de dados (excluindo templates)
echo "[INFO] Consultando bancos de dados no servidor..."
if [ "$IS_DOCKER" = true ]; then
    DATABASES=$(docker exec -i "$PG_CONTAINER" psql -U "$PG_USER" -At -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null)
else
    DATABASES=$(psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -At -c "SELECT datname FROM pg_database WHERE datistemplate = false;" 2>/dev/null)
fi

if [ -z "$DATABASES" ]; then
    echo "[ERRO] Não foi possível obter a lista de bancos de dados ou nenhum banco foi encontrado!" >&2
    exit 1
fi

echo "[INFO] Bancos de dados encontrados para backup:"
for DB in $DATABASES; do
    echo "  - $DB"
done
echo "----------------------------------------------------------"

# Backup dos globals (usuários, roles e senhas do cluster)
GLOBALS_FILE="$FILES_DIR/globals_${TIMESTAMP}.gz"
echo "[INFO] Gerando backup dos globals (roles/permissões)..."
if [ "$IS_DOCKER" = true ]; then
    docker exec -i "$PG_CONTAINER" pg_dumpall --globals-only -U "$PG_USER" 2>/dev/null | gzip > "$GLOBALS_FILE"
else
    pg_dumpall --globals-only -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" 2>/dev/null | gzip > "$GLOBALS_FILE"
fi

if [ -f "$GLOBALS_FILE" ] && [ -s "$GLOBALS_FILE" ]; then
    FILE_SIZE=$(du -h "$GLOBALS_FILE" | cut -f1)
    echo "[SUCESSO] Backup dos globals concluído: $GLOBALS_FILE ($FILE_SIZE)"
else
    echo "[AVISO] Falha ao gerar backup dos globals ou arquivo vazio." >&2
    rm -f "$GLOBALS_FILE"
fi

# Backup individual de cada banco de dados
FAILED_DATABASES=()
SUCCESS_COUNT=0

for DB in $DATABASES; do
    OUTPUT_FILE="$FILES_DIR/${DB}_${TIMESTAMP}.gz"
    echo "[INFO] Realizando backup do database: '$DB'..."
    
    if [ "$IS_DOCKER" = true ]; then
        if docker exec -i "$PG_CONTAINER" pg_dump --no-owner -U "$PG_USER" "$DB" 2>/dev/null | gzip > "$OUTPUT_FILE"; then
            DUMP_SUCCESS=true
        else
            DUMP_SUCCESS=false
        fi
    else
        if pg_dump --no-owner -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$DB" 2>/dev/null | gzip > "$OUTPUT_FILE"; then
            DUMP_SUCCESS=true
        else
            DUMP_SUCCESS=false
        fi
    fi
    
    if [ "$DUMP_SUCCESS" = true ] && [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
        FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo "[SUCESSO] Backup de '$DB' finalizado: $OUTPUT_FILE ($FILE_SIZE)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "[ERRO] Falha ao realizar backup do database '$DB'!" >&2
        rm -f "$OUTPUT_FILE"
        FAILED_DATABASES+=("$DB")
    fi
done

echo "----------------------------------------------------------"
echo "[INFO] Resumo: $SUCCESS_COUNT database(s) com backup concluído."
if [ ${#FAILED_DATABASES[@]} -gt 0 ]; then
    echo "[AVISO] Falha nos seguintes databases: ${FAILED_DATABASES[*]}" >&2
fi

# Upload para o Dropbox
PYTHON_BIN=""
if [ -x "$BASE_DIR/venv/bin/python" ]; then
    PYTHON_BIN="$BASE_DIR/venv/bin/python"
elif command -v python3 &> /dev/null; then
    PYTHON_BIN="$(command -v python3)"
elif command -v python &> /dev/null; then
    PYTHON_BIN="$(command -v python)"
fi

if [ -f "$BASE_DIR/dropbox_upload.py" ] && [ -n "$PYTHON_BIN" ]; then
    echo "[INFO] Iniciando upload para o Dropbox..."
    "$PYTHON_BIN" "$BASE_DIR/dropbox_upload.py"
else
    echo "[AVISO] Script dropbox_upload.py ou executável Python não encontrado."
fi

echo "=========================================================="
echo "Processo finalizado: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================================="