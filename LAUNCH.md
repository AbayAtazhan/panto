# Launch kit — Panto 0.4.2

Состояние на 30.10.2026. Всё ниже — копипаста, ссылки уже настоящие.

## Готовность

| | |
|---|---|
| ✅ | Репозиторий публичный, MIT, README на EN/RU/ZH, реальный скриншот, demo.gif + demo.mp4 |
| ✅ | Релиз `v0.4.2`, в нём `Panto.dmg` и `Panto.zip`; `releases/latest/download/Panto.dmg` работает |
| ✅ | `install.sh` (одна строка), `Read me.txt` внутри DMG, topics, описание |
| ⚠️ | CI-workflow не запушены (у токена нет scope `workflow`) — бейджа CI нет |
| ⚠️ | Нотаризации нет ($99) — первый запуск через правый клик или `install.sh` |
| ⚠️ | Демо-видео синтетическое (камера настоящая, сцена — мок). Скриншот окна настоящий |

Перед HN стоит закрыть только первое: перетащить `build.yml` и `release.yml` в
`.github/workflows/` через веб (Add file → Upload files) — 2 минуты, и появится CI-бейдж.
Остальное — сознательные компромиссы, о них лучше сказать честно в первом комментарии.

## Куда постить (по убыванию отдачи)

| Канал | Кому | Что даёт | Когда |
|---|---|---|---|
| **Hacker News, Show HN** | разработчики, инди | 300–3 000★ за сутки, если попал в топ-30 | вт–чт, 18:00–20:00 по Алматы (08:00–10:00 ET) |
| **r/macapps** | владельцы маков | самый тёплый трафик, мало токсичности | сразу после HN |
| **X / Twitter** | инди-хакеры, дизайнеры | вирусность клипа, DM-ы инфлюенсерам | в день HN, тред из 4 постов |
| **小红书 + V2EX + 少数派** | китайские мак-юзеры | половина топовых Mac-репо набирает звёзды здесь | +1 день, с `README.zh-CN.md` |
| **Telegram (Mac-каналы) + Habr** | русскоязычные | тёплые установки, меньше звёзд | +1 день |
| **Product Hunt** | ранние адоптеры | трафик, но для dev-tool слабее HN | +1 день, 00:01 PT |
| **r/SideProject, r/swift** | инди, свифтеры | немного звёзд, полезная критика | +1 день |
| **Dev.to / Hashnode** | поиск | длинный хвост на месяцы | +3 дня |
| **awesome-mac PR** | каталоги | медленно, но навсегда | +7 дней |

Правило: **один канал в день**, кроме HN + X (они усиливают друг друга). Не постить один
и тот же текст в 5 сабреддитов за час — забанят.

## День 0 (вторник)

**Hacker News, 18:00 Алматы:**

> **Show HN: Panto – free, native auto-zoom for screen recordings**
>
> Screen Studio is $89, and most people only use it for one thing: zooms on the parts of a demo
> that matter. Panto records a display with ScreenCaptureKit at native resolution, tracks clicks
> (or your own hotkey), and bakes a smooth camera move into the mp4 afterwards. A timeline editor
> lets you fix anything the automation missed. System audio and microphone are separate tracks,
> mixed on export.
>
> Native Swift, no Electron, no account, no telemetry. MIT.
>
> It is not notarized yet ($99 is real money for a student), so macOS asks for a right-click on
> first launch — the one-line installer strips the quarantine flag. I would love feedback on how
> the zoom feels, that is the whole product.

Первый комментарий сразу: «как устроена камера» в трёх строках + «что я сделал не так» +
просьба прислать запись, где зум ощущается плохо.

**X, тред:**
1. `docs/demo.mp4`, без текста.
2. «Screen Studio стоит $89. Я сделал одну функцию, за которой туда идут.»
3. скриншот редактора / кусок `Renderer.swift` с камерой.
4. «free + MIT → github.com/AbayAtazhan/panto».
Затем 20 личных сообщений инди, которые публикуют скринкасты: «дай 10 секунд, скажи, где зум врёт».

**r/macapps:**
> I made a free, native Screen Studio alternative for macOS — auto-zoom, system audio + voiceover, no subscription

## День +1

- Product Hunt: `Auto-zoom for screen recordings. Free and open source.`
- r/SideProject: `I refused to pay $89 for zooms, so I built the camera myself`
- Telegram: 2–3 Mac-канала, пост с гифкой и одной ссылкой.
- Habr: статья «Как я сделал камеру для скринкастов на AVVideoComposition» (не реклама, а разбор).

## День +2

- 小红书: вертикальное видео 15 сек, подпись «免费开源的 Screen Studio 替代品».
- V2EX, узел 分享创造: `Panto：免费开源的 macOS 录屏自动缩放`.
- 少数派: заявка на публикацию.

## Чего не делать

- Покупать звёзды — GitHub чистит, а HN находит по графику.
- Запускаться в пятницу или в праздник США.
- Спорить с критикой про «ещё один Screen Studio» — отвечать фактами и благодарить.
- Добавлять фичи до первых 100 звёзд. Чинить демо, а не бэклог.

## Метрики

| Сигнал | Нормально | Хорошо |
|---|---|---|
| HN на главной | топ-30 | топ-10 на 3 часа |
| Звёзд за первые сутки | 100 | 400 |
| Звёзд за неделю | 400 | 1 500 |
| Скачиваний DMG | 300 | 1 500 |

10 000 звёзд за 10 дней — это ~1 000 в день, топ-3 мира за неделю. Это происходит, когда
гифку пересылают **не** разработчики. Оптимизируй гифку и первые 20 секунд клипа.
