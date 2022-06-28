#Create Folder
cd /home/user/labs/backup-postgres/
mkdir -p "files"

#backup Postgres
pg_dump --no-owner -h painel.bolsadedados.com.br -p 5432 -U postgres database | gzip > /home/user/labs/backup-postgres/files/alerta_$(date +%d-%m-%y-%H-%M-%S).gz

#Upload to Dropbox
/home/user/.local/share/virtualenvs/backup-postgres-wR48kqji/bin/python /home/user/labs/backup-postgres/dropbox_upload.py