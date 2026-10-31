# Деплой beg-deals на Contabo (185.215.166.206)

Все команды «на Маке» выполняются в Terminal на Маке, «на сервере» — в SSH-сессии.

## Шаг 1. Ключ на сервер (на Маке)

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@185.215.166.206
```
Попросит root-пароль (тот, что задал при заказе). Проверка: `ssh root@185.215.166.206` должен пустить без пароля.

## Шаг 2. Архив на сервер (на Маке)

```bash
scp ~/Downloads/beg-deals.zip root@185.215.166.206:/root/
```

## Шаг 3. Bootstrap (на сервере, под root)

```bash
ssh root@185.215.166.206
apt-get update && apt-get install -y unzip
unzip -o beg-deals.zip
bash beg-deals/deploy/bootstrap.sh alek "$(head -1 ~/.ssh/authorized_keys)"
```
Занимает 2–5 минут. В конце должно быть «Готово». **Root-сессию не закрывать.**

## Шаг 4. Проверка входа (на Маке, НОВОЕ окно терминала)

```bash
ssh alek@185.215.166.206
```
Должно пустить без пароля. Только после этого можно закрыть root-сессию.
Проверка, что вход root и по паролю закрыт:
```bash
ssh -o PubkeyAuthentication=no root@185.215.166.206   # должно быть Permission denied
```

## Шаг 5. Алиас (на Маке)

В `~/.ssh/config` добавить:
```
Host beg
    HostName 185.215.166.206
    User alek
```
Дальше достаточно `ssh beg`.

## Шаг 6. Проект в домашнюю папку (на сервере)

```bash
ssh beg
sudo mv /root/beg-deals ~/ && sudo chown -R alek: ~/beg-deals
cd ~/beg-deals
docker --version && docker compose version
```

## Шаг 7. Токены и запуск (на сервере)

Нужны: Travelpayouts (TP_TOKEN, TP_MARKER, TP_TRS), токен бота от @BotFather (TG_TOKEN), канал (TG_CHANNEL), бот — админ канала.

```bash
cp .env.example .env
nano .env                                   # заполнить токены, DB_PASSWORD
docker compose up -d --build
docker compose logs -f bot                  # Ctrl+C — выйти из логов
```

## Шаг 8. Проверка до публикации

```bash
docker compose run --rm bot python -m app.main collect
docker compose run --rm bot python -m app.main preview 10
docker compose run --rm bot python -m app.main test -100XXXXXXXXXX   # id тестовой группы
```

## Шаг 9. Бэкап базы (на сервере)

`crontab -e` и добавить строку:
```
15 4 * * * cd ~/beg-deals && docker compose exec -T db pg_dump -U deals deals | gzip > ~/backup-$(date +\%F).sql.gz && find ~ -maxdepth 1 -name 'backup-*.sql.gz' -mtime +14 -delete
```

## Шаг 10. После настройки

- Выключить VNC в панели Contabo (Customer Control Panel → VPS → VNC).
- Сделать Snapshot в панели — точка отката.

## Обновление кода потом

```bash
# на Маке
scp ~/Downloads/beg-deals.zip beg:~
# на сервере
cd ~ && unzip -o beg-deals.zip -x 'beg-deals/.env' && cd beg-deals && docker compose up -d --build
```
`.env` при распаковке не перезаписывается.
