# Manuseio do Banco de Dados (PostgreSQL)

Guia rápido e sucinto de operações usadas no fluxo descrito no script `local_backup_test.sh`.

## 1) Acesso ao banco local

- Verificar serviço:
```bash
systemctl status postgresql.service
```
- Entrar no psql como postgres:
```bash
sudo -u postgres psql
```
  - Listar bancos: `\l`
  - Listar roles: `\du`
  - Sair: `\q`

## 2) Acesso a instâncias via SSM

- Abrir sessão na instância (ex.: bastion):
```bash
aws ssm start-session --target i-0361914b888aacc3f --region us-east-1
```

### Port forwarding para acesso ao PostgreSQL remoto
- Encaminhar porta 5432 remota para 5433 local:
```bash
aws ssm start-session \
  --target i-0b340ab1f11bd336f \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["localhost"],"portNumber":["5432"], "localPortNumber":["5433"]}' \
  --region us-east-1
```

## 3) Backup e restauração – i-EDUCAR

- Conectar na instância do i-EDUCAR:
```bash
aws ssm start-session --target i-0c26365dd4f4683bf --region us-east-1
```
- Gerar dump como usuário postgres:
```bash
sudo -u postgres pg_dump -U postgres -F c -d ieducar -f /tmp/ieducar.dump
```
- Enviar para S3 (ajuste o bucket, se necessário):
```bash
aws s3 cp /tmp/ieducar.dump s3://i-educar-dev-storage/ieducar.dump
```
- No destino, conectar e baixar do S3:
```bash
aws ssm start-session --target i-02783f9b5e72e28b1 --region us-east-1
aws s3 cp s3://i-educar-dev-storage/ieducar.dump /tmp/ieducar.dump
```
- Restaurar no banco `semed_db`:
```bash
sudo -u postgres pg_restore -v --clean --if-exists -U postgres -d semed_db /tmp/ieducar.dump
```

## 4) Backup e restauração – i-DIARIO

- Conectar na instância do i-DIARIO:
```bash
aws ssm start-session --target i-0a2534d6fbb6c1a92 --region us-east-1
```
- Gerar dump (excluindo tabelas específicas) como postgres:
```bash
sudo -u postgres pg_dump -U postgres -F c -d idiario_production \
  --exclude-table=public.entities \
  --exclude-table=public.ieducar_api_configurations \
  --exclude-table=public.ieducar_api_synchronizations \
  --exclude-table=public.ieducar_api_exam_postings \
  -f /tmp/idiario.dump
```
- Enviar para S3 (ajuste o bucket):
```bash
aws s3 cp /tmp/idiario.dump s3://i-diario-dev-storage/idiario.dump
```
- No destino, conectar e baixar do S3:
```bash
aws ssm start-session --target i-013bf08d0073a104f --region us-east-1
aws s3 cp s3://i-diario-dev-storage/idiario.dump /tmp/idiario.dump
```
- Restaurar no banco desejado (ex.: `semed_db`):
```bash
sudo -u postgres pg_restore -v --clean --if-exists -U postgres -d semed_db /tmp/idiario.dump
```

## 5) Backup/restauração de tabelas específicas

- Dump apenas de tabelas selecionadas (ex.: `tabela1`, `tabela2`):
```bash
sudo -u postgres pg_dump -U postgres -F c -d semed_db -t tabela1 -t tabela2 -f /tmp/tabelas.dump
```
- Restauração (o dump contém apenas as tabelas escolhidas):
```bash
sudo -u postgres pg_restore -v --clean --if-exists -U postgres -d semed_db /tmp/tabelas.dump
```

## Observações
- Execute `pg_dump`/`pg_restore` como usuário `postgres` para evitar erros de permissão.
- Garanta permissões de IAM para uso de SSM e acesso ao S3.
- Ajuste IDs de instância, regiões, nomes de banco e buckets conforme o ambiente.
