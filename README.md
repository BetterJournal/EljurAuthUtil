<div align="center">
	<a href="https://betterjournal.app">
		<picture>
      <img alt="BetterJournal Logo" src="https://betterjournal.app/pwa-192x192.png" height="128">
    </picture>
	</a>
  <h1>@betterjournal/eljur-auth-util</h1>
  
<a href="https://betterjournal.app"><img alt="Made for people" src="https://img.shields.io/badge/MADE%20FOR%20PEOPLE-000000?style=for-the-badge&logo=pipecat&logoColor=e12afb"></a>

</div>

## О проекте (утилите)

Данная CLI-утилита предназначена для удобной и безопасной авторизации в электронном журнале **ЭлЖур** через учетную запись **Госуслуг (ЕСИА)**.

Утилита полностью реализует пошаговый процесс авторизации (включая поддержку двухфакторной аутентификации SMS и TOTP) и предоставляет необходимые токены доступа (`v_token` ESIA JWT, хэш региона и сессионные токены `token:vendor` для каждой школы/профиля).

## Возможности

- 🚀 **Пошаговая цепочка OAuth (Фазы 1–4)** по спецификации ЭлЖура и ЕСИА.
- 🔐 **Поддержка двухфакторной аутентификации (2FA)**: СМС-коды и TOTP из приложений-аутентификаторов.
- 🔒 **Безопасный ввод**: маскирование пароля при интерактивном вводе.
- ⚙️ **Интерактивный и флаг-режим**: возможность передачи аргументов командной строки или пошагового ввода.
- 📊 **JSON вывод (`--json`)**: для интеграции со скриптами и сторонними сервисами.
- 🍪 **Встроенный CookieJar**: корректное сохранение и изоляция сессионных cookie.

## Использование

### Запуск в интерактивном режиме
```bash
dart run bin/eljur_auth_util.dart
```

### Запуск с передачей параметров
```bash
dart run bin/eljur_auth_util.dart --host school.eljur.ru --login +79001234567 --password "MySecretPass"
```

### Запуск с выводом в формате JSON
```bash
dart run bin/eljur_auth_util.dart --host school.eljur.ru -j
```

### Опции командной строки
```
-H, --host        Хост школы в ЭлЖур (например: school.eljur.ru или keo.gov39.ru)
-l, --login       Логин для входа в Госуслуги (телефон, email или СНИЛС)
-p, --password    Пароль для входа в Госуслуги
-j, --json        Вывести итоговый результат в формате JSON
-h, --help        Показать справку по использованию утилиты
-v, --version     Показать версию утилиты
```

## Тестирование

Запуск набора unit-тестов:
```bash
dart test
```
