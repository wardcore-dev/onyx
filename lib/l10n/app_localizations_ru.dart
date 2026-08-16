// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get navChats => 'Чаты';

  @override
  String get navGroups => 'Группы';

  @override
  String get navFavorites => 'Избранное';

  @override
  String get navAccounts => 'Аккаунты';

  @override
  String get navSettings => 'Настройки';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get close => 'Закрыть';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get delete => 'Удалить';

  @override
  String get clear => 'Очистить';

  @override
  String get loading => 'Загрузка...';

  @override
  String get error => 'Ошибка';

  @override
  String get success => 'Успешно';

  @override
  String get copy => 'Копировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get test => 'Тест';

  @override
  String get connect => 'Подключить';

  @override
  String get disconnect => 'Отключить';

  @override
  String get enabled => 'Включено';

  @override
  String get disabled => 'Выключено';

  @override
  String get on => 'Вкл';

  @override
  String get off => 'Выкл';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get supportOnyx => 'Поддержать ONYX';

  @override
  String get securityTitle => 'Безопасность';

  @override
  String get securitySubtitle => 'Советы и детали шифрования';

  @override
  String get tipOfTheDay => 'Совет дня';

  @override
  String get statusSettings => 'Настройки статуса';

  @override
  String get showDisplayNameInGroups => 'Показывать имя в группах';

  @override
  String get showDisplayNameSubtitle =>
      'Если выключено, ваши сообщения будут подписаны как \"Anonymous\"';

  @override
  String get pinLock => 'PIN-блокировка';

  @override
  String get enablePinLock => 'Включить PIN-блокировку';

  @override
  String get enablePinSubtitle =>
      'Требовать 4-значный PIN при запуске приложения';

  @override
  String get pinLockEnabled => ' PIN-блокировка включена';

  @override
  String get pinLockDisabled => 'PIN-блокировка отключена';

  @override
  String get useBiometrics => 'Использовать биометрию';

  @override
  String get useBiometricsSubtitle => 'Разблокировать по отпечатку или лицу';

  @override
  String get biometricsUnavailable => 'Биометрия недоступна на этом устройстве';

  @override
  String get lockOnResume => 'Блокировать при сворачивании';

  @override
  String get lockOnResumeSubtitle =>
      'Запрашивать PIN каждый раз при возврате в приложение';

  @override
  String get pinScreenSetTitle => 'Задать PIN';

  @override
  String get pinScreenConfirmTitle => 'Подтвердите PIN';

  @override
  String get pinScreenEnterTitle => 'Введите PIN';

  @override
  String get pinScreenChooseSubtitle => 'Придумайте 4-значный PIN';

  @override
  String get pinScreenChooseChatSubtitle =>
      'Придумайте 4-значный PIN для этого чата';

  @override
  String get pinScreenReenterSubtitle =>
      'Введите PIN ещё раз для подтверждения';

  @override
  String get pinScreenUnlockSubtitle =>
      'Введите свой 4-значный PIN для разблокировки';

  @override
  String get pinScreenGenericSubtitle => 'Введите свой 4-значный PIN';

  @override
  String get pinScreenDisableHeader => 'Введите текущий PIN, чтобы отключить';

  @override
  String get pinScreenMismatchError =>
      'PIN-коды не совпадают. Попробуйте снова.';

  @override
  String get pinScreenIncorrectError => 'Неверный PIN';

  @override
  String get searchChatsHint => 'Поиск чатов и сообщений…';

  @override
  String get searchGroupsHint => 'Поиск групп и сообщений…';

  @override
  String get searchFavoritesHint => 'Поиск избранного…';

  @override
  String get searchSettingsHint => 'Поиск в настройках…';

  @override
  String get keyMgmtTitle => 'Управление ключами';

  @override
  String get keyMgmtSubtitle => 'Ротация или сброс ключа шифрования';

  @override
  String get keyMgmtDescription =>
      'Выполните ротацию E2EE-ключа, если подозреваете его компрометацию. Контакты получат новый ключ автоматически.';

  @override
  String get rotateE2eeKey => 'Ротация E2EE-ключа';

  @override
  String get rotateE2eeKeyPrimaryOnly =>
      'Ротация E2EE-ключа (только основное устройство)';

  @override
  String get rotateKeyDialogTitle => 'Ротировать ключ шифрования?';

  @override
  String get rotateKeyDialogContent =>
      'Будет создана новая пара ключей X25519 и загружена на сервер.nnСессия и история сообщений НЕ затрагиваются. Контакты автоматически начнут использовать новый ключ.';

  @override
  String get rotateKeyBtn => 'Ротировать';

  @override
  String get rotatingKey => ' Ротация ключа...';

  @override
  String get keyRotated => ' E2EE-ключ ротирован и загружен';

  @override
  String get keyRotationFailed => ' Ошибка ротации ключа';

  @override
  String get activeDevices => 'Активные устройства';

  @override
  String get activeDevicesSubtitle => 'Устройства, пароль и ключ шифрования';

  @override
  String get activeDevicesPrimaryOnly =>
      'Активные устройства (только основное)';

  @override
  String get changePassword => 'Изменить пароль';

  @override
  String get changePasswordPrimaryOnly =>
      'Изменить пароль (только основное устройство)';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsSubtitle => 'Управление оповещениями';

  @override
  String get notificationsEnabled => 'Включить уведомления';

  @override
  String get notificationsEnabledSubtitle =>
      'Показывать системные уведомления о новых сообщениях';

  @override
  String get notificationPosition => 'Позиция уведомлений';

  @override
  String get notifPosTopLeft => 'Верх-лево';

  @override
  String get notifPosTopRight => 'Верх-право';

  @override
  String get notifPosBottomLeft => 'Низ-лево';

  @override
  String get notifPosBottomRight => 'Низ-право';

  @override
  String get appearanceTitle => 'Внешний вид';

  @override
  String get appearanceSubtitle => 'Тема и тёмный режим';

  @override
  String get selectTheme => 'Выбрать тему';

  @override
  String get darkMode => 'Тёмный режим';

  @override
  String get fontAndTextSize => 'Шрифт и размер текста';

  @override
  String get fontFamily => 'Семейство шрифтов';

  @override
  String get messageSize => 'Размер сообщений';

  @override
  String get fontPreviewMessage => 'Пример';

  @override
  String get ownMessagesRight => 'Мои сообщения: справа';

  @override
  String get ownMessagesLeft => 'Мои сообщения: слева';

  @override
  String get alignAllRight => 'Выровнять все сообщения вправо';

  @override
  String get alignAllRightSubtitle =>
      'Все сообщения отображаются справа, как в зеркале';

  @override
  String get showAvatarInChats => 'Аватар в списке чатов';

  @override
  String get showAccountIndicator => 'Показывать текущий аккаунт';

  @override
  String get showAccountIndicatorSubtitle =>
      'Отображать имя и юзернейм в углу приложения';

  @override
  String get showAvatarSubtitle =>
      'Показывать аватар собеседника в списке чатов';

  @override
  String get chatBackground => 'Фон чата';

  @override
  String get chatBgSubtitle => 'Установить изображение как фон в чатах';

  @override
  String get chooseImage => 'Выбрать изображение';

  @override
  String get clearBackground => 'Убрать фон';

  @override
  String get applyGlobally => 'Применить ко всем чатам';

  @override
  String get applyGloballySubtitle => 'Использовать этот фон во всех чатах';

  @override
  String get blurBackground => 'Размыть фон';

  @override
  String get elementOpacity => 'Прозрачность элементов';

  @override
  String get elementBrightness => 'Яркость элементов';

  @override
  String get uiLayout => 'Макет интерфейса';

  @override
  String get navBarPosition => 'Позиция навигации';

  @override
  String get navLeft => 'Слева';

  @override
  String get navBottom => 'Снизу';

  @override
  String get inputBarMaxWidth => 'Ширина строки ввода';

  @override
  String get minimizeBottomNav => 'Компактная навигация';

  @override
  String get minimizeBottomNavSubtitle => 'Скрыть подписи в нижней панели';

  @override
  String get swipeTabs => 'Свайп между вкладками';

  @override
  String get swipeTabsSubtitle => 'Переключать вкладки горизонтальным свайпом';

  @override
  String get smoothScroll => 'Плавная прокрутка';

  @override
  String get performanceOptimizations => 'Оптимизация производительности';

  @override
  String get macOsWindowStyle => 'Стиль окна';

  @override
  String get macOsWindowStyleSubtitle => 'Кнопки управления окном';

  @override
  String get macOsNativeTitleBar => 'Нативный macOS (светофор слева)';

  @override
  String get macOsCustomTitleBar => 'Windows-стиль (справа)';

  @override
  String get updateAvailableLabel => 'Доступно обновление';

  @override
  String get updateDownload => 'Скачать';

  @override
  String get cacheTitle => 'Кэш';

  @override
  String get cacheSubtitle => 'Управление локальным и серверным кэшем медиа';

  @override
  String get mediaCacheSize => 'Кэш медиа: ';

  @override
  String get clearLocalCache => 'Очистить локальный кэш';

  @override
  String get clearLocalCacheTitle => 'Очистить локальный кэш?';

  @override
  String get clearLocalCacheContent =>
      'Вы уверены, что хотите удалить весь кэшированный медиаконтент (голос, изображения, видео)?nЗагрузки на сервере и история чатов НЕ затрагиваются.';

  @override
  String get clearAll => 'Очистить всё';

  @override
  String get serverMediaCache => 'Серверный кэш медиа';

  @override
  String get serverMediaCacheSubtitle =>
      'Хранится на сервере: изображения, голос, видео.';

  @override
  String get clearServerCache => 'Очистить серверный кэш';

  @override
  String get dangerZone => 'Опасная зона';

  @override
  String get dangerZoneSubtitle =>
      'Удалить аккаунт с сервера и/или стереть локальные данные.';

  @override
  String get factoryReset => 'Сброс';

  @override
  String get factoryResetHint =>
      'Выберите что сбросить. Нужно выбрать хотя бы один пункт.';

  @override
  String get resetDeleteAccount => 'Удалить аккаунт с сервера';

  @override
  String resetDeleteAccountSubtitle(String username) {
    return 'Навсегда удалит @$username — все сообщения, медиа и ключи с сервера.';
  }

  @override
  String get resetNoAccount => 'Нет авторизованного аккаунта.';

  @override
  String get resetDeleteLocal => 'Удалить локальные данные';

  @override
  String get resetDeleteLocalSubtitle =>
      'Удалит все локальные чаты, ключи, настройки, кэш и медиа.';

  @override
  String get reset => 'Сбросить';

  @override
  String get resetFailed => 'Сброс не удался';

  @override
  String get resetConfirmStep1Title => 'Вы уверены, что хотите это сделать?';

  @override
  String get resetConfirmStep1Message =>
      'Это навсегда удалит выбранные вами данные. Это действие нельзя отменить.';

  @override
  String get resetConfirmStep2Title => 'Вы точно уверены?';

  @override
  String get resetConfirmStep2Message =>
      'Это ваш последний шанс отменить. Подтверждение немедленно запустит сброс.';

  @override
  String get connectionTitle => 'Соединение';

  @override
  String get connectionSubtitle => 'Статус и управление WebSocket';

  @override
  String get proxyTitle => 'Прокси';

  @override
  String get proxySubtitle => 'Маршрутизация через HTTP или SOCKS5 прокси';

  @override
  String get enableProxy => 'Включить прокси';

  @override
  String get proxyType => 'Тип прокси';

  @override
  String get proxyHost => 'Хост';

  @override
  String get proxyPort => 'Порт';

  @override
  String get proxyUsername => 'Логин';

  @override
  String get proxyPassword => 'Пароль';

  @override
  String get testProxy => 'Проверить прокси';

  @override
  String get proxyTesting => 'Проверка...';

  @override
  String get proxyOk => ' Прокси работает';

  @override
  String get proxyFailed => ' Прокси недоступен';

  @override
  String get useProxy => 'Использовать прокси';

  @override
  String get proxyDirectConnection => 'Прямое подключение';

  @override
  String get proxyRouted => 'Трафик идёт через прокси';

  @override
  String get proxyConnectedStatus => 'Подключено';

  @override
  String get proxyNotConnectedStatus => 'Не подключено';

  @override
  String get proxyLoginOptional => 'Логин (необязательно)';

  @override
  String get proxyPasswordOptional => 'Пароль (необязательно)';

  @override
  String get proxyApplyReconnect => 'Применить и переподключить';

  @override
  String get appDataTitle => 'Папка данных ONYX';

  @override
  String get appDataSubtitle => 'Перенос системной папки данных на другой диск';

  @override
  String get appDataCurrentPath => 'Текущая папка';

  @override
  String get appDataDefault => 'По умолчанию (системная папка)';

  @override
  String get appDataMove => 'Переместить…';

  @override
  String get appDataReset => 'Сбросить';

  @override
  String get appDataMigrating => 'Перемещение данных…';

  @override
  String get appDataMigrateError => 'Ошибка при перемещении';

  @override
  String get appDataRestartRequired =>
      'Папка изменена. Перезапустите ONYX, чтобы изменения вступили в силу.';

  @override
  String get appDataRestart => 'Перезапустить ONYX';

  @override
  String get appDataOpenFolder => 'Открыть папку';

  @override
  String get appDataDeleteOldFolder => 'Удалить предыдущую папку';

  @override
  String get appDataDeleteOldFolderSubtitle =>
      'Удалить исходную системную папку данных, оставшуюся после переноса';

  @override
  String get appDataDeleteOldFolderConfirm =>
      'Удалить исходную папку ONYX?nnЭто действие необратимо. Убедитесь, что данные успешно перенесены.';

  @override
  String get appDataDeleteOldFolderSuccess => 'Предыдущая папка удалена';

  @override
  String get appDataDeleteOldFolderError => 'Ошибка при удалении: ';

  @override
  String get interactTitle => 'Взаимодействие';

  @override
  String get interactSubtitle => 'Подтверждение загрузки файлов';

  @override
  String get confirmFileUpload => 'Подтверждение отправки файла';

  @override
  String get confirmFileUploadSubtitle =>
      'Показывать диалог подтверждения перед отправкой файлов';

  @override
  String get confirmVoiceMessage => 'Подтверждение голосового сообщения';

  @override
  String get confirmVoiceSubtitle =>
      'Показывать диалог подтверждения перед отправкой голосового';

  @override
  String get downloadFolder => 'Папка для сохранения файлов';

  @override
  String get downloadFolderSubtitle =>
      'Куда сохранять полученные файлы (по умолчанию: Загрузки/ONYX)';

  @override
  String get downloadFolderDefault => 'По умолчанию (Загрузки/ONYX)';

  @override
  String get downloadFolderChange => 'Выбрать папку';

  @override
  String get downloadFolderReset => 'Сбросить';

  @override
  String get contactTitle => 'Контакты';

  @override
  String get contactSubtitle => 'Сайт, репозиторий и обратная связь';

  @override
  String get contactWebsite => 'Официальный сайт';

  @override
  String get contactRepository => 'Исходный код (клиент)';

  @override
  String get contactRepositoryServer => 'Исходный код (self-hosted сервер)';

  @override
  String get contactEmail => 'Написать нам';

  @override
  String get debugTitle => 'Отладка / Логи';

  @override
  String get debugSubtitle =>
      'Производительность и журналирование в реальном времени';

  @override
  String get debugMode => 'Режим отладки';

  @override
  String get debugModeSubtitle =>
      'Включить мониторинг производительности и логи';

  @override
  String get enableFileLogging => 'Запись логов в файл';

  @override
  String get enableFileLoggingSubtitle =>
      'Записывать логи на диск (отключите для приватности)';

  @override
  String get deleteAllLogs => 'Удалить все логи';

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageSubtitle => 'Язык интерфейса приложения';

  @override
  String get languageChanged => 'Язык изменён';

  @override
  String get noChatsYet => 'Чатов пока нет';

  @override
  String get deleteChatTitle => 'Удалить чат?';

  @override
  String get blockUserLabel => 'Заблокировать';

  @override
  String get unblockUserLabel => 'Разблокировать';

  @override
  String get muteUserLabel => 'Отключить уведомления';

  @override
  String get unmuteUserLabel => 'Включить уведомления';

  @override
  String get blockedByUserMessage =>
      'Этот пользователь ограничил получение сообщений от вас.';

  @override
  String unblockUserConfirmContent(String name) {
    return 'Разблокировать $name?';
  }

  @override
  String blockUserConfirmContent(String name) {
    return 'Заблокировать $name? Они не смогут отправлять вам сообщения.';
  }

  @override
  String deleteChatContent(String name) {
    return 'Удалить чат с \"$name\"? Это действие необратимо.';
  }

  @override
  String get editProfile => 'Профиль';

  @override
  String get displayName => 'Отображаемое имя';

  @override
  String get addAccount => 'Добавить аккаунт';

  @override
  String get welcomeTitle => 'Добро пожаловать';

  @override
  String get welcomeTagline => 'Безопасный мессенджер с шифрованием';

  @override
  String get otherAccounts => 'Другие аккаунты';

  @override
  String get tapToSwitch => 'Нажмите для входа';

  @override
  String get deleteFromRecentTitle => 'Удалить из недавних?';

  @override
  String get authUsernameLabel => 'Юзернейм (3–16 симв.)';

  @override
  String get authPasswordLabel => 'Пароль (мин. 16 симв.)';

  @override
  String get loginBtn => 'Войти';

  @override
  String get registerBtn => 'Регистрация';

  @override
  String get deviceAuthTitle => 'Привязать устройство';

  @override
  String get deviceAuthTabScan => 'Скан';

  @override
  String get deviceAuthTapToScan => 'Нажмите, чтобы отсканировать QR-код';

  @override
  String get deviceAuthLanNote =>
      'Оба устройства должны быть в одной локальной сети';

  @override
  String get loginWithQr => 'Войти по QR';

  @override
  String get qrAuthWaitingTitle => 'Ожидание телефона';

  @override
  String get qrAuthWaitingSubtitle =>
      'Отсканируйте этот код на авторизованном устройстве — оно передаст сессию на этот экран';

  @override
  String get qrAuthSuccess => 'Устройство авторизовано';

  @override
  String get qrAuthFailed => 'Ошибка QR-авторизации';

  @override
  String get qrAuthCancelled => 'QR-авторизация отменена';

  @override
  String get authorizeDevice => 'Авторизовать устройство';

  @override
  String get authorizeDeviceSubtitle =>
      'Разрешить другому устройству войти через QR-код';

  @override
  String get authorizeDeviceScanHint =>
      'Наведите камеру на QR-код, отображаемый на другом устройстве';

  @override
  String get authorizeDeviceSuccess => 'Устройство успешно авторизовано';

  @override
  String get authorizeDeviceFailed => 'Не удалось авторизовать устройство';

  @override
  String get authorizeDeviceSending => 'Отправка данных...';

  @override
  String get qrAuthEncryptedNote =>
      'Передача зашифрована (X25519 + AES-256-GCM)';

  @override
  String get scanFromPc => 'Получить с компьютера';

  @override
  String get scanFromPcHint =>
      'Наведите камеру на QR-код, отображаемый на другом устройстве, чтобы войти здесь';

  @override
  String get grantDeviceTitle => 'Авторизовать телефон';

  @override
  String get grantDeviceSubtitle =>
      'Отсканируйте этот код на другом устройстве — оно получит доступ к этому аккаунту';

  @override
  String get grantDeviceSuccess => 'Телефон успешно авторизован';

  @override
  String get grantDeviceFailed => 'Не удалось авторизовать телефон';

  @override
  String get enterUsernameMsg => 'Введите имя пользователя';

  @override
  String get loginSuccess => 'Вход выполнен';

  @override
  String get loginFailed => 'Ошибка входа';

  @override
  String get registeringMsg => 'Регистрация...';

  @override
  String get registrationFailed => ' Ошибка регистрации';

  @override
  String get usernameInvalidMsg =>
      'Юзернейм: 3–16 симв., только буквы, цифры, _ . -';

  @override
  String get passwordTooShortMsg => 'Пароль слишком короткий (мин. 16)';

  @override
  String get generatePasswordTooltip => 'Сгенерировать надёжный пароль';

  @override
  String get savePasswordWarning =>
      'Обязательно сохраните пароль в надёжном месте — запишите его. Восстановление без пароля невозможно.';

  @override
  String get passphraseWriteDown =>
      'Эта фраза больше никогда не будет показана. Запишите эти 12 слов от руки и храните их в надёжном месте — они нужны для восстановления аккаунта, если вы забудете пароль.';

  @override
  String get passphraseWriteOnPaper =>
      'Запишите секретную фразу на бумаге прямо сейчас — второго шанса не будет!';

  @override
  String get copyToClipboard => 'Копировать в буфер';

  @override
  String get copiedToClipboard => 'Скопировано!';

  @override
  String passphraseCountdown(int s) {
    return 'Прочитайте внимательно — доступно через $s с...';
  }

  @override
  String get iSavedIt => 'Я сохранил(-а)';

  @override
  String deleteFromRecentContent(String acc) {
    return 'Удалить \"$acc\" из списка? Аккаунт на сервере не будет удалён.';
  }

  @override
  String get createGroupChannel => 'Создать группу/канал';

  @override
  String get channelAdminOnly => 'Канал (только администратор)';

  @override
  String get viewByToken => 'Просмотр по токену';

  @override
  String get viewByIp => 'Просмотр по IP (внешний сервер)';

  @override
  String get createGroupOrChannel => 'Создать группу или канал';

  @override
  String get removeExternalServerTitle => 'Удалить внешний сервер?';

  @override
  String removeExternalServerContent(String name) {
    return 'Удалить \"$name\" и все его группы из списка? Вы сможете переподключиться позже.';
  }

  @override
  String get noGroupsYet => 'Групп пока нет';

  @override
  String get groupNameLabel => 'Название группы:';

  @override
  String get groupNameHint => 'Введите название';

  @override
  String get pasteToken => 'Вставьте токен:';

  @override
  String get create => 'Создать';

  @override
  String get view => 'Просмотр';

  @override
  String get leave => 'Выйти';

  @override
  String get remove => 'Удалить';

  @override
  String get leaveGroupAction => 'Покинуть';

  @override
  String leaveGroupContent(String name) {
    return 'Покинуть \"$name\"? Вы больше не будете получать сообщения из неё.';
  }

  @override
  String get chooseCrypto => 'Выберите криптовалюту для доната';

  @override
  String get addressCopied => 'адрес скопирован';

  @override
  String get hideFromSearch => 'Не показывать меня в поиске';

  @override
  String get hideFromSearchSubtitle =>
      'Другие пользователи не смогут найти вас по имени';

  @override
  String get hideFromSearchSavedOk => ' Настройки приватности сохранены';

  @override
  String get hideFromSearchSavedFail =>
      ' Сохранено локально, ошибка синхронизации';

  @override
  String get statusVisibility => 'Видимость';

  @override
  String get statusShowStatus => 'Показывать';

  @override
  String get statusHideStatus => 'Скрывать';

  @override
  String get statusCustomText => 'Текст статуса';

  @override
  String get statusWhenOnline => 'Когда онлайн';

  @override
  String get statusWhenOffline => 'Когда офлайн';

  @override
  String get statusSavedOk => ' Настройки статуса сохранены и синхронизированы';

  @override
  String get statusSavedFail => ' Сохранено локально, ошибка синхронизации';

  @override
  String get clearServerCacheTitle => 'Очистить серверный кэш?';

  @override
  String get clearServerCacheContent =>
      'Это удалит все загруженные медиа с сервера:n\'\n        \'• Голосовые сообщенияn\'\n        \'• Изображенияn\'\n        \'• Видеоn\'\n        \'• Файлыn\'\n        \'• Аватарnn\'\n        \'Локальный кэш останется. Действие необратимо.';

  @override
  String get serverMediaCleared => ' Серверный кэш полностью очищен';

  @override
  String get notLoggedIn => 'Не авторизован';

  @override
  String get serverMediaManagerTitle => 'Серверные медиа';

  @override
  String get cacheTabImages => 'Изображения';

  @override
  String get cacheTabVoice => 'Голос';

  @override
  String get cacheTabAudio => 'Аудио';

  @override
  String get cacheTabVideo => 'Видео';

  @override
  String get cacheTabFiles => 'Файлы';

  @override
  String get cacheTabDocuments => 'Документы';

  @override
  String get cacheTabArchives => 'Архивы';

  @override
  String get cacheTabData => 'Данные';

  @override
  String get cacheTabAvatars => 'Аватары';

  @override
  String get cacheNoFiles => 'Нет файлов в этой категории';

  @override
  String get cacheClearTabTitle => 'Очистить категорию?';

  @override
  String cacheClearTabContent(String typeName) {
    return 'Удалить все файлы в категории \"$typeName\"? Действие необратимо.';
  }

  @override
  String get cacheFileDeleteFailed => 'Не удалось удалить файл';

  @override
  String get cacheClearAll => 'Очистить всё';

  @override
  String get cacheClearTab => 'Очистить вкладку';

  @override
  String get cleanUnusedFiles => 'Очистить неиспользуемые файлы';

  @override
  String get cleaningUnusedFiles => 'Очистка...';

  @override
  String get orphanedCleanupAppNotReady => 'Приложение ещё не готово';

  @override
  String get orphanedCleanupNoFiles => 'Неиспользуемые файлы не найдены';

  @override
  String get manageCacheTitle => 'Управление кэшем';

  @override
  String get manageCacheButton => 'Управление кэшем медиа';

  @override
  String get localCacheTab => 'Локальный';

  @override
  String get serverCacheTab => 'Серверный';

  @override
  String get cacheSelectAll => 'Выбрать все';

  @override
  String get cacheDeselectAll => 'Снять выбор';

  @override
  String get cacheSelected => 'выбрано';

  @override
  String get clearLocalCacheDialogTitle => 'Очистить кэш?';

  @override
  String get clearLocalCacheDialogContent =>
      'Удалить весь кэшированный медиаконтент (голос, фото, видео)?nЗагрузки на сервере и история чатов не затрагиваются.';

  @override
  String get deleteAllLogsTitle => 'Удалить все логи?';

  @override
  String get deleteAllLogsContent =>
      'Все файлы логов будут безвозвратно удалены с диска.\nДействие необратимо.';

  @override
  String get noLogsFound => 'Лог-файлы не найдены.';

  @override
  String get changePasswordInfo =>
      'Введите фразу восстановления и текущий пароль для установки нового.';

  @override
  String get changePasswordPassphraseLabel => 'Фраза восстановления (12 слов)';

  @override
  String get changePasswordCurrentLabel => 'Текущий пароль';

  @override
  String get changePasswordNewLabel => 'Новый пароль (минимум 16 символов)';

  @override
  String get changePasswordChange => 'Изменить';

  @override
  String get changePasswordFieldsRequired => 'Заполните все поля';

  @override
  String get changePasswordTooShort =>
      'Новый пароль должен содержать минимум 16 символов';

  @override
  String get changePasswordChanging => 'Изменение пароля...';

  @override
  String get changePasswordSuccess => ' Пароль успешно изменён';

  @override
  String get clearBgTitle => 'Убрать фон?';

  @override
  String get clearBgContent =>
      'Убрать пользовательский фон чата и восстановить стандартный.';

  @override
  String get chatBgSet => ' Фон чата установлен';

  @override
  String get chatBgCleared => 'Фон убран';

  @override
  String get sendAsCodeTitle => 'Отправить как код?';

  @override
  String get sendAsCodeContent =>
      'Это сообщение похоже на код. Отправить его как отформатированный блок кода?';

  @override
  String get sendAsCode => 'Отправить как код';

  @override
  String get sendAsPlainText => 'Отправить как текст';

  @override
  String get allMessagesLeft => 'Все сообщения: слева';

  @override
  String get allMessagesRight2 => 'Все сообщения: справа';

  @override
  String get allMessagesMixed => 'Все сообщения: смешанно';

  @override
  String get applyBackgroundToApp => 'Применить фон во всём приложении';

  @override
  String get uiElementsOpacityLabel => 'Прозрачность элементов';

  @override
  String get uiElementsBrightnessLabel => 'Яркость элементов';

  @override
  String get navPanelPosition => 'Позиция панели навигации';

  @override
  String get navPosBottom => 'Снизу (под списком чатов)';

  @override
  String get navPosLeft => 'Слева (боковая панель)';

  @override
  String get tabSwiping => 'Свайп между вкладками';

  @override
  String get tabSwipingSubtitle => 'Переключать вкладки свайпом';

  @override
  String get showAvatarsInChats => 'Аватары в чатах';

  @override
  String get smoothScrollDown => 'Плавная прокрутка';

  @override
  String get messageAnimations => 'Анимации сообщений';

  @override
  String get chatListMoveAnimations => 'Анимация перемещения чатов';

  @override
  String get scrollDownButtonPosition => 'Положение кнопки вниз';

  @override
  String get scrollDownButtonPositionLeft => 'Слева';

  @override
  String get scrollDownButtonPositionCenter => 'По центру';

  @override
  String get scrollDownButtonPositionRight => 'Справа';

  @override
  String get scrollDownButtonSize => 'Размер кнопки вниз';

  @override
  String get loadOlderMessagesOnScroll => 'Старые сообщения';

  @override
  String get showSnackbars => 'Всплывающие уведомления';

  @override
  String get autoLoadVideos => 'Загружать видео сразу';

  @override
  String get autoLoadVideosSubtitle =>
      'Когда выключено, видео грузятся только по нажатию — меньше лагов при прокрутке';

  @override
  String get tapToLoadVideo => 'Нажмите, чтобы загрузить';

  @override
  String get chooseBackground => 'Выбрать';

  @override
  String get presetsBackground => 'Пресеты';

  @override
  String get clearBackground2 => 'Очистить';

  @override
  String get liquidGlassSubtitle =>
      'Настройки эффектов стекла для каждого элемента';

  @override
  String get liquidGlassNavBarLabel => 'Навигационная панель';

  @override
  String get liquidGlassNavBarDesc => 'Эффект стекла нижней навигации';

  @override
  String get liquidGlassCardsLabel => 'Карточки и список';

  @override
  String get liquidGlassCardsDesc =>
      'Эффект стекла в списке чатов и настройках';

  @override
  String get liquidGlassInputLabel => 'Панель ввода';

  @override
  String get liquidGlassInputDesc => 'Эффект стекла панели ввода';

  @override
  String get liquidGlassSearchLabel => 'Поиск';

  @override
  String get liquidGlassSearchDesc => 'Стеклянная панель поиска';

  @override
  String get liquidGlassAppBarLabel => 'Кнопки шапки';

  @override
  String get liquidGlassAppBarDesc =>
      'Эффект стекла на кнопках верхней панели чата';

  @override
  String get sendFavoritesScanHint =>
      'Наведите камеру на QR-кодnна устройстве получателя';

  @override
  String get mediaPickerGallery => 'Галерея';

  @override
  String get mediaPickerCamera => 'Камера';

  @override
  String get mediaPickerFile => 'Файл';

  @override
  String mediaPickerSend(int n) {
    return 'Отправить $n';
  }

  @override
  String get mediaPickerChooseWallpaper => 'Выбрать обои';

  @override
  String get mediaPickerFiles => 'Файлы';

  @override
  String get mediaPickerDeniedTitle => 'Доступ к галерее запрещён';

  @override
  String get mediaPickerDeniedBody =>
      'Разрешите доступ в настройках или выберите файл напрямую.';

  @override
  String get mediaPickerPickFile => 'Выбрать файл';

  @override
  String get mediaPickerOpenSettings => 'Настройки';

  @override
  String get notifWarning =>
      'Уведомления доставляются только пока приложение запущено в фоне. Чтобы не пропускать сообщения, держите ONYX свёрнутым.';

  @override
  String get backgroundServiceTitle => 'Фоновая служба';

  @override
  String get backgroundServiceSubtitle =>
      'Держать ONYX на связи при свёрнутом приложении';

  @override
  String get backgroundServiceEnableLabel => 'Работать в фоне';

  @override
  String get backgroundServiceEnableSubtitle =>
      'Показывает постоянное уведомление, чтобы система не останавливала получение сообщений при свёрнутом приложении';

  @override
  String get backgroundServiceTextLabel => 'Текст уведомления';

  @override
  String get backgroundServiceDefaultText => 'Ожидание сообщений';

  @override
  String get notifPopupPosition => 'Позиция попапа';

  @override
  String get notifPopupPositionSubtitle =>
      'Выберите угол экрана для показа уведомлений';

  @override
  String get notifEnableLabel => 'Включить уведомления';

  @override
  String get notifHideContentLabel => 'Скрывать содержимое';

  @override
  String get notifSoundEnableLabel => 'Звук уведомлений';

  @override
  String get notifSoundChooseLabel => 'Выберите звук';

  @override
  String get notifSoundCustom => 'Загрузить свой звук...';

  @override
  String get notifSoundCustomLoaded => 'Кастомный звук установлен';

  @override
  String get notifSoundCustomError => 'Не удалось загрузить звук';

  @override
  String get notifSoundCustomInvalidFormat =>
      'Поддерживаются: WAV, MP3, M4A, OGG, AAC';

  @override
  String get resetting => 'Сброс...';

  @override
  String get launchAtStartupLabel => 'Автозапуск';

  @override
  String get launchAtStartupSubtitle =>
      'Запускать ONYX автоматически при входе в систему';

  @override
  String get launchAtStartupEnabled => 'Автозапуск включён';

  @override
  String get launchAtStartupDisabled => 'Автозапуск отключён';

  @override
  String get launchAtStartupFailed => 'Не удалось изменить автозапуск';

  @override
  String get avatarUpdated => 'Аватар обновлён';

  @override
  String get fileNotFound => 'Файл не найден';

  @override
  String get fileSent => 'Файл отправлен';

  @override
  String get imageSent => 'Изображение отправлено';

  @override
  String get videoSent => 'Видео отправлено';

  @override
  String uploadingFile(String name) {
    return 'Загрузка $name...';
  }

  @override
  String albumSent(int n) {
    return 'Альбом отправлен ($n фото)';
  }

  @override
  String get fileEmpty => 'Файл пустой';

  @override
  String get networkError => 'Ошибка сети';

  @override
  String get avatarRemoved => 'Аватар удалён';

  @override
  String get uinCopied => 'UIN скопирован';

  @override
  String get displayNameLength => 'Имя должно быть от 1 до 16 символов';

  @override
  String get failedSendLan => 'Ошибка отправки по LAN';

  @override
  String get fileCancelled => 'Отправка отменена';

  @override
  String get doneRestarting => 'Готово! Перезапуск...';

  @override
  String get deleteMessageTitle => 'Удалить сообщение?';

  @override
  String get deleteMessageContent =>
      'Сообщение будет удалено для обеих сторон.';

  @override
  String get cannotDeleteMsg =>
      'Нельзя удалить: сообщение ещё не сохранено на сервере';

  @override
  String get deleteForMeTitle => 'Удалить только у себя?';

  @override
  String get deleteForMeContent =>
      'Сообщение будет удалено только с вашего устройства. У собеседника оно останется.';

  @override
  String get deleteFavMessageContent =>
      'Сообщение будет удалено из избранного.';

  @override
  String get pinnedMessage => 'Закреплённое сообщение';

  @override
  String get setReminder => 'Поставить напоминание';

  @override
  String get cancelReminder => 'Отменить напоминание';

  @override
  String get reminderSet => 'Напоминание установлено';

  @override
  String get reminderCancelled => 'Напоминание отменено';

  @override
  String get reminderNotificationPrefix => 'Напоминание';

  @override
  String get reminderGenericBody => 'У вас есть напоминание';

  @override
  String get reminderHourLabel => 'Час';

  @override
  String get reminderMinuteLabel => 'Минута';

  @override
  String get reminderPickDate => 'Указать дату';

  @override
  String get reminderDateToday => 'Сегодня';

  @override
  String get reminderDateTomorrow => 'Завтра';

  @override
  String get reminderInvalidTime => 'Введите корректное время';

  @override
  String get reminderPastTime => 'Это время уже прошло';

  @override
  String get msgCopied => 'Скопировано';

  @override
  String copiedUsername(String name) {
    return 'Скопировано @$name';
  }

  @override
  String get deliveryModeTitle => 'Режим доставки';

  @override
  String get deliveryInternet => 'Интернет';

  @override
  String get deliveryInternetSubtitle => 'Отправка через сервер (зашифровано)';

  @override
  String get deliveryLanSubtitle => 'Отправка по локальной сети (напрямую)';

  @override
  String get deliveryUserNotInLan => 'Пользователь не найден в LAN';

  @override
  String get fastChange => 'Быстрое переключение';

  @override
  String get fastChangeSubtitle => 'Переключать режим долгим нажатием';

  @override
  String get lanModeEnabled => 'Режим LAN включён';

  @override
  String get internetModeEnabled => 'Режим интернет включён';

  @override
  String get previewMessageTitle => 'Предпросмотр сообщения';

  @override
  String get previewYourMessage => 'Ваше сообщение:';

  @override
  String replyingTo(String name) {
    return 'Ответ: $name';
  }

  @override
  String get send => 'Отправить';

  @override
  String get fileSentLan => 'Файл отправлен по LAN';

  @override
  String uploadingImages(int n) {
    return 'Загрузка $n изображений...';
  }

  @override
  String get albumUploadFailed => 'Ошибка загрузки альбома';

  @override
  String get message => 'Написать';

  @override
  String get noMessagesYet => 'Нет сообщений';

  @override
  String get voiceCallsTitle => 'Голосовые звонки';

  @override
  String get voiceCallsContent =>
      'Голосовые звонки пока работают только через LAN (локальная сеть).\n\nМы собираем средства на поддержку сервера и разработку альтернативы.';

  @override
  String get supportOnyxBtn => 'Задонатить';

  @override
  String get call => 'Позвонить';

  @override
  String get securityCheckTitle => 'Проверка безопасности';

  @override
  String securityCheckContent(String name) {
    return 'Сравните эти эмодзи с $name.\nЕсли совпадают — ваш чат защищён.';
  }

  @override
  String get failedToFetchPubkey => 'Ошибка получения публичного ключа';

  @override
  String get userHasNoPubkey => 'У пользователя нет публичного ключа';

  @override
  String get galleryMenuLabel => 'Галерея';

  @override
  String get galleryTitle => 'Галерея';

  @override
  String get galleryTabMedia => 'Медиа';

  @override
  String get galleryTabVoice => 'Голосовые';

  @override
  String get galleryTabFiles => 'Файлы';

  @override
  String get galleryEmptyMedia => 'Нет фото и видео';

  @override
  String get galleryEmptyVoice => 'Нет голосовых сообщений';

  @override
  String get galleryEmptyFiles => 'Нет файлов';

  @override
  String get galleryShowInChat => 'Показать в чате';

  @override
  String get failedDelete => 'Не удалось удалить';

  @override
  String get failedEdit => 'Не удалось изменить сообщение';

  @override
  String get failedReaction => 'Не удалось поставить реакцию';

  @override
  String get noInternetCached =>
      'Нет интернета — показаны кэшированные сообщения';

  @override
  String get sendFailed => 'Ошибка отправки';

  @override
  String get mediaUploadNotSupportedWeb =>
      'Загрузка медиа недоступна в веб-версии';

  @override
  String get localFileRequired => 'Требуется локальный файл';

  @override
  String get uploadFailed => 'Ошибка загрузки';

  @override
  String get voiceUploadFailed => 'Ошибка загрузки голосового';

  @override
  String get voiceCancelled => 'Голосовое отменено';

  @override
  String get uploadingVoice => 'Загрузка голосового...';

  @override
  String uploadingAlbumProgress(int done, int total) {
    return 'Загрузка альбома: $done/$total фото';
  }

  @override
  String get uploadingImageLabel => 'Загрузка изображения...';

  @override
  String get uploadingVideoLabel => 'Загрузка видео...';

  @override
  String get uploadingAudioLabel => 'Загрузка аудио...';

  @override
  String get uploadingFileLabel => 'Загрузка файла...';

  @override
  String get leftGroup => 'Вы вышли из группы';

  @override
  String get failedLeaveGroup => 'Не удалось покинуть группу';

  @override
  String get avatarOnlyOwnerMod =>
      'Только владелец и модераторы могут менять аватар';

  @override
  String get failedReadFile => 'Не удалось прочитать файл';

  @override
  String get uploadingAvatar => 'Загрузка аватара...';

  @override
  String get avatarUpdatedGroup => 'Аватар группы обновлён';

  @override
  String get avatarDeleted => 'Аватар удалён';

  @override
  String get failedDeleteAvatar => 'Не удалось удалить аватар';

  @override
  String get copyLink => 'Скопировать ссылку';

  @override
  String get tokenCopied => 'Токен скопирован';

  @override
  String get groupNameLength => 'Название группы: 1–50 символов';

  @override
  String get groupUpdated => 'Группа обновлена';

  @override
  String get failedUpdateGroup => 'Не удалось обновить группу';

  @override
  String get deleteAvatarTitle => 'Удалить аватар?';

  @override
  String get deleteAvatarContent => 'Аватар группы будет удалён для всех.';

  @override
  String get deleteGroupMsgContent =>
      'Сообщение будет удалено для всех участников.';

  @override
  String get reply => 'Ответить';

  @override
  String get edit => 'Изменить';

  @override
  String get editGroupTitle => 'Редактировать группу';

  @override
  String get editChannelTitle => 'Редактировать канал';

  @override
  String get groupInfoTitle => 'Group';

  @override
  String get channelInfoTitle => 'Channel';

  @override
  String get channelNameLabel => 'Название канала';

  @override
  String get channelNameHint => 'Введите название канала';

  @override
  String unsupportedFileType(String ext) {
    return 'Неподдерживаемый тип файла: $ext';
  }

  @override
  String failedToConnect(String e) {
    return 'Ошибка подключения: $e';
  }

  @override
  String roleChanged(String role) {
    return 'Ваша роль изменена на $role';
  }

  @override
  String get unbannedReconnecting => 'Вы разбанены! Переподключение...';

  @override
  String get onlyModsCanPost =>
      'Только владелец и модераторы могут писать в каналах';

  @override
  String get failedSendMessage => 'Ошибка отправки сообщения';

  @override
  String get uploadFailedConnectionAborted =>
      'Ошибка загрузки: соединение прервано. Попробуйте файл меньшего размера.';

  @override
  String get failedSendMedia => 'Ошибка отправки медиа';

  @override
  String get joinedGroup => 'Вы присоединились к группе!';

  @override
  String get failedJoinGroup => 'Не удалось вступить в группу';

  @override
  String get cancelled => 'Отменено';

  @override
  String get avatarWillBeDeleted => 'Аватар будет удалён';

  @override
  String get ipCopied => 'IP скопирован';

  @override
  String get nameCannotBeEmpty => 'Название не может быть пустым';

  @override
  String get groupRenamed => 'Группа переименована';

  @override
  String errorMsg(String e) {
    return 'Ошибка: $e';
  }

  @override
  String get failedRename => 'Ошибка переименования';

  @override
  String get imageTooLarge => 'Изображение слишком большое (макс. 5 МБ)';

  @override
  String get avatarUpdatedSuccessfully => 'Аватар обновлён';

  @override
  String get failedUploadAvatar => 'Ошибка загрузки аватара';

  @override
  String get deletingAvatar => 'Удаление аватара...';

  @override
  String get avatarDeletedSuccessfully => 'Аватар удалён';

  @override
  String userBanned(String name) {
    return '$name заблокирован';
  }

  @override
  String get failedBan => 'Не удалось заблокировать';

  @override
  String roleUpdated(String role) {
    return 'Роль изменена на $role';
  }

  @override
  String get failedChangeRole => 'Не удалось изменить роль';

  @override
  String userUnbanned(String name) {
    return '$name разблокирован';
  }

  @override
  String get failedUnban => 'Не удалось разблокировать';

  @override
  String get youHaveBeenBanned => 'Вы заблокированы';

  @override
  String get renameGroupTitle => 'Переименовать группу';

  @override
  String get rename => 'Переименовать';

  @override
  String get join => 'Вступить';

  @override
  String get manageMembers => 'Управление участниками';

  @override
  String get banMemberTitle => 'Заблокировать участника';

  @override
  String get ban => 'Заблокировать';

  @override
  String get selectNewRole => 'Выберите новую роль:';

  @override
  String get moderator => 'Модератор';

  @override
  String get memberRole => 'Участник';

  @override
  String get manageMembersTitle => 'Управление участниками';

  @override
  String get viewBans => 'Заблокированные';

  @override
  String get unbanUserTitle => 'Разблокировать пользователя';

  @override
  String get unban => 'Разблокировать';

  @override
  String get bannedUsersTitle => 'Заблокированные пользователи';

  @override
  String get bannedFromGroup => 'Вы заблокированы в этой группе.';

  @override
  String bannedReason(String reason) {
    return 'Причина: $reason';
  }

  @override
  String get noBannedUsers => 'Нет заблокированных пользователей';

  @override
  String bannedBy(String name) {
    return 'Заблокировал: $name';
  }

  @override
  String bannedDate(String date) {
    return 'Дата: $date';
  }

  @override
  String banConfirm(String name) {
    return 'Заблокировать $name в группе?';
  }

  @override
  String get banReason => 'Причина (необязательно)';

  @override
  String changeRoleTitle(String name) {
    return 'Изменить роль: $name';
  }

  @override
  String currentRoleLabel(String role) {
    return 'Текущая роль: $role';
  }

  @override
  String ownerCount(int n) {
    return 'Владельцы: $n/3';
  }

  @override
  String get ownerCurrent => 'Владелец (текущий)';

  @override
  String get ownerLimitReached => 'Владелец (лимит достигнут)';

  @override
  String get owner => 'Владелец';

  @override
  String get cannotDemoteLastOwner => 'Нельзя понизить последнего владельца';

  @override
  String get noMembersYet => 'Нет участников';

  @override
  String get changeRole => 'Изменить роль';

  @override
  String unbanConfirm(String name) {
    return 'Разблокировать $name?';
  }

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get failedCreateGroup => 'Не удалось создать группу';

  @override
  String get invalidInviteLinkFormat => 'Неверный формат ссылки';

  @override
  String get invalidInviteLink => 'Недействительная ссылка';

  @override
  String get groupAddedForViewing => 'Группа добавлена!';

  @override
  String get failedAddGroup => 'Не удалось добавить группу';

  @override
  String serverRemoved(String name) {
    return 'Сервер \"$name\" удалён';
  }

  @override
  String get channelAdminOnlySubtitle => 'Канал (только админы)';

  @override
  String get groupSubtitle => 'Группа';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get externalGroup => 'Внешняя группа';

  @override
  String get externalChannel => 'Внешний канал';

  @override
  String get joinExternalServer => 'Подключиться к серверу';

  @override
  String get enterServerAddress => 'Введите адрес сервера';

  @override
  String get enterValidIp => 'Введите корректный IP-адрес или хост';

  @override
  String couldNotConnect(String host) {
    return 'Не удалось подключиться к $host';
  }

  @override
  String get usernameRequiredMsg =>
      'Логин не указан. Убедитесь, что создали аккаунт в приложении.';

  @override
  String get passwordRequiredForGroups => 'Для групп необходим пароль';

  @override
  String get passwordRequired => 'Требуется пароль';

  @override
  String connectionFailed(String e) {
    return 'Ошибка подключения: $e';
  }

  @override
  String connectedToServer(String type, String name) {
    return 'Подключено к $type \"$name\"';
  }

  @override
  String get externalGroupType => 'внешней группе';

  @override
  String get externalChannelType => 'внешнему каналу';

  @override
  String get identityVisible => 'Ваш аккаунт будет виден серверу';

  @override
  String get usernameLabel => 'Имя пользователя';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get noPasswordForChannels => 'Для каналов пароль не требуется';

  @override
  String get noRegistrationRequired => 'Регистрация не требуется.';

  @override
  String get back => 'Назад';

  @override
  String get connecting => 'Подключение...';

  @override
  String get connectBtn => 'Подключить';

  @override
  String get serverInfoGroups => 'Группы';

  @override
  String get serverInfoMembers => 'Участники';

  @override
  String get serverInfoMedia => 'Медиа';

  @override
  String get serverInfoMaxFile => 'Макс. размер файла';

  @override
  String get profilePresets => 'Личность';

  @override
  String get profilePresetsSubtitle =>
      'Сохранённые личности для входа на внешние серверы';

  @override
  String get newPreset => 'Новая личность';

  @override
  String get editPreset => 'Изменить личность';

  @override
  String get deletePreset => 'Удалить личность';

  @override
  String deletePresetConfirm(String label) {
    return 'Удалить личность «$label»?';
  }

  @override
  String get presetLabel => 'Название личности';

  @override
  String get presetLabelHint => 'например, Работа, Игры';

  @override
  String get presetNote => 'Заметка';

  @override
  String get presetNoteHint => 'Для чего эта личность? (необязательно)';

  @override
  String get presetColor => 'Цвет метки';

  @override
  String get presetLabelRequired => 'Введите название личности';

  @override
  String get noPresetsYet => 'Пока нет личностей';

  @override
  String get noPresetsYetSubtitle =>
      'Сохраните связку логина и пароля один раз — используйте её на любом внешнем сервере';

  @override
  String get myPresets => 'Мои личности';

  @override
  String get usePreset => 'Использовать личность';

  @override
  String get saveAsPreset => 'Сохранить как личность';

  @override
  String get presetSaved => 'Личность сохранена';

  @override
  String get presetDeleted => 'Личность удалена';

  @override
  String get thirdPartyServer => 'СТОРОННИЙ СЕРВЕР';

  @override
  String get thirdPartyWarning =>
      'Этот сервер не управляется ONYX. Подключайтесь только если доверяете владельцу.';

  @override
  String get serverWillKnow => 'Сервер узнает:';

  @override
  String get serverWillNotReceive => 'Сервер НЕ получит:';

  @override
  String get knowIpAddress => 'Ваш IP-адрес';

  @override
  String get knowUsername => 'Ваш логин';

  @override
  String get knowMessages => 'Содержимое ваших сообщений на этом сервере';

  @override
  String get notReceiveAccount => 'Ваш аккаунт и пароль ONYX';

  @override
  String get notReceiveContacts => 'Ваши контакты и личные чаты';

  @override
  String get notReceiveKeys => 'Ваши ключи шифрования';

  @override
  String get yourPassphraseTitle => 'Ваша секретная фраза';

  @override
  String get sessionExpiredBanner => 'Сессия истекла — войдите заново';

  @override
  String get sessionExpiredTitle => 'Сессия истекла';

  @override
  String get sessionExpiredSubtitle => 'Войдите заново';

  @override
  String get sessionSignIn => 'Войти';

  @override
  String get sessionRenewSoon => 'Скоро потребуется повторный вход';

  @override
  String get sessionStillValid => 'Токен авторизации действителен';

  @override
  String get blockedUsersTitle => 'Заблокированные';

  @override
  String get blockedUsersSubtitle => 'Управление блокировками';

  @override
  String get blockedUsersEmpty => 'Список заблокированных пуст';

  @override
  String get unblockAction => 'Разблокировать';

  @override
  String get writeMessage => 'Написать';

  @override
  String get fakePinTitle => 'Фейковый PIN';

  @override
  String get fakePinSubtitle => 'Открыть фейковый аккаунт под принуждением';

  @override
  String get fakePinSheetTitle => 'Настройка фейкового PIN';

  @override
  String get fakePinStatusActive => 'Активен';

  @override
  String get fakePinStatusOff => 'Выкл';

  @override
  String get fakePinDescription =>
      'Когда этот PIN вводится на экране блокировки, приложение открывается с фейковым аккаунтом вместо настоящего.';

  @override
  String get setFakePin => 'Установить фейковый PIN';

  @override
  String get disableFakePin => 'Отключить фейковый PIN';

  @override
  String get changeFakePin => 'Изменить фейковый PIN';

  @override
  String get disableFakePinTitle => 'Отключить фейковый PIN?';

  @override
  String get disableFakePinContent =>
      'Фейковый PIN будет удалён. Настройки фейкового аккаунта сохранятся.';

  @override
  String get fakePinEnabledSnack => 'Фейковый PIN включён';

  @override
  String get fakePinDisabledSnack => 'Фейковый PIN отключён';

  @override
  String get fakePinCannotMatchReal =>
      'Фейковый PIN не может совпадать с реальным';

  @override
  String get decoyAccountSection => 'Фейковый аккаунт';

  @override
  String get decoyAccountSubtitle =>
      'Этот аккаунт будет показан при вводе фейкового PIN';

  @override
  String get decoyDisplayNameLabel => 'Имя';

  @override
  String get decoyUsernameLabel => 'Имя пользователя';

  @override
  String get decoyDisplayNameHint => 'Введите имя';

  @override
  String get decoyUsernameHint => 'Введите логин';

  @override
  String get saveDecoyAccount => 'Сохранить фейковый аккаунт';

  @override
  String get decoyAccountSaved => 'Фейковый аккаунт сохранён';

  @override
  String get decoyFieldsRequired => 'Имя и логин не могут быть пустыми';

  @override
  String get removeAvatar => 'Удалить аватарку';

  @override
  String get fakePinSecurityNote =>
      'Фейковый PIN должен отличаться от реального. Фейковый аккаунт не подключается ни к какому серверу — он показывает только настроенный вами профиль.';

  @override
  String get decoyNoChats => 'Нет чатов';

  @override
  String get decoyNoGroups => 'Нет групп';

  @override
  String get decoyNoFavorites => 'Нет избранного';

  @override
  String get decoyOtherAccounts => 'Другие аккаунты';

  @override
  String get decoyNoOtherAccounts => 'Нет других аккаунтов';

  @override
  String get lock => 'Заблокировать';

  @override
  String get decoyAppearance => 'Внешний вид';

  @override
  String get decoyNotifications => 'Уведомления';

  @override
  String get decoyStorage => 'Хранилище';

  @override
  String get decoyAppearanceSubtitle => 'Тема и параметры отображения';

  @override
  String get decoyNotificationsSubtitle => 'Звук и оповещения';

  @override
  String get decoyStorageSubtitle => 'Управление кэшем файлов';

  @override
  String get decoyContactsSection => 'Фейковые чаты';

  @override
  String get decoyContactsSubtitle =>
      'Добавьте контакты с перепиской — они появятся когда открывается фейк-аккаунт';

  @override
  String get generateContacts => 'Сгенерировать контакты';

  @override
  String get addDecoyContact => 'Добавить контакт';

  @override
  String get decoyNoContacts => 'Нет фейковых чатов';

  @override
  String get decoyContactUsername => 'Юзернейм контакта';

  @override
  String get decoyContactDisplayName => 'Имя контакта';

  @override
  String contactsGenerated(int n) {
    return 'Добавлено $n контактов';
  }

  @override
  String get contactAdded => 'Контакт добавлен';

  @override
  String get contactRemoved => 'Контакт удалён';

  @override
  String get decoyContactExists => 'Такой контакт уже есть';

  @override
  String get decoyContactsCleared => 'Все чаты очищены';

  @override
  String get clearDecoyChats => 'Очистить все чаты';

  @override
  String get messagesCount => 'сообщений';

  @override
  String get add => 'Добавить';

  @override
  String get decoyChatsSubtitle => 'Контакты с историей переписки';

  @override
  String get decoyGroupsSection => 'Группы и каналы';

  @override
  String get decoyGroupsSubtitle => 'Фейковые группы и каналы';

  @override
  String get decoyFavoritesSection => 'Избранное';

  @override
  String get decoyFavoritesSubtitle => 'Закреплённые чаты';

  @override
  String get noFakeGroups => 'Нет групп';

  @override
  String get noFakeFavorites => 'Нет избранного';

  @override
  String get addFakeGroup => 'Группу';

  @override
  String get addFakeChannel => 'Канал';

  @override
  String get addFakeFavorite => 'Добавить избранное';

  @override
  String get groupType => 'Группа';

  @override
  String get channelType => 'Канал';

  @override
  String get favTitleHint => 'Название';

  @override
  String get generateAll => 'Сгенерировать всё';

  @override
  String get generateAllConfirm =>
      'Будет сгенерирован случайный контент. Текущие данные будут заменены.';

  @override
  String get sendFavoritesTitle => 'Отправка избранного';

  @override
  String get sendFavoritesShowQrToReceiver => 'Показать QR получателю';

  @override
  String get sendFavoritesScanReceiver => 'Сканировать QR получателя';

  @override
  String get sendFavoritesSending => 'Идёт отправка избранного';

  @override
  String get sendFavoritesSelectTitle => 'Выберите чаты для отправки';

  @override
  String get sendFavoritesHintDesktop =>
      'Получатель должен нажать «Получить» первым. Затем сканируйте QR-код здесь.';

  @override
  String get sendFavoritesHintMobile =>
      'Получатель должен нажать «Получить» первым и показать QR-код.';

  @override
  String allChatsCount(int n) {
    return 'Все чаты ($n)';
  }

  @override
  String get sendFavoritesNoFavs => 'Нет избранных чатов.';

  @override
  String get sendFavoritesSelectAtLeastOne => 'Выберите хотя бы один чат';

  @override
  String get sendFavoritesShowQrBtn => 'Показать QR';

  @override
  String get sendFavoritesScanQrBtn => 'Сканировать QR';

  @override
  String get receiveFavoritesTitle => 'Получение избранного';

  @override
  String get receiveFavoritesScanSender => 'Сканировать QR отправителя';

  @override
  String get receiveFavoritesScanOnSender =>
      'Сканируйте QR на устройстве отправителя';

  @override
  String get receiveFavoritesInstruction =>
      'Откройте Избранное → Синхронизация → Отправить, затем сканируйте этот код';

  @override
  String get receiveFavoritesE2E =>
      'Сквозное шифрование · только локальная сеть';

  @override
  String get receiveFavoritesScanHint =>
      'Наведите камеру на QR-кодnна устройстве отправителя';

  @override
  String get receiveFavoritesScanEncrypted =>
      'Передача зашифрована · только локальная сеть';

  @override
  String get receiveFavoritesWaiting =>
      'Ожидание сканирования QR-кода отправителем…';

  @override
  String get receiveFavoritesComplete => 'Передача завершена.';

  @override
  String get receiveFavoritesConnecting => 'Подключение к отправителю…';

  @override
  String get receiveFavoritesConnected => 'Подключено! Ожидание файлов…';

  @override
  String get cancelTransfer => 'Прервать передачу';

  @override
  String get wardLinkTitle => 'WardLink';

  @override
  String get wardLinkSubtitle =>
      'Пассивная синхронизация между вашими устройствами в локальной сети';

  @override
  String get wardLinkEnable => 'Пассивная синхронизация';

  @override
  String get wardLinkEnableDesc =>
      'Автоматически синхронизировать данные с доверенными устройствами, когда они в одной сети. На телефоне работает, пока приложение открыто; на компьютере — постоянно.';

  @override
  String get wardLinkPairedDevices => 'Доверенные устройства';

  @override
  String get wardLinkNoPairedDevices => 'Нет сопряжённых устройств';

  @override
  String get wardLinkAddDevice => 'Добавить';

  @override
  String get wardLinkRemoveDevice => 'Удалить';

  @override
  String get wardLinkRemoveConfirm =>
      'Перестать синхронизироваться с этим устройством?';

  @override
  String get wardLinkFavoritesOnlyNote =>
      'Синхронизируется содержимое «Избранного» — сообщения и медиа';

  @override
  String get wardLinkMaxFileSize => 'Лимит размера файла';

  @override
  String get wardLinkPairTitle => 'Сопряжение устройства';

  @override
  String get wardLinkShowCode => 'Показать код';

  @override
  String get wardLinkScanCode => 'Сканировать код';

  @override
  String get wardLinkShowInstruction =>
      'Откройте WardLink на другом своём устройстве и отсканируйте этот код';

  @override
  String get wardLinkScanInstruction =>
      'Наведите камеру на код WardLink другого устройства';

  @override
  String get wardLinkPairedOk => 'Устройство сопряжено';

  @override
  String get wardLinkPairFailed => 'Не удалось выполнить сопряжение';

  @override
  String get wardLinkE2E => 'Сквозное шифрование · только LAN';

  @override
  String get wardLinkSyncingNow => 'Синхронизация…';

  @override
  String get wardLinkDone => 'Синхронизировано';

  @override
  String get wardLinkCurrentFile => 'Текущий файл';

  @override
  String get wardLinkLog => 'Журнал синхронизации';

  @override
  String get wardLinkLogEmpty => 'Событий пока нет';

  @override
  String get wardLinkHoldForLog => 'Удерживайте кружок для журнала';

  @override
  String get wardLinkUpToDate => 'Всё актуально';

  @override
  String syncedFromDevice(String device) {
    return 'Синхронизировано с устройства $device';
  }

  @override
  String get syncedFromUnknownDevice => 'Синхронизировано с другого устройства';

  @override
  String wardLinkFilesDone(int n) {
    return 'Передано файлов: $n';
  }

  @override
  String get wardLinkNoFilesYet => 'Файлы не передавались';

  @override
  String wardLinkSyncedAgo(String when) {
    return 'Синхронизировано: $when';
  }

  @override
  String get wardLinkNeverSynced => 'Ещё не синхронизировано';

  @override
  String get wardLinkFirewallHintWindows =>
      'Если телефон не может подключиться к ПК — разрешите ONYX в брандмауэре Windows (порт TCP 47832). ONYX пробует добавить правило автоматически, но при необходимости: Брандмауэр Windows → Дополнительные параметры → Входящие правила → Создать правило → Порт → TCP → 47832.';

  @override
  String get wardLinkFirewallHintMac =>
      'Если телефон не может подключиться к Mac — убедитесь, что брандмауэр macOS не блокирует входящие соединения для ONYX: Системные настройки → Сеть → Брандмауэр → Параметры → добавьте ONYX.';

  @override
  String get wardLinkFirewallHintLinux =>
      'Если телефон не может подключиться — откройте порт TCP 47832 в вашем брандмауэре. Например: sudo ufw allow 47832/tcp  или  sudo firewall-cmd --add-port=47832/tcp --permanent';

  @override
  String get wardLinkSyncFromBeginning => 'Синхронизировать с начала';

  @override
  String get wardLinkSyncFromBeginningDesc =>
      'Подтянуть всю историю, которой нет на этом устройстве';

  @override
  String get wardLinkSyncPending => 'Синхронизация в процессе…';

  @override
  String get wardLinkBubbleVisibility => 'Кружок синхронизации';

  @override
  String get wardLinkBubbleShowAlways => 'Показывать всегда';

  @override
  String get wardLinkBubbleShowOnErrors => 'Показывать только при ошибках';

  @override
  String get wardLinkBubbleSize => 'Размер кружка';

  @override
  String get wardLinkSyncFavoritesToggle => 'Синхронизировать избранное';

  @override
  String get wardLinkSyncFavoritesToggleDesc =>
      'Синхронизировать избранные чаты — их сообщения и медиа';

  @override
  String get wardLinkSyncPersonalToggle => 'Синхронизировать мои сообщения';

  @override
  String get wardLinkSyncPersonalToggleDesc =>
      'Синхронизировать на другие устройства только те сообщения, которые отправили ВЫ, в личных чатах — сообщения собеседника и так приходят с сервера и никогда не передаются этим способом';

  @override
  String get meshSubtitle => 'Mesh-сеть без интернета';

  @override
  String get meshEnable => 'Включить Mesh-сеть';

  @override
  String get meshEnableDesc =>
      'Прямое общение без интернета через Wi-Fi или Bluetooth.\nРаботает только в личных чатах.';

  @override
  String get meshUnavailable => 'Mesh-сеть недоступна на этой платформе.';

  @override
  String get meshOpenRadar => 'Открыть Радар';

  @override
  String meshNearbyCount(int n) {
    return 'В эфире: $n устройств';
  }

  @override
  String get meshRadarTitle => 'Mesh Радар';

  @override
  String get meshRadarScanning => 'Сканируем эфир…';

  @override
  String get meshRadarSearchHint => 'Поиск по имени...';

  @override
  String meshRadarSearchEmpty(String q) {
    return 'Никого не найдено по запросу \"$q\"';
  }

  @override
  String get meshRadarNoDevices =>
      'Нет устройств поблизости.\nMesh сканирует каждые 20 сек.';

  @override
  String get meshRadarDisabled =>
      'Mesh режим выключен.\nВключите тоггл в Настройках → Mesh.';

  @override
  String get meshRadarStarting => 'Запускаем сканирование BLE…';

  @override
  String get meshMenuRadar => 'Радар';

  @override
  String get meshMenuDiagnostics => 'Диагностика';

  @override
  String get meshMenuModeAuto => 'Авто';

  @override
  String get meshBluetoothOffTitle => 'Bluetooth выключен';

  @override
  String get meshBluetoothOffContent =>
      'Mesh-чат переключён в режим \"только Bluetooth\", но Bluetooth выключен. Включите его в настройках системы, чтобы видеть устройства поблизости.';

  @override
  String get meshOpenSystemSettings => 'Открыть настройки';

  @override
  String get meshModeLabel => 'РЕЖИМ';

  @override
  String get meshModeActive => 'Mesh режим активен';

  @override
  String get meshChatLabel => 'Mesh Чат';

  @override
  String get meshLocationRequired =>
      'Включите службы геолокации для BLE сканирования (Android ≤11)';

  @override
  String get meshChatEmpty =>
      'Нет сообщений.\nОтправьте первое сообщение через Mesh.';

  @override
  String get meshChatInputHint => 'Сообщение…';

  @override
  String get meshChatSend => 'Отправить';

  @override
  String get meshChatOutOfRange => 'Вне зоны';

  @override
  String get meshStatusSending => 'Отправка…';

  @override
  String get meshStatusSendingWifi => 'Отправка через Wi-Fi…';

  @override
  String get meshStatusSendingBle => 'Отправка через Bluetooth…';

  @override
  String get meshStatusRelayed => 'В пути через сеть';

  @override
  String get meshStatusDelivered => 'Доставлено';

  @override
  String get meshStatusFailed => 'Не доставлено';

  @override
  String get meshStatusRetry => 'Повторить';

  @override
  String get meshStatusFailedHint => 'Сообщение не дошло до получателя';

  @override
  String get meshErrorVideoWifiOnly =>
      'Видео отправляется только через Wi-Fi. Подключитесь к той же Wi-Fi сети, что и получатель.';

  @override
  String get meshErrorFileTooLargeForBle =>
      'Файл слишком большой для Bluetooth (макс. 10 МБ). Нужен общий Wi-Fi.';

  @override
  String get meshErrorFileTooLarge => 'Файл слишком большой (макс. 200 МБ).';

  @override
  String get meshErrorAttachmentsUnsupported =>
      'Вложения только на мобильных/десктопе';

  @override
  String get meshErrorPickFileFailed => 'Ошибка выбора файла';

  @override
  String get meshErrorSendFileFailed => 'Ошибка отправки файла';

  @override
  String get meshErrorSendVoiceFailed => 'Ошибка отправки голосового сообщения';

  @override
  String meshErrorOutOfRange(String username) {
    return '$username вне зоны досягаемости';
  }

  @override
  String get backupTitle => 'Бэкап';

  @override
  String get backupSubtitle => 'Локальное сохранение и восстановление данных';

  @override
  String get backupExport => 'Сохранить все данные';

  @override
  String get backupRestore => 'Восстановить из бэкапа';

  @override
  String get backupScope => 'Что бэкапить';

  @override
  String get backupFavorites => 'Избранные чаты';

  @override
  String get backupPersonal => 'Личные чаты';

  @override
  String get backupIncludeMedia => 'Включать медиа';

  @override
  String get backupMediaImages => 'Изображения';

  @override
  String get backupMediaVideos => 'Видео';

  @override
  String get backupMediaVoice => 'Голосовые и аудио';

  @override
  String get backupMediaOther => 'Другие файлы';

  @override
  String get backupSchedule => 'Запланированный бэкап';

  @override
  String get backupFreqOff => 'Выкл';

  @override
  String get backupFreqDaily => 'Каждый день';

  @override
  String get backupFreqWeekly => 'Каждую неделю';

  @override
  String get backupFreqMonthly => 'Каждый месяц';

  @override
  String get backupFolder => 'Папка авто-бэкапов';

  @override
  String get backupChangeFolder => 'Изменить';

  @override
  String get backupLastAuto => 'Последний авто-бэкап';

  @override
  String get backupNever => 'ещё не было';

  @override
  String get backupInProgress => 'Создание бэкапа…';

  @override
  String get backupRestoring => 'Восстановление…';

  @override
  String get backupSelectScope => 'Выберите хотя бы одну категорию';

  @override
  String get backupNoAccount => 'Нет активного аккаунта';

  @override
  String get backupNoPermission =>
      'Нет доступа к хранилищу. Разрешите «Доступ ко всем файлам» в настройках приложения.';

  @override
  String get backupOpenFolder => 'Открыть папку';

  @override
  String get backupFolderUnsupported =>
      'Эта папка недоступна. Выберите папку во внутреннем хранилище.';

  @override
  String get backupRestoreConfirmTitle => 'Восстановить из бэкапа?';

  @override
  String get backupRestoreConfirmBody =>
      'Данные из файла будут восстановлены поверх текущих (чаты, избранное, настройки).';

  @override
  String get backupRestartHint =>
      'Перезапустите приложение, чтобы увидеть изменения';

  @override
  String get recycleBinTitle => 'Корзина';

  @override
  String get recycleBinSubtitle =>
      'Удалённые чаты и защита от случайных удалений по синхронизации';

  @override
  String get recycleBinPendingTitle => 'Запросы на удаление';

  @override
  String recycleBinPendingDesc(String device, int count) {
    return 'Устройство «$device» предлагает удалить $count чат(ов). Применить или оставить?';
  }

  @override
  String get recycleBinApply => 'Удалить';

  @override
  String get recycleBinKeep => 'Оставить мои чаты';

  @override
  String get recycleBinNoPending => 'Нет ожидающих запросов на удаление';

  @override
  String get recycleBinResetTitle => 'Сбросить записи об удалениях';

  @override
  String get recycleBinResetDesc =>
      'Очищает список удалённых чатов. После этого синхронизация перестанет повторно удалять их на других устройствах и сможет вернуть их обратно.';

  @override
  String get recycleBinResetButton => 'Очистить список удалённых';

  @override
  String get recycleBinResetDone => 'Записи об удалениях очищены';

  @override
  String get recycleBinResetConfirm =>
      'Очистить все записи об удалениях для этого аккаунта?';

  @override
  String get accountGraph => 'График аккаунта';

  @override
  String get accountGraphSubtitleDesktopOn =>
      'Показывает граф чатов, групп и каналов, когда чат не открыт';

  @override
  String get accountGraphSubtitleMobileOn =>
      'Визуализация вашего аккаунта в планетарном виде';

  @override
  String get accountGraphSubtitleDesktopOff =>
      'Показывает подсказку, когда чат не открыт';

  @override
  String get accountGraphSubtitleMobileOff => 'График аккаунта отключён';

  @override
  String get orbitSpeed => 'Скорость орбиты';

  @override
  String secOrbit(int s) {
    return '$s сек/орбита';
  }

  @override
  String minOrbit(int m) {
    return '$m мин/орбита';
  }

  @override
  String get animateGraph => 'Анимация';

  @override
  String get animateGraphOn => 'Орбиты вращаются в реальном времени';

  @override
  String get animateGraphOff => 'Граф заморожен / статичен';

  @override
  String get preserveView => 'Сохранять вид';

  @override
  String get preserveViewOn => 'Сохраняет масштаб и позицию при выходе из чата';

  @override
  String get preserveViewOff => 'Сбрасывает в центр при возврате';

  @override
  String get migrationTitle => 'Миграция хранилища';

  @override
  String get migrationBody =>
      'ONYX переходит на новый высокоскоростной движок хранения данных. Чаты и медиа будут загружаться значительно быстрее.';

  @override
  String get migrationAccounts => 'Аккаунтов';

  @override
  String get migrationDataSize => 'Размер данных';

  @override
  String get migrationBackupNote =>
      'Перед миграцией будет создана резервная копия. Во время этого приложение может временно не отвечать.';

  @override
  String get migrationStart => 'Начать миграцию';

  @override
  String get migrationSkip => 'Пропустить';

  @override
  String get migrationPhaseBackup => 'Создание резервной копии';

  @override
  String get migrationPhaseImport => 'Импорт данных';

  @override
  String get migrationPhaseVerify => 'Проверка';

  @override
  String get migrationPhasePreparing => 'Подготовка';

  @override
  String get migrationDontClose => 'Не закрывайте приложение';

  @override
  String get migrationDoneTitle => 'Готово!';

  @override
  String get migrationDoneBody =>
      'Хранилище обновлено. Резервная копия сохранена в папке Backups.';

  @override
  String get migrationDoneNote =>
      'После того как убедитесь, что всё работает — можете удалить её вручную.';

  @override
  String get migrationDoneButton => 'Отлично!';

  @override
  String get migrationErrorTitle => 'Ошибка миграции';

  @override
  String get migrationErrorBody =>
      'Приложение продолжит работу на старой системе. Повторная попытка будет при следующем запуске.';

  @override
  String get migrationErrorButton => 'Понятно';

  @override
  String get audioTitle => 'Аудио';

  @override
  String get audioSubtitle => 'Выбор микрофона и колонок';

  @override
  String get audioMicInput => 'Микрофон (вход)';

  @override
  String get audioSpeakerOutput => 'Колонки (выход)';

  @override
  String get audioSystemDefault => 'Системный по умолчанию';

  @override
  String get audioChangesNote =>
      'Изменения вступят в силу при следующем подключении к голосовому каналу.';

  @override
  String get wardlinkReceive => 'Получить с устройства';

  @override
  String get wardlinkReceiveSubtitle =>
      'Покажите QR-код — отправитель его сканирует';

  @override
  String get wardlinkSend => 'Отправить на устройство';

  @override
  String get wardlinkSendSubtitle =>
      'Сканируйте QR-код на устройстве получателя';

  @override
  String get react => 'Реакция';

  @override
  String get pin => 'Закрепить';

  @override
  String get unpin => 'Открепить';

  @override
  String get copyImage => 'Копировать изображение';

  @override
  String get forward => 'Переслать';

  @override
  String get showInFileSystem => 'Показать в проводнике';

  @override
  String get saveNotSupportedOnWeb => 'Сохранение недоступно в веб-версии';

  @override
  String get imageNotLoadedYet => 'Изображение ещё не загружено';

  @override
  String get voiceNotLoadedYet => 'Голосовое сообщение ещё не загружено';

  @override
  String get videoNotLoadedYet => 'Видео ещё не загружено';

  @override
  String get fileNotLoadedYet => 'Файл ещё не загружен';

  @override
  String get fileNotLoadedOpenFirst =>
      'Файл не скачан на устройство — нажмите на него в чате, чтобы скачать';

  @override
  String editTimerLabel(int s) {
    return 'Изменить  ·  $sс';
  }

  @override
  String deleteTimerLabel(int s) {
    return 'Удалить  ·  $sс';
  }

  @override
  String get newChat => 'Новый чат';

  @override
  String get newChatSubtitle => 'Создать новый избранный чат';

  @override
  String get newFolder => 'Новая папка';

  @override
  String get newFolderSubtitle => 'Группировать чаты в папку';

  @override
  String get searchEmoji => 'Поиск эмодзи…';

  @override
  String get syncCompleted => 'Синхронизация завершена';

  @override
  String get syncCompletedWithErrors => 'Синхронизация завершена с ошибками';

  @override
  String get receivingFiles => 'Получение файлов...';

  @override
  String syncFromUser(String sender) {
    return 'от $sender';
  }

  @override
  String get aboutServer => 'СЕРВЕР';

  @override
  String get aboutWhatsNew => 'ЧТО НОВОГО';

  @override
  String get aboutConnected => 'Подключено';

  @override
  String get aboutConnecting => 'Подключение...';

  @override
  String get aboutLoadingLocation => 'Загрузка...';

  @override
  String get aboutNoReleaseNotes => 'Нет информации об обновлении.';

  @override
  String get aboutCheckForUpdates => 'Проверить обновления';

  @override
  String get aboutChecking => 'Проверка...';

  @override
  String get aboutUpToDate => 'Версия актуальна!';

  @override
  String aboutUpdateAvailable(String v) {
    return 'Доступно обновление: $v';
  }

  @override
  String get downloadUpdateTitle => 'Скачать обновление';

  @override
  String get downloadUpdateVersion => 'Версия';

  @override
  String get downloadUpdateWhatsNew => 'ЧТО НОВОГО';

  @override
  String get downloadUpdateReady => 'Готово к загрузке';

  @override
  String get downloadUpdateDownloading => 'Загрузка...';

  @override
  String get downloadUpdateComplete => 'Загрузка завершена!';

  @override
  String get downloadUpdateNoPlatform => 'Нет загрузки для этой платформы';

  @override
  String get downloadUpdateInstall => 'Скачать и установить';

  @override
  String get downloadUpdateOpen => 'Открыть';

  @override
  String get downloadUpdateRetry => 'Повторить';

  @override
  String get downloadUpdateCancel => 'Отменить загрузку';

  @override
  String get editChat => 'Редактировать чат';

  @override
  String get chatNameLabel => 'Название чата';

  @override
  String get editFolder => 'Редактировать папку';

  @override
  String get folderNameLabel => 'Название папки';

  @override
  String get createChat => 'Новый чат';

  @override
  String get profileMessage => 'Написать';

  @override
  String get tapAvatarHint => 'Нажмите на аватар • Удержите чтобы удалить';

  @override
  String get tapAvatarLongRemove =>
      'Нажмите чтобы сменить • Удержите чтобы удалить';

  @override
  String get e2eeWarnTitle => 'Без сквозного шифрования';

  @override
  String get e2eeWarnUnderstand => 'Понятно';

  @override
  String get e2eeWarnDoNotShare =>
      'Не делитесь здесь паролями, личными файлами и конфиденциальной информацией.';

  @override
  String get e2eeWarnGroupBody =>
      'Сообщения в этой группе не защищены сквозным шифрованием — сервер может их читать.';

  @override
  String get e2eeWarnGroupMedia =>
      'Прикреплённые медиа загружаются на публичный хостинг (catbox.moe) и доступны любому, у кого есть ссылка.';

  @override
  String get e2eeWarnExtBody =>
      'Сообщения в этой группе не защищены сквозным шифрованием — сервер владельца группы может их читать.';

  @override
  String get e2eeWarnExtMedia =>
      'Прикреплённые медиа загружаются и хранятся на собственном сервере владельца, а не в ONYX.';

  @override
  String get e2eeWarnExtOnyxUnrelated =>
      'ONYX не имеет ни малейшего отношения к этой группе и не может модерировать или защищать её содержимое.';

  @override
  String get securityLevelTitle => 'Уровень защиты';

  @override
  String get securityLevelEasy => 'Просто';

  @override
  String get securityLevelEasyDesc =>
      'Новое устройство доверяется сразу после входа. Минимум трения, но пароль — единственная защита.';

  @override
  String get securityLevelBalanced => 'Сбалансировано';

  @override
  String get securityLevelBalancedDesc =>
      'Новое устройство одобряет любое уже доверенное устройство. Рекомендуется большинству.';

  @override
  String get securityLevelStrict => 'Строго';

  @override
  String get securityLevelStrictDesc =>
      'Новое устройство требует одобрения от двух разных доверенных устройств.';

  @override
  String get securityLevelLowerRequiresTrusted =>
      'Понизить уровень защиты можно только с доверенного устройства.';

  @override
  String get securityLevelUpdated => 'Уровень защиты обновлён';

  @override
  String get sessionTtlTitle => 'Срок жизни сессии';

  @override
  String get sessionTtlSubtitle =>
      'Через сколько потребуется снова ввести пароль на этом устройстве';

  @override
  String get sessionTtlRecommended => 'рекомендовано';

  @override
  String sessionTtlDays(int days) {
    return '$days дней';
  }

  @override
  String get sessionTtlNever => 'Никогда';

  @override
  String get sessionTtlUpdated => 'Срок жизни сессии обновлён';

  @override
  String get approvalsProgress => 'Одобрено';

  @override
  String get pendingDeviceTitleSingle => 'Новое устройство';

  @override
  String pendingDeviceTitleMulti(int count) {
    return 'Новые устройства ($count)';
  }

  @override
  String get pendingDeviceApprove => 'Одобрить';

  @override
  String get pendingDeviceDeny => 'Отклонить';

  @override
  String get recoveryTitle => 'Восстановление доступа';

  @override
  String get recoveryBannerText =>
      'Это устройство ещё не одобрено. Если ни одно доверенное устройство недоступно — можно восстановить доступ паролем и фразой восстановления.';

  @override
  String get recoveryBannerButton => 'Восстановить доступ';

  @override
  String get recoveryIntro =>
      'Введите пароль и 12-словную фразу восстановления, которую вам показали при регистрации. Запрос вступит в силу не сразу — у ваших доверенных устройств будет время его отменить, если это не вы.';

  @override
  String get recoveryPasswordLabel => 'Пароль';

  @override
  String get recoveryPassphraseLabel => 'Фраза восстановления (12 слов)';

  @override
  String get recoverySubmit => 'Отправить запрос';

  @override
  String get recoveryInvalid => 'Неверный пароль или фраза восстановления';

  @override
  String get recoveryAlreadyPending =>
      'Запрос уже отправлен и ожидает исполнения';

  @override
  String get recoveryPendingTitle => 'Запрос отправлен';

  @override
  String recoveryPendingBody(String when) {
    return 'Доступ будет восстановлен $when, если запрос не отменят с одного из доверенных устройств.';
  }

  @override
  String get recoveryCancelled => 'Запрос восстановления отменён';

  @override
  String get recoveryExecuted =>
      'Доступ восстановлен. Перезайдите, чтобы применить изменения.';

  @override
  String get recoveryCancelRequiresTrusted =>
      'Отменить может только доверенное устройство. Сначала подтвердите это устройство в разделе \"Активные устройства\".';

  @override
  String get recoveryAlertRequestedTitle =>
      'Кто-то запросил восстановление доступа';

  @override
  String recoveryAlertRequestedBody(String deviceName, String when) {
    return 'Устройство \"$deviceName\" запросило восстановление доступа. Если это не вы — отмените запрос сейчас. Иначе он вступит в силу $when.';
  }

  @override
  String get recoveryAlertCancelButton => 'Отменить';

  @override
  String get recoveryAlertIgnoreButton => 'Это я, игнорировать';

  @override
  String get recoveryAlertFailedTitle => 'Неудачная попытка восстановления';

  @override
  String get recoveryAlertFailedBody =>
      'Кто-то пытался восстановить доступ к вашему аккаунту, но ввёл неверный пароль или фразу восстановления.';

  @override
  String get recoveryAlertExecutedTitle => 'Восстановление выполнено';

  @override
  String get recoveryAlertExecutedBody =>
      'Запрос на восстановление доступа вступил в силу — у аккаунта новое основное устройство. Если это были не вы, немедленно отзовите незнакомую сессию в Активных устройствах.';

  @override
  String get wardLinkSyncSettingsTitle => 'Настройки синхронизации';

  @override
  String get wardLinkSyncSettingsSubtitle =>
      'Лимит размера файла и уведомления кружка';

  @override
  String get wardLinkPairedDevicesSubtitle =>
      'Добавление и управление сопряжёнными устройствами';

  @override
  String get notifGeneralTitle => 'Общие';

  @override
  String get notifGeneralSubtitle =>
      'Включение уведомлений и видимость содержимого';

  @override
  String get notifSoundSubtitle => 'Звук уведомлений и аудиофайл';

  @override
  String get notifAdvancedTitle => 'Дополнительно';

  @override
  String get notifAdvancedSubtitle =>
      'Поведение при запуске и позиция всплывающих окон';

  @override
  String get securityPrivacyTitle => 'Приватность';

  @override
  String get securityPrivacySubtitle => 'Настройки видимости и поиска';

  @override
  String get cacheStorageTitle => 'Хранилище';

  @override
  String get cacheStorageSubtitle =>
      'Кэш медиа и очистка неиспользуемых файлов';

  @override
  String get connectionServerTitle => 'Подключение к серверу';

  @override
  String get connectionServerSubtitle =>
      'Подключение и отключение от WebSocket-сервера';

  @override
  String get interactPerformanceTitle => 'Производительность';

  @override
  String get interactPerformanceSubtitle =>
      'Буфер прокрутки и окно предзагрузки изображений';

  @override
  String get interactFilesTitle => 'Файлы и хранилище';

  @override
  String get interactFilesSubtitle =>
      'Папка загрузок и управление данными приложения';

  @override
  String get appearanceChatDisplayTitle => 'Отображение чата';

  @override
  String get appearanceChatDisplaySubtitle =>
      'Выравнивание, аватары и анимации';

  @override
  String get appearanceLayoutTitle => 'Макет';

  @override
  String get appearanceLayoutSubtitle => 'Навигация, граф и свайпы вкладок';

  @override
  String get appearanceLiquidGlassTitle => 'Эффекты Liquid Glass';

  @override
  String get trashChatsTitle => 'Удалённые чаты';

  @override
  String get trashChatsSubtitle =>
      'Восстановление или безвозвратное удаление чатов';

  @override
  String get trashMessagesTitle => 'Удалённые сообщения';

  @override
  String get trashMessagesSubtitle =>
      'Восстановление или безвозвратное удаление сообщений';

  @override
  String get download => 'Скачать';

  @override
  String get retry => 'Повторить';

  @override
  String get refresh => 'Обновить';

  @override
  String get revoke => 'Отозвать';

  @override
  String get setup => 'Настроить';

  @override
  String get current => 'Текущий';

  @override
  String get select => 'Выбрать';

  @override
  String get token => 'Токен';

  @override
  String get always => 'Всегда';

  @override
  String favRemoveFromFolderNamed(String folderName) {
    return 'Убрать из «$folderName»';
  }

  @override
  String get favMoveToFolder => 'Переместить в папку';

  @override
  String get favRemoveFromFolder => 'Убрать из папки';

  @override
  String get favUnlock => 'Разблокировать';

  @override
  String get favLock => 'Заблокировать';

  @override
  String get favUnlockFolder => 'Разблокировать папку';

  @override
  String get favLockFolder => 'Заблокировать папку';

  @override
  String favChatsCount(int n) {
    return '$n чатов';
  }

  @override
  String get favNewFolder => 'Новая папка';

  @override
  String get favChatsMovedToTopLevel =>
      'Чаты будут перемещены на верхний уровень';

  @override
  String get favDeleteChatQuestion => 'Удалить чат?';

  @override
  String get favRemoveAvatarQuestion => 'Удалить аватар?';

  @override
  String get favSelectedRemovedFromFavorites =>
      'Выбранные сообщения будут удалены из избранного.';

  @override
  String get favDeleteMessageQuestion => 'Удалить сообщение?';

  @override
  String get favMessageRemovedFromFavorites =>
      'Это сообщение будет удалено из избранного.';

  @override
  String get favDeleteAvatarQuestion => 'Удалить аватар?';

  @override
  String get favRemoveAvatarConfirm => 'Аватар этого избранного будет удалён.';

  @override
  String get sendAlbum => 'Отправить альбом';

  @override
  String get sendAlbums => 'Отправить альбомы';

  @override
  String get sendAllMedia => 'Отправить всё';

  @override
  String get setAsWallpaper => 'Установить как обои';

  @override
  String get sendVoice => 'Отправить голосовое';

  @override
  String get cropAndUpload => 'Обрезать и загрузить';

  @override
  String get deleteMessagesQuestion => 'Удалить сообщения?';

  @override
  String get connectionDiagnostics => 'Диагностика соединения';

  @override
  String get voiceChannels => 'Голосовые каналы';

  @override
  String get forwardMessage => 'Переслать сообщение';

  @override
  String get noChats => 'Нет чатов';

  @override
  String get noGroups => 'Нет групп';

  @override
  String get noFavorites => 'Нет избранного';

  @override
  String get wifiOnlyOption => 'Только Wi-Fi';

  @override
  String get emptyTrash => 'Очистить корзину';

  @override
  String get performanceReport => 'Отчёт о производительности';

  @override
  String get revokeSessionQuestion => 'Отозвать сессию?';

  @override
  String get revokeSessionConfirm =>
      'Это устройство будет немедленно разлогинено.';

  @override
  String get failedToRevokeSession => 'Не удалось отозвать сессию';

  @override
  String get failedToApproveDevice => 'Не удалось подтвердить устройство';

  @override
  String get noActiveSessionsFound => 'Активных сессий не найдено';

  @override
  String get quotaExceeded => 'Превышена квота';

  @override
  String get openSettingsAction => 'Открыть настройки';

  @override
  String get trashIsEmpty => 'Корзина пуста';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get deviceAuthTabQr => 'QR';

  @override
  String get meshTitle => 'Mesh';

  @override
  String get meshMenuModeWifi => 'Wi-Fi';

  @override
  String get meshMenuModeBluetooth => 'Bluetooth';

  @override
  String mediaCachesCleared(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: ' Очищено $n кэша',
      many: ' Очищено $n кэшей',
      few: ' Очищено $n кэша',
      one: ' Очищено $n кэш',
    );
    return '$_temp0';
  }

  @override
  String leaveGroupTitle(String isChannel) {
    String _temp0 = intl.Intl.selectLogic(
      isChannel,
      {
        'true': 'канал',
        'other': 'группу',
      },
    );
    return 'Покинуть $_temp0?';
  }

  @override
  String cacheFilesDeleted(int n) {
    return 'Удалено файлов: $n';
  }

  @override
  String orphanedCleanupDeleted(int files, String freedMb) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: 'Удалено $files неиспользуемых файла',
      many: 'Удалено $files неиспользуемых файлов',
      few: 'Удалено $files неиспользуемых файла',
      one: 'Удалено $files неиспользуемый файл',
    );
    return '$_temp0 ($freedMb MB освобождено)';
  }

  @override
  String deletedLogsCount(int n) {
    return 'Удалено лог-файлов: $n.';
  }

  @override
  String notifEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'Вы будете получать уведомления о новых сообщениях',
        'other': 'Все уведомления отключены',
      },
    );
    return '$_temp0';
  }

  @override
  String notifHideContentSubtitle(String hidden) {
    String _temp0 = intl.Intl.selectLogic(
      hidden,
      {
        'true': 'Уведомления без текста сообщения',
        'other': 'Показывать текст сообщения',
      },
    );
    return '$_temp0';
  }

  @override
  String notifSoundEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'Звук включён',
        'other': 'Звук выключен',
      },
    );
    return '$_temp0';
  }

  @override
  String sessionExpiresInDays(int n) {
    return 'Сессия истекает через $n д.';
  }

  @override
  String sessionExpiresInHours(int n) {
    return 'Сессия истекает через $n ч.';
  }

  @override
  String sessionActiveForDays(int n) {
    return 'Сессия активна ещё $n д.';
  }

  @override
  String meshRadarFound(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n устройства в диапазоне',
      many: '$n устройств в диапазоне',
      few: '$n устройства в диапазоне',
      one: '$n устройство в диапазоне',
    );
    return '$_temp0';
  }

  @override
  String trashSummary(int chats, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: 'чата',
      many: 'чатов',
      few: 'чата',
      one: 'чат',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: 'сообщения',
      many: 'сообщений',
      few: 'сообщения',
      one: 'сообщение',
    );
    return '$chats $_temp0, $messages $_temp1';
  }

  @override
  String get muteAction => 'Заглушить';

  @override
  String get unmuteAction => 'Снять заглушение';

  @override
  String muteUserTitle(String name) {
    return 'Заглушить $name';
  }

  @override
  String get durationLabel => 'Длительность';

  @override
  String get duration15Min => '15 мин';

  @override
  String get duration1Hour => '1 час';

  @override
  String get duration1Day => '1 день';

  @override
  String get duration1Week => '1 неделя';

  @override
  String get muteReasonLabel => 'Причина (необязательно)';

  @override
  String userMuted(String name) {
    return '$name заглушён(а)';
  }

  @override
  String get failedMute => 'Не удалось заглушить';

  @override
  String failedMuteUser(String name) {
    return 'Не удалось заглушить $name';
  }

  @override
  String get mutedUsersTitle => 'Заглушённые пользователи';

  @override
  String get noMutedUsers => 'Нет заглушённых пользователей';

  @override
  String mutedByLabel(String name) {
    return 'Заглушил(а): $name';
  }

  @override
  String mutedUntilLabel(String date) {
    return 'До: $date';
  }

  @override
  String userUnmuted(String name) {
    return '$name больше не заглушён(а)';
  }

  @override
  String get failedUnmute => 'Не удалось снять заглушение';

  @override
  String failedUnmuteUser(String name) {
    return 'Не удалось снять заглушение с $name';
  }

  @override
  String get youAreMutedTitle => 'Вы заглушены';

  @override
  String mutedUntilMessage(String date) {
    return 'Вы не можете отправлять сообщения в этом чате до $date.';
  }

  @override
  String get slowModeLabel => 'Медленный режим (секунды, 0 = выкл.)';

  @override
  String get slowModeHelper =>
      'Минимальная задержка между сообщениями для обычных участников. На администраторов не действует.';

  @override
  String slowModeSetTo(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Медленный режим: $seconds секунды',
      many: 'Медленный режим: $seconds секунд',
      few: 'Медленный режим: $seconds секунды',
      one: 'Медленный режим: $seconds секунда',
    );
    return '$_temp0';
  }

  @override
  String get slowModeDisabled => 'Медленный режим выключен';

  @override
  String get failedSetSlowMode => 'Не удалось включить медленный режим';

  @override
  String get failedUpdateSlowMode => 'Не удалось обновить медленный режим';

  @override
  String get donateMenuLabel => 'Донат';

  @override
  String get pollsMenuLabel => 'Опросы';

  @override
  String get supportThisCommunityTitle => 'Поддержать сообщество';

  @override
  String get donationDisclaimer =>
      'ONYX не обрабатывает эти платежи и не может их вернуть. Отправляйте крипту только на адреса, которым доверяете.';

  @override
  String get noDonationsOwnerHint =>
      'Пока нет адресов для донатов. Нажмите «Изменить», чтобы добавить.';

  @override
  String get noDonationsMemberHint => 'Это сообщество ещё не настроило донаты.';

  @override
  String get editDonationsTitle => 'Изменить адреса для донатов';

  @override
  String get donationCoinLabel => 'Монета (напр. BTC)';

  @override
  String get donationAddressLabel => 'Адрес';

  @override
  String get addDonationAddress => 'Добавить адрес';

  @override
  String get donationsSaved => 'Адреса для донатов сохранены';

  @override
  String get failedSaveDonations => 'Не удалось сохранить адреса для донатов';

  @override
  String get noPollsOwnerHint =>
      'Пока нет опросов. Нажмите «Новый опрос», чтобы создать.';

  @override
  String get noPollsHint => 'Пока нет опросов.';

  @override
  String get newPollAction => 'Новый опрос';

  @override
  String get addPollOption => 'Добавить вариант';

  @override
  String get pollQuestionLabel => 'Вопрос';

  @override
  String pollOptionLabel(int number) {
    return 'Вариант $number';
  }

  @override
  String get multipleChoiceLabel => 'Множественный выбор';

  @override
  String get pollQuestionEmpty => 'Вопрос не может быть пустым';

  @override
  String get pollNeedsTwoOptions => 'Добавьте минимум 2 варианта';

  @override
  String get failedCreatePoll => 'Не удалось создать опрос';

  @override
  String get failedVote => 'Не удалось отправить голос';

  @override
  String pollVoteCountAnonymous(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count голоса',
      many: '$count голосов',
      few: '$count голоса',
      one: '$count голос',
    );
    return '$_temp0 • анонимно';
  }

  @override
  String get descriptionLabel => 'Description';

  @override
  String get descriptionHint => 'What is this group about?';

  @override
  String get noDescriptionSet => 'No description set.';

  @override
  String get limitsHeader => 'Limits';

  @override
  String get maxMembersLabel => 'Max members';

  @override
  String get maxMessageLengthLabel => 'Max message length';

  @override
  String get maxMessagesPerMinuteLabel => 'Max messages per minute';

  @override
  String get invalidLimitValue => 'Enter a valid number';

  @override
  String get defaultRoleLabel => 'Default role for new members';

  @override
  String get rolesHeader => 'Roles';

  @override
  String get addRoleAction => 'Add role';

  @override
  String get deleteRoleConfirmTitle => 'Delete role?';

  @override
  String get deleteRoleConfirmContent =>
      'Members with this role will be moved to Member.';

  @override
  String get roleEditorCreateTitle => 'Create role';

  @override
  String get roleEditorEditTitle => 'Edit role';

  @override
  String get roleNameLabel => 'Role name';

  @override
  String get roleColorLabel => 'Color';

  @override
  String get rolePermissionsLabel => 'Permissions';

  @override
  String roleSubtitle(int count, int members) {
    return '$count permissions · $members members';
  }

  @override
  String get settingsUpdated => 'Settings updated';

  @override
  String get failedUpdateSettings => 'Failed to update settings';

  @override
  String get roleSaved => 'Role saved';

  @override
  String get failedSaveRole => 'Failed to save role';

  @override
  String get roleDeleted => 'Role deleted';

  @override
  String get failedDeleteRole => 'Failed to delete role';

  @override
  String get addCommentAction => 'Comment';

  @override
  String commentsCount(int count) {
    return '$count comments';
  }

  @override
  String get commentsTitle => 'Comments';

  @override
  String get writeCommentHint => 'Write a comment...';

  @override
  String get failedLoadComments => 'Failed to load comments';

  @override
  String get failedPostComment => 'Failed to post comment';

  @override
  String get failedDeleteComment => 'Failed to delete comment';

  @override
  String get failedEditComment => 'Failed to edit comment';

  @override
  String get noCommentsYet => 'No comments yet';

  @override
  String get permKickMembers => 'Kick members';

  @override
  String get permBanMembers => 'Ban members';

  @override
  String get permMuteMembers => 'Mute members';

  @override
  String get permManageRoles => 'Manage roles';

  @override
  String get permManageSettings => 'Manage settings';

  @override
  String get permManageDonations => 'Manage donations';

  @override
  String get permCreatePolls => 'Create polls';

  @override
  String get permPostInChannel => 'Post in channel';

  @override
  String get permDeleteMessages => 'Delete messages';

  @override
  String get permManageMembers => 'Manage members';

  @override
  String get permManageSlowMode => 'Manage slow mode';

  @override
  String get permViewBanList => 'Manage ban list';

  @override
  String get permViewMuteList => 'Manage mute list';

  @override
  String get permViewInviteLink => 'View invite link';

  @override
  String get manageMembersRequiresChild =>
      'Select at least one of Manage Ban List, Manage Mute List, or Manage Roles';
}
