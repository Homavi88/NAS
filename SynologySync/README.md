# Silica

Нативное iOS‑приложение для **iPhone 17 Pro и новее** с дизайном под **iOS 27.2 Liquid Glass**.

**Silica** — лёгкий «стеклянный» клиент для Synology NAS: локальная сеть / QuickConnect / свой URL, File Station и резервное копирование Фото с iPhone.

## Возможности

- Вход в DSM и сессия File Station
- Просмотр общих папок и вложенных каталогов
- Создание папок, переименование, удаление, загрузка файлов с iPhone
- Вкладка синхронизации Фото → выбранная папка на NAS
- Копирование без удаления снимков с телефона
- Автосинхронизация по условиям:
  - iPhone в локальной сети (Wi‑Fi / Ethernet)
  - iPhone на зарядке

## Открыть в Xcode

1. На Mac с Xcode, где есть SDK **iOS 27.2**, откройте:

```text
SynologySync/SynologySync.xcodeproj
```

2. Выберите Team в Signing & Capabilities.
3. Подключите iPhone 17 Pro (или новее) / Simulator.
4. Build & Run.

Bundle ID по умолчанию: `app.synologysync.ios`.

## Подключение к NAS

| Режим | Что указать |
| --- | --- |
| Локальная сеть | IP/hostname, порт `5001` (HTTPS) или `5000` (HTTP) |
| QuickConnect | QuickConnect ID |
| Свой адрес | Домен/IP и порт внешнего доступа |

Учётка DSM должна иметь права на нужные share в File Station.

## Разрешения

Приложение запросит:

- доступ к **Фото** (чтение для копирования на NAS)
- доступ к **локальной сети** (поиск/работа с NAS дома)

Логин и пароль хранятся в **Keychain**.

## Структура

```text
SynologySync/
  App/           — точка входа и AppModel
  Models/        — credentials, файлы
  Services/      — Synology API, фото, сеть, питание
  Views/         — Connection, Files, Photos, Settings
  Utilities/     — визуальный язык iOS 27.2
  Resources/     — Info.plist, Assets
```

## Замечания

- Сборка выполняется на Mac в Xcode; в этой cloud‑среде нет iOS SDK.
- QuickConnect у разных DSM может требовать relay‑URL; если ID не резолвится, используйте режим «Свой адрес» с внешним доменом/портом.
- Автосинхронизация работает, пока приложение активно/в фоне в рамках системных ограничений iOS; для более агрессивного фона позже можно добавить BGProcessingTask.
