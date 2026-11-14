import Foundation

/// Язык интерфейса. Переключается в Settings → General без перезапуска.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, ru

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: t("System")
        case .en: "English"
        case .ru: "Русский"
        }
    }
}

enum L10n {
    /// Текущий язык. Меняется из AppSettings.
    nonisolated(unsafe) static var isRussian = false

    static func apply(_ language: AppLanguage) {
        switch language {
        case .en: isRussian = false
        case .ru: isRussian = true
        case .system: isRussian = Locale.preferredLanguages.first?.hasPrefix("ru") ?? false
        }
    }

    /// Английская строка → русская. Ключ — сама английская строка.
    static let ru: [String: String] = [
        // Меню в трее
        // Файл настроек
        "Settings file": "Файл настроек",
        "Export…": "Экспорт…",
        "Import…": "Импорт…",
        "Replace all settings?": "Заменить все настройки?",
        "Replace": "Заменить",
        "Cancel": "Отмена",
        "The settings from the file replace your settings.": "Настройки из файла заменят твои текущие настройки.",
        "The settings are saved.": "Настройки сохранены.",
        "The settings are loaded.": "Настройки загружены.",
        "Pinok cannot save the file.": "Pinok не может сохранить файл.",
        "Pinok cannot open the file.": "Pinok не может открыть файл.",
        "This file is from a newer Pinok. Update the app.": "Файл из более новой версии Pinok. Обнови приложение.",
        "This file is not a Pinok settings file.": "Это не файл настроек Pinok.",
        // Панель в трее (вкладки «Сейчас» и «Статистика»)
        "Now": "Сейчас",
        "Pause for %ld min": "Пауза на %ld мин",
        "Break time": "Время перерыва",
        "Pause ends in": "Пауза закончится через",
        "at the computer": "за компьютером",
        "Longest work": "Макс. без перерыва",
        "Top apps": "Приложения",
        "now": "сейчас",
        "Work": "Работа",
        "Away": "Не за компьютером",
        "%ld h %ld": "%ld ч %ld",
        "Your day: work, breaks and time away": "Твой день: работа, перерывы и время без компьютера",
        "Reminders wait": "Напоминания ждут",
        "Breaks are off": "Перерывы выключены",
        "Pinok is on": "Pinok работает",
        "Skipped": "Пропущено",
        "Posture — off": "Осанка — выкл.",
        "Posture — paused": "Осанка — на паузе",
        "Posture — in %@": "Осанка — через %@",
        "Tongue — off": "Язык — выкл.",
        "Tongue — paused": "Язык — на паузе",
        "Tongue — in %@": "Язык — через %@",
        "Break — off": "Перерыв — выкл.",
        "Break — in progress": "Перерыв — идёт сейчас",
        "Break — paused": "Перерыв — на паузе",
        "Break — in %@": "Перерыв — через %@",
        "Paused until %@": "На паузе до %@",
        "Paused — %@": "Пауза — %@",
        "Resume": "Продолжить",
        "You are away. Timers are waiting.": "Тебя нет за компьютером. Таймеры ждут.",
        "Posture reminder now": "Напомнить про осанку",
        "Tongue reminder now": "Напомнить про язык",
        "Start break now": "Начать перерыв",
        "Skip next break": "Пропустить следующий перерыв",
        "Pause": "Пауза",
        "30 minutes": "30 минут",
        "1 hour": "1 час",
        "2 hours": "2 часа",
        "Until tomorrow": "До завтра",
        "Today: posture %ld · tongue %ld · breaks %ld": "Сегодня: осанка %ld · язык %ld · перерывы %ld",
        "Settings…": "Настройки…",
        "Quit Pinok": "Выйти из Pinok",
        "<1m": "<1м",
        "%ldm": "%ldм",
        "break": "перерыв",
        "you are in a call": "идёт звонок",
        "fullscreen video": "видео на весь экран",

        // Оверлеи
        "Sit up straight": "Выпрямись",
        "Tongue up": "Язык к нёбу",
        "Time to stretch": "Время размяться",
        "Skip": "Пропустить",
        "+%ld min": "+%ld мин",
        "+%ldm": "+%ldм",
        "Preview · Esc to close": "Предпросмотр · Esc — закрыть",
        "Break in %@": "Перерыв через %@",
        "Break in": "Перерыв через",
        "Start now": "Сейчас",
        "Finish typing…": "Допечатай…",

        // Советы на перерыве
        "Stand up and walk around for a couple of minutes": "Встань и пройдись пару минут",
        "Look at something far away for 20 seconds": "Посмотри вдаль 20 секунд",
        "Roll your shoulders back 10 times": "Покрути плечами назад 10 раз",
        "Join your hands and stretch up": "Сцепи руки в замок и потянись вверх",
        "Drink a glass of water": "Выпей стакан воды",
        "Take 10 slow, deep breaths": "Сделай 10 медленных глубоких вдохов",
        "Tilt your head to each shoulder for 15 seconds": "Наклони голову к каждому плечу на 15 секунд",
        "Pull your shoulders back for 5 seconds. Do it 5 times.": "Сведи лопатки на 5 секунд, 5 раз",

        // Варианты
        "White": "Белая", "Mint": "Мятная", "Blue": "Голубая", "Orange": "Оранжевая",
        "Glass": "Стекло", "Line": "Линия",
        "Blur screen": "Размытие", "Wallpaper": "Обои", "Gradient": "Градиент", "Image": "Картинка",
        "System": "Как в системе",

        // Настройки — разделы
        "General": "Общие",
        "Posture": "Осанка",
        "Tongue": "Язык",
        "Breaks": "Перерывы",
        "Stats": "Статистика",
        "Appearance": "Вид",
        "Sounds": "Звуки",
        "Reminders": "Напоминания",
        "Behavior": "Поведение",

        // Общие
        "Language": "Язык",
        "Launch at login": "Запускать при входе в систему",
        "Show minutes to the break in the menu bar": "Минуты до перерыва в строке меню",
        "Time left until the next reminder": "Сколько осталось до ближайшего напоминания",
        "Smart pause": "Умная пауза",
        "Pause when I'm away for": "Пауза, если меня нет",
        "Timers restart when you come back": "Когда вернёшься — отсчёт начнётся заново",
        "%ld min": "%ld мин",
        "Pause during calls": "Пауза во время звонков",
        "When the microphone or camera is in use": "Когда занят микрофон или камера",
        "Pause during full-screen video": "Пауза при видео на весь экран",
        "When a video plays in full screen": "Когда видео открыто на весь экран",
        "Wait until I stop typing": "Ждать, пока я допечатаю",
        "Reminders wait a few seconds until you stop typing": "Напоминания ждут пару секунд, пока ты не допечатаешь",
        "Sleep and screen lock": "Сон и блокировка экрана",
        "Timers reset automatically": "Таймеры сбрасываются автоматически",

        // Осанка / язык
        "Preview": "Показать",
        "An arrow moves up the screen. It reminds you to sit up straight.": "Стрелка поднимается по экрану. Это сигнал выпрямиться.",
        "Posture reminders": "Напоминать про осанку",
        "Every": "Каждые",
        "Show the text “Sit up straight”": "Подпись «Выпрямись»",
        "Change the arrow and colors in Appearance. Change sounds in Sounds.": "Стрелку и цвета меняй в разделе «Вид». Звуки — в «Звуках».",
        "The tongue moves up to the roof of the mouth. Keep it there all day.": "Язык поднимается к нёбу. Держи его там весь день.",
        "Tongue reminders": "Напоминать держать язык у нёба",
        "Show the text “Tongue up”": "Подпись «Язык к нёбу»",

        // Перерывы
        "The screen locks for a few minutes. Stand up, stretch and rest your eyes.": "Экран блокируется на пару минут. Встань, разомнись, дай глазам отдохнуть.",
        "Lock the screen for breaks": "Блокировать экран для перерыва",
        "Duration": "Длительность",
        "Warning": "Предупреждение",
        "Warn me before a break": "Предупреждать перед перерывом",
        "You can delay the break or start it now": "Можно отложить перерыв или начать сразу",
        "Warn me": "Предупредить за",
        "%ld sec before": "%ld сек",
        "%ld min before": "%ld мин",
        "Countdown next to the cursor": "Отсчёт рядом с курсором",
        "Shows the last 10 seconds before a break": "Последние 10 секунд перед перерывом",
        "Background": "Фон",
        "Messages": "Сообщения",
        "Each break shows one random message. The preview lasts 10 seconds. Press Esc to close it.": "На каждом перерыве показывается одно случайное сообщение. Предпросмотр длится 10 секунд. Esc — закрыть.",
        "No image selected": "Картинка не выбрана",
        "Choose…": "Выбрать…",
        "Choose a picture for breaks": "Выбери картинку для перерывов",
        "Remove": "Удалить",
        "Add your own message…": "Добавь своё сообщение…",
        "Add": "Добавить",
        "Reset to defaults": "Вернуть стандартные",

        // Статистика
        "Today": "Сегодня",
        "Counts all reminders and breaks. Previews are not counted.":
            "Считаются напоминания по расписанию и из меню. Предпросмотр не учитывается.",

        // Внешний вид
        "Arrow style": "Стиль стрелки",
        "Color": "Цвет",
        "Effect": "Эффект",
        "Darken screen": "Затемнение",
        "Arrow thickness": "Толщина стрелки",
        "Show on all displays": "На всех мониторах",
        "Used for posture and tongue reminders.": "Для напоминаний про осанку и язык.",

        // Звуки
        "Volume": "Громкость",
        "Break starts": "Начало перерыва",
        "Break ends": "Конец перерыва",
        "Built-in Mac sounds. You hear a sound when you pick it.":
            "Встроенные звуки macOS. При выборе звук сразу проигрывается.",
        "None": "Без звука",
        "Play": "Прослушать",

        // Напоминания и библиотека
        "%@ — in %@": "%@ — через %@",
        "%@ — paused": "%@ — на паузе",
        "%ld h": "%ld ч",
        "%ld h %ld min": "%ld ч %ld мин",
        "Every %@": "Каждые %@",
        "Remind me now": "Напомнить сейчас",
        "Today: %ld reminders · %ld breaks": "Сегодня: напоминаний %ld · перерывов %ld",
        "Add reminder": "Добавить напоминание",
        "More": "Ещё",
        "Animation": "Анимация",
        "Sound": "Звук",
        "Text": "Текст",
        "Name": "Название",
        "Text on the screen": "Текст на экране",
        "Open": "Открыть",
        "Turn on this reminder": "Включить это напоминание",
        "Show the text on the screen": "Показывать текст на экране",
        "Remove reminder": "Удалить напоминание",
        "This reminder was removed.": "Это напоминание удалено.",
        "Pick a ready reminder, or make your own.": "Выбери готовое напоминание или сделай своё.",
        "Ready reminders": "Готовые напоминания",
        "Your own reminder": "Своё напоминание",
        "Your own reminder.": "Твоё собственное напоминание.",
        "For example: Relax your face": "Например: Расслабь лицо",
        "For example: Relax your jaw": "Например: Расслабь челюсть",
        "Create reminder": "Создать напоминание",
        "Used for all reminders.": "Для всех напоминаний.",

        // Анимации
        "Arrow up": "Стрелка вверх",
        "Blink": "Моргнуть",
        "Look far away": "Посмотреть вдаль",
        "Water drop": "Капля",
        "Stretch": "Размяться",
        "Breathe": "Дыхание",
        "Hands": "Руки",
        "Workout": "Упражнение",
        "Squats": "Приседания",
        "Do 10 push-ups.": "Отожмись 10 раз.",
        "Roll your shoulders back 10 times.": "Покрути плечами назад 10 раз.",
        "Walk": "Прогулка",
        "Shoulder rolls": "Плечи",
        "Neck stretch": "Шея",
        "Raise your arms and stretch up. Hold for 10 seconds.": "Подними руки и потянись вверх. Задержись на 10 секунд.",
        "Do 15 squats. Keep your back straight.": "Присядь 15 раз. Держи спину прямо.",
        "Walk around the room for 2 minutes.": "Походи по комнате 2 минуты.",
        "Tilt your head to each shoulder. Hold for 15 seconds.": "Наклони голову к каждому плечу. Задержись на 15 секунд.",
        "Exercises": "Упражнения",
        "Small pushes for a healthy day at the computer.": "Маленькие пинки для здорового дня за компьютером.",
        "Choose your language": "Выбери язык",
        "Pick your reminders": "Выбери напоминания",
        "They show for a few seconds. You can click and type at this time.":
            "Они появляются на пару секунд. В это время можно кликать и печатать.",
        "You can change the times later in Settings.": "Время можно поменять потом в настройках.",
        "Breaks with exercises": "Перерывы с упражнениями",
        "The screen locks for a few minutes. You do a short list of exercises.":
            "Экран блокируется на пару минут. Ты делаешь короткий список упражнений.",
        "You are ready": "Всё готово",
        "Pinok lives in the menu bar. Click the ↑ icon to see the next reminder.":
            "Pinok живёт в строке меню. Нажми на значок ↑, чтобы увидеть следующее напоминание.",
        "Show me a reminder": "Покажи напоминание",
        "Continue": "Дальше",
        "Back": "Назад",
        "Start": "Начать",
        "Welcome screen": "Экран приветствия",
        "Close": "Закрыть",
        "Change…": "Сменить…",
        "How dark the screen becomes during a reminder.": "Насколько темнеет экран во время напоминания.",
        "Light": "Слабо",
        "Strong": "Сильно",
        "Try it": "Попробовать",
        "Icon": "Иконка",
        "Your icon": "Твоя иконка",
        "Choose an image…": "Выбрать картинку…",
        "Choose an image for the icon": "Выбери картинку для иконки",
        "Reset": "Сбросить",
        "Stop": "Остановить",
        "Short reminders": "Короткие напоминания",
        "You hear a short sound when you release the slider.": "Когда отпустишь ползунок, прозвучит короткий звук.",
        "Show on my screen": "Показать на экране",
        "Show the reminder on the full screen, as it really looks.": "Показать напоминание на весь экран, как оно выглядит на самом деле.",
        "Other texts": "Другие тексты",
        "Each time, the reminder shows one text at random.": "Каждый раз напоминание показывает случайный текст.",
        "Main": "Основной",
        "Add one more text…": "Добавь ещё один текст…",
        "Color of the icon and text": "Цвет значка и текста",
        "The arrow, the icon and the text of a reminder on the screen.": "Стрелка, иконка и текст напоминания на экране.",
        "Darken the screen": "Затемнение экрана",
        "How dark and blurry the screen becomes during a reminder.": "Насколько темнеет и размывается экран во время напоминания.",
        "My screen": "Мой экран",
        "Show the reminder on top of your screen or your wallpaper.": "Показать напоминание поверх твоего экрана или обоев.",
        "Allow Screen Recording for Pinok in System Settings to see your screen.":
            "Разреши Pinok запись экрана в Системных настройках, чтобы видеть свой экран.",
        "Turn off to mute all sounds of Pinok.": "Выключи, чтобы заглушить все звуки Pinok.",
        "On": "Вкл",
        "Long breaks": "Долгие перерывы",
        "Live preview": "Живое превью",
        "Play again": "Повторить",
        "Sound on or off": "Звук вкл. / выкл.",
        "Choose a file…": "Выбрать файл…",
        "Choose a sound file": "Выбери звуковой файл",
        "Welcome sound": "Звук заставки",
        "Welcome melody": "Мелодия заставки",
        "Screen effect": "Сила эффекта",
        "Wait while you type, talk in a call or watch a video.": "Ждать, пока ты печатаешь, говоришь по звонку или смотришь видео.",
        "Off": "Выкл",
        "No reminders are on.": "Нет включённых напоминаний.",
        "Remind": "Напомнить",
        "Break": "Перерыв",
        "Quit": "Выйти",
        "Choose the language and the first reminders again.": "Снова выбрать язык и первые напоминания.",
        "Show": "Показать",
        "Show a reminder for": "Показывать напоминание",
        "Give yourself more time to do it.": "Дай себе время всё сделать.",
        "Show the combo for": "Показывать комбо",
        "A combo has more actions. Give it more time.": "В комбо больше действий. Дай ему больше времени.",
        "Auto": "Авто",
        "%ld sec": "%ld сек",
        "Sunset": "Закат", "Ocean": "Океан", "Forest": "Лес", "Lavender": "Лаванда", "Midnight": "Полночь",
        "Trackpad haptics": "Вибрация трекпада",
        "You feel it only when your finger is on the trackpad.": "Чувствуется, только когда палец на трекпаде.",
        "Time for a break": "Время перерыва",
        "Done. Continue": "Готово. Дальше",
        "Time is up. Check the list to continue.": "Время вышло. Отметь список, чтобы продолжить.",
        "Exercises in one break": "Упражнений за перерыв",
        "End the break only when the list is done": "Заканчивать перерыв только после списка",
        "Skip and Esc always work.": "«Пропустить» и Esc работают всегда.",
        "Each break shows a list of exercises that are on. Click each one when you do it.":
            "На перерыве — список включённых упражнений. Отмечай каждое, когда сделаешь.",
        "Other exercise": "Другое упражнение",
        "Each break shows one exercise that is on. You can change it during the break.":
            "На каждом перерыве — одно из включённых упражнений. Его можно сменить прямо на перерыве.",
        "Melodies": "Мелодии",
        "Short sounds": "Короткие звуки",
        "Rise": "Подъём",
        "Jingle": "Джингл",
        "Done": "Готово",
        "Chime": "Перезвон",
        "Calm": "Спокойствие",
        "Breath": "Вдох",
        "Sparkle": "Искры",
        "A melody plays while the animation moves. Short sounds are built-in Mac sounds.":
            "Мелодия звучит, пока идёт анимация. Короткие звуки — встроенные звуки Mac.",
        "Push-ups": "Отжимания",
        "Do 10 push-ups": "Отожмись 10 раз",
        "A short exercise keeps your body strong. Do 10 push-ups.":
            "Короткое упражнение держит тело в форме. Отожмись 10 раз.",
        "Bell": "Колокольчик",

        // Шаблоны
        "Water": "Вода",
        "Hand cream": "Крем для рук",
        "Blink slowly 10 times": "Медленно моргни 10 раз",
        "Look far away for 20 seconds": "Посмотри вдаль 20 секунд",
        "Drink some water": "Выпей воды",
        "Stand up and stretch": "Встань и потянись",
        "Take 3 slow breaths": "Сделай 3 медленных вдоха",
        "Put cream on your hands": "Намажь руки кремом",
        "Your eyes become dry at the screen. Blink slowly to rest them.":
            "У экрана глаза пересыхают. Медленно моргай, чтобы дать им отдых.",
        "Every 20 minutes, look at a far object for 20 seconds. This rests your eyes.":
            "Каждые 20 минут смотри на дальний предмет 20 секунд. Так глаза отдыхают.",
        "Drink water during the day. Your body and your head need it.":
            "Пей воду в течение дня. Это нужно телу и голове.",
        "Stand up and move your body for one minute.": "Встань и подвигайся одну минуту.",
        "Slow breaths help you to be calm and to focus.": "Медленное дыхание помогает успокоиться и сосредоточиться.",
        "Your hands become dry at the keyboard. Put some cream on them.":
            "За клавиатурой руки сохнут. Намажь их кремом.",

        // Наборы
        "Combos": "Комбо",
        "New combo": "Новое комбо",
        "Combo": "Комбо",
        "My combo": "Моё комбо",
        "Turn on this combo": "Включить это комбо",
        "Reminders in this combo": "Напоминания в комбо",
        "Remove combo": "Удалить комбо",
        "This combo was removed.": "Это комбо удалено.",
        "Show some reminders at the same time. They share the screen from left to right.":
            "Несколько напоминаний сразу. Они делят экран слева направо.",
        "A reminder in a combo that is on does not show alone.": "Напоминание из включённого комбо не показывается отдельно.",
        "This reminder is in the combo “%@”. It shows with the combo.": "Это напоминание входит в комбо «%@». Оно показывается вместе с ним.",
        "Select 2 or more reminders.": "Выбери 2 или больше напоминаний.",
    ]
}

/// Перевод строки интерфейса на текущий язык.
func t(_ english: String) -> String {
    L10n.isRussian ? (L10n.ru[english] ?? english) : english
}

/// Перевод с подстановкой: `t("Break in %@", "0:45")`.
func t(_ english: String, _ args: CVarArg...) -> String {
    String(format: t(english), arguments: args)
}
