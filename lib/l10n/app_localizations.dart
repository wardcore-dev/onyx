// lib/l10n/app_localizations.dart
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  bool get _ru => locale.languageCode == 'ru';

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get navChats => _ru ? 'Чаты' : 'Chats';
  String get navGroups => _ru ? 'Группы' : 'Groups';
  String get navFavorites => _ru ? 'Избранное' : 'Favorites';
  String get navAccounts => _ru ? 'Аккаунты' : 'Accounts';
  String get navSettings => _ru ? 'Настройки' : 'Settings';

  String get cancel => _ru ? 'Отмена' : 'Cancel';
  String get save => _ru ? 'Сохранить' : 'Save';
  String get ok => _ru ? 'OK' : 'OK';
  String get yes => _ru ? 'Да' : 'Yes';
  String get no => _ru ? 'Нет' : 'No';
  String get close => _ru ? 'Закрыть' : 'Close';
  String get confirm => _ru ? 'Подтвердить' : 'Confirm';
  String get delete => _ru ? 'Удалить' : 'Delete';
  String get clear => _ru ? 'Очистить' : 'Clear';
  String get loading => _ru ? 'Загрузка...' : 'Loading...';
  String get error => _ru ? 'Ошибка' : 'Error';
  String get success => _ru ? 'Успешно' : 'Success';
  String get copy => _ru ? 'Копировать' : 'Copy';
  String get copied => _ru ? 'Скопировано' : 'Copied';
  String get test => _ru ? 'Тест' : 'Test';
  String get connect => _ru ? 'Подключить' : 'Connect';
  String get disconnect => _ru ? 'Отключить' : 'Disconnect';
  String get enabled => _ru ? 'Включено' : 'Enabled';
  String get disabled => _ru ? 'Выключено' : 'Disabled';
  String get on => _ru ? 'Вкл' : 'On';
  String get off => _ru ? 'Выкл' : 'Off';

  String get settingsTitle => _ru ? 'Настройки' : 'Settings';
  String get supportOnyx => _ru ? 'Поддержать ONYX' : 'Support ONYX';

  String get securityTitle => _ru ? 'Безопасность' : 'Security & Privacy';
  String get securitySubtitle => _ru ? 'Советы и детали шифрования' : 'Tap to view tips and encryption details';
  String get tipOfTheDay => _ru ? 'Совет дня' : 'Tip of the day';
  String get statusSettings => _ru ? 'Настройки статуса' : 'Status Settings';
  String get showDisplayNameInGroups => _ru ? 'Показывать имя в группах' : 'Show my display name in groups';
  String get showDisplayNameSubtitle => _ru ? 'Если выключено, ваши сообщения будут подписаны как "Anonymous"' : 'When off, your messages appear as "Anonymous"';
  String get pinLock => _ru ? 'PIN-блокировка' : 'PIN Lock';
  String get enablePinLock => _ru ? 'Включить PIN-блокировку' : 'Enable PIN Lock';
  String get enablePinSubtitle => _ru ? 'Требовать 4-значный PIN при запуске приложения' : 'Require a 4-digit PIN to unlock the app on launch';
  String get pinLockEnabled => _ru ? ' PIN-блокировка включена' : ' PIN Lock enabled';
  String get pinLockDisabled => _ru ? 'PIN-блокировка отключена' : 'PIN Lock disabled';
  String get useBiometrics => _ru ? 'Использовать биометрию' : 'Use Biometrics';
  String get useBiometricsSubtitle => _ru ? 'Разблокировать по отпечатку или лицу' : 'Unlock with fingerprint or face recognition';
  String get biometricsUnavailable => _ru ? 'Биометрия недоступна на этом устройстве' : 'Biometrics not available on this device';
  String get lockOnResume => _ru ? 'Блокировать при сворачивании' : 'Lock when backgrounded';
  String get lockOnResumeSubtitle => _ru ? 'Запрашивать PIN каждый раз при возврате в приложение' : 'Require PIN every time the app returns to foreground';
  String get searchChatsHint => _ru ? 'Поиск чатов и сообщений…' : 'Search chats and messages…';
  String get searchGroupsHint => _ru ? 'Поиск групп и сообщений…' : 'Search groups and messages…';
  String get searchFavoritesHint => _ru ? 'Поиск избранного…' : 'Search favorites…';
  String get searchSettingsHint => _ru ? 'Поиск в настройках…' : 'Search settings…';
  List<String> get securityTips => _ru
      ? [
          'Не используйте ONYX на рутованных устройствах — это ослабляет безопасность шифрования.',
          'Ваши сообщения защищены сквозным шифрованием X25519 и XChaCha20-Poly1305.',
          'Приватные ключи никогда не покидают устройство и хранятся в защищённом хранилище.',
          'Никогда не делитесь паролем или приватными ключами — ONYX никогда их не запросит.',
          'Выход из аккаунта или его удаление безвозвратно удаляет ключи с устройства.',
          'Всегда сверяйте pubkey с собеседником перед обсуждением чувствительных тем.',
        ]
      : [
          'Avoid using ONYX on rooted or jailbroken devices — they weaken encryption security.',
          'Your messages are protected with end-to-end encryption using X25519 and XChaCha20-Poly1305.',
          'Private keys never leave your device and are stored in secure system storage.',
          'Never share your password or private keys — ONYX will never ask for them.',
          'Logging out or deleting your account permanently removes your keys from this device.',
          'Always check pubkey with interlocutor before discussing sensitive topics.',
        ];

  String get keyMgmtTitle => _ru ? 'Управление ключами' : 'Key Management';
  String get keyMgmtSubtitle => _ru ? 'Ротация или сброс ключа шифрования' : 'Rotate or reset your encryption identity';
  String get keyMgmtDescription => _ru
      ? 'Выполните ротацию E2EE-ключа, если подозреваете его компрометацию. Контакты получат новый ключ автоматически.'
      : 'Rotate your E2EE identity key if you suspect it was compromised. Contacts receive the new key automatically.';
  String get rotateE2eeKey => _ru ? 'Ротация E2EE-ключа' : 'Rotate E2EE Key';
  String get rotateE2eeKeyPrimaryOnly => _ru ? 'Ротация E2EE-ключа (только основное устройство)' : 'Rotate E2EE Key (primary device only)';
  String get rotateKeyDialogTitle => _ru ? 'Ротировать ключ шифрования?' : 'Rotate encryption key?';
  String get rotateKeyDialogContent => _ru
      ? 'Будет создана новая пара ключей X25519 и загружена на сервер.\n\nСессия и история сообщений НЕ затрагиваются. Контакты автоматически начнут использовать новый ключ.'
      : 'A new X25519 keypair will be generated and uploaded to the server.\n\nYour session and message history are NOT affected. Contacts will automatically use the new key on their next message.';
  String get rotateKeyBtn => _ru ? 'Ротировать' : 'Rotate';
  String get rotatingKey => _ru ? ' Ротация ключа...' : ' Rotating key…';
  String get keyRotated => _ru ? ' E2EE-ключ ротирован и загружен' : ' E2EE key rotated and uploaded';
  String get keyRotationFailed => _ru ? ' Ошибка ротации ключа' : ' Key rotation failed';
  String get activeDevices => _ru ? 'Активные устройства' : 'Active Devices';
  String get activeDevicesPrimaryOnly => _ru ? 'Активные устройства (только основное)' : 'Active Devices (primary device only)';
  String get showPassphrase => _ru ? 'Показать секретную фразу' : 'Show Passphrase';
  String get showPassphrasePrimaryOnly => _ru ? 'Показать секретную фразу (только основное устройство)' : 'Show Passphrase (primary device only)';
  String get changePassword => _ru ? 'Изменить пароль' : 'Change Password';
  String get changePasswordPrimaryOnly => _ru ? 'Изменить пароль (только основное устройство)' : 'Change Password (primary device only)';

  String get notificationsTitle => _ru ? 'Уведомления' : 'Notifications';
  String get notificationsSubtitle => _ru ? 'Управление оповещениями' : 'Manage alerts and delivery options';
  String get notificationsEnabled => _ru ? 'Включить уведомления' : 'Enable Notifications';
  String get notificationsEnabledSubtitle => _ru ? 'Показывать системные уведомления о новых сообщениях' : 'Show system notifications for new messages';
  String get notificationPosition => _ru ? 'Позиция уведомлений' : 'Notification Position';
  String get notifPosTopLeft => _ru ? 'Верх-лево' : 'Top Left';
  String get notifPosTopRight => _ru ? 'Верх-право' : 'Top Right';
  String get notifPosBottomLeft => _ru ? 'Низ-лево' : 'Bottom Left';
  String get notifPosBottomRight => _ru ? 'Низ-право' : 'Bottom Right';

  String get appearanceTitle => _ru ? 'Внешний вид' : 'Appearance';
  String get appearanceSubtitle => _ru ? 'Тема и тёмный режим' : 'Choose theme and dark mode';
  String get selectTheme => _ru ? 'Выбрать тему' : 'Select Theme';
  String get darkMode => _ru ? 'Тёмный режим' : 'Dark Mode';
  String get fontAndTextSize => _ru ? 'Шрифт и размер текста' : 'Font & Text Size';
  String get fontFamily => _ru ? 'Семейство шрифтов' : 'Font Family';
  String get messageSize => _ru ? 'Размер сообщений' : 'Message Size';
  String get ownMessagesRight => _ru ? 'Мои сообщения: справа' : 'Own messages: Right';
  String get ownMessagesLeft => _ru ? 'Мои сообщения: слева' : 'Own messages: Left';
  String get alignAllRight => _ru ? 'Выровнять все сообщения вправо' : 'Align all messages right';
  String get alignAllRightSubtitle => _ru ? 'Все сообщения отображаются справа, как в зеркале' : 'All messages aligned to the right side like a mirror';
  String get showAvatarInChats => _ru ? 'Аватар в списке чатов' : 'Show avatar in chats list';
  String get showAccountIndicator => _ru ? 'Показывать текущий аккаунт' : 'Show current account';
  String get showAccountIndicatorSubtitle => _ru ? 'Отображать имя и юзернейм в углу приложения' : 'Display name and username in the app corner';
  String get showAvatarSubtitle => _ru ? 'Показывать аватар собеседника в списке чатов' : 'Show contact avatar in chat list';
  String get chatBackground => _ru ? 'Фон чата' : 'Chat Background';
  String get chatBgSubtitle => _ru ? 'Установить изображение как фон в чатах' : 'Set an image as chat background';
  String get chooseImage => _ru ? 'Выбрать изображение' : 'Choose Image';
  String get clearBackground => _ru ? 'Убрать фон' : 'Clear Background';
  String get applyGlobally => _ru ? 'Применить ко всем чатам' : 'Apply globally';
  String get applyGloballySubtitle => _ru ? 'Использовать этот фон во всех чатах' : 'Use this background in all chats';
  String get blurBackground => _ru ? 'Размыть фон' : 'Blur background';
  String get elementOpacity => _ru ? 'Прозрачность элементов' : 'Element Opacity';
  String get elementBrightness => _ru ? 'Яркость элементов' : 'Element Brightness';
  String get uiLayout => _ru ? 'Макет интерфейса' : 'UI Layout';
  String get navBarPosition => _ru ? 'Позиция навигации' : 'Navigation Bar Position';
  String get navLeft => _ru ? 'Слева' : 'Left';
  String get navBottom => _ru ? 'Снизу' : 'Bottom';
  String get inputBarMaxWidth => _ru ? 'Ширина строки ввода' : 'Input Bar Width';
  String get minimizeBottomNav => _ru ? 'Компактная навигация' : 'Minimize Bottom Nav';
  String get minimizeBottomNavSubtitle => _ru ? 'Скрыть подписи в нижней панели' : 'Hide labels in bottom navigation bar';
  String get swipeTabs => _ru ? 'Свайп между вкладками' : 'Swipe between tabs';
  String get swipeTabsSubtitle => _ru ? 'Переключать вкладки горизонтальным свайпом' : 'Switch tabs with horizontal swipe gesture';
  String get smoothScroll => _ru ? 'Плавная прокрутка' : 'Smooth Scrolling';
  String get performanceOptimizations => _ru ? 'Оптимизация производительности' : 'Performance Optimizations';
  String get macOsWindowStyle => _ru ? 'Стиль окна' : 'Window Style';
  String get macOsWindowStyleSubtitle => _ru ? 'Кнопки управления окном' : 'Window controls style';
  String get macOsNativeTitleBar => _ru ? 'Нативный macOS (светофор слева)' : 'Native macOS (traffic lights)';
  String get macOsCustomTitleBar => _ru ? 'Windows-стиль (справа)' : 'Windows-style (right side)';
  String get updateAvailableLabel => _ru ? 'Доступно обновление' : 'Update available';
  String get updateDownload => _ru ? 'Скачать' : 'Download';

  String get cacheTitle => _ru ? 'Кэш' : 'Cache';
  String get cacheSubtitle => _ru ? 'Управление локальным и серверным кэшем медиа' : 'Manage local & server media cache';
  String get mediaCacheSize => _ru ? 'Кэш медиа: ' : 'Media messages cache: ';
  String get clearLocalCache => _ru ? 'Очистить локальный кэш' : 'Clear Local Cache';
  String get clearLocalCacheTitle => _ru ? 'Очистить локальный кэш?' : 'Clear local cache';
  String get clearLocalCacheContent => _ru
      ? 'Вы уверены, что хотите удалить весь кэшированный медиаконтент (голос, изображения, видео)?\nЗагрузки на сервере и история чатов НЕ затрагиваются.'
      : 'Are you sure you want to delete all cached media (voice, images, videos)?\nThis does NOT affect server uploads or chat history.';
  String get clearAll => _ru ? 'Очистить всё' : 'Clear All';
  String get serverMediaCache => _ru ? 'Серверный кэш медиа' : 'Server Media Cache';
  String get serverMediaCacheSubtitle => _ru ? 'Хранится на сервере: изображения, голос, видео.' : 'Stored on server: images, voice, video.';
  String get clearServerCache => _ru ? 'Очистить серверный кэш' : 'Clear Server Cache';
  String get dangerZone => _ru ? 'Опасная зона' : 'Danger Zone';
  String get dangerZoneSubtitle => _ru ? 'Удалить аккаунт с сервера и/или стереть локальные данные.' : 'Delete account from server and/or wipe local data.';
  String get factoryReset => _ru ? 'Сброс' : 'Factory Reset';
  String get factoryResetHint => _ru ? 'Выберите что сбросить. Нужно выбрать хотя бы один пункт.' : 'Select what to reset. At least one option must be chosen.';
  String get resetDeleteAccount => _ru ? 'Удалить аккаунт с сервера' : 'Delete account from server';
  String resetDeleteAccountSubtitle(String username) => _ru
      ? 'Навсегда удалит @$username — все сообщения, медиа и ключи с сервера.'
      : 'Permanently deletes @$username — all messages, media and keys from the server.';
  String get resetNoAccount => _ru ? 'Нет авторизованного аккаунта.' : 'No account is logged in.';
  String get resetDeleteLocal => _ru ? 'Удалить локальные данные' : 'Delete local app data';
  String get resetDeleteLocalSubtitle => _ru ? 'Удалит все локальные чаты, ключи, настройки, кэш и медиа.' : 'Wipes all local chats, keys, settings, cache and media.';
  String get reset => _ru ? 'Сбросить' : 'Reset';
  String get resetFailed => _ru ? 'Сброс не удался' : 'Reset failed';
  String mediaCachesCleared(int n) => _ru ? ' Очищено $n кэш${n == 1 ? '' : 'а'}' : ' Cleared $n media cache${n == 1 ? '' : 's'}';

  String get connectionTitle => _ru ? 'Соединение' : 'Connection';
  String get connectionSubtitle => _ru ? 'Статус и управление WebSocket' : 'WebSocket status & controls';

  String get proxyTitle => _ru ? 'Прокси' : 'Proxy';
  String get proxySubtitle => _ru ? 'Маршрутизация через HTTP или SOCKS5 прокси' : 'Route traffic through HTTP or SOCKS5 proxy';
  String get enableProxy => _ru ? 'Включить прокси' : 'Enable Proxy';
  String get proxyType => _ru ? 'Тип прокси' : 'Proxy Type';
  String get proxyHost => _ru ? 'Хост' : 'Host';
  String get proxyPort => _ru ? 'Порт' : 'Port';
  String get proxyUsername => _ru ? 'Логин' : 'Username';
  String get proxyPassword => _ru ? 'Пароль' : 'Password';
  String get testProxy => _ru ? 'Проверить прокси' : 'Test Proxy';
  String get proxyTesting => _ru ? 'Проверка...' : 'Testing...';
  String get proxyOk => _ru ? ' Прокси работает' : ' Proxy OK';
  String get proxyFailed => _ru ? ' Прокси недоступен' : ' Proxy unreachable';
  String get useProxy => _ru ? 'Использовать прокси' : 'Use proxy';
  String get proxyDirectConnection => _ru ? 'Прямое подключение' : 'Direct connection';
  String get proxyRouted => _ru ? 'Трафик идёт через прокси' : 'Traffic routed through proxy';
  String get proxyConnectedStatus => _ru ? 'Подключено' : 'Connected';
  String get proxyNotConnectedStatus => _ru ? 'Не подключено' : 'Not connected';
  String get proxyLoginOptional => _ru ? 'Логин (необязательно)' : 'Login (optional)';
  String get proxyPasswordOptional => _ru ? 'Пароль (необязательно)' : 'Password (optional)';
  String get proxyApplyReconnect => _ru ? 'Применить и переподключить' : 'Apply & Reconnect';

  String get appDataTitle => _ru ? 'Папка данных ONYX' : 'ONYX data folder';
  String get appDataSubtitle => _ru ? 'Перенос системной папки данных на другой диск' : 'Move the app data folder to another drive';
  String get appDataCurrentPath => _ru ? 'Текущая папка' : 'Current folder';
  String get appDataDefault => _ru ? 'По умолчанию (системная папка)' : 'Default (system folder)';
  String get appDataMove => _ru ? 'Переместить…' : 'Move…';
  String get appDataReset => _ru ? 'Сбросить' : 'Reset';
  String get appDataMigrating => _ru ? 'Перемещение данных…' : 'Moving data…';
  String get appDataMigrateError => _ru ? 'Ошибка при перемещении' : 'Error during move';
  String get appDataRestartRequired => _ru
      ? 'Папка изменена. Перезапустите ONYX, чтобы изменения вступили в силу.'
      : 'Folder changed. Restart ONYX for the change to take effect.';
  String get appDataRestart => _ru ? 'Перезапустить ONYX' : 'Restart ONYX';
  String get appDataOpenFolder => _ru ? 'Открыть папку' : 'Open folder';
  String get appDataDeleteOldFolder => _ru ? 'Удалить предыдущую папку' : 'Delete previous folder';
  String get appDataDeleteOldFolderSubtitle => _ru
      ? 'Удалить исходную системную папку данных, оставшуюся после переноса'
      : 'Delete the original system data folder left after migration';
  String get appDataDeleteOldFolderConfirm => _ru
      ? 'Удалить исходную папку ONYX?\n\nЭто действие необратимо. Убедитесь, что данные успешно перенесены.'
      : 'Delete the original ONYX data folder?\n\nThis cannot be undone. Make sure data was migrated successfully.';
  String get appDataDeleteOldFolderSuccess => _ru ? 'Предыдущая папка удалена' : 'Previous folder deleted';
  String get appDataDeleteOldFolderError => _ru ? 'Ошибка при удалении: ' : 'Error deleting: ';

  String get interactTitle => _ru ? 'Взаимодействие' : 'Interaction';
  String get interactSubtitle => _ru ? 'Подтверждение загрузки файлов' : 'File upload confirmations';
  String get confirmFileUpload => _ru ? 'Подтверждение отправки файла' : 'Confirm File Upload';
  String get confirmFileUploadSubtitle => _ru ? 'Показывать диалог подтверждения перед отправкой файлов' : 'Show confirmation dialog before sending files';
  String get confirmVoiceMessage => _ru ? 'Подтверждение голосового сообщения' : 'Confirm Voice Message';
  String get confirmVoiceSubtitle => _ru ? 'Показывать диалог подтверждения перед отправкой голосового' : 'Show confirmation dialog before sending voice';

  String get downloadFolder => _ru ? 'Папка для сохранения файлов' : 'Download folder';
  String get downloadFolderSubtitle => _ru ? 'Куда сохранять полученные файлы (по умолчанию: Загрузки/ONYX)' : 'Where to save received files (default: Downloads/ONYX)';
  String get downloadFolderDefault => _ru ? 'По умолчанию (Загрузки/ONYX)' : 'Default (Downloads/ONYX)';
  String get downloadFolderChange => _ru ? 'Выбрать папку' : 'Choose folder';
  String get downloadFolderReset => _ru ? 'Сбросить' : 'Reset';

  String get contactTitle => _ru ? 'Контакты' : 'Contact';
  String get contactSubtitle => _ru ? 'Сайт, репозиторий и обратная связь' : 'Website, repository & feedback';
  String get contactWebsite => _ru ? 'Официальный сайт' : 'Official website';
  String get contactRepository => _ru ? 'Исходный код (клиент)' : 'Source code (client)';
  String get contactRepositoryServer => _ru ? 'Исходный код (self-hosted сервер)' : 'Source code (self-hosted server)';
  String get contactEmail => _ru ? 'Написать нам' : 'Contact us';

  String get debugTitle => _ru ? 'Отладка / Логи' : 'Debug/Logs';
  String get debugSubtitle => _ru ? 'Производительность и журналирование в реальном времени' : 'Real-time performance & logging';
  String get debugMode => _ru ? 'Режим отладки' : 'Debug Mode';
  String get debugModeSubtitle => _ru ? 'Включить мониторинг производительности и логи' : 'Enable performance monitoring & logs';
  String get enableFileLogging => _ru ? 'Запись логов в файл' : 'Enable File Logging';
  String get enableFileLoggingSubtitle => _ru ? 'Записывать логи на диск (отключите для приватности)' : 'Write app logs to disk (disable for privacy)';
  String get deleteAllLogs => _ru ? 'Удалить все логи' : 'Delete All Logs';

  String get languageTitle => _ru ? 'Язык' : 'Language';
  String get languageSubtitle => _ru ? 'Язык интерфейса приложения' : 'App interface language';
  String get languageEnglish => 'English';
  String get languageRussian => 'Русский';
  String get languageChanged => _ru ? 'Язык изменён' : 'Language changed';

  String get noChatsYet => _ru ? 'Чатов пока нет' : 'No chats yet';
  String get deleteChatTitle => _ru ? 'Удалить чат?' : 'Delete chat?';
  String get blockUserLabel => _ru ? 'Заблокировать' : 'Block user';
  String get unblockUserLabel => _ru ? 'Разблокировать' : 'Unblock';
  String get muteUserLabel => _ru ? 'Отключить уведомления' : 'Mute notifications';
  String get unmuteUserLabel => _ru ? 'Включить уведомления' : 'Unmute notifications';
  String get blockedByUserMessage => _ru
      ? 'Этот пользователь ограничил получение сообщений от вас.'
      : 'This user has restricted incoming messages from you.';
  String unblockUserConfirmContent(String name) => _ru
      ? 'Разблокировать $name?'
      : 'Unblock $name?';
  String blockUserConfirmContent(String name) => _ru
      ? 'Заблокировать $name? Они не смогут отправлять вам сообщения.'
      : 'Block $name? They won\'t be able to send you messages.';
  String deleteChatContent(String name) => _ru
      ? 'Удалить чат с "$name"? Это действие необратимо.'
      : 'Are you sure you want to delete the chat with "$name"? This action cannot be undone.';

  String localizePreview(String key) {
    if (!_ru) return key;
    
    if (key.startsWith('Album · ') && key.endsWith(' photos')) {
      final countStr = key.substring('Album · '.length, key.length - ' photos'.length);
      final n = int.tryParse(countStr);
      if (n != null) return 'Альбом · $n фото';
    }
    if (key.startsWith('[Message not decrypted]')) return '[Сообщение не расшифровано]';
    const map = {
      'Voice message': 'Голосовое',
      'Music': 'Музыка',
      'Video file': 'Видео',
      'Video': 'Видео',
      'Image': 'Фото',
      'Album': 'Альбом',
      'File': 'Файл',
      'Document': 'Документ',
      'Spreadsheet': 'Таблица',
      'Presentation': 'Презентация',
      'Archive': 'Архив',
      'Artifact': 'Код',
    };
    return map[key] ?? key;
  }

  String get editProfile => _ru ? 'Профиль' : 'Edit Profile';
  String get displayName => _ru ? 'Отображаемое имя' : 'Display Name';
  String get addAccount => _ru ? 'Добавить аккаунт' : 'Add Account';
  String get welcomeTitle => _ru ? 'Добро пожаловать' : 'Welcome';
  String get welcomeTagline => _ru ? 'Безопасный мессенджер с шифрованием' : 'Secure end-to-end encrypted messenger';
  String get otherAccounts => _ru ? 'Другие аккаунты' : 'Other Accounts';
  String get tapToSwitch => _ru ? 'Нажмите для входа' : 'Tap to switch';
  String get deleteFromRecentTitle => _ru ? 'Удалить из недавних?' : 'Delete account from recent?';

  String get authUsernameLabel => _ru ? 'Юзернейм (3–16 симв.)' : 'Username (3-16 chars)';
  String get authPasswordLabel => _ru ? 'Пароль (мин. 16 симв.)' : 'Password (min 16 chars)';
  String get loginBtn => _ru ? 'Войти' : 'Login';
  String get registerBtn => _ru ? 'Регистрация' : 'Register';

  // QR auth / device linking
  String get deviceAuthTitle => _ru ? 'Привязать устройство' : 'Link Device';
  String get deviceAuthTabQr => 'QR';
  String get deviceAuthTabScan => _ru ? 'Скан' : 'Scan';
  String get deviceAuthLanNote => _ru
      ? 'Оба устройства должны быть в одной локальной сети'
      : 'Both devices must be on the same local network';
  String get loginWithQr => _ru ? 'Войти по QR' : 'Login via QR';
  String get qrAuthWaitingTitle => _ru ? 'Ожидание телефона' : 'Waiting for phone';
  String get qrAuthWaitingSubtitle => _ru
      ? 'Отсканируйте этот код на авторизованном устройстве — оно передаст сессию на этот экран'
      : 'Scan this code on an authorized device to transfer the session here';
  String get qrAuthSuccess => _ru ? 'Устройство авторизовано' : 'Device authorized';
  String get qrAuthFailed => _ru ? 'Ошибка QR-авторизации' : 'QR auth failed';
  String get qrAuthCancelled => _ru ? 'QR-авторизация отменена' : 'QR auth cancelled';
  String get authorizeDevice => _ru ? 'Авторизовать устройство' : 'Authorize device';
  String get authorizeDeviceSubtitle => _ru
      ? 'Разрешить другому устройству войти через QR-код'
      : 'Allow another device to log in by scanning a QR code';
  String get authorizeDeviceScanHint => _ru
      ? 'Наведите камеру на QR-код, отображаемый на другом устройстве'
      : 'Point the camera at the QR code shown on the other device';
  String get authorizeDeviceSuccess => _ru ? 'Устройство успешно авторизовано' : 'Device authorized successfully';
  String get authorizeDeviceFailed => _ru ? 'Не удалось авторизовать устройство' : 'Failed to authorize device';
  String get authorizeDeviceSending => _ru ? 'Отправка данных...' : 'Sending credentials…';
  String get qrAuthEncryptedNote => _ru
      ? 'Передача зашифрована (X25519 + AES-256-GCM)'
      : 'Transfer is encrypted (X25519 + AES-256-GCM)';
  // Desktop → Phone grant flow
  String get scanFromPc => _ru ? 'Получить с компьютера' : 'Receive from PC';
  String get scanFromPcHint => _ru
      ? 'Наведите камеру на QR-код, отображаемый на другом устройстве, чтобы войти здесь'
      : 'Point the camera at the QR code shown on another device to sign in here';
  String get grantDeviceTitle => _ru ? 'Авторизовать телефон' : 'Authorize phone';
  String get grantDeviceSubtitle => _ru
      ? 'Отсканируйте этот код на другом устройстве — оно получит доступ к этому аккаунту'
      : 'Scan this code on another device to sign in there with this account';
  String get grantDeviceSuccess => _ru ? 'Телефон успешно авторизован' : 'Phone authorized successfully';
  String get grantDeviceFailed => _ru ? 'Не удалось авторизовать телефон' : 'Failed to authorize phone';
  String get enterUsernameMsg => _ru ? 'Введите имя пользователя' : 'Enter your username';
  String get loginSuccess => _ru ? 'Вход выполнен' : 'Login successful';
  String get loginFailed => _ru ? 'Ошибка входа' : 'Login failed';
  String get registeringMsg => _ru ? 'Регистрация...' : 'Registering...';
  String get registrationFailed => _ru ? ' Ошибка регистрации' : ' Registration failed';
  String get usernameInvalidMsg => _ru ? 'Юзернейм: 3–16 симв., только буквы, цифры, _ . -' : 'Username: 3-16 chars, only letters, digits, _ . -';
  String get passwordTooShortMsg => _ru ? 'Пароль слишком короткий (мин. 16)' : 'Password too short (min 16)';
  String get generatePasswordTooltip => _ru ? 'Сгенерировать надёжный пароль' : 'Generate strong password';
  String get savePasswordWarning => _ru
      ? 'Обязательно сохраните пароль в надёжном месте — запишите его. Восстановление без пароля невозможно.'
      : 'Make sure to save your password in a safe place — write it down. Recovery without a password is impossible.';

  String get passphraseWriteDown => _ru
      ? 'Запишите эти 12 слов и храните их в надёжном месте. Они нужны для смены пароля.'
      : 'Write down these 12 words and store them somewhere safe. They are needed to change your password.';
  String get passphraseWriteOnPaper => _ru
      ? 'Запишите секретную фразу на бумаге и положите в надёжное место!'
      : 'Write your passphrase on paper and keep it in a safe place!';
  String get copyToClipboard => _ru ? 'Копировать в буфер' : 'Copy to clipboard';
  String get copiedToClipboard => _ru ? 'Скопировано!' : 'Copied!';
  String passphraseCountdown(int s) => _ru ? 'Прочитайте внимательно — доступно через $s с...' : 'Please read carefully — available in $s s...';
  String get iSavedIt => _ru ? 'Я сохранил(-а)' : "I've saved it";
  String deleteFromRecentContent(String acc) => _ru
      ? 'Удалить "$acc" из списка? Аккаунт на сервере не будет удалён.'
      : 'Are you sure you want to remove "$acc" from the recent list?\nThis does not delete the account from the server.';

  String get createGroupChannel => _ru ? 'Создать группу/канал' : 'Create Group/Channel';
  String get channelAdminOnly => _ru ? 'Канал (только администратор)' : 'Channel (only admin posts)';
  String get viewByToken => _ru ? 'Просмотр по токену' : 'View by token';
  String get viewByIp => _ru ? 'Просмотр по IP (внешний сервер)' : 'View by IP (external server)';
  String get createGroupOrChannel => _ru ? 'Создать группу или канал' : 'Create group or channel';
  String get removeExternalServerTitle => _ru ? 'Удалить внешний сервер?' : 'Remove external server?';
  String removeExternalServerContent(String name) => _ru
      ? 'Удалить "$name" и все его группы из списка? Вы сможете переподключиться позже.'
      : 'Remove "$name" and all its groups from your list? You can rejoin later by entering the server address again.';
  String get noGroupsYet => _ru ? 'Групп пока нет' : 'No groups yet';
  String get groupNameLabel => _ru ? 'Название группы:' : 'Group name:';
  String get groupNameHint => _ru ? 'Введите название' : 'Enter name';
  String get pasteToken => _ru ? 'Вставьте токен:' : 'Paste token:';
  String get create => _ru ? 'Создать' : 'Create';
  String get view => _ru ? 'Просмотр' : 'View';
  String get leave => _ru ? 'Выйти' : 'Leave';
  String get remove => _ru ? 'Удалить' : 'Remove';
  String get leaveGroupAction => _ru ? 'Покинуть' : 'Leave';
  String leaveGroupTitle(bool isChannel) => _ru
      ? 'Покинуть ${isChannel ? "канал" : "группу"}?'
      : 'Leave ${isChannel ? "channel" : "group"}?';
  String leaveGroupContent(String name) => _ru
      ? 'Покинуть "$name"? Вы больше не будете получать сообщения из неё.'
      : 'Are you sure you want to leave "$name"? You will no longer receive messages from it.';

  String get chooseCrypto => _ru ? 'Выберите криптовалюту для доната' : 'Choose a crypto to donate';
  String get addressCopied => _ru ? 'адрес скопирован' : 'address copied';

  String get hideFromSearch => _ru ? 'Не показывать меня в поиске' : 'Hide me from search';
  String get hideFromSearchSubtitle => _ru ? 'Другие пользователи не смогут найти вас по имени' : 'Others won\'t find you by username search';
  String get hideFromSearchSavedOk => _ru ? ' Настройки приватности сохранены' : ' Privacy settings saved';
  String get hideFromSearchSavedFail => _ru ? ' Сохранено локально, ошибка синхронизации' : ' Saved locally, failed to sync';

  String get statusVisibility => _ru ? 'Видимость' : 'Visibility';
  String get statusShowStatus => _ru ? 'Показывать' : 'Show Status';
  String get statusHideStatus => _ru ? 'Скрывать' : 'Hide Status';
  String get statusCustomText => _ru ? 'Текст статуса' : 'Custom Status Text';
  String get statusWhenOnline => _ru ? 'Когда онлайн' : 'When Online';
  String get statusWhenOffline => _ru ? 'Когда офлайн' : 'When Offline';
  String get statusSavedOk => _ru ? ' Настройки статуса сохранены и синхронизированы' : ' Status settings saved and synced';
  String get statusSavedFail => _ru ? ' Сохранено локально, ошибка синхронизации' : ' Saved locally, failed to sync to server';

  String get clearServerCacheTitle => _ru ? 'Очистить серверный кэш?' : 'Clear server media?';
  String get clearServerCacheContent => _ru
      ? 'Это удалит все загруженные медиа с сервера:\n'
        '• Голосовые сообщения\n'
        '• Изображения\n'
        '• Видео\n'
        '• Файлы\n'
        '• Аватар\n\n'
        'Локальный кэш останется. Действие необратимо.'
      : 'This will delete ALL your uploaded media from the server, including:\n'
        '• Voice messages\n'
        '• Images\n'
        '• Videos\n'
        '• Files\n'
        '• Avatar\n\n'
        'Local cache will remain. This action cannot be undone.';
  String get serverMediaCleared => _ru ? ' Серверный кэш полностью очищен' : ' All server media cleared';
  String get notLoggedIn => _ru ? 'Не авторизован' : 'Not logged in';

  // Cache manager screen
  String get serverMediaManagerTitle => _ru ? 'Серверные медиа' : 'Server Media';
  String get cacheTabImages => _ru ? 'Изображения' : 'Images';
  String get cacheTabVoice => _ru ? 'Голос' : 'Voice';
  String get cacheTabAudio => _ru ? 'Аудио' : 'Audio';
  String get cacheTabVideo => _ru ? 'Видео' : 'Video';
  String get cacheTabFiles => _ru ? 'Файлы' : 'Files';
  String get cacheTabDocuments => _ru ? 'Документы' : 'Documents';
  String get cacheTabArchives => _ru ? 'Архивы' : 'Archives';
  String get cacheTabData => _ru ? 'Данные' : 'Data';
  String get cacheTabAvatars => _ru ? 'Аватары' : 'Avatars';
  String get cacheNoFiles => _ru ? 'Нет файлов в этой категории' : 'No files in this category';
  String get cacheClearTabTitle => _ru ? 'Очистить категорию?' : 'Clear category?';
  String cacheClearTabContent(String typeName) => _ru
      ? 'Удалить все файлы в категории "$typeName"? Действие необратимо.'
      : 'Delete all files in "$typeName"? This cannot be undone.';
  String cacheFilesDeleted(int n) => _ru
      ? 'Удалено файлов: $n'
      : 'Deleted $n file${n == 1 ? '' : 's'}';
  String get cacheFileDeleteFailed => _ru ? 'Не удалось удалить файл' : 'Failed to delete file';
  String get cacheClearAll => _ru ? 'Очистить всё' : 'Clear All';
  String get cacheClearTab => _ru ? 'Очистить вкладку' : 'Clear tab';
  String get cleanUnusedFiles => _ru ? 'Очистить неиспользуемые файлы' : 'Clean unused files';
  String get cleaningUnusedFiles => _ru ? 'Очистка...' : 'Cleaning...';
  String get orphanedCleanupAppNotReady => _ru ? 'Приложение ещё не готово' : 'App not ready';
  String get orphanedCleanupNoFiles => _ru ? 'Неиспользуемые файлы не найдены' : 'No unused files found';
  String orphanedCleanupDeleted(int files, String freedMb) => _ru
      ? 'Удалено $files неиспользуем${files == 1 ? 'ый файл' : files < 5 ? 'ых файла' : 'ых файлов'} ($freedMb MB освобождено)'
      : 'Deleted $files unused file${files == 1 ? '' : 's'} ($freedMb MB freed)';
  String get manageCacheTitle => _ru ? 'Управление кэшем' : 'Manage Cache';
  String get manageCacheButton => _ru ? 'Управление кэшем медиа' : 'Manage Media Cache';
  String get localCacheTab => _ru ? 'Локальный' : 'Local';
  String get serverCacheTab => _ru ? 'Серверный' : 'Server';
  String get cacheSelectAll => _ru ? 'Выбрать все' : 'Select all';
  String get cacheDeselectAll => _ru ? 'Снять выбор' : 'Deselect all';
  String get cacheSelected => _ru ? 'выбрано' : 'selected';
  String get clearLocalCacheDialogTitle => _ru ? 'Очистить кэш?' : 'Clear local cache';
  String get clearLocalCacheDialogContent => _ru
      ? 'Удалить весь кэшированный медиаконтент (голос, фото, видео)?\nЗагрузки на сервере и история чатов не затрагиваются.'
      : 'Are you sure you want to delete all cached media (voice, images, videos)?\nThis does NOT affect server uploads or chat history.';

  String get deleteAllLogsTitle => _ru ? 'Удалить все логи?' : 'Delete all logs?';
  String get deleteAllLogsContent => _ru
      ? 'Все файлы логов будут безвозвратно удалены с диска.\nДействие необратимо.'
      : 'This will permanently delete all app log files from disk.\nThis action cannot be undone.';
  String get noLogsFound => _ru ? 'Лог-файлы не найдены.' : 'No log files found.';
  String deletedLogsCount(int n) => _ru
      ? 'Удалено лог-файлов: $n.'
      : 'Deleted $n log file${n == 1 ? '' : 's'}.';

  String get changePasswordInfo => _ru
      ? 'Введите фразу восстановления и текущий пароль для установки нового.'
      : 'Enter your recovery passphrase and current password to set a new password.';
  String get changePasswordPassphraseLabel => _ru ? 'Фраза восстановления (12 слов)' : 'Recovery passphrase (12 words)';
  String get changePasswordCurrentLabel => _ru ? 'Текущий пароль' : 'Current password';
  String get changePasswordNewLabel => _ru ? 'Новый пароль (минимум 16 символов)' : 'New password (min 16 chars)';
  String get changePasswordChange => _ru ? 'Изменить' : 'Change';
  String get changePasswordFieldsRequired => _ru ? 'Заполните все поля' : 'All fields are required';
  String get changePasswordTooShort => _ru ? 'Новый пароль должен содержать минимум 16 символов' : 'New password must be at least 16 characters';
  String get changePasswordChanging => _ru ? 'Изменение пароля...' : 'Changing password...';
  String get changePasswordSuccess => _ru ? ' Пароль успешно изменён' : ' Password changed successfully';

  String get clearBgTitle => _ru ? 'Убрать фон?' : 'Clear background?';
  String get clearBgContent => _ru ? 'Убрать пользовательский фон чата и восстановить стандартный.' : 'Remove custom chat background and restore default.';
  String get chatBgSet => _ru ? ' Фон чата установлен' : ' Chat background set';
  String get chatBgCleared => _ru ? 'Фон убран' : 'Background cleared';

  String get allMessagesLeft => _ru ? 'Все сообщения: слева' : 'All messages: Left';
  String get allMessagesRight2 => _ru ? 'Все сообщения: справа' : 'All messages: Right';
  String get allMessagesMixed => _ru ? 'Все сообщения: смешанно' : 'All messages: Mixed';
  String get applyBackgroundToApp => _ru ? 'Применить фон во всём приложении' : 'Apply background to whole app';
  String get uiElementsOpacityLabel => _ru ? 'Прозрачность элементов' : 'UI Elements Opacity';
  String get uiElementsBrightnessLabel => _ru ? 'Яркость элементов' : 'UI Elements Brightness';
  String get navPanelPosition => _ru ? 'Позиция панели навигации' : 'Navigation Panel Position';
  String get navPosBottom => _ru ? 'Снизу (под списком чатов)' : 'Bottom (under chat list)';
  String get navPosLeft => _ru ? 'Слева (боковая панель)' : 'Left (sidebar)';
  String get tabSwiping => _ru ? 'Свайп между вкладками' : 'Tab Swiping';
  String get tabSwipingSubtitle => _ru ? 'Переключать вкладки свайпом' : 'Swipe between tabs with a bounce effect';
  String get showAvatarsInChats => _ru ? 'Аватары в чатах' : 'Show avatars in chats';
  String get smoothScrollDown => _ru ? 'Плавная прокрутка' : 'Smooth scroll down';
  String get messageAnimations => _ru ? 'Анимации сообщений' : 'Message animations';
  String get chatListMoveAnimations => _ru ? 'Анимация перемещения чатов' : 'Chat list move animations';
  String get scrollDownButtonPosition => _ru ? 'Положение кнопки вниз' : 'Scroll-down button position';
  String get scrollDownButtonPositionLeft => _ru ? 'Слева' : 'Left';
  String get scrollDownButtonPositionCenter => _ru ? 'По центру' : 'Center';
  String get scrollDownButtonPositionRight => _ru ? 'Справа' : 'Right';
  String get scrollDownButtonSize => _ru ? 'Размер кнопки вниз' : 'Scroll-down button size';
  String get loadOlderMessagesOnScroll => _ru ? 'Старые сообщения' : 'Load older messages on scroll';
  String get showSnackbars => _ru ? 'Всплывающие уведомления' : 'Show snackbars';
  String get autoLoadVideos => _ru ? 'Загружать видео сразу' : 'Auto-load videos';
  String get autoLoadVideosSubtitle => _ru
      ? 'Когда выключено, видео грузятся только по нажатию — меньше лагов при прокрутке'
      : 'When off, videos load only on tap — smoother scrolling';
  String get tapToLoadVideo => _ru ? 'Нажмите, чтобы загрузить' : 'Tap to load video';
  String get chooseBackground => _ru ? 'Выбрать' : 'Choose';
  String get presetsBackground => _ru ? 'Пресеты' : 'Presets';
  String get clearBackground2 => _ru ? 'Очистить' : 'Clear';
  String get liquidGlassSubtitle => _ru ? 'Настройки эффектов стекла для каждого элемента' : 'Configure glass effects and quality per element';
  String get liquidGlassNavBarLabel => _ru ? 'Навигационная панель' : 'Navigation Bar';
  String get liquidGlassNavBarDesc => _ru ? 'Эффект стекла нижней навигации' : 'Glass effect on the bottom navigation bar';
  String get liquidGlassCardsLabel => _ru ? 'Карточки и список' : 'Cards & List Items';
  String get liquidGlassCardsDesc => _ru ? 'Эффект стекла в списке чатов и настройках' : 'Glass effect on chat list and settings cards';
  String get liquidGlassInputLabel => _ru ? 'Панель ввода' : 'Input Bar';
  String get liquidGlassInputDesc => _ru ? 'Эффект стекла панели ввода' : 'Glass effect on the message composition bar';
  String get liquidGlassSearchLabel => _ru ? 'Поиск' : 'Search';
  String get liquidGlassSearchDesc => _ru ? 'Стеклянная панель поиска' : 'Spotlight-style glass panel for user search';
  String get sendFavoritesScanHint => _ru ? 'Наведите камеру на QR-код\nна устройстве получателя' : 'Point the camera at the QR code shown on the receiver device';
  String get mediaPickerGallery => _ru ? 'Галерея' : 'Gallery';
  String get mediaPickerCamera => _ru ? 'Камера' : 'Camera';
  String get mediaPickerFile => _ru ? 'Файл' : 'File';
  String mediaPickerSend(int n) => _ru ? 'Отправить $n' : 'Send $n';
  String get mediaPickerChooseWallpaper => _ru ? 'Выбрать обои' : 'Choose wallpaper';
  String get mediaPickerFiles => _ru ? 'Файлы' : 'Files';
  String get mediaPickerDeniedTitle => _ru ? 'Доступ к галерее запрещён' : 'Gallery access denied';
  String get mediaPickerDeniedBody => _ru ? 'Разрешите доступ в настройках или выберите файл напрямую.' : 'Allow access in settings or pick a file directly.';
  String get mediaPickerPickFile => _ru ? 'Выбрать файл' : 'Pick File';
  String get mediaPickerOpenSettings => _ru ? 'Настройки' : 'Open Settings';

  String get notifWarning => _ru
      ? 'Уведомления доставляются только пока приложение запущено в фоне. Чтобы не пропускать сообщения, держите ONYX свёрнутым.'
      : 'Notifications are delivered only while the app is running. To never miss a message, keep ONYX minimised to the system tray instead of closing it.';
  String notifEnabledSubtitle(bool enabled) => _ru
      ? (enabled ? 'Вы будете получать уведомления о новых сообщениях' : 'Все уведомления отключены')
      : (enabled ? 'You will be alerted for new messages' : 'All notifications are silenced');
  String get notifPopupPosition => _ru ? 'Позиция попапа' : 'Popup position';
  String get notifPopupPositionSubtitle => _ru ? 'Выберите угол экрана для показа уведомлений' : 'Choose where the notification popup appears on screen';
  String localizeNotifPosition(String pos) {
    if (!_ru) {
      const map = {
        'top_left': '↖  Top left',
        'top_right': '↗  Top right',
        'bottom_left': '↙  Bottom left',
        'bottom_right': '↘  Bottom right',
      };
      return map[pos] ?? pos;
    }
    const map = {
      'top_left': '↖  Сверху слева',
      'top_right': '↗  Сверху справа',
      'bottom_left': '↙  Снизу слева',
      'bottom_right': '↘  Снизу справа',
    };
    return map[pos] ?? pos;
  }
  String get notifEnableLabel => _ru ? 'Включить уведомления' : 'Enable notifications';

  String get notifHideContentLabel => _ru ? 'Скрывать содержимое' : 'Hide message content';
  String notifHideContentSubtitle(bool hidden) => _ru
      ? (hidden ? 'Уведомления без текста сообщения' : 'Показывать текст сообщения')
      : (hidden ? 'Notifications without message text' : 'Show message text in notifications');

  String get notifSoundEnableLabel => _ru ? 'Звук уведомлений' : 'Notification sound';
  String notifSoundEnabledSubtitle(bool enabled) => _ru
      ? (enabled ? 'Звук включён' : 'Звук выключен')
      : (enabled ? 'Sound enabled' : 'Sound disabled');
  String get notifSoundChooseLabel => _ru ? 'Выберите звук' : 'Choose sound';

  String get notifSoundCustom => _ru ? 'Загрузить свой звук...' : 'Upload custom sound...';
  String get notifSoundCustomLoaded => _ru ? 'Кастомный звук установлен' : 'Custom sound set';
  String get notifSoundCustomError => _ru ? 'Не удалось загрузить звук' : 'Failed to load sound';
  String get notifSoundCustomInvalidFormat => _ru
      ? 'Поддерживаются: WAV, MP3, M4A, OGG, AAC'
      : 'Supported: WAV, MP3, M4A, OGG, AAC';

  String localizeNotifSound(String sound) {
    if (sound.startsWith('custom:')) {
      final name = sound.substring(7);
      return _ru ? 'Свой: $name' : 'Custom: $name';
    }
    if (!_ru) {
      const map = {
        'notification0': 'Default',
        'notification1': 'Alert',
        'notification2': 'Gentle',
      };
      return map[sound] ?? sound;
    }
    const map = {
      'notification0': 'Стандартный',
      'notification1': 'Сигнал',
      'notification2': 'Мягкий',
    };
    return map[sound] ?? sound;
  }

  String get resetting => _ru ? 'Сброс...' : 'Resetting...';

  String get launchAtStartupLabel => _ru ? 'Автозапуск' : 'Launch at startup';
  String get launchAtStartupSubtitle => _ru
      ? 'Запускать ONYX автоматически при входе в систему'
      : 'Automatically start ONYX when you log in';
  String get launchAtStartupEnabled => _ru ? 'Автозапуск включён' : 'Launch at startup enabled';
  String get launchAtStartupDisabled => _ru ? 'Автозапуск отключён' : 'Launch at startup disabled';
  String get launchAtStartupFailed => _ru ? 'Не удалось изменить автозапуск' : 'Failed to change startup setting';
  String get avatarUpdated => _ru ? 'Аватар обновлён' : 'Avatar updated';
  String get fileNotFound => _ru ? 'Файл не найден' : 'File not found';
  String get fileSent => _ru ? 'Файл отправлен' : 'File sent';
  String get imageSent => _ru ? 'Изображение отправлено' : 'Image sent';
  String get videoSent => _ru ? 'Видео отправлено' : 'Video sent';
  String uploadingFile(String name) => _ru ? 'Загрузка $name...' : 'Uploading $name...';
  String albumSent(int n) => _ru ? 'Альбом отправлен ($n фото)' : 'Album sent ($n images)';
  String get fileEmpty => _ru ? 'Файл пустой' : 'File is empty';
  String get networkError => _ru ? 'Ошибка сети' : 'Network error';
  String get avatarRemoved => _ru ? 'Аватар удалён' : 'Avatar removed';
  String get uinCopied => _ru ? 'UIN скопирован' : 'UIN copied';
  String get displayNameLength => _ru ? 'Имя должно быть от 1 до 16 символов' : 'Display name must be 1–16 characters';
  String get failedSendLan => _ru ? 'Ошибка отправки по LAN' : 'Failed to send via LAN';
  String get fileCancelled => _ru ? 'Отправка отменена' : 'File cancelled';
  String get doneRestarting => _ru ? 'Готово! Перезапуск...' : 'Done! Restarting...';

  String get deleteMessageTitle => _ru ? 'Удалить сообщение?' : 'Delete message?';
  String get deleteMessageContent => _ru ? 'Сообщение будет удалено для обеих сторон.' : 'This message will be deleted for both sides.';
  String get cannotDeleteMsg => _ru ? 'Нельзя удалить: сообщение ещё не сохранено на сервере' : 'Cannot delete: message not yet saved on server';
  String get msgCopied => _ru ? 'Скопировано' : 'Copied';
  String copiedUsername(String name) => _ru ? 'Скопировано @$name' : 'Copied @$name';
  String get deliveryModeTitle => _ru ? 'Режим доставки' : 'Choose delivery mode';
  String get deliveryInternet => _ru ? 'Интернет' : 'Internet';
  String get deliveryInternetSubtitle => _ru ? 'Отправка через сервер (зашифровано)' : 'Send via server (encrypted)';
  String get deliveryLanSubtitle => _ru ? 'Отправка по локальной сети (напрямую)' : 'Send via local network (direct)';
  String get deliveryUserNotInLan => _ru ? 'Пользователь не найден в LAN' : 'User not found in LAN';
  String get fastChange => _ru ? 'Быстрое переключение' : 'Fast change';
  String get fastChangeSubtitle => _ru ? 'Переключать режим долгим нажатием' : 'Toggle mode on long press';
  String get lanModeEnabled => _ru ? 'Режим LAN включён' : 'LAN mode enabled';
  String get internetModeEnabled => _ru ? 'Режим интернет включён' : 'Internet mode enabled';
  String get previewMessageTitle => _ru ? 'Предпросмотр сообщения' : 'Preview Message';
  String get previewYourMessage => _ru ? 'Ваше сообщение:' : 'Your message:';
  String replyingTo(String name) => _ru ? 'Ответ: $name' : 'Replying to: $name';
  String get send => _ru ? 'Отправить' : 'Send';
  String get fileSentLan => _ru ? 'Файл отправлен по LAN' : 'File sent via LAN';
  String uploadingImages(int n) => _ru ? 'Загрузка $n изображений...' : 'Uploading $n images...';
  String get albumUploadFailed => _ru ? 'Ошибка загрузки альбома' : 'Album upload failed';
  String get message => _ru ? 'Написать' : 'Message';
  String get noMessagesYet => _ru ? 'Нет сообщений' : 'No messages yet';
  String get voiceCallsTitle => _ru ? 'Голосовые звонки' : 'Voice Calls';
  String get voiceCallsContent => _ru
      ? 'Голосовые звонки пока работают только через LAN (локальная сеть).\n\n'
        'Мы собираем средства на поддержку сервера и разработку альтернативы.'
      : 'Voice calls currently work only over LAN (local network).\n\n'
        'We are raising funds for central server maintenance and development of an alternative.';
  String get supportOnyxBtn => _ru ? 'Задонатить' : 'Support ONYX';
  String get call => _ru ? 'Позвонить' : 'Call';
  String get securityCheckTitle => _ru ? 'Проверка безопасности' : 'Security check';
  String securityCheckContent(String name) => _ru
      ? 'Сравните эти эмодзи с $name.\nЕсли совпадают — ваш чат защищён.'
      : 'Compare these emojis with $name.\nIf they match — your chat is secure.';
  String get failedToFetchPubkey => _ru ? 'Ошибка получения публичного ключа' : 'Failed to fetch pubkey';
  String get userHasNoPubkey => _ru ? 'У пользователя нет публичного ключа' : 'User has no pubkey';

  String get galleryMenuLabel => _ru ? 'Галерея' : 'Gallery';
  String get galleryTitle => _ru ? 'Галерея' : 'Gallery';
  String get galleryTabMedia => _ru ? 'Медиа' : 'Media';
  String get galleryTabVoice => _ru ? 'Голосовые' : 'Voice';
  String get galleryTabFiles => _ru ? 'Файлы' : 'Files';
  String get galleryEmptyMedia => _ru ? 'Нет фото и видео' : 'No photos or videos yet';
  String get galleryEmptyVoice => _ru ? 'Нет голосовых сообщений' : 'No voice messages yet';
  String get galleryEmptyFiles => _ru ? 'Нет файлов' : 'No files yet';

  String get failedDelete => _ru ? 'Не удалось удалить' : 'Failed to delete';
  String get failedEdit => _ru ? 'Не удалось изменить сообщение' : 'Failed to edit message';
  String get noInternetCached => _ru ? 'Нет интернета — показаны кэшированные сообщения' : 'No internet — showing cached messages';
  String get sendFailed => _ru ? 'Ошибка отправки' : 'Send failed';
  String get mediaUploadNotSupportedWeb => _ru ? 'Загрузка медиа недоступна в веб-версии' : 'Media upload not supported on web';
  String get localFileRequired => _ru ? 'Требуется локальный файл' : 'Local file required';
  String get uploadFailed => _ru ? 'Ошибка загрузки' : 'Upload failed';
  String get voiceUploadFailed => _ru ? 'Ошибка загрузки голосового' : 'Voice upload failed';
  String get voiceCancelled => _ru ? 'Голосовое отменено' : 'Voice message cancelled';
  String get uploadingVoice => _ru ? 'Загрузка голосового...' : 'Uploading voice...';
  String get leftGroup => _ru ? 'Вы вышли из группы' : 'You have left the group';
  String get failedLeaveGroup => _ru ? 'Не удалось покинуть группу' : 'Failed to leave group';
  String get avatarOnlyOwnerMod => _ru ? 'Только владелец и модераторы могут менять аватар' : 'Only owners and moderators can change the avatar';
  String get failedReadFile => _ru ? 'Не удалось прочитать файл' : 'Failed to read file';
  String get uploadingAvatar => _ru ? 'Загрузка аватара...' : 'Uploading avatar...';
  String get avatarUpdatedGroup => _ru ? 'Аватар группы обновлён' : 'Group avatar updated';
  String get avatarDeleted => _ru ? 'Аватар удалён' : 'Avatar deleted';
  String get failedDeleteAvatar => _ru ? 'Не удалось удалить аватар' : 'Failed to delete avatar';
  String get copyLink => _ru ? 'Скопировать ссылку' : 'Copy link';
  String get tokenCopied => _ru ? 'Токен скопирован' : 'Token copied';
  String get groupNameLength => _ru ? 'Название группы: 1–50 символов' : 'Group name must be 1–50 chars';
  String get groupUpdated => _ru ? 'Группа обновлена' : 'Group updated';
  String get failedUpdateGroup => _ru ? 'Не удалось обновить группу' : 'Failed to update group';
  String get deleteAvatarTitle => _ru ? 'Удалить аватар?' : 'Delete avatar?';
  String get deleteAvatarContent => _ru ? 'Аватар группы будет удалён для всех.' : 'This will remove the group avatar for everyone.';
  String get deleteGroupMsgContent => _ru ? 'Сообщение будет удалено для всех участников.' : 'This message will be deleted for everyone.';
  String get reply => _ru ? 'Ответить' : 'Reply';
  String get edit => _ru ? 'Изменить' : 'Edit';
  String get editGroupTitle => _ru ? 'Редактировать группу' : 'Edit group';
  String get editChannelTitle => _ru ? 'Редактировать канал' : 'Edit channel';
  String get channelNameLabel => _ru ? 'Название канала' : 'Channel name';
  String get channelNameHint => _ru ? 'Введите название канала' : 'Enter channel name';
  String memberCount(int n) {
    if (!_ru) return '$n ${n == 1 ? 'member' : 'members'}';
    final mod10 = n % 10, mod100 = n % 100;
    final word = (mod10 == 1 && mod100 != 11)
        ? 'участник'
        : (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20))
            ? 'участника'
            : 'участников';
    return '$n $word';
  }
  String unsupportedFileType(String ext) => _ru ? 'Неподдерживаемый тип файла: $ext' : 'Unsupported file type: $ext';

  String failedToConnect(String e) => _ru ? 'Ошибка подключения: $e' : 'Failed to connect: $e';
  String roleChanged(String role) => _ru ? 'Ваша роль изменена на $role' : 'Your role was changed to $role';
  String get unbannedReconnecting => _ru ? 'Вы разбанены! Переподключение...' : 'You have been unbanned! Reconnecting...';
  String get onlyModsCanPost => _ru ? 'Только владелец и модераторы могут писать в каналах' : 'Only owner and moderators can post in channels';
  String get failedSendMessage => _ru ? 'Ошибка отправки сообщения' : 'Failed to send message';
  String get uploadFailedConnectionAborted => _ru
      ? 'Ошибка загрузки: соединение прервано. Попробуйте файл меньшего размера.'
      : 'Upload failed: Connection aborted. Try smaller file or check server settings.';
  String get failedSendMedia => _ru ? 'Ошибка отправки медиа' : 'Failed to send media';
  String get joinedGroup => _ru ? 'Вы присоединились к группе!' : 'You have joined the group!';
  String get failedJoinGroup => _ru ? 'Не удалось вступить в группу' : 'Failed to join group';
  String get cancelled => _ru ? 'Отменено' : 'Cancelled';
  String get avatarWillBeDeleted => _ru ? 'Аватар будет удалён' : 'Avatar will be deleted';
  String get ipCopied => _ru ? 'IP скопирован' : 'IP copied';
  String get nameCannotBeEmpty => _ru ? 'Название не может быть пустым' : 'Name cannot be empty';
  String get groupRenamed => _ru ? 'Группа переименована' : 'Group renamed successfully';
  String errorMsg(String e) => _ru ? 'Ошибка: $e' : 'Error: $e';
  String get failedRename => _ru ? 'Ошибка переименования' : 'Failed to rename';
  String get imageTooLarge => _ru ? 'Изображение слишком большое (макс. 5 МБ)' : 'Image too large (max 5MB)';
  String get avatarUpdatedSuccessfully => _ru ? 'Аватар обновлён' : 'Avatar updated successfully';
  String get failedUploadAvatar => _ru ? 'Ошибка загрузки аватара' : 'Failed to upload avatar';
  String get deletingAvatar => _ru ? 'Удаление аватара...' : 'Deleting avatar...';
  String get avatarDeletedSuccessfully => _ru ? 'Аватар удалён' : 'Avatar deleted successfully';
  String userBanned(String name) => _ru ? '$name заблокирован' : '$name banned';
  String get failedBan => _ru ? 'Не удалось заблокировать' : 'Failed to ban';
  String roleUpdated(String role) => _ru ? 'Роль изменена на $role' : 'Role updated to $role';
  String get failedChangeRole => _ru ? 'Не удалось изменить роль' : 'Failed to change role';
  String userUnbanned(String name) => _ru ? '$name разблокирован' : '$name unbanned';
  String get failedUnban => _ru ? 'Не удалось разблокировать' : 'Failed to unban';
  String get youHaveBeenBanned => _ru ? 'Вы заблокированы' : 'You have been banned';
  String get renameGroupTitle => _ru ? 'Переименовать группу' : 'Rename Group';
  String get rename => _ru ? 'Переименовать' : 'Rename';
  String get join => _ru ? 'Вступить' : 'Join';
  String get manageMembers => _ru ? 'Управление участниками' : 'Manage members';
  String get banMemberTitle => _ru ? 'Заблокировать участника' : 'Ban Member';
  String get ban => _ru ? 'Заблокировать' : 'Ban';
  String get selectNewRole => _ru ? 'Выберите новую роль:' : 'Select new role:';
  String get moderator => _ru ? 'Модератор' : 'Moderator';
  String get memberRole => _ru ? 'Участник' : 'Member';
  String get manageMembersTitle => _ru ? 'Управление участниками' : 'Manage Members';
  String get viewBans => _ru ? 'Заблокированные' : 'View Bans';
  String get unbanUserTitle => _ru ? 'Разблокировать пользователя' : 'Unban User';
  String get unban => _ru ? 'Разблокировать' : 'Unban';
  String get bannedUsersTitle => _ru ? 'Заблокированные пользователи' : 'Banned Users';
  String get bannedFromGroup => _ru ? 'Вы заблокированы в этой группе.' : 'You have been banned from this group.';
  String bannedReason(String reason) => _ru ? 'Причина: $reason' : 'Reason: $reason';
  String get noBannedUsers => _ru ? 'Нет заблокированных пользователей' : 'No banned users';
  String bannedBy(String name) => _ru ? 'Заблокировал: $name' : 'Banned by: $name';
  String bannedDate(String date) => _ru ? 'Дата: $date' : 'Date: $date';
  String banConfirm(String name) => _ru ? 'Заблокировать $name в группе?' : 'Ban $name from the group?';
  String get banReason => _ru ? 'Причина (необязательно)' : 'Reason (optional)';
  String changeRoleTitle(String name) => _ru ? 'Изменить роль: $name' : 'Change role for $name';
  String currentRoleLabel(String role) => _ru ? 'Текущая роль: $role' : 'Current role: $role';
  String ownerCount(int n) => _ru ? 'Владельцы: $n/3' : 'Owners: $n/3';
  String get ownerCurrent => _ru ? 'Владелец (текущий)' : 'Owner (current)';
  String get ownerLimitReached => _ru ? 'Владелец (лимит достигнут)' : 'Owner (limit reached)';
  String get owner => _ru ? 'Владелец' : 'Owner';
  String get cannotDemoteLastOwner => _ru ? 'Нельзя понизить последнего владельца' : 'Cannot demote the last owner';
  String get noMembersYet => _ru ? 'Нет участников' : 'No members';
  String get changeRole => _ru ? 'Изменить роль' : 'Change role';
  String unbanConfirm(String name) => _ru ? 'Разблокировать $name?' : 'Unban $name?';

  String localizeHint(String hint) {
    if (!_ru) return hint;
    return 'Сообщение...';
  }

  String localizeMotivationalHint(String s) {
    if (!_ru) return s;
    const map = {
      'Talk different.': 'Говори иначе.',
      'Nothing unnecessary.': 'Ничего лишнего.',
      "Don't know. Don't want to.": 'Не знаю. И не хочу знать.',
      "Be yourself — or someone else.": 'Будь собой - или кем-то другим.',
      'Privacy is on. Extra questions are off.': 'Приватность включена. Лишние вопросы отключены.',
      "I don't collect data. I've got enough on my plate.": 'Я не собираю данные. У меня хватает своих забот.',
    };
    return map[s] ?? s;
  }

  String get today => _ru ? 'Сегодня' : 'Today';
  String get yesterday => _ru ? 'Вчера' : 'Yesterday';

  String get failedCreateGroup => _ru ? 'Не удалось создать группу' : 'Failed to create group';
  String get invalidInviteLinkFormat => _ru ? 'Неверный формат ссылки' : 'Invalid invite link format';
  String get invalidInviteLink => _ru ? 'Недействительная ссылка' : 'Invalid invite link';
  String get groupAddedForViewing => _ru ? 'Группа добавлена!' : 'Group added for viewing!';
  String get failedAddGroup => _ru ? 'Не удалось добавить группу' : 'Failed to add group';
  String serverRemoved(String name) => _ru ? 'Сервер "$name" удалён' : 'Server "$name" removed';
  String get channelAdminOnlySubtitle => _ru ? 'Канал (только админы)' : 'Channel (admin only)';
  String get groupSubtitle => _ru ? 'Группа' : 'Group';
  String get newGroup => _ru ? 'Новая группа' : 'New group';
  String get externalGroup => _ru ? 'Внешняя группа' : 'External Group';
  String get externalChannel => _ru ? 'Внешний канал' : 'External Channel';

  String get joinExternalServer => _ru ? 'Подключиться к серверу' : 'Join External Server';
  String get enterServerAddress => _ru ? 'Введите адрес сервера' : 'Enter server address';
  String get enterValidIp => _ru ? 'Введите корректный IP-адрес или хост' : 'Enter a valid IP address or hostname';
  String couldNotConnect(String host) => _ru ? 'Не удалось подключиться к $host' : 'Could not connect to $host';
  String get usernameRequiredMsg => _ru ? 'Логин не указан. Убедитесь, что создали аккаунт в приложении.' : 'Username is required. Please make sure you have created an account in the app.';
  String get passwordRequiredForGroups => _ru ? 'Для групп необходим пароль' : 'Password is required for groups';
  String connectionFailed(String e) => _ru ? 'Ошибка подключения: $e' : 'Connection failed: $e';
  String connectedToServer(String type, String name) => _ru ? 'Подключено к $type "$name"' : 'Connected to $type "$name"';
  String get externalGroupType => _ru ? 'внешней группе' : 'external group';
  String get externalChannelType => _ru ? 'внешнему каналу' : 'external channel';
  String get identityVisible => _ru ? 'Ваш аккаунт будет виден серверу' : 'Your identity will be visible to the server';
  String get usernameLabel => _ru ? 'Имя пользователя' : 'Username';
  String get passwordLabel => _ru ? 'Пароль' : 'Password';
  String get noPasswordForChannels => _ru ? 'Для каналов пароль не требуется' : 'No password required for channels';
  String get noRegistrationRequired => _ru ? 'Регистрация не требуется.' : 'No registration required.';
  String get back => _ru ? 'Назад' : 'Back';
  String get connecting => _ru ? 'Подключение...' : 'Connecting...';
  String get connectBtn => _ru ? 'Подключить' : 'Connect';
  String get serverInfoGroups => _ru ? 'Группы' : 'Groups';
  String get serverInfoMembers => _ru ? 'Участники' : 'Members';
  String get serverInfoMedia => _ru ? 'Медиа' : 'Media';
  String get serverInfoMaxFile => _ru ? 'Макс. размер файла' : 'Max file size';

  String get thirdPartyServer => _ru ? 'СТОРОННИЙ СЕРВЕР' : 'THIRD-PARTY SERVER';
  String get thirdPartyWarning => _ru ? 'Этот сервер не управляется ONYX. Подключайтесь только если доверяете владельцу.' : 'This server is not operated by ONYX. Only connect if you trust the owner.';
  String get serverWillKnow => _ru ? 'Сервер узнает:' : 'Server will know:';
  String get serverWillNotReceive => _ru ? 'Сервер НЕ получит:' : 'Server will NOT receive:';
  String get knowIpAddress => _ru ? 'Ваш IP-адрес' : 'Your IP address';
  String get knowUsername => _ru ? 'Ваш логин' : 'Your chosen username';
  String get knowMessages => _ru ? 'Содержимое ваших сообщений на этом сервере' : 'Content of your messages in this server';
  String get notReceiveAccount => _ru ? 'Ваш аккаунт и пароль ONYX' : 'Your ONYX account or password';
  String get notReceiveContacts => _ru ? 'Ваши контакты и личные чаты' : 'Your contacts and private chats';
  String get notReceiveKeys => _ru ? 'Ваши ключи шифрования' : 'Your encryption keys';

  String get passphraseNotFound => _ru ? 'Секретная фраза не найдена на этом устройстве' : 'Passphrase not found on this device';
  String get yourPassphraseTitle => _ru ? 'Ваша секретная фраза' : 'Your Recovery Passphrase';
  String get passphraseWarning => _ru ? 'Храните эти слова в тайне. Любой, кто знает вашу секретную фразу, может сменить ваш пароль.' : 'Keep these words secret. Anyone with your passphrase can change your password.';
  String get copyLabel => _ru ? 'Копировать' : 'Copy';
  String get done => _ru ? 'Готово' : 'Done';

  String localizeFontDescription(String s) {
    if (!_ru) return s;
    const map = {
      'Default system font': 'Системный шрифт по умолчанию',
      'Friendly and open-ended': 'Дружелюбный и открытый',
      'Classic modern sans-serif': 'Современный sans-serif',
      'Clean and universal': 'Чистый и универсальный',
      'Optimized for screen display': 'Оптимизирован для экрана',
      'Bold rounded geometric': 'Скруглённый геометрический',
      'Bold rounded Apple design': 'Скруглённый дизайн Apple',
    };
    return map[s] ?? s;
  }

  String localizeDonateText(String s) {
    if (!_ru) return s;
    const map = {
      'Most widely accepted': 'Принимается повсеместно',
      'Available on any exchange': 'Доступен на любой бирже',
      'Maximum liquidity': 'Максимальная ликвидность',
      'High transaction fees': 'Высокие комиссии',
      'Transactions are public': 'Транзакции публичны',
      'Slow confirmation (~10 min)': 'Медленное подтверждение (~10 мин)',
      'Low fees': 'Низкие комиссии',
      'Fast confirmation (~2.5 min)': 'Быстрое подтверждение (~2.5 мин)',
      'Available on most exchanges': 'Доступен на большинстве бирж',
      'Less popular than BTC': 'Менее популярен, чем BTC',
      'Fully anonymous by default': 'Полная анонимность по умолчанию',
      'Untraceable transactions': 'Неотслеживаемые транзакции',
      'Perfectly fits our philosophy': 'Идеально подходит под нашу философию',
      'Best fit for a privacy app': 'Лучший выбор для приватного приложения',
      'Harder to buy (limited exchanges)': 'Сложнее купить (ограниченный выбор бирж)',
      'Longer sync time in wallet': 'Долгая синхронизация кошелька',
    };
    return map[s] ?? s;
  }

  // ── Token / session expiry ────────────────────────────────────────────────
  String get sessionExpiredBanner => _ru
      ? 'Сессия истекла — войдите заново'
      : 'Session expired — please log in again';
  String get sessionExpiredTitle =>
      _ru ? 'Сессия истекла' : 'Session expired';
  String get sessionExpiredSubtitle =>
      _ru ? 'Войдите заново' : 'Please sign in again';
  String get sessionSignIn => _ru ? 'Войти' : 'Sign in';
  String sessionExpiresInDays(int n) => _ru
      ? 'Сессия истекает через $n д.'
      : 'Session expires in $n day${n == 1 ? '' : 's'}';
  String sessionExpiresInHours(int n) => _ru
      ? 'Сессия истекает через $n ч.'
      : 'Session expires in $n hour${n == 1 ? '' : 's'}';
  String sessionActiveForDays(int n) => _ru
      ? 'Сессия активна ещё $n д.'
      : 'Session valid for $n more day${n == 1 ? '' : 's'}';
  String get sessionRenewSoon =>
      _ru ? 'Скоро потребуется повторный вход' : 'Re-login will be required soon';
  String get sessionStillValid =>
      _ru ? 'Токен авторизации действителен' : 'Authorization token is valid';

  String get blockedUsersTitle => _ru ? 'Заблокированные' : 'Blocked Users';
  String get blockedUsersSubtitle => _ru ? 'Управление блокировками' : 'Manage blocked users';
  String get blockedUsersEmpty => _ru ? 'Список заблокированных пуст' : 'No blocked users';
  String get unblockAction => _ru ? 'Разблокировать' : 'Unblock';
  String get writeMessage => _ru ? 'Написать' : 'Write';

  // ── Fake PIN / Decoy account ──────────────────────────────────────────────
  String get fakePinTitle => _ru ? 'Фейковый PIN' : 'Fake PIN';
  String get fakePinSubtitle => _ru ? 'Открыть фейковый аккаунт под принуждением' : 'Open a decoy account under duress';
  String get fakePinSheetTitle => _ru ? 'Настройка фейкового PIN' : 'Fake PIN Setup';
  String get fakePinStatusActive => _ru ? 'Активен' : 'Active';
  String get fakePinStatusOff => _ru ? 'Выкл' : 'Off';
  String get fakePinDescription => _ru
      ? 'Когда этот PIN вводится на экране блокировки, приложение открывается с фейковым аккаунтом вместо настоящего.'
      : 'When this PIN is entered at the lock screen, the app opens showing your decoy account instead of your real one.';
  String get setFakePin => _ru ? 'Установить фейковый PIN' : 'Set Fake PIN';
  String get disableFakePin => _ru ? 'Отключить фейковый PIN' : 'Disable Fake PIN';
  String get changeFakePin => _ru ? 'Изменить фейковый PIN' : 'Change Fake PIN';
  String get disableFakePinTitle => _ru ? 'Отключить фейковый PIN?' : 'Disable Fake PIN?';
  String get disableFakePinContent => _ru
      ? 'Фейковый PIN будет удалён. Настройки фейкового аккаунта сохранятся.'
      : 'The fake PIN will be removed. Your decoy account settings will be kept.';
  String get fakePinEnabledSnack => _ru ? 'Фейковый PIN включён' : 'Fake PIN enabled';
  String get fakePinDisabledSnack => _ru ? 'Фейковый PIN отключён' : 'Fake PIN disabled';
  String get fakePinCannotMatchReal => _ru ? 'Фейковый PIN не может совпадать с реальным' : 'Fake PIN cannot match your real PIN';
  String get decoyAccountSection => _ru ? 'Фейковый аккаунт' : 'Decoy Account';
  String get decoyAccountSubtitle => _ru ? 'Этот аккаунт будет показан при вводе фейкового PIN' : 'This account will be shown when the fake PIN is used';
  String get decoyDisplayNameLabel => _ru ? 'Имя' : 'Display name';
  String get decoyUsernameLabel => _ru ? 'Имя пользователя' : 'Username';
  String get decoyDisplayNameHint => _ru ? 'Введите имя' : 'Enter display name';
  String get decoyUsernameHint => _ru ? 'Введите логин' : 'Enter username';
  String get saveDecoyAccount => _ru ? 'Сохранить фейковый аккаунт' : 'Save decoy account';
  String get decoyAccountSaved => _ru ? 'Фейковый аккаунт сохранён' : 'Decoy account saved';
  String get decoyFieldsRequired => _ru ? 'Имя и логин не могут быть пустыми' : 'Username and display name cannot be empty';
  String get removeAvatar => _ru ? 'Удалить аватарку' : 'Remove avatar';
  String get fakePinSecurityNote => _ru
      ? 'Фейковый PIN должен отличаться от реального. Фейковый аккаунт не подключается ни к какому серверу — он показывает только настроенный вами профиль.'
      : 'The fake PIN must differ from your real PIN. The decoy account has no server connection — it only shows the profile you configured here.';
  String get decoyNoChats => _ru ? 'Нет чатов' : 'No chats yet';
  String get decoyNoGroups => _ru ? 'Нет групп' : 'No groups yet';
  String get decoyNoFavorites => _ru ? 'Нет избранного' : 'No favorites yet';
  String get decoyOtherAccounts => _ru ? 'Другие аккаунты' : 'Other accounts';
  String get decoyNoOtherAccounts => _ru ? 'Нет других аккаунтов' : 'No other accounts';
  String get lock => _ru ? 'Заблокировать' : 'Lock';
  String get decoyAppearance => _ru ? 'Внешний вид' : 'Appearance';
  String get decoyNotifications => _ru ? 'Уведомления' : 'Notifications';
  String get decoyStorage => _ru ? 'Хранилище' : 'Storage';
  String get decoyAppearanceSubtitle => _ru ? 'Тема и параметры отображения' : 'Theme and display options';
  String get decoyNotificationsSubtitle => _ru ? 'Звук и оповещения' : 'Sound and alert settings';
  String get decoyStorageSubtitle => _ru ? 'Управление кэшем файлов' : 'Manage cached files';

  // Decoy contacts
  String get decoyContactsSection => _ru ? 'Фейковые чаты' : 'Fake Chats';
  String get decoyContactsSubtitle => _ru
      ? 'Добавьте контакты с перепиской — они появятся когда открывается фейк-аккаунт'
      : 'Add contacts with messages — they appear when the decoy account is opened';
  String get generateContacts => _ru ? 'Сгенерировать контакты' : 'Generate Contacts';
  String get addDecoyContact => _ru ? 'Добавить контакт' : 'Add Contact';
  String get decoyNoContacts => _ru ? 'Нет фейковых чатов' : 'No fake chats yet';
  String get decoyContactUsername => _ru ? 'Юзернейм контакта' : 'Contact username';
  String get decoyContactDisplayName => _ru ? 'Имя контакта' : 'Contact display name';
  String contactsGenerated(int n) =>
      _ru ? 'Добавлено $n контактов' : 'Added $n contacts';
  String get contactAdded => _ru ? 'Контакт добавлен' : 'Contact added';
  String get contactRemoved => _ru ? 'Контакт удалён' : 'Contact removed';
  String get decoyContactExists => _ru ? 'Такой контакт уже есть' : 'Contact already exists';
  String get decoyContactsCleared => _ru ? 'Все чаты очищены' : 'All chats cleared';
  String get clearDecoyChats => _ru ? 'Очистить все чаты' : 'Clear All Chats';
  String get messagesCount => _ru ? 'сообщений' : 'messages';
  String get add => _ru ? 'Добавить' : 'Add';
  String get decoyChatsSubtitle => _ru
      ? 'Контакты с историей переписки'
      : 'Contacts with message history';
  String get decoyGroupsSection => _ru ? 'Группы и каналы' : 'Groups & Channels';
  String get decoyGroupsSubtitle => _ru ? 'Фейковые группы и каналы' : 'Fake groups and channels';
  String get decoyFavoritesSection => _ru ? 'Избранное' : 'Favorites';
  String get decoyFavoritesSubtitle => _ru ? 'Закреплённые чаты' : 'Pinned favorite chats';
  String get noFakeGroups => _ru ? 'Нет групп' : 'No groups yet';
  String get noFakeFavorites => _ru ? 'Нет избранного' : 'No favorites yet';
  String get addFakeGroup => _ru ? 'Группу' : 'Group';
  String get addFakeChannel => _ru ? 'Канал' : 'Channel';
  String get addFakeFavorite => _ru ? 'Добавить избранное' : 'Add Favorite';
  String get groupType => _ru ? 'Группа' : 'Group';
  String get channelType => _ru ? 'Канал' : 'Channel';
  String get favTitleHint => _ru ? 'Название' : 'Title';
  String get generateAll => _ru ? 'Сгенерировать всё' : 'Generate All';
  String get generateAllConfirm => _ru
      ? 'Будет сгенерирован случайный контент. Текущие данные будут заменены.'
      : 'Random content will be generated, replacing existing data.';

  // ── Send Favorites screen ─────────────────────────────────────────────────
  String get sendFavoritesTitle => _ru ? 'Отправка избранного' : 'Send Favorites';
  String get sendFavoritesShowQrToReceiver => _ru ? 'Показать QR получателю' : 'Show QR to Receiver';
  String get sendFavoritesScanReceiver => _ru ? 'Сканировать QR получателя' : 'Scan Receiver QR';
  String get sendFavoritesSending => _ru ? 'Идёт отправка избранного' : 'Sending Favorites';
  String get sendFavoritesSelectTitle => _ru ? 'Выберите чаты для отправки' : 'Select chats to send';
  String get sendFavoritesHintDesktop => _ru
      ? 'Получатель должен нажать «Получить» первым. Затем сканируйте QR-код здесь.'
      : 'The receiver must press "Receive" first. Then scan the QR code shown here.';
  String get sendFavoritesHintMobile => _ru
      ? 'Получатель должен нажать «Получить» первым и показать QR-код.'
      : 'The receiver must press "Receive" first and show the QR code.';
  String allChatsCount(int n) => _ru ? 'Все чаты ($n)' : 'All chats ($n)';
  String get sendFavoritesNoFavs => _ru ? 'Нет избранных чатов.' : 'No favourite chats yet.';
  String get sendFavoritesSelectAtLeastOne => _ru ? 'Выберите хотя бы один чат' : 'Select at least one chat';
  String chatsSelected(int n) {
    if (!_ru) return '$n chat${n == 1 ? '' : 's'} selected';
    final mod10 = n % 10, mod100 = n % 100;
    final word = (mod10 == 1 && mod100 != 11)
        ? 'чат выбран'
        : (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20))
            ? 'чата выбрано'
            : 'чатов выбрано';
    return '$n $word';
  }
  String get sendFavoritesShowQrBtn => _ru ? 'Показать QR' : 'Show QR';
  String get sendFavoritesScanQrBtn => _ru ? 'Сканировать QR' : 'Scan QR';

  // ── Receive Favorites screen ──────────────────────────────────────────────
  String get receiveFavoritesTitle => _ru ? 'Получение избранного' : 'Receive Favorites';
  String get receiveFavoritesScanSender => _ru ? 'Сканировать QR отправителя' : 'Scan Sender QR';
  String get receiveFavoritesScanOnSender => _ru ? 'Сканируйте QR на устройстве отправителя' : 'Scan on sender device';
  String get receiveFavoritesInstruction => _ru
      ? 'Откройте Избранное → Синхронизация → Отправить, затем сканируйте этот код'
      : 'Open Favorites on the sender, tap Sync → Send, then scan this code';
  String get receiveFavoritesE2E => _ru
      ? 'Сквозное шифрование · только локальная сеть'
      : 'End-to-end encrypted · local network only';
  String get receiveFavoritesScanHint => _ru
      ? 'Наведите камеру на QR-код\nна устройстве отправителя'
      : 'Point the camera at the QR code shown on the sender device';
  String get receiveFavoritesScanEncrypted => _ru
      ? 'Передача зашифрована · только локальная сеть'
      : 'Transfer is encrypted · local network only';
  String get receiveFavoritesWaiting => _ru
      ? 'Ожидание сканирования QR-кода отправителем…'
      : 'Waiting for sender to scan QR code…';
  String get receiveFavoritesComplete => _ru ? 'Передача завершена.' : 'Transfer complete.';
  String get receiveFavoritesConnecting => _ru ? 'Подключение к отправителю…' : 'Connecting to sender…';
  String get receiveFavoritesConnected => _ru ? 'Подключено! Ожидание файлов…' : 'Connected! Waiting for files…';
  String get cancelTransfer => _ru ? 'Прервать передачу' : 'Cancel transfer';

  // ── WardLink (passive local-network sync) ──────────────────────────────────
  String get wardLinkTitle => _ru ? 'WardLink' : 'WardLink';
  String get wardLinkSubtitle => _ru
      ? 'Пассивная синхронизация между вашими устройствами в локальной сети'
      : 'Passive sync between your devices on the local network';
  String get wardLinkEnable => _ru ? 'Пассивная синхронизация' : 'Passive sync';
  String get wardLinkEnableDesc => _ru
      ? 'Автоматически синхронизировать данные с доверенными устройствами, когда они в одной сети. На телефоне работает, пока приложение открыто; на компьютере — постоянно.'
      : 'Automatically sync with trusted devices on the same network. On phones this works while the app is open; on desktop it runs continuously.';
  String get wardLinkPairedDevices => _ru ? 'Доверенные устройства' : 'Trusted devices';
  String get wardLinkNoPairedDevices =>
      _ru ? 'Нет сопряжённых устройств' : 'No paired devices yet';
  String get wardLinkAddDevice => _ru ? 'Добавить' : 'Add';
  String get wardLinkRemoveDevice => _ru ? 'Удалить' : 'Remove';
  String get wardLinkRemoveConfirm => _ru
      ? 'Перестать синхронизироваться с этим устройством?'
      : 'Stop syncing with this device?';
  String get wardLinkFavoritesOnlyNote => _ru
      ? 'Синхронизируется содержимое «Избранного» — сообщения и медиа'
      : 'Syncs your Favorites — their messages and media';
  String get wardLinkMaxFileSize =>
      _ru ? 'Лимит размера файла' : 'Max file size';
  String get wardLinkPairTitle => _ru ? 'Сопряжение устройства' : 'Pair device';
  String get wardLinkShowCode => _ru ? 'Показать код' : 'Show code';
  String get wardLinkScanCode => _ru ? 'Сканировать код' : 'Scan code';
  String get wardLinkShowInstruction => _ru
      ? 'Откройте WardLink на другом своём устройстве и отсканируйте этот код'
      : 'Open WardLink on your other device and scan this code';
  String get wardLinkScanInstruction => _ru
      ? 'Наведите камеру на код WardLink другого устройства'
      : 'Point the camera at the WardLink code on the other device';
  String get wardLinkPairedOk => _ru ? 'Устройство сопряжено' : 'Device paired';
  String get wardLinkPairFailed =>
      _ru ? 'Не удалось выполнить сопряжение' : 'Pairing failed';
  String get wardLinkE2E => _ru
      ? 'Сквозное шифрование · только LAN'
      : 'End-to-end encrypted · LAN only';
  String get wardLinkSyncingNow => _ru ? 'Синхронизация…' : 'Syncing…';
  String get wardLinkDone => _ru ? 'Синхронизировано' : 'Synced';
  String get wardLinkCurrentFile => _ru ? 'Текущий файл' : 'Current file';
  String get wardLinkLog => _ru ? 'Журнал синхронизации' : 'Sync log';
  String get wardLinkLogEmpty => _ru ? 'Событий пока нет' : 'No events yet';
  String get wardLinkHoldForLog =>
      _ru ? 'Удерживайте кружок для журнала' : 'Hold the bubble for the log';
  String get wardLinkUpToDate => _ru ? 'Всё актуально' : 'Up to date';
  String wardLinkFilesDone(int n) =>
      _ru ? 'Передано файлов: $n' : 'Files transferred: $n';
  String get wardLinkNoFilesYet =>
      _ru ? 'Файлы не передавались' : 'No files transferred';
  String wardLinkSyncedAgo(String when) =>
      _ru ? 'Синхронизировано: $when' : 'Synced $when';
  String get wardLinkNeverSynced => _ru ? 'Ещё не синхронизировано' : 'Not synced yet';
  String get wardLinkFirewallHintWindows => _ru
      ? 'Если телефон не может подключиться к ПК — разрешите ONYX в брандмауэре Windows (порт TCP ${'47832'}). ONYX пробует добавить правило автоматически, но при необходимости: Брандмауэр Windows → Дополнительные параметры → Входящие правила → Создать правило → Порт → TCP → 47832.'
      : 'If the phone cannot reach this PC, allow ONYX in Windows Firewall (TCP port ${'47832'}). ONYX tries to add the rule automatically; if it fails: Windows Firewall → Advanced → Inbound Rules → New Rule → Port → TCP → 47832.';
  String get wardLinkFirewallHintMac => _ru
      ? 'Если телефон не может подключиться к Mac — убедитесь, что брандмауэр macOS не блокирует входящие соединения для ONYX: Системные настройки → Сеть → Брандмауэр → Параметры → добавьте ONYX.'
      : 'If the phone cannot reach this Mac, make sure the macOS firewall is not blocking ONYX: System Settings → Network → Firewall → Options → add ONYX.';
  String get wardLinkFirewallHintLinux => _ru
      ? 'Если телефон не может подключиться — откройте порт TCP 47832 в вашем брандмауэре. Например: sudo ufw allow 47832/tcp  или  sudo firewall-cmd --add-port=47832/tcp --permanent'
      : 'If the phone cannot connect, open TCP port 47832 in your firewall. Example: sudo ufw allow 47832/tcp  or  sudo firewall-cmd --add-port=47832/tcp --permanent';
  String get wardLinkSyncFromBeginning =>
      _ru ? 'Синхронизировать с начала' : 'Sync from beginning';
  String get wardLinkSyncFromBeginningDesc => _ru
      ? 'Подтянуть всю историю, которой нет на этом устройстве'
      : 'Pull all history not yet on this device';
  String get wardLinkSyncPending =>
      _ru ? 'Синхронизация в процессе…' : 'Sync pending…';
  String get wardLinkBubbleVisibility =>
      _ru ? 'Кружок синхронизации' : 'Sync bubble';
  String get wardLinkBubbleShowAlways =>
      _ru ? 'Показывать всегда' : 'Show always';
  String get wardLinkBubbleShowOnErrors =>
      _ru ? 'Показывать только при ошибках' : 'Show on errors only';
  String get wardLinkBubbleSize => _ru ? 'Размер кружка' : 'Bubble size';

  // ── Backup ────────────────────────────────────────────────────────────────
  String get backupTitle => _ru ? 'Бэкап' : 'Backup';
  String get backupSubtitle => _ru
      ? 'Локальное сохранение и восстановление данных'
      : 'Local backup and restore of your data';
  String get backupExport => _ru ? 'Сохранить все данные' : 'Save all data';
  String get backupRestore =>
      _ru ? 'Восстановить из бэкапа' : 'Restore from backup';
  String get backupScope => _ru ? 'Что бэкапить' : 'What to back up';
  String get backupFavorites => _ru ? 'Избранные чаты' : 'Favorite chats';
  String get backupPersonal => _ru ? 'Личные чаты' : 'Personal chats';
  String get backupIncludeMedia => _ru ? 'Включать медиа' : 'Include media';
  String get backupMediaImages => _ru ? 'Изображения' : 'Images';
  String get backupMediaVideos => _ru ? 'Видео' : 'Videos';
  String get backupMediaVoice => _ru ? 'Голосовые и аудио' : 'Voice & audio';
  String get backupMediaOther => _ru ? 'Другие файлы' : 'Other files';
  String get backupSchedule => _ru ? 'Запланированный бэкап' : 'Scheduled backup';
  String get backupFreqOff => _ru ? 'Выкл' : 'Off';
  String get backupFreqDaily => _ru ? 'Каждый день' : 'Daily';
  String get backupFreqWeekly => _ru ? 'Каждую неделю' : 'Weekly';
  String get backupFreqMonthly => _ru ? 'Каждый месяц' : 'Monthly';
  String get backupFolder => _ru ? 'Папка авто-бэкапов' : 'Auto-backup folder';
  String get backupChangeFolder => _ru ? 'Изменить' : 'Change';
  String get backupLastAuto => _ru ? 'Последний авто-бэкап' : 'Last auto-backup';
  String get backupNever => _ru ? 'ещё не было' : 'never';
  String get backupInProgress => _ru ? 'Создание бэкапа…' : 'Creating backup…';
  String get backupRestoring => _ru ? 'Восстановление…' : 'Restoring…';
  String get backupSelectScope => _ru
      ? 'Выберите хотя бы одну категорию'
      : 'Select at least one category';
  String get backupNoAccount =>
      _ru ? 'Нет активного аккаунта' : 'No active account';
  String get backupNoPermission => _ru
      ? 'Нет доступа к хранилищу. Разрешите «Доступ ко всем файлам» в настройках приложения.'
      : 'Storage access denied. Grant "All files access" in app settings.';
  String get backupOpenFolder => _ru ? 'Открыть папку' : 'Open folder';
  String get backupFolderUnsupported => _ru
      ? 'Эта папка недоступна. Выберите папку во внутреннем хранилище.'
      : 'This folder is not accessible. Please pick a folder on internal storage.';
  String get backupRestoreConfirmTitle =>
      _ru ? 'Восстановить из бэкапа?' : 'Restore from backup?';
  String get backupRestoreConfirmBody => _ru
      ? 'Данные из файла будут восстановлены поверх текущих (чаты, избранное, настройки).'
      : 'Data from the file will be restored over your current data (chats, favorites, settings).';
  String get backupRestartHint => _ru
      ? 'Перезапустите приложение, чтобы увидеть изменения'
      : 'Restart the app to see the changes';

  // ── Recycle bin / deletion safety ──────────────────────────────────────────
  String get recycleBinTitle => _ru ? 'Корзина' : 'Trash';
  String get recycleBinSubtitle => _ru
      ? 'Удалённые чаты и защита от случайных удалений по синхронизации'
      : 'Deleted chats and protection from accidental sync deletions';
  String get recycleBinPendingTitle => _ru
      ? 'Запросы на удаление'
      : 'Deletion requests';
  String recycleBinPendingDesc(String device, int count) => _ru
      ? 'Устройство «$device» предлагает удалить $count чат(ов). Применить или оставить?'
      : 'Device "$device" wants to delete $count chat(s). Apply or keep?';
  String get recycleBinApply => _ru ? 'Удалить' : 'Apply delete';
  String get recycleBinKeep => _ru ? 'Оставить мои чаты' : 'Keep my chats';
  String get recycleBinNoPending => _ru
      ? 'Нет ожидающих запросов на удаление'
      : 'No pending deletion requests';
  String get recycleBinResetTitle =>
      _ru ? 'Сбросить записи об удалениях' : 'Reset deletion records';
  String get recycleBinResetDesc => _ru
      ? 'Очищает список удалённых чатов. После этого синхронизация перестанет повторно удалять их на других устройствах и сможет вернуть их обратно.'
      : 'Clears the list of deleted chats. Sync will stop re-deleting them on other devices and can bring them back.';
  String get recycleBinResetButton =>
      _ru ? 'Очистить список удалённых' : 'Clear deleted list';
  String get recycleBinResetDone =>
      _ru ? 'Записи об удалениях очищены' : 'Deletion records cleared';
  String get recycleBinResetConfirm => _ru
      ? 'Очистить все записи об удалениях для этого аккаунта?'
      : 'Clear all deletion records for this account?';

  // ── Account Graph settings ────────────────────────────────────────────────
  String get accountGraph => _ru ? 'График аккаунта' : 'Account Graph';
  String get accountGraphSubtitleDesktopOn => _ru
      ? 'Показывает граф чатов, групп и каналов, когда чат не открыт'
      : 'Shows a graph of your chats, groups and channels when no chat is open';
  String get accountGraphSubtitleMobileOn => _ru
      ? 'Визуализация вашего аккаунта в планетарном виде'
      : 'Visualizing your account in planetary view';
  String get accountGraphSubtitleDesktopOff => _ru
      ? 'Показывает подсказку, когда чат не открыт'
      : 'Shows a hint when no chat is open';
  String get accountGraphSubtitleMobileOff => _ru ? 'График аккаунта отключён' : 'Account Graph is disabled';
  String get orbitSpeed => _ru ? 'Скорость орбиты' : 'Orbit Speed';
  String secOrbit(int s) => _ru ? '$s сек/орбита' : '$s sec/orbit';
  String minOrbit(int m) => _ru ? '$m мин/орбита' : '$m min/orbit';
  String get animateGraph => _ru ? 'Анимация' : 'Animate';
  String get animateGraphOn => _ru ? 'Орбиты вращаются в реальном времени' : 'Orbits rotate in real time';
  String get animateGraphOff => _ru ? 'Граф заморожен / статичен' : 'Graph is frozen / static';
  String get preserveView => _ru ? 'Сохранять вид' : 'Preserve View';
  String get preserveViewOn => _ru ? 'Сохраняет масштаб и позицию при выходе из чата' : 'Keeps zoom & position when leaving a chat';
  String get preserveViewOff => _ru ? 'Сбрасывает в центр при возврате' : 'Resets to center when returning';

  // Migration dialog
  String get migrationTitle => _ru ? 'Миграция хранилища' : 'Storage Migration';
  String get migrationBody => _ru
      ? 'ONYX переходит на новый высокоскоростной движок хранения данных. Чаты и медиа будут загружаться значительно быстрее.'
      : 'ONYX is switching to a new high-speed storage engine. Chats and media will load much faster.';
  String get migrationAccounts => _ru ? 'Аккаунтов' : 'Accounts';
  String get migrationDataSize => _ru ? 'Размер данных' : 'Data size';
  String get migrationBackupNote => _ru
      ? 'Перед миграцией будет создана резервная копия. Во время этого приложение может временно не отвечать.'
      : 'A backup will be created before migration. The app may be temporarily unresponsive during this process.';
  String get migrationStart => _ru ? 'Начать миграцию' : 'Start Migration';
  String get migrationSkip => _ru ? 'Пропустить' : 'Skip';
  String get migrationPhaseBackup => _ru ? 'Создание резервной копии' : 'Creating backup';
  String get migrationPhaseImport => _ru ? 'Импорт данных' : 'Importing data';
  String get migrationPhaseVerify => _ru ? 'Проверка' : 'Verifying';
  String get migrationPhasePreparing => _ru ? 'Подготовка' : 'Preparing';
  String get migrationDontClose => _ru ? 'Не закрывайте приложение' : 'Do not close the app';
  String get migrationDoneTitle => _ru ? 'Готово!' : 'Done!';
  String get migrationDoneBody => _ru
      ? 'Хранилище обновлено. Резервная копия сохранена в папке Backups.'
      : 'Storage updated. A backup has been saved to the Backups folder.';
  String get migrationDoneNote => _ru
      ? 'После того как убедитесь, что всё работает — можете удалить её вручную.'
      : 'Once you confirm everything works — you can delete it manually.';
  String get migrationDoneButton => _ru ? 'Отлично!' : 'Great!';
  String get migrationErrorTitle => _ru ? 'Ошибка миграции' : 'Migration Error';
  String get migrationErrorBody => _ru
      ? 'Приложение продолжит работу на старой системе. Повторная попытка будет при следующем запуске.'
      : 'The app will continue on the old system. Migration will be retried on next launch.';
  String get migrationErrorButton => _ru ? 'Понятно' : 'Got it';

  // ── Audio settings ────────────────────────────────────────────────────────
  String get audioTitle => _ru ? 'Аудио' : 'Audio';
  String get audioSubtitle => _ru ? 'Выбор микрофона и колонок' : 'Microphone and speaker device selection';
  String get audioMicInput => _ru ? 'Микрофон (вход)' : 'Microphone (input)';
  String get audioSpeakerOutput => _ru ? 'Колонки (выход)' : 'Speaker (output)';
  String get audioSystemDefault => _ru ? 'Системный по умолчанию' : 'System default';
  String get audioChangesNote => _ru
      ? 'Изменения вступят в силу при следующем подключении к голосовому каналу.'
      : 'Changes take effect on the next voice channel join.';

  // ── WardLink ──────────────────────────────────────────────────────────────
  String get wardlinkReceive => _ru ? 'Получить с устройства' : 'Receive from device';
  String get wardlinkReceiveSubtitle => _ru ? 'Покажите QR-код — отправитель его сканирует' : 'Show a QR code — the sender scans it';
  String get wardlinkSend => _ru ? 'Отправить на устройство' : 'Send to device';
  String get wardlinkSendSubtitle => _ru ? 'Сканируйте QR-код на устройстве получателя' : 'Scan the QR code shown on the receiver';

  // ── Message context menu ──────────────────────────────────────────────────
  String get react => _ru ? 'Реакция' : 'React';
  String get pin => _ru ? 'Закрепить' : 'Pin';
  String get unpin => _ru ? 'Открепить' : 'Unpin';
  String get copyImage => _ru ? 'Копировать изображение' : 'Copy Image';
  String get forward => _ru ? 'Переслать' : 'Forward';
  String get showInFileSystem => _ru ? 'Показать в проводнике' : 'Show in file system';
  String get saveNotSupportedOnWeb => _ru ? 'Сохранение недоступно в веб-версии' : 'Save not supported on web';
  String get imageNotLoadedYet => _ru ? 'Изображение ещё не загружено' : 'Image not loaded yet';
  String get voiceNotLoadedYet => _ru ? 'Голосовое сообщение ещё не загружено' : 'Voice not loaded yet';
  String get videoNotLoadedYet => _ru ? 'Видео ещё не загружено' : 'Video not loaded yet';
  String get fileNotLoadedYet => _ru ? 'Файл ещё не загружен' : 'File not loaded yet';
  String get fileNotLoadedOpenFirst => _ru ? 'Файл ещё не загружен — сначала откройте его' : 'File not loaded yet — open it first';
  String editTimerLabel(int s) => _ru ? 'Изменить  ·  ${s}с' : 'Edit  ·  ${s}s'; // ignore: unnecessary_brace_in_string_interps
  String deleteTimerLabel(int s) => _ru ? 'Удалить  ·  ${s}с' : 'Delete  ·  ${s}s'; // ignore: unnecessary_brace_in_string_interps

  // ── Favorites tab ─────────────────────────────────────────────────────────
  String get newChat => _ru ? 'Новый чат' : 'New chat';
  String get newChatSubtitle => _ru ? 'Создать новый избранный чат' : 'Create a new favorite chat';
  String get newFolder => _ru ? 'Новая папка' : 'New folder';
  String get newFolderSubtitle => _ru ? 'Группировать чаты в папку' : 'Group chats into a folder';

  // ── Emoji picker ──────────────────────────────────────────────────────────
  String get searchEmoji => _ru ? 'Поиск эмодзи…' : 'Search emoji…';

  // ── LAN favorites sync ────────────────────────────────────────────────────
  String get syncCompleted => _ru ? 'Синхронизация завершена' : 'Sync completed';
  String get syncCompletedWithErrors => _ru ? 'Синхронизация завершена с ошибками' : 'Sync completed with errors';
  String get receivingFiles => _ru ? 'Получение файлов...' : 'Receiving files...';
  String syncFromUser(String sender) => _ru ? 'от $sender' : 'from $sender';
  String syncFileCount(int n) {
    if (!_ru) return '$n file${n == 1 ? '' : 's'}';
    final mod10 = n % 10, mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return '$n файлов';
    if (mod10 == 1) return '$n файл';
    if (mod10 >= 2 && mod10 <= 4) return '$n файла';
    return '$n файлов';
  }

  // ── About ONYX dialog ─────────────────────────────────────────────────────
  String get aboutServer => _ru ? 'СЕРВЕР' : 'SERVER';
  String get aboutWhatsNew => _ru ? "ЧТО НОВОГО" : "WHAT'S NEW";
  String get aboutConnected => _ru ? 'Подключено' : 'Connected';
  String get aboutConnecting => _ru ? 'Подключение...' : 'Connecting...';
  String get aboutLoadingLocation => _ru ? 'Загрузка...' : 'Loading...';
  String get aboutNoReleaseNotes => _ru ? 'Нет информации об обновлении.' : 'No release notes available.';
  String get aboutCheckForUpdates => _ru ? 'Проверить обновления' : 'Check for updates';
  String get aboutChecking => _ru ? 'Проверка...' : 'Checking...';
  String get aboutUpToDate => _ru ? 'Версия актуальна!' : "You're up to date!";
  String aboutUpdateAvailable(String v) => _ru ? 'Доступно обновление: $v' : 'Update available: $v';

  // ── Download Update dialog ────────────────────────────────────────────────
  String get downloadUpdateTitle => _ru ? 'Скачать обновление' : 'Download Update';
  String get downloadUpdateVersion => _ru ? 'Версия' : 'Version';
  String get downloadUpdateWhatsNew => _ru ? "ЧТО НОВОГО" : "WHAT'S NEW";
  String get downloadUpdateReady => _ru ? 'Готово к загрузке' : 'Ready to download';
  String get downloadUpdateDownloading => _ru ? 'Загрузка...' : 'Downloading...';
  String get downloadUpdateComplete => _ru ? 'Загрузка завершена!' : 'Download complete!';
  String get downloadUpdateNoPlatform => _ru ? 'Нет загрузки для этой платформы' : 'No download available for this platform';
  String get downloadUpdateInstall => _ru ? 'Скачать и установить' : 'Download & Install';
  String get downloadUpdateOpen => _ru ? 'Открыть' : 'Open';
  String get downloadUpdateRetry => _ru ? 'Повторить' : 'Retry';
  String get downloadUpdateCancel => _ru ? 'Отменить загрузку' : 'Cancel download';

  // ── Edit chat / folder / group dialogs ────────────────────────────────────
  String get editChat => _ru ? 'Редактировать чат' : 'Edit chat';
  String get chatNameLabel => _ru ? 'Название чата' : 'Chat name';
  String get editFolder => _ru ? 'Редактировать папку' : 'Edit folder';
  String get folderNameLabel => _ru ? 'Название папки' : 'Folder name';
  String get createChat => _ru ? 'Новый чат' : 'New chat';

  // ── User profile dialog ───────────────────────────────────────────────────
  String get profileMessage => _ru ? 'Написать' : 'Message';

  // ── Profile edit dialog ───────────────────────────────────────────────────
  String get tapAvatarHint => _ru ? 'Нажмите на аватар • Удержите чтобы удалить' : 'Tap avatar to change • Long-press to remove';

  // ── Folder dialogs ────────────────────────────────────────────────────────
  String get tapAvatarLongRemove => _ru ? 'Нажмите чтобы сменить • Удержите чтобы удалить' : 'Tap to change • Long-press to remove';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ru'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

typedef AppL10n = AppLocalizations;
