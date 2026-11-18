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
        "System": "Как в системе",
        // Файл настроек
        "Settings file": "Файл настроек",
        "Export…": "Экспорт…",
        "Import…": "Импорт…",
        "Replace all settings?": "Заменить все настройки?",
        "Replace": "Заменить",
        "Cancel": "Отмена",
        "The settings from the file replace your settings.": "Настройки из файла заменят твои текущие настройки.",
        "Pinok saved the settings.": "Настройки сохранены.",
        "Pinok loaded the settings.": "Настройки загружены.",
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
        "Longest work": "Без перерыва",
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
        "Resume": "Продолжить",
        "You are away. Timers are waiting.": "Тебя нет за компьютером. Таймеры ждут.",
        "Pause": "Пауза",
        "Settings…": "Настройки…",
        "Quit Pinok": "Выйти из Pinok",
        "<1m": "<1м",
        "%ldm": "%ldм",
        "break": "перерыв",
        "You are in a call": "Идёт звонок",
        "Full-screen video": "Видео на весь экран",

        // Оверлеи
        "Sit up straight": "Выпрямись",
        "Tongue up": "Язык к нёбу",
        "Skip": "Пропустить",
        "+%ld min": "+%ld мин",
        "Preview · Esc to close": "Предпросмотр · Esc — закрыть",
        "Break in %@": "Перерыв через %@",
        "Break in": "Перерыв через",
        "Start now": "Начать",
        "Finish typing…": "Допечатай…",

        // Советы на перерыве
        "Stand up and walk for 2 minutes": "Встань и пройдись 2 минуты",
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

        // Настройки — разделы
        "General": "Общие",
        "Posture": "Осанка",
        "Tongue": "Язык",
        "Breaks": "Перерывы",
        "Stats": "Статистика",
        "Sounds": "Звуки",
        "Reminders": "Напоминания",

        // Общие
        "Language": "Язык",
        "Launch at login": "Запускать при входе в систему",
        "Show minutes to the break in the menu bar": "Минуты до перерыва в строке меню",
        "Smart pause": "Умная пауза",
        "Pause when I am away for": "Пауза, если меня нет",
        "%ld min": "%ld мин",
        "Pause during calls": "Пауза во время звонков",
        "Pause during full-screen video": "Пауза при видео на весь экран",
        "Wait until I stop typing": "Ждать, пока я допечатаю",

        // Осанка / язык
        "Preview": "Показать",
        "An arrow moves up the screen. It reminds you to sit up straight.": "Стрелка поднимается по экрану. Это сигнал выпрямиться.",
        "Every": "Каждые",
        "The tongue moves up to the roof of the mouth. Keep it there all day.": "Язык поднимается к нёбу. Держи его там весь день.",

        // Перерывы
        "The screen locks for a few minutes. Stand up, stretch and rest your eyes.": "Экран блокируется на пару минут. Встань, разомнись, дай глазам отдохнуть.",
        "Lock the screen for breaks": "Блокировать экран для перерыва",
        "Duration": "Длительность",
        "Warn me": "Предупредить за",
        "%ld sec before": "%ld сек",
        "%ld min before": "%ld мин",
        "Background": "Фон",
        "No image selected": "Картинка не выбрана",
        "Choose…": "Выбрать…",
        "Choose a picture for breaks": "Выбери картинку для перерывов",
        "Remove": "Удалить",
        "Add": "Добавить",

        // Статистика
        "Counts all reminders and breaks. Previews are not counted.":
            "Считаются напоминания по расписанию и из меню. Предпросмотр не учитывается.",

        // Внешний вид

        // Звуки
        "Volume": "Громкость",
        "Break starts": "Начало перерыва",
        "Break ends": "Конец перерыва",
        "Built-in Mac sounds. You hear a sound when you pick it.":
            "Встроенные звуки macOS. При выборе звук сразу проигрывается.",
        "None": "Без звука",
        "Play": "Прослушать",

        // Напоминания и библиотека
        "%ld h": "%ld ч",
        "%ld h %ld min": "%ld ч %ld мин",
        "Every %@": "Каждые %@",
        "Today: %ld reminders · %ld breaks": "Сегодня: напоминаний %ld · перерывов %ld",
        "Add reminder": "Добавить напоминание",
        "More": "Ещё",
        "Animation": "Анимация",
        "Sound": "Звук",
        "Text": "Текст",
        "Name": "Название",
        "Text on the screen": "Текст на экране",
        "Open": "Открыть",
        "Show the text on the screen": "Показывать текст на экране",
        "Remove reminder": "Удалить напоминание",
        "You removed this reminder.": "Ты удалил это напоминание.",
        "Choose a ready reminder, or make your own.": "Выбери готовое напоминание или сделай своё.",
        "Ready reminders": "Готовые напоминания",
        "Your own reminder": "Своё напоминание",
        "Your own reminder.": "Твоё собственное напоминание.",
        "For example: Relax your face": "Например: Расслабь лицо",
        "For example: Relax your jaw": "Например: Расслабь челюсть",
        "Create reminder": "Создать напоминание",

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
        "Choose your reminders": "Выбери напоминания",
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
        "Allow Screen Recording for Pinok in System Settings to see your screen.":
            "Разреши Pinok запись экрана в Системных настройках, чтобы видеть свой экран.",
        "All sounds of Pinok: reminders, breaks and the welcome screen.": "Все звуки Pinok: напоминания, перерывы и приветствие.",
        "On": "Вкл",
        "Long breaks": "Долгие перерывы",
        "Live preview": "Живое превью",
        "Play again": "Повторить",
        "Sound on or off": "Звук вкл. / выкл.",
        "Choose a file…": "Выбрать файл…",
        "Choose a sound file": "Выбери звуковой файл",
        "Welcome sound": "Звук заставки",
        "Welcome melody": "Мелодия заставки",
        "Wait while you type, talk in a call or watch a video.": "Ждать, пока ты печатаешь, говоришь по звонку или смотришь видео.",
        "Off": "Выкл",
        "Break": "Перерыв",
        "Choose the language and the first reminders again.": "Снова выбрать язык и первые напоминания.",
        "Show": "Показать",
        "Show a reminder for": "Показывать напоминание",
        "Give yourself more time to do it.": "Дай себе время всё сделать.",
        "Show the combo for": "Показывать комбо",
        "A combo has more actions. Give it more time.": "В комбо больше действий. Дай ему больше времени.",
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
        "A short exercise keeps your body strong. Do 10 push-ups.":
            "Короткое упражнение держит тело в форме. Отожмись 10 раз.",
        "Bell": "Колокольчик",

        // Шаблоны
        "Water": "Вода",
        "Hand cream": "Крем для рук",
        "Blink slowly 10 times": "Медленно моргни 10 раз",
        "Look far away for 20 seconds": "Посмотри вдаль 20 секунд",
        "Drink some water": "Выпей воды",
        "Take 3 slow breaths": "Сделай 3 медленных вдоха",
        "Put cream on your hands": "Намажь руки кремом",
        "Your eyes become dry at the screen. Blink slowly to rest them.":
            "У экрана глаза пересыхают. Медленно моргай, чтобы дать им отдых.",
        "Every 20 minutes, look at a far object for 20 seconds. This rests your eyes.":
            "Каждые 20 минут смотри на дальний предмет 20 секунд. Так глаза отдыхают.",
        "Drink water during the day. Your body and your head need it.":
            "Пей воду в течение дня. Это нужно телу и голове.",
        "Slow breaths help you to be calm and to focus.": "Медленное дыхание помогает успокоиться и сосредоточиться.",
        "Your hands become dry at the keyboard. Put some cream on them.":
            "За клавиатурой руки сохнут. Намажь их кремом.",

        // Наборы
        "Combos": "Комбо",
        "New combo": "Новое комбо",
        "Combo": "Комбо",
        "My combo": "Моё комбо",
        "Reminders in this combo": "Напоминания в комбо",
        "Remove combo": "Удалить комбо",
        "You removed this combo.": "Ты удалил это комбо.",
        "Show some reminders at the same time. They share the screen from left to right.":
            "Несколько напоминаний сразу. Они делят экран слева направо.",
        "A reminder in a combo that is on does not show alone.": "Напоминание из включённого комбо не показывается отдельно.",
        "This reminder is in the combo “%@”. It shows with the combo.": "Это напоминание входит в комбо «%@». Оно показывается вместе с ним.",
        "Select 2 or more reminders.": "Выбери 2 или больше напоминаний.",

        // Конец рабочего дня
        "Workday": "Рабочий день",
        "End of the day": "Конец дня",
        "Pinok tells you when to stop work. Then it shows your list for the end of the day.":
            "Pinok скажет, когда пора заканчивать работу, и покажет список дел на конец дня.",
        "End time": "Конец работы",
        "Days": "Дни",
        "You can select more than one.": "Можно выбрать несколько.",
        "List for the end of the day": "Список на конец дня",
        "New step": "Новый пункт",
        "Remove step": "Удалить пункт",
        "Add step": "Добавить пункт",
        "At the end time, Pinok shows this list on the screen. Click each step when you do it.":
            "В конце дня Pinok покажет этот список на экране. Отмечай каждый пункт, когда сделаешь его.",
        "Show the list again after": "Показать список снова через",
        "Click Do the steps to close the list for this time.": "Кнопка «Выполнить пункты» закрывает список на это время.",
        "Write what you did today": "Записать, что сделано сегодня",
        "Write where you stopped": "Записать, на чём остановилась работа",
        "Write a to-do list for tomorrow": "Написать список дел на завтра",
        "Close the work apps": "Закрыть рабочие приложения",
        "The workday is over": "Рабочий день закончен",
        "Do these steps. Then stop work.": "Сделай эти пункты и заканчивай работу.",
        "Do the steps": "Выполнить пункты",
        "End the day": "Закончить день",
        "Pinok will show this list again in %ld min.": "Pinok покажет этот список снова через %ld мин.",
        "Busy?": "Очень занят?",
        "Skip today": "Пропустить сегодня",
        "+%ld h": "+%ld ч",
        "The workday ends in %@": "Рабочий день закончится через %@",
        "Show the list": "Показать список",
        "Pinok waits until tomorrow": "Pinok ждёт до завтра",
        "Workday ends at %@": "Рабочий день до %@",
        "Move": "Перенести",
        "OK": "ОК",
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
