// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get navChats => 'Chats';

  @override
  String get navGroups => 'Gruppen';

  @override
  String get navFavorites => 'Favoriten';

  @override
  String get navAccounts => 'Konten';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get close => 'Schließen';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get delete => 'Löschen';

  @override
  String get clear => 'Leeren';

  @override
  String get loading => 'Lädt...';

  @override
  String get error => 'Fehler';

  @override
  String get success => 'Erfolg';

  @override
  String get copy => 'Kopieren';

  @override
  String get copied => 'Kopiert';

  @override
  String get test => 'Test';

  @override
  String get connect => 'Verbinden';

  @override
  String get disconnect => 'Trennen';

  @override
  String get enabled => 'Aktiviert';

  @override
  String get disabled => 'Deaktiviert';

  @override
  String get on => 'An';

  @override
  String get off => 'Aus';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get supportOnyx => 'ONYX unterstützen';

  @override
  String get securityTitle => 'Sicherheit & Datenschutz';

  @override
  String get securitySubtitle =>
      'Tippen, um Tipps und Verschlüsselungsdetails anzuzeigen';

  @override
  String get tipOfTheDay => 'Tipp des Tages';

  @override
  String get statusSettings => 'Status-Einstellungen';

  @override
  String get showDisplayNameInGroups => 'Meinen Anzeigenamen in Gruppen zeigen';

  @override
  String get showDisplayNameSubtitle =>
      'Wenn deaktiviert, erscheinen deine Nachrichten als \"Anonym\"';

  @override
  String get pinLock => 'PIN-Sperre';

  @override
  String get enablePinLock => 'PIN-Sperre aktivieren';

  @override
  String get enablePinSubtitle =>
      'Beim Start eine 4-stellige PIN zum Entsperren der App verlangen';

  @override
  String get pinLockEnabled => ' PIN-Sperre aktiviert';

  @override
  String get pinLockDisabled => 'PIN-Sperre deaktiviert';

  @override
  String get useBiometrics => 'Biometrie verwenden';

  @override
  String get useBiometricsSubtitle =>
      'Mit Fingerabdruck oder Gesichtserkennung entsperren';

  @override
  String get biometricsUnavailable =>
      'Biometrie auf diesem Gerät nicht verfügbar';

  @override
  String get lockOnResume => 'Im Hintergrund sperren';

  @override
  String get lockOnResumeSubtitle =>
      'Jedes Mal PIN verlangen, wenn die App in den Vordergrund zurückkehrt';

  @override
  String get pinScreenSetTitle => 'PIN festlegen';

  @override
  String get pinScreenConfirmTitle => 'PIN bestätigen';

  @override
  String get pinScreenEnterTitle => 'PIN eingeben';

  @override
  String get pinScreenChooseSubtitle => 'Wähle eine 4-stellige PIN';

  @override
  String get pinScreenChooseChatSubtitle =>
      'Wähle eine 4-stellige PIN für diesen Chat';

  @override
  String get pinScreenReenterSubtitle =>
      'Gib deine PIN zur Bestätigung erneut ein';

  @override
  String get pinScreenUnlockSubtitle =>
      'Gib deine 4-stellige PIN zum Entsperren ein';

  @override
  String get pinScreenGenericSubtitle => 'Gib deine 4-stellige PIN ein';

  @override
  String get pinScreenDisableHeader =>
      'Gib die aktuelle PIN ein, um sie zu deaktivieren';

  @override
  String get pinScreenMismatchError =>
      'PINs stimmen nicht überein. Versuche es erneut.';

  @override
  String get pinScreenIncorrectError => 'Falsche PIN';

  @override
  String get searchChatsHint => 'Chats und Nachrichten durchsuchen…';

  @override
  String get searchGroupsHint => 'Gruppen und Nachrichten durchsuchen…';

  @override
  String get searchFavoritesHint => 'Favoriten durchsuchen…';

  @override
  String get searchSettingsHint => 'Einstellungen durchsuchen…';

  @override
  String get keyMgmtTitle => 'Schlüsselverwaltung';

  @override
  String get keyMgmtSubtitle =>
      'Deine Verschlüsselungsidentität rotieren oder zurücksetzen';

  @override
  String get keyMgmtDescription =>
      'Rotiere deinen E2EE-Identitätsschlüssel, wenn du vermutest, dass er kompromittiert wurde. Kontakte erhalten den neuen Schlüssel automatisch.';

  @override
  String get rotateE2eeKey => 'E2EE-Schlüssel rotieren';

  @override
  String get rotateE2eeKeyPrimaryOnly =>
      'E2EE-Schlüssel rotieren (nur Primärgerät)';

  @override
  String get rotateKeyDialogTitle => 'Verschlüsselungsschlüssel rotieren?';

  @override
  String get rotateKeyDialogContent =>
      'Ein neues X25519-Schlüsselpaar wird erzeugt und auf den Server hochgeladen.nnDeine Sitzung und dein Nachrichtenverlauf sind NICHT betroffen. Kontakte verwenden automatisch den neuen Schlüssel bei ihrer nächsten Nachricht.';

  @override
  String get rotateKeyBtn => 'Rotieren';

  @override
  String get rotatingKey => ' Schlüssel wird rotiert…';

  @override
  String get keyRotated => ' E2EE-Schlüssel rotiert und hochgeladen';

  @override
  String get keyRotationFailed => ' Schlüsselrotation fehlgeschlagen';

  @override
  String get activeDevices => 'Aktive Geräte';

  @override
  String get activeDevicesSubtitle =>
      'Geräte, Passwort und Verschlüsselungsschlüssel';

  @override
  String get activeDevicesPrimaryOnly => 'Aktive Geräte (nur Primärgerät)';

  @override
  String get changePassword => 'Passwort ändern';

  @override
  String get changePasswordPrimaryOnly => 'Passwort ändern (nur Primärgerät)';

  @override
  String get notificationsTitle => 'Benachrichtigungen';

  @override
  String get notificationsSubtitle =>
      'Warnungen und Zustellungsoptionen verwalten';

  @override
  String get notificationsEnabled => 'Benachrichtigungen aktivieren';

  @override
  String get notificationsEnabledSubtitle =>
      'Systembenachrichtigungen für neue Nachrichten anzeigen';

  @override
  String get notificationPosition => 'Position der Benachrichtigung';

  @override
  String get notifPosTopLeft => 'Oben links';

  @override
  String get notifPosTopRight => 'Oben rechts';

  @override
  String get notifPosBottomLeft => 'Unten links';

  @override
  String get notifPosBottomRight => 'Unten rechts';

  @override
  String get appearanceTitle => 'Erscheinungsbild';

  @override
  String get appearanceSubtitle => 'Design und Dunkelmodus wählen';

  @override
  String get selectTheme => 'Design auswählen';

  @override
  String get darkMode => 'Dunkelmodus';

  @override
  String get fontAndTextSize => 'Schriftart & Textgröße';

  @override
  String get fontFamily => 'Schriftart';

  @override
  String get messageSize => 'Nachrichtengröße';

  @override
  String get fontPreviewMessage => 'Beispiel';

  @override
  String get ownMessagesRight => 'Eigene Nachrichten: Rechts';

  @override
  String get ownMessagesLeft => 'Eigene Nachrichten: Links';

  @override
  String get alignAllRight => 'Alle Nachrichten rechts ausrichten';

  @override
  String get alignAllRightSubtitle =>
      'Alle Nachrichten wie in einem Spiegel rechts ausgerichtet';

  @override
  String get showAvatarInChats => 'Avatar in der Chatliste anzeigen';

  @override
  String get showAccountIndicator => 'Aktuelles Konto anzeigen';

  @override
  String get showAccountIndicatorSubtitle =>
      'Name und Benutzername in der App-Ecke anzeigen';

  @override
  String get showAvatarSubtitle => 'Kontaktavatar in der Chatliste anzeigen';

  @override
  String get chatBackground => 'Chat-Hintergrund';

  @override
  String get chatBgSubtitle => 'Ein Bild als Chat-Hintergrund festlegen';

  @override
  String get chooseImage => 'Bild wählen';

  @override
  String get clearBackground => 'Hintergrund entfernen';

  @override
  String get applyGlobally => 'Global anwenden';

  @override
  String get applyGloballySubtitle =>
      'Diesen Hintergrund in allen Chats verwenden';

  @override
  String get blurBackground => 'Hintergrund weichzeichnen';

  @override
  String get elementOpacity => 'Elementdeckkraft';

  @override
  String get elementBrightness => 'Elementhelligkeit';

  @override
  String get uiLayout => 'UI-Layout';

  @override
  String get navBarPosition => 'Position der Navigationsleiste';

  @override
  String get navLeft => 'Links';

  @override
  String get navBottom => 'Unten';

  @override
  String get inputBarMaxWidth => 'Breite der Eingabeleiste';

  @override
  String get minimizeBottomNav => 'Untere Navigation minimieren';

  @override
  String get minimizeBottomNavSubtitle =>
      'Beschriftungen in der unteren Navigationsleiste ausblenden';

  @override
  String get swipeTabs => 'Zwischen Tabs wischen';

  @override
  String get swipeTabsSubtitle =>
      'Mit horizontaler Wischgeste zwischen Tabs wechseln';

  @override
  String get smoothScroll => 'Sanftes Scrollen';

  @override
  String get performanceOptimizations => 'Leistungsoptimierungen';

  @override
  String get macOsWindowStyle => 'Fensterstil';

  @override
  String get macOsWindowStyleSubtitle => 'Stil der Fenstersteuerung';

  @override
  String get macOsNativeTitleBar => 'Nativ macOS (Ampel-Symbole)';

  @override
  String get macOsCustomTitleBar => 'Windows-Stil (rechte Seite)';

  @override
  String get updateAvailableLabel => 'Update verfügbar';

  @override
  String get updateDownload => 'Herunterladen';

  @override
  String get cacheTitle => 'Cache';

  @override
  String get cacheSubtitle => 'Lokalen & Server-Medien-Cache verwalten';

  @override
  String get mediaCacheSize => 'Cache für Mediennachrichten: ';

  @override
  String get clearLocalCache => 'Lokalen Cache leeren';

  @override
  String get clearLocalCacheTitle => 'Lokalen Cache leeren';

  @override
  String get clearLocalCacheContent =>
      'Möchtest du wirklich alle zwischengespeicherten Medien (Sprachnachrichten, Bilder, Videos) löschen?nDies betrifft NICHT Server-Uploads oder den Chatverlauf.';

  @override
  String get clearAll => 'Alles leeren';

  @override
  String get serverMediaCache => 'Server-Medien-Cache';

  @override
  String get serverMediaCacheSubtitle =>
      'Auf dem Server gespeichert: Bilder, Sprachnachrichten, Videos.';

  @override
  String get clearServerCache => 'Server-Cache leeren';

  @override
  String get dangerZone => 'Gefahrenzone';

  @override
  String get dangerZoneSubtitle =>
      'Konto vom Server löschen und/oder lokale Daten löschen.';

  @override
  String get factoryReset => 'Werksreset';

  @override
  String get factoryResetHint =>
      'Wähle, was zurückgesetzt werden soll. Mindestens eine Option muss ausgewählt sein.';

  @override
  String get resetDeleteAccount => 'Konto vom Server löschen';

  @override
  String resetDeleteAccountSubtitle(String username) {
    return 'Löscht @$username dauerhaft — alle Nachrichten, Medien und Schlüssel vom Server.';
  }

  @override
  String get resetNoAccount => 'Es ist kein Konto angemeldet.';

  @override
  String get resetDeleteLocal => 'Lokale App-Daten löschen';

  @override
  String get resetDeleteLocalSubtitle =>
      'Löscht alle lokalen Chats, Schlüssel, Einstellungen, Cache und Medien.';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get resetFailed => 'Zurücksetzen fehlgeschlagen';

  @override
  String get resetConfirmStep1Title =>
      'Sind Sie sicher, dass Sie das tun möchten?';

  @override
  String get resetConfirmStep1Message =>
      'Dadurch werden die ausgewählten Daten dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get resetConfirmStep2Title => 'Sind Sie sicher?';

  @override
  String get resetConfirmStep2Message =>
      'Dies ist Ihre letzte Möglichkeit zum Abbrechen. Die Bestätigung startet den Reset sofort.';

  @override
  String get connectionTitle => 'Verbindung';

  @override
  String get connectionSubtitle => 'WebSocket-Status & Steuerung';

  @override
  String get proxyTitle => 'Proxy';

  @override
  String get proxySubtitle =>
      'Datenverkehr über HTTP- oder SOCKS5-Proxy leiten';

  @override
  String get enableProxy => 'Proxy aktivieren';

  @override
  String get proxyType => 'Proxy-Typ';

  @override
  String get proxyHost => 'Host';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxyUsername => 'Benutzername';

  @override
  String get proxyPassword => 'Passwort';

  @override
  String get testProxy => 'Proxy testen';

  @override
  String get proxyTesting => 'Testen...';

  @override
  String get proxyOk => ' Proxy OK';

  @override
  String get proxyFailed => ' Proxy nicht erreichbar';

  @override
  String get useProxy => 'Proxy verwenden';

  @override
  String get proxyDirectConnection => 'Direktverbindung';

  @override
  String get proxyRouted => 'Datenverkehr über Proxy geleitet';

  @override
  String get proxyConnectedStatus => 'Verbunden';

  @override
  String get proxyNotConnectedStatus => 'Nicht verbunden';

  @override
  String get proxyLoginOptional => 'Anmeldename (optional)';

  @override
  String get proxyPasswordOptional => 'Passwort (optional)';

  @override
  String get proxyApplyReconnect => 'Anwenden & neu verbinden';

  @override
  String get appDataTitle => 'ONYX-Datenordner';

  @override
  String get appDataSubtitle =>
      'Den App-Datenordner auf ein anderes Laufwerk verschieben';

  @override
  String get appDataCurrentPath => 'Aktueller Ordner';

  @override
  String get appDataDefault => 'Standard (Systemordner)';

  @override
  String get appDataMove => 'Verschieben…';

  @override
  String get appDataReset => 'Zurücksetzen';

  @override
  String get appDataMigrating => 'Daten werden verschoben…';

  @override
  String get appDataMigrateError => 'Fehler beim Verschieben';

  @override
  String get appDataRestartRequired =>
      'Ordner geändert. Starte ONYX neu, damit die Änderung wirksam wird.';

  @override
  String get appDataRestart => 'ONYX neu starten';

  @override
  String get appDataOpenFolder => 'Ordner öffnen';

  @override
  String get appDataDeleteOldFolder => 'Vorherigen Ordner löschen';

  @override
  String get appDataDeleteOldFolderSubtitle =>
      'Löscht den ursprünglichen Systemdatenordner, der nach der Migration übrig blieb';

  @override
  String get appDataDeleteOldFolderConfirm =>
      'Den ursprünglichen ONYX-Datenordner löschen?nnDies kann nicht rückgängig gemacht werden. Stelle sicher, dass die Daten erfolgreich migriert wurden.';

  @override
  String get appDataDeleteOldFolderSuccess => 'Vorheriger Ordner gelöscht';

  @override
  String get appDataDeleteOldFolderError => 'Fehler beim Löschen: ';

  @override
  String get interactTitle => 'Interaktion';

  @override
  String get interactSubtitle => 'Bestätigungen beim Datei-Upload';

  @override
  String get confirmFileUpload => 'Datei-Upload bestätigen';

  @override
  String get confirmFileUploadSubtitle =>
      'Bestätigungsdialog vor dem Senden von Dateien anzeigen';

  @override
  String get confirmVoiceMessage => 'Sprachnachricht bestätigen';

  @override
  String get confirmVoiceSubtitle =>
      'Bestätigungsdialog vor dem Senden von Sprachnachrichten anzeigen';

  @override
  String get downloadFolder => 'Download-Ordner';

  @override
  String get downloadFolderSubtitle =>
      'Wo empfangene Dateien gespeichert werden (Standard: Downloads/ONYX)';

  @override
  String get downloadFolderDefault => 'Standard (Downloads/ONYX)';

  @override
  String get downloadFolderChange => 'Ordner wählen';

  @override
  String get downloadFolderReset => 'Zurücksetzen';

  @override
  String get contactTitle => 'Kontakt';

  @override
  String get contactSubtitle => 'Website, Repository & Feedback';

  @override
  String get contactWebsite => 'Offizielle Website';

  @override
  String get contactRepository => 'Quellcode (Client)';

  @override
  String get contactRepositoryServer => 'Quellcode (selbst gehosteter Server)';

  @override
  String get contactEmail => 'Kontaktiere uns';

  @override
  String get debugTitle => 'Debug/Protokolle';

  @override
  String get debugSubtitle => 'Echtzeit-Leistung & Protokollierung';

  @override
  String get debugMode => 'Debug-Modus';

  @override
  String get debugModeSubtitle =>
      'Leistungsüberwachung & Protokolle aktivieren';

  @override
  String get enableFileLogging => 'Dateiprotokollierung aktivieren';

  @override
  String get enableFileLoggingSubtitle =>
      'App-Protokolle auf die Festplatte schreiben (für Privatsphäre deaktivieren)';

  @override
  String get deleteAllLogs => 'Alle Protokolle löschen';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageSubtitle => 'Sprache der App-Oberfläche';

  @override
  String get languageChanged => 'Sprache geändert';

  @override
  String get noChatsYet => 'Noch keine Chats';

  @override
  String get deleteChatTitle => 'Chat löschen?';

  @override
  String get blockUserLabel => 'Benutzer blockieren';

  @override
  String get unblockUserLabel => 'Entsperren';

  @override
  String get muteUserLabel => 'Benachrichtigungen stummschalten';

  @override
  String get unmuteUserLabel => 'Benachrichtigungen aktivieren';

  @override
  String get blockedByUserMessage =>
      'Dieser Benutzer hat eingehende Nachrichten von dir eingeschränkt.';

  @override
  String unblockUserConfirmContent(String name) {
    return '$name entsperren?';
  }

  @override
  String blockUserConfirmContent(String name) {
    return '$name blockieren? Diese Person kann dir dann keine Nachrichten mehr senden.';
  }

  @override
  String deleteChatContent(String name) {
    return 'Möchtest du den Chat mit \"$name\" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get displayName => 'Anzeigename';

  @override
  String get addAccount => 'Konto hinzufügen';

  @override
  String get welcomeTitle => 'Willkommen';

  @override
  String get welcomeTagline =>
      'Sicherer Ende-zu-Ende-verschlüsselter Messenger';

  @override
  String get otherAccounts => 'Andere Konten';

  @override
  String get tapToSwitch => 'Zum Wechseln tippen';

  @override
  String get deleteFromRecentTitle => 'Konto aus der letzten Liste löschen?';

  @override
  String get authUsernameLabel => 'Benutzername (3–16 Zeichen)';

  @override
  String get authPasswordLabel => 'Passwort (mind. 16 Zeichen)';

  @override
  String get loginBtn => 'Anmelden';

  @override
  String get registerBtn => 'Registrieren';

  @override
  String get deviceAuthTitle => 'Gerät verknüpfen';

  @override
  String get deviceAuthTabScan => 'Scannen';

  @override
  String get deviceAuthTapToScan => 'Tippen, um den QR-Code zu scannen';

  @override
  String get deviceAuthLanNote =>
      'Beide Geräte müssen sich im gleichen lokalen Netzwerk befinden';

  @override
  String get loginWithQr => 'Anmeldung per QR-Code';

  @override
  String get qrAuthWaitingTitle => 'Warte auf Telefon';

  @override
  String get qrAuthWaitingSubtitle =>
      'Scanne diesen Code auf einem autorisierten Gerät, um die Sitzung hierher zu übertragen';

  @override
  String get qrAuthSuccess => 'Gerät autorisiert';

  @override
  String get qrAuthFailed => 'QR-Anmeldung fehlgeschlagen';

  @override
  String get qrAuthCancelled => 'QR-Anmeldung abgebrochen';

  @override
  String get authorizeDevice => 'Gerät autorisieren';

  @override
  String get authorizeDeviceSubtitle =>
      'Einem anderen Gerät die Anmeldung per QR-Code erlauben';

  @override
  String get authorizeDeviceScanHint =>
      'Richte die Kamera auf den QR-Code, der auf dem anderen Gerät angezeigt wird';

  @override
  String get authorizeDeviceSuccess => 'Gerät erfolgreich autorisiert';

  @override
  String get authorizeDeviceFailed => 'Gerät konnte nicht autorisiert werden';

  @override
  String get authorizeDeviceSending => 'Anmeldedaten werden gesendet…';

  @override
  String get qrAuthEncryptedNote =>
      'Übertragung ist verschlüsselt (X25519 + AES-256-GCM)';

  @override
  String get scanFromPc => 'Von PC empfangen';

  @override
  String get scanFromPcHint =>
      'Richte die Kamera auf den QR-Code, der auf einem anderen Gerät angezeigt wird, um dich hier anzumelden';

  @override
  String get grantDeviceTitle => 'Telefon autorisieren';

  @override
  String get grantDeviceSubtitle =>
      'Scanne diesen Code auf einem anderen Gerät, um dich dort mit diesem Konto anzumelden';

  @override
  String get grantDeviceSuccess => 'Telefon erfolgreich autorisiert';

  @override
  String get grantDeviceFailed => 'Telefon konnte nicht autorisiert werden';

  @override
  String get enterUsernameMsg => 'Gib deinen Benutzernamen ein';

  @override
  String get loginSuccess => 'Anmeldung erfolgreich';

  @override
  String get loginFailed => 'Anmeldung fehlgeschlagen';

  @override
  String get registeringMsg => 'Registrierung läuft...';

  @override
  String get registrationFailed => ' Registrierung fehlgeschlagen';

  @override
  String get usernameInvalidMsg =>
      'Benutzername: 3–16 Zeichen, nur Buchstaben, Ziffern, _ . -';

  @override
  String get passwordTooShortMsg => 'Passwort zu kurz (mind. 16)';

  @override
  String get generatePasswordTooltip => 'Sicheres Passwort generieren';

  @override
  String get savePasswordWarning =>
      'Speichere dein Passwort unbedingt an einem sicheren Ort — schreib es auf. Eine Wiederherstellung ohne Passwort ist nicht möglich.';

  @override
  String get passphraseWriteDown =>
      'Diese Passphrase wird nie wieder angezeigt. Schreibe diese 12 Wörter jetzt von Hand auf und bewahre sie an einem sicheren Ort auf — du benötigst sie, um dein Konto wiederherzustellen, falls du dein Passwort vergisst.';

  @override
  String get passphraseWriteOnPaper =>
      'Schreibe deine Passphrase jetzt sofort auf Papier — es gibt keine zweite Chance!';

  @override
  String get copyToClipboard => 'In die Zwischenablage kopieren';

  @override
  String get copiedToClipboard => 'Kopiert!';

  @override
  String passphraseCountdown(int s) {
    return 'Bitte sorgfältig lesen — verfügbar in $s s...';
  }

  @override
  String get iSavedIt => 'Ich habe sie gespeichert';

  @override
  String deleteFromRecentContent(String acc) {
    return 'Möchtest du \"$acc\" wirklich aus der letzten Liste entfernen?nDadurch wird das Konto nicht vom Server gelöscht.';
  }

  @override
  String get createGroupChannel => 'Gruppe/Kanal erstellen';

  @override
  String get channelAdminOnly => 'Kanal (nur Admin postet)';

  @override
  String get viewByToken => 'Per Token anzeigen';

  @override
  String get viewByIp => 'Per IP anzeigen (externer Server)';

  @override
  String get createGroupOrChannel => 'Gruppe oder Kanal erstellen';

  @override
  String get removeExternalServerTitle => 'Externen Server entfernen?';

  @override
  String removeExternalServerContent(String name) {
    return '\"$name\" und alle zugehörigen Gruppen aus deiner Liste entfernen? Du kannst später erneut beitreten, indem du die Serveradresse wieder eingibst.';
  }

  @override
  String get noGroupsYet => 'Noch keine Gruppen';

  @override
  String get groupNameLabel => 'Gruppenname:';

  @override
  String get groupNameHint => 'Namen eingeben';

  @override
  String get pasteToken => 'Token einfügen:';

  @override
  String get create => 'Erstellen';

  @override
  String get view => 'Anzeigen';

  @override
  String get leave => 'Verlassen';

  @override
  String get remove => 'Entfernen';

  @override
  String get leaveGroupAction => 'Verlassen';

  @override
  String leaveGroupContent(String name) {
    return 'Möchtest du \"$name\" wirklich verlassen? Du erhältst dann keine Nachrichten mehr davon.';
  }

  @override
  String get chooseCrypto => 'Wähle eine Kryptowährung zum Spenden';

  @override
  String get addressCopied => 'Adresse kopiert';

  @override
  String get hideFromSearch => 'Mich aus der Suche ausblenden';

  @override
  String get hideFromSearchSubtitle =>
      'Andere finden dich nicht über die Benutzernamensuche';

  @override
  String get hideFromSearchSavedOk => ' Datenschutzeinstellungen gespeichert';

  @override
  String get hideFromSearchSavedFail =>
      ' Lokal gespeichert, Synchronisierung fehlgeschlagen';

  @override
  String get statusVisibility => 'Sichtbarkeit';

  @override
  String get statusShowStatus => 'Status anzeigen';

  @override
  String get statusHideStatus => 'Status verbergen';

  @override
  String get statusCustomText => 'Benutzerdefinierter Statustext';

  @override
  String get statusWhenOnline => 'Wenn online';

  @override
  String get statusWhenOffline => 'Wenn offline';

  @override
  String get statusSavedOk =>
      ' Statuseinstellungen gespeichert und synchronisiert';

  @override
  String get statusSavedFail =>
      ' Lokal gespeichert, Synchronisierung mit Server fehlgeschlagen';

  @override
  String get clearServerCacheTitle => 'Server-Medien löschen?';

  @override
  String get clearServerCacheContent =>
      'Dadurch werden ALLE deine hochgeladenen Medien vom Server gelöscht, einschließlich:n\'\n        \'• Sprachnachrichtenn\'\n        \'• Bildern\'\n        \'• Videosn\'\n        \'• Dateien\'\n        \'• Avatarnn\'\n        \'Der lokale Cache bleibt erhalten. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get serverMediaCleared => ' Alle Server-Medien gelöscht';

  @override
  String get notLoggedIn => 'Nicht angemeldet';

  @override
  String get serverMediaManagerTitle => 'Server-Medien';

  @override
  String get cacheTabImages => 'Bilder';

  @override
  String get cacheTabVoice => 'Sprachnachrichten';

  @override
  String get cacheTabAudio => 'Audio';

  @override
  String get cacheTabVideo => 'Video';

  @override
  String get cacheTabFiles => 'Dateien';

  @override
  String get cacheTabDocuments => 'Dokumente';

  @override
  String get cacheTabArchives => 'Archive';

  @override
  String get cacheTabData => 'Daten';

  @override
  String get cacheTabAvatars => 'Avatare';

  @override
  String get cacheNoFiles => 'Keine Dateien in dieser Kategorie';

  @override
  String get cacheClearTabTitle => 'Kategorie leeren?';

  @override
  String cacheClearTabContent(String typeName) {
    return 'Alle Dateien in \"$typeName\" löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get cacheFileDeleteFailed => 'Datei konnte nicht gelöscht werden';

  @override
  String get cacheClearAll => 'Alles leeren';

  @override
  String get cacheClearTab => 'Tab leeren';

  @override
  String get cleanUnusedFiles => 'Ungenutzte Dateien bereinigen';

  @override
  String get cleaningUnusedFiles => 'Bereinigen...';

  @override
  String get orphanedCleanupAppNotReady => 'App nicht bereit';

  @override
  String get orphanedCleanupNoFiles => 'Keine ungenutzten Dateien gefunden';

  @override
  String get manageCacheTitle => 'Cache verwalten';

  @override
  String get manageCacheButton => 'Medien-Cache verwalten';

  @override
  String get localCacheTab => 'Lokal';

  @override
  String get serverCacheTab => 'Server';

  @override
  String get cacheSelectAll => 'Alle auswählen';

  @override
  String get cacheDeselectAll => 'Auswahl aufheben';

  @override
  String get cacheSelected => 'ausgewählt';

  @override
  String get clearLocalCacheDialogTitle => 'Lokalen Cache leeren';

  @override
  String get clearLocalCacheDialogContent =>
      'Möchtest du wirklich alle zwischengespeicherten Medien (Sprachnachrichten, Bilder, Videos) löschen?nDies betrifft NICHT Server-Uploads oder den Chatverlauf.';

  @override
  String get deleteAllLogsTitle => 'Alle Protokolle löschen?';

  @override
  String get deleteAllLogsContent =>
      'Dadurch werden alle App-Protokolldateien dauerhaft von der Festplatte gelöscht.\nDiese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get noLogsFound => 'Keine Protokolldateien gefunden.';

  @override
  String get changePasswordInfo =>
      'Gib deine Wiederherstellungsphrase und dein aktuelles Passwort ein, um ein neues Passwort festzulegen.';

  @override
  String get changePasswordPassphraseLabel =>
      'Wiederherstellungsphrase (12 Wörter)';

  @override
  String get changePasswordCurrentLabel => 'Aktuelles Passwort';

  @override
  String get changePasswordNewLabel => 'Neues Passwort (mind. 16 Zeichen)';

  @override
  String get changePasswordChange => 'Ändern';

  @override
  String get changePasswordFieldsRequired => 'Alle Felder sind erforderlich';

  @override
  String get changePasswordTooShort =>
      'Das neue Passwort muss mindestens 16 Zeichen lang sein';

  @override
  String get changePasswordChanging => 'Passwort wird geändert...';

  @override
  String get changePasswordSuccess => ' Passwort erfolgreich geändert';

  @override
  String get clearBgTitle => 'Hintergrund entfernen?';

  @override
  String get clearBgContent =>
      'Benutzerdefinierten Chat-Hintergrund entfernen und Standard wiederherstellen.';

  @override
  String get chatBgSet => ' Chat-Hintergrund festgelegt';

  @override
  String get chatBgCleared => 'Hintergrund entfernt';

  @override
  String get sendAsCodeTitle => 'Als Code senden?';

  @override
  String get sendAsCodeContent =>
      'Diese Nachricht sieht wie Code aus. Als formatierten Codeblock senden?';

  @override
  String get sendAsCode => 'Als Code senden';

  @override
  String get sendAsPlainText => 'Als Text senden';

  @override
  String get allMessagesLeft => 'Alle Nachrichten: Links';

  @override
  String get allMessagesRight2 => 'Alle Nachrichten: Rechts';

  @override
  String get allMessagesMixed => 'Alle Nachrichten: Gemischt';

  @override
  String get applyBackgroundToApp => 'Hintergrund auf die ganze App anwenden';

  @override
  String get uiElementsOpacityLabel => 'Deckkraft der UI-Elemente';

  @override
  String get uiElementsBrightnessLabel => 'Helligkeit der UI-Elemente';

  @override
  String get navPanelPosition => 'Position der Navigationsleiste';

  @override
  String get navPosBottom => 'Unten (unter der Chatliste)';

  @override
  String get navPosLeft => 'Links (Seitenleiste)';

  @override
  String get tabSwiping => 'Tab-Wischen';

  @override
  String get tabSwipingSubtitle => 'Mit Sprungeffekt zwischen Tabs wischen';

  @override
  String get showAvatarsInChats => 'Avatare in Chats anzeigen';

  @override
  String get smoothScrollDown => 'Sanftes Herunterscrollen';

  @override
  String get messageAnimations => 'Nachrichtenanimationen';

  @override
  String get chatListMoveAnimations => 'Bewegungsanimationen der Chatliste';

  @override
  String get scrollDownButtonPosition => 'Position des Herunterscroll-Buttons';

  @override
  String get scrollDownButtonPositionLeft => 'Links';

  @override
  String get scrollDownButtonPositionCenter => 'Mitte';

  @override
  String get scrollDownButtonPositionRight => 'Rechts';

  @override
  String get scrollDownButtonSize => 'Größe des Herunterscroll-Buttons';

  @override
  String get loadOlderMessagesOnScroll =>
      'Ältere Nachrichten beim Scrollen laden';

  @override
  String get showSnackbars => 'Snackbars anzeigen';

  @override
  String get autoLoadVideos => 'Videos automatisch laden';

  @override
  String get autoLoadVideosSubtitle =>
      'Wenn deaktiviert, werden Videos erst bei Antippen geladen — flüssigeres Scrollen';

  @override
  String get tapToLoadVideo => 'Zum Laden des Videos tippen';

  @override
  String get chooseBackground => 'Wählen';

  @override
  String get presetsBackground => 'Vorlagen';

  @override
  String get clearBackground2 => 'Entfernen';

  @override
  String get liquidGlassSubtitle =>
      'Glaseffekte und Qualität pro Element konfigurieren';

  @override
  String get liquidGlassNavBarLabel => 'Navigationsleiste';

  @override
  String get liquidGlassNavBarDesc =>
      'Glaseffekt auf der unteren Navigationsleiste';

  @override
  String get liquidGlassCardsLabel => 'Karten & Listenelemente';

  @override
  String get liquidGlassCardsDesc =>
      'Glaseffekt auf der Chatliste und den Einstellungskarten';

  @override
  String get liquidGlassInputLabel => 'Eingabeleiste';

  @override
  String get liquidGlassInputDesc =>
      'Glaseffekt auf der Nachrichteneingabeleiste';

  @override
  String get liquidGlassSearchLabel => 'Suche';

  @override
  String get liquidGlassSearchDesc =>
      'Glasfläche im Spotlight-Stil für die Benutzersuche';

  @override
  String get liquidGlassAppBarLabel => 'App-Leisten-Buttons';

  @override
  String get liquidGlassAppBarDesc =>
      'Glaseffekt auf den Symbol-Buttons der Chat-App-Leiste';

  @override
  String get sendFavoritesScanHint =>
      'Richte die Kamera auf den QR-Code, der auf dem Empfängergerät angezeigt wird';

  @override
  String get mediaPickerGallery => 'Galerie';

  @override
  String get mediaPickerCamera => 'Kamera';

  @override
  String get mediaPickerFile => 'Datei';

  @override
  String mediaPickerSend(int n) {
    return '$n senden';
  }

  @override
  String get mediaPickerChooseWallpaper => 'Hintergrundbild wählen';

  @override
  String get mediaPickerFiles => 'Dateien';

  @override
  String get mediaPickerDeniedTitle => 'Galeriezugriff verweigert';

  @override
  String get mediaPickerDeniedBody =>
      'Erlaube den Zugriff in den Einstellungen oder wähle direkt eine Datei aus.';

  @override
  String get mediaPickerPickFile => 'Datei auswählen';

  @override
  String get mediaPickerOpenSettings => 'Einstellungen öffnen';

  @override
  String get notifWarning =>
      'Benachrichtigungen werden nur zugestellt, während die App läuft. Damit du keine Nachricht verpasst, minimiere ONYX ins System-Tray, anstatt es zu schließen.';

  @override
  String get backgroundServiceTitle => 'Hintergrunddienst';

  @override
  String get backgroundServiceSubtitle =>
      'ONYX im Hintergrund verbunden halten';

  @override
  String get backgroundServiceEnableLabel => 'Im Hintergrund weiterlaufen';

  @override
  String get backgroundServiceEnableSubtitle =>
      'Zeigt eine dauerhafte Benachrichtigung an, damit das System ONYX nicht am Empfang von Nachrichten im Hintergrund hindert';

  @override
  String get backgroundServiceTextLabel => 'Benachrichtigungstext';

  @override
  String get backgroundServiceDefaultText => 'Warten auf Nachrichten';

  @override
  String get notifPopupPosition => 'Popup-Position';

  @override
  String get notifPopupPositionSubtitle =>
      'Wähle, wo das Benachrichtigungs-Popup auf dem Bildschirm erscheint';

  @override
  String get notifEnableLabel => 'Benachrichtigungen aktivieren';

  @override
  String get notifHideContentLabel => 'Nachrichteninhalt verbergen';

  @override
  String get notifSoundEnableLabel => 'Benachrichtigungston';

  @override
  String get notifSoundChooseLabel => 'Ton wählen';

  @override
  String get notifSoundCustom => 'Eigenen Ton hochladen...';

  @override
  String get notifSoundCustomLoaded => 'Eigener Ton festgelegt';

  @override
  String get notifSoundCustomError => 'Ton konnte nicht geladen werden';

  @override
  String get notifSoundCustomInvalidFormat =>
      'Unterstützt: WAV, MP3, M4A, OGG, AAC';

  @override
  String get resetting => 'Wird zurückgesetzt...';

  @override
  String get launchAtStartupLabel => 'Beim Start ausführen';

  @override
  String get launchAtStartupSubtitle =>
      'ONYX beim Anmelden automatisch starten';

  @override
  String get launchAtStartupEnabled => 'Autostart aktiviert';

  @override
  String get launchAtStartupDisabled => 'Autostart deaktiviert';

  @override
  String get launchAtStartupFailed =>
      'Autostart-Einstellung konnte nicht geändert werden';

  @override
  String get avatarUpdated => 'Avatar aktualisiert';

  @override
  String get fileNotFound => 'Datei nicht gefunden';

  @override
  String get fileSent => 'Datei gesendet';

  @override
  String get imageSent => 'Bild gesendet';

  @override
  String get videoSent => 'Video gesendet';

  @override
  String uploadingFile(String name) {
    return '$name wird hochgeladen...';
  }

  @override
  String albumSent(int n) {
    return 'Album gesendet ($n Bilder)';
  }

  @override
  String get fileEmpty => 'Datei ist leer';

  @override
  String get networkError => 'Netzwerkfehler';

  @override
  String get avatarRemoved => 'Avatar entfernt';

  @override
  String get uinCopied => 'UIN kopiert';

  @override
  String get displayNameLength => 'Der Anzeigename muss 1–16 Zeichen lang sein';

  @override
  String get failedSendLan => 'Senden über LAN fehlgeschlagen';

  @override
  String get fileCancelled => 'Datei abgebrochen';

  @override
  String get doneRestarting => 'Fertig! Wird neu gestartet...';

  @override
  String get deleteMessageTitle => 'Nachricht löschen?';

  @override
  String get deleteMessageContent =>
      'Diese Nachricht wird für beide Seiten gelöscht.';

  @override
  String get cannotDeleteMsg =>
      'Löschen nicht möglich: Nachricht noch nicht auf dem Server gespeichert';

  @override
  String get deleteForMeTitle => 'Für mich löschen?';

  @override
  String get deleteForMeContent =>
      'Dadurch wird die Nachricht nur von deinem Gerät entfernt. Die andere Person sieht sie weiterhin.';

  @override
  String get deleteFavMessageContent =>
      'Diese Nachricht wird aus den Favoriten entfernt.';

  @override
  String get pinnedMessage => 'Angepinnte Nachricht';

  @override
  String get setReminder => 'Set Reminder';

  @override
  String get cancelReminder => 'Cancel Reminder';

  @override
  String get reminderSet => 'Reminder set';

  @override
  String get reminderCancelled => 'Reminder cancelled';

  @override
  String get reminderNotificationPrefix => 'Reminder';

  @override
  String get reminderGenericBody => 'You have a reminder';

  @override
  String get reminderHourLabel => 'Hour';

  @override
  String get reminderMinuteLabel => 'Minute';

  @override
  String get reminderPickDate => 'Choose date';

  @override
  String get reminderDateToday => 'Today';

  @override
  String get reminderDateTomorrow => 'Tomorrow';

  @override
  String get reminderInvalidTime => 'Enter a valid time';

  @override
  String get reminderPastTime => 'This time has already passed';

  @override
  String get msgCopied => 'Kopiert';

  @override
  String copiedUsername(String name) {
    return '@$name kopiert';
  }

  @override
  String get deliveryModeTitle => 'Zustellmodus wählen';

  @override
  String get deliveryInternet => 'Internet';

  @override
  String get deliveryInternetSubtitle => 'Über Server senden (verschlüsselt)';

  @override
  String get deliveryLanSubtitle => 'Über lokales Netzwerk senden (direkt)';

  @override
  String get deliveryUserNotInLan => 'Benutzer im LAN nicht gefunden';

  @override
  String get fastChange => 'Schnellwechsel';

  @override
  String get fastChangeSubtitle => 'Modus mit langem Drücken umschalten';

  @override
  String get lanModeEnabled => 'LAN-Modus aktiviert';

  @override
  String get internetModeEnabled => 'Internet-Modus aktiviert';

  @override
  String get previewMessageTitle => 'Nachrichtenvorschau';

  @override
  String get previewYourMessage => 'Deine Nachricht:';

  @override
  String replyingTo(String name) {
    return 'Antwort an: $name';
  }

  @override
  String get send => 'Senden';

  @override
  String get fileSentLan => 'Datei über LAN gesendet';

  @override
  String uploadingImages(int n) {
    return '$n Bilder werden hochgeladen...';
  }

  @override
  String get albumUploadFailed => 'Album-Upload fehlgeschlagen';

  @override
  String get message => 'Nachricht';

  @override
  String get noMessagesYet => 'Noch keine Nachrichten';

  @override
  String get voiceCallsTitle => 'Sprachanrufe';

  @override
  String get voiceCallsContent =>
      'Sprachanrufe funktionieren derzeit nur über LAN (lokales Netzwerk).\n\nWir sammeln Spenden für die Wartung des zentralen Servers und die Entwicklung einer Alternative.';

  @override
  String get supportOnyxBtn => 'ONYX unterstützen';

  @override
  String get call => 'Anrufen';

  @override
  String get securityCheckTitle => 'Sicherheitsprüfung';

  @override
  String securityCheckContent(String name) {
    return 'Vergleiche diese Emojis mit $name.\nStimmen sie überein — ist dein Chat sicher.';
  }

  @override
  String get failedToFetchPubkey =>
      'Öffentlicher Schlüssel konnte nicht abgerufen werden';

  @override
  String get userHasNoPubkey => 'Benutzer hat keinen öffentlichen Schlüssel';

  @override
  String get galleryMenuLabel => 'Galerie';

  @override
  String get galleryTitle => 'Galerie';

  @override
  String get galleryTabMedia => 'Medien';

  @override
  String get galleryTabVoice => 'Sprachnachrichten';

  @override
  String get galleryTabFiles => 'Dateien';

  @override
  String get galleryEmptyMedia => 'Noch keine Fotos oder Videos';

  @override
  String get galleryEmptyVoice => 'Noch keine Sprachnachrichten';

  @override
  String get galleryEmptyFiles => 'Noch keine Dateien';

  @override
  String get galleryShowInChat => 'Im Chat anzeigen';

  @override
  String get failedDelete => 'Löschen fehlgeschlagen';

  @override
  String get failedEdit => 'Nachricht konnte nicht bearbeitet werden';

  @override
  String get failedReaction => 'Reaktion konnte nicht hinzugefügt werden';

  @override
  String get noInternetCached =>
      'Kein Internet — zwischengespeicherte Nachrichten werden angezeigt';

  @override
  String get sendFailed => 'Senden fehlgeschlagen';

  @override
  String get mediaUploadNotSupportedWeb =>
      'Medien-Upload wird im Web nicht unterstützt';

  @override
  String get localFileRequired => 'Lokale Datei erforderlich';

  @override
  String get uploadFailed => 'Upload fehlgeschlagen';

  @override
  String get voiceUploadFailed => 'Upload der Sprachnachricht fehlgeschlagen';

  @override
  String get voiceCancelled => 'Sprachnachricht abgebrochen';

  @override
  String get uploadingVoice => 'Sprachnachricht wird hochgeladen...';

  @override
  String uploadingAlbumProgress(int done, int total) {
    return 'Album wird hochgeladen: $done/$total Fotos';
  }

  @override
  String get uploadingImageLabel => 'Bild wird hochgeladen...';

  @override
  String get uploadingVideoLabel => 'Video wird hochgeladen...';

  @override
  String get uploadingAudioLabel => 'Audio wird hochgeladen...';

  @override
  String get uploadingFileLabel => 'Datei wird hochgeladen...';

  @override
  String get leftGroup => 'Du hast die Gruppe verlassen';

  @override
  String get failedLeaveGroup => 'Gruppe konnte nicht verlassen werden';

  @override
  String get avatarOnlyOwnerMod =>
      'Nur Besitzer und Moderatoren können den Avatar ändern';

  @override
  String get failedReadFile => 'Datei konnte nicht gelesen werden';

  @override
  String get uploadingAvatar => 'Avatar wird hochgeladen...';

  @override
  String get avatarUpdatedGroup => 'Gruppenavatar aktualisiert';

  @override
  String get avatarDeleted => 'Avatar gelöscht';

  @override
  String get failedDeleteAvatar => 'Avatar konnte nicht gelöscht werden';

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get tokenCopied => 'Token kopiert';

  @override
  String get groupNameLength => 'Der Gruppenname muss 1–50 Zeichen lang sein';

  @override
  String get groupUpdated => 'Gruppe aktualisiert';

  @override
  String get failedUpdateGroup => 'Gruppe konnte nicht aktualisiert werden';

  @override
  String get deleteAvatarTitle => 'Avatar löschen?';

  @override
  String get deleteAvatarContent =>
      'Dadurch wird der Gruppenavatar für alle entfernt.';

  @override
  String get deleteGroupMsgContent => 'Diese Nachricht wird für alle gelöscht.';

  @override
  String get reply => 'Antworten';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get editGroupTitle => 'Gruppe bearbeiten';

  @override
  String get editChannelTitle => 'Kanal bearbeiten';

  @override
  String get groupInfoTitle => 'Group';

  @override
  String get channelInfoTitle => 'Channel';

  @override
  String get channelNameLabel => 'Kanalname';

  @override
  String get channelNameHint => 'Kanalnamen eingeben';

  @override
  String unsupportedFileType(String ext) {
    return 'Nicht unterstützter Dateityp: $ext';
  }

  @override
  String failedToConnect(String e) {
    return 'Verbindung fehlgeschlagen: $e';
  }

  @override
  String roleChanged(String role) {
    return 'Deine Rolle wurde zu $role geändert';
  }

  @override
  String get unbannedReconnecting =>
      'Du wurdest entsperrt! Verbindung wird wiederhergestellt...';

  @override
  String get onlyModsCanPost =>
      'Nur Besitzer und Moderatoren können in Kanälen posten';

  @override
  String get failedSendMessage => 'Nachricht konnte nicht gesendet werden';

  @override
  String get uploadFailedConnectionAborted =>
      'Upload fehlgeschlagen: Verbindung abgebrochen. Versuche eine kleinere Datei oder überprüfe die Servereinstellungen.';

  @override
  String get failedSendMedia => 'Medien konnten nicht gesendet werden';

  @override
  String get joinedGroup => 'Du bist der Gruppe beigetreten!';

  @override
  String get failedJoinGroup => 'Beitritt zur Gruppe fehlgeschlagen';

  @override
  String get cancelled => 'Abgebrochen';

  @override
  String get avatarWillBeDeleted => 'Avatar wird gelöscht';

  @override
  String get ipCopied => 'IP kopiert';

  @override
  String get nameCannotBeEmpty => 'Name darf nicht leer sein';

  @override
  String get groupRenamed => 'Gruppe erfolgreich umbenannt';

  @override
  String errorMsg(String e) {
    return 'Fehler: $e';
  }

  @override
  String get failedRename => 'Umbenennen fehlgeschlagen';

  @override
  String get imageTooLarge => 'Bild zu groß (max. 5 MB)';

  @override
  String get avatarUpdatedSuccessfully => 'Avatar erfolgreich aktualisiert';

  @override
  String get failedUploadAvatar => 'Avatar konnte nicht hochgeladen werden';

  @override
  String get deletingAvatar => 'Avatar wird gelöscht...';

  @override
  String get avatarDeletedSuccessfully => 'Avatar erfolgreich gelöscht';

  @override
  String userBanned(String name) {
    return '$name gesperrt';
  }

  @override
  String get failedBan => 'Sperren fehlgeschlagen';

  @override
  String roleUpdated(String role) {
    return 'Rolle zu $role geändert';
  }

  @override
  String get failedChangeRole => 'Rolle konnte nicht geändert werden';

  @override
  String userUnbanned(String name) {
    return '$name entsperrt';
  }

  @override
  String get failedUnban => 'Entsperren fehlgeschlagen';

  @override
  String get youHaveBeenBanned => 'Du wurdest gesperrt';

  @override
  String get renameGroupTitle => 'Gruppe umbenennen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get join => 'Beitreten';

  @override
  String get manageMembers => 'Mitglieder verwalten';

  @override
  String get banMemberTitle => 'Mitglied sperren';

  @override
  String get ban => 'Sperren';

  @override
  String get selectNewRole => 'Neue Rolle auswählen:';

  @override
  String get moderator => 'Moderator';

  @override
  String get memberRole => 'Mitglied';

  @override
  String get manageMembersTitle => 'Mitglieder verwalten';

  @override
  String get viewBans => 'Sperrungen anzeigen';

  @override
  String get unbanUserTitle => 'Benutzer entsperren';

  @override
  String get unban => 'Entsperren';

  @override
  String get bannedUsersTitle => 'Gesperrte Benutzer';

  @override
  String get bannedFromGroup => 'Du wurdest aus dieser Gruppe gesperrt.';

  @override
  String bannedReason(String reason) {
    return 'Grund: $reason';
  }

  @override
  String get noBannedUsers => 'Keine gesperrten Benutzer';

  @override
  String bannedBy(String name) {
    return 'Gesperrt von: $name';
  }

  @override
  String bannedDate(String date) {
    return 'Datum: $date';
  }

  @override
  String banConfirm(String name) {
    return '$name aus der Gruppe sperren?';
  }

  @override
  String get banReason => 'Grund (optional)';

  @override
  String changeRoleTitle(String name) {
    return 'Rolle für $name ändern';
  }

  @override
  String currentRoleLabel(String role) {
    return 'Aktuelle Rolle: $role';
  }

  @override
  String ownerCount(int n) {
    return 'Besitzer: $n/3';
  }

  @override
  String get ownerCurrent => 'Besitzer (aktuell)';

  @override
  String get ownerLimitReached => 'Besitzer (Limit erreicht)';

  @override
  String get owner => 'Besitzer';

  @override
  String get cannotDemoteLastOwner =>
      'Der letzte Besitzer kann nicht degradiert werden';

  @override
  String get noMembersYet => 'Keine Mitglieder';

  @override
  String get changeRole => 'Rolle ändern';

  @override
  String unbanConfirm(String name) {
    return '$name entsperren?';
  }

  @override
  String get today => 'Heute';

  @override
  String get yesterday => 'Gestern';

  @override
  String get failedCreateGroup => 'Gruppe konnte nicht erstellt werden';

  @override
  String get invalidInviteLinkFormat => 'Ungültiges Format des Einladungslinks';

  @override
  String get invalidInviteLink => 'Ungültiger Einladungslink';

  @override
  String get groupAddedForViewing => 'Gruppe zur Ansicht hinzugefügt!';

  @override
  String get failedAddGroup => 'Gruppe konnte nicht hinzugefügt werden';

  @override
  String serverRemoved(String name) {
    return 'Server \"$name\" entfernt';
  }

  @override
  String get channelAdminOnlySubtitle => 'Kanal (nur Admin)';

  @override
  String get groupSubtitle => 'Gruppe';

  @override
  String get newGroup => 'Neue Gruppe';

  @override
  String get externalGroup => 'Externe Gruppe';

  @override
  String get externalChannel => 'Externer Kanal';

  @override
  String get joinExternalServer => 'Externem Server beitreten';

  @override
  String get enterServerAddress => 'Serveradresse eingeben';

  @override
  String get enterValidIp =>
      'Gib eine gültige IP-Adresse oder einen Hostnamen ein';

  @override
  String couldNotConnect(String host) {
    return 'Verbindung zu $host nicht möglich';
  }

  @override
  String get usernameRequiredMsg =>
      'Ein Benutzername ist erforderlich. Stelle sicher, dass du in der App ein Konto erstellt hast.';

  @override
  String get passwordRequiredForGroups =>
      'Für Gruppen ist ein Passwort erforderlich';

  @override
  String get passwordRequired => 'Passwort ist erforderlich';

  @override
  String connectionFailed(String e) {
    return 'Verbindung fehlgeschlagen: $e';
  }

  @override
  String connectedToServer(String type, String name) {
    return 'Mit $type \"$name\" verbunden';
  }

  @override
  String get externalGroupType => 'externe Gruppe';

  @override
  String get externalChannelType => 'externer Kanal';

  @override
  String get identityVisible =>
      'Deine Identität wird für den Server sichtbar sein';

  @override
  String get usernameLabel => 'Benutzername';

  @override
  String get passwordLabel => 'Passwort';

  @override
  String get noPasswordForChannels =>
      'Für Kanäle ist kein Passwort erforderlich';

  @override
  String get noRegistrationRequired => 'Keine Registrierung erforderlich.';

  @override
  String get back => 'Zurück';

  @override
  String get connecting => 'Verbindung wird hergestellt...';

  @override
  String get connectBtn => 'Verbinden';

  @override
  String get serverInfoGroups => 'Gruppen';

  @override
  String get serverInfoMembers => 'Mitglieder';

  @override
  String get serverInfoMedia => 'Medien';

  @override
  String get serverInfoMaxFile => 'Maximale Dateigröße';

  @override
  String get profilePresets => 'Identität';

  @override
  String get profilePresetsSubtitle =>
      'Gespeicherte Identitäten für externe Server';

  @override
  String get newPreset => 'Neue Identität';

  @override
  String get editPreset => 'Identität bearbeiten';

  @override
  String get deletePreset => 'Identität löschen';

  @override
  String deletePresetConfirm(String label) {
    return 'Identität \"$label\" löschen?';
  }

  @override
  String get presetLabel => 'Name der Identität';

  @override
  String get presetLabelHint => 'z. B. Arbeit, Gaming';

  @override
  String get presetNote => 'Notiz';

  @override
  String get presetNoteHint => 'Wofür ist diese Identität? (optional)';

  @override
  String get presetColor => 'Etikettenfarbe';

  @override
  String get presetLabelRequired => 'Gib einen Namen für die Identität ein';

  @override
  String get noPresetsYet => 'Noch keine Identitäten';

  @override
  String get noPresetsYetSubtitle =>
      'Speichere eine Benutzername-Passwort-Kombination einmal und nutze sie auf jedem externen Server';

  @override
  String get myPresets => 'Meine Identitäten';

  @override
  String get usePreset => 'Identität verwenden';

  @override
  String get saveAsPreset => 'Als Identität speichern';

  @override
  String get presetSaved => 'Identität gespeichert';

  @override
  String get presetDeleted => 'Identität gelöscht';

  @override
  String get thirdPartyServer => 'DRITTANBIETER-SERVER';

  @override
  String get thirdPartyWarning =>
      'Dieser Server wird nicht von ONYX betrieben. Verbinde dich nur, wenn du dem Betreiber vertraust.';

  @override
  String get serverWillKnow => 'Der Server erfährt:';

  @override
  String get serverWillNotReceive => 'Der Server erhält NICHT:';

  @override
  String get knowIpAddress => 'Deine IP-Adresse';

  @override
  String get knowUsername => 'Deinen gewählten Benutzernamen';

  @override
  String get knowMessages => 'Den Inhalt deiner Nachrichten auf diesem Server';

  @override
  String get notReceiveAccount => 'Dein ONYX-Konto oder Passwort';

  @override
  String get notReceiveContacts => 'Deine Kontakte und privaten Chats';

  @override
  String get notReceiveKeys => 'Deine Verschlüsselungsschlüssel';

  @override
  String get yourPassphraseTitle => 'Deine Wiederherstellungsphrase';

  @override
  String get sessionExpiredBanner =>
      'Sitzung abgelaufen — bitte melde dich erneut an';

  @override
  String get sessionExpiredTitle => 'Sitzung abgelaufen';

  @override
  String get sessionExpiredSubtitle => 'Bitte melde dich erneut an';

  @override
  String get sessionSignIn => 'Anmelden';

  @override
  String get sessionRenewSoon =>
      'Eine erneute Anmeldung wird bald erforderlich sein';

  @override
  String get sessionStillValid => 'Autorisierungstoken ist gültig';

  @override
  String get blockedUsersTitle => 'Blockierte Benutzer';

  @override
  String get blockedUsersSubtitle => 'Blockierte Benutzer verwalten';

  @override
  String get blockedUsersEmpty => 'Keine blockierten Benutzer';

  @override
  String get unblockAction => 'Entsperren';

  @override
  String get writeMessage => 'Schreiben';

  @override
  String get fakePinTitle => 'Tarn-PIN';

  @override
  String get fakePinSubtitle => 'Unter Zwang ein Täuschungskonto öffnen';

  @override
  String get fakePinSheetTitle => 'Tarn-PIN einrichten';

  @override
  String get fakePinStatusActive => 'Aktiv';

  @override
  String get fakePinStatusOff => 'Aus';

  @override
  String get fakePinDescription =>
      'Wenn diese PIN am Sperrbildschirm eingegeben wird, öffnet die App statt deines echten Kontos dein Täuschungskonto.';

  @override
  String get setFakePin => 'Tarn-PIN festlegen';

  @override
  String get disableFakePin => 'Tarn-PIN deaktivieren';

  @override
  String get changeFakePin => 'Tarn-PIN ändern';

  @override
  String get disableFakePinTitle => 'Tarn-PIN deaktivieren?';

  @override
  String get disableFakePinContent =>
      'Die Tarn-PIN wird entfernt. Die Einstellungen des Täuschungskontos bleiben erhalten.';

  @override
  String get fakePinEnabledSnack => 'Tarn-PIN aktiviert';

  @override
  String get fakePinDisabledSnack => 'Tarn-PIN deaktiviert';

  @override
  String get fakePinCannotMatchReal =>
      'Die Tarn-PIN darf nicht mit deiner echten PIN übereinstimmen';

  @override
  String get decoyAccountSection => 'Täuschungskonto';

  @override
  String get decoyAccountSubtitle =>
      'Dieses Konto wird angezeigt, wenn die Tarn-PIN verwendet wird';

  @override
  String get decoyDisplayNameLabel => 'Anzeigename';

  @override
  String get decoyUsernameLabel => 'Benutzername';

  @override
  String get decoyDisplayNameHint => 'Anzeigenamen eingeben';

  @override
  String get decoyUsernameHint => 'Benutzernamen eingeben';

  @override
  String get saveDecoyAccount => 'Täuschungskonto speichern';

  @override
  String get decoyAccountSaved => 'Täuschungskonto gespeichert';

  @override
  String get decoyFieldsRequired =>
      'Benutzername und Anzeigename dürfen nicht leer sein';

  @override
  String get removeAvatar => 'Avatar entfernen';

  @override
  String get fakePinSecurityNote =>
      'Die Tarn-PIN muss sich von deiner echten PIN unterscheiden. Das Täuschungskonto hat keine Serververbindung — es zeigt nur das hier konfigurierte Profil an.';

  @override
  String get decoyNoChats => 'Noch keine Chats';

  @override
  String get decoyNoGroups => 'Noch keine Gruppen';

  @override
  String get decoyNoFavorites => 'Noch keine Favoriten';

  @override
  String get decoyOtherAccounts => 'Andere Konten';

  @override
  String get decoyNoOtherAccounts => 'Keine anderen Konten';

  @override
  String get lock => 'Sperren';

  @override
  String get decoyAppearance => 'Erscheinungsbild';

  @override
  String get decoyNotifications => 'Benachrichtigungen';

  @override
  String get decoyStorage => 'Speicher';

  @override
  String get decoyAppearanceSubtitle => 'Design und Anzeigeoptionen';

  @override
  String get decoyNotificationsSubtitle => 'Ton- und Warnungseinstellungen';

  @override
  String get decoyStorageSubtitle => 'Zwischengespeicherte Dateien verwalten';

  @override
  String get decoyContactsSection => 'Täuschungs-Chats';

  @override
  String get decoyContactsSubtitle =>
      'Kontakte mit Nachrichten hinzufügen — sie erscheinen, wenn das Täuschungskonto geöffnet wird';

  @override
  String get generateContacts => 'Kontakte generieren';

  @override
  String get addDecoyContact => 'Kontakt hinzufügen';

  @override
  String get decoyNoContacts => 'Noch keine Täuschungs-Chats';

  @override
  String get decoyContactUsername => 'Benutzername des Kontakts';

  @override
  String get decoyContactDisplayName => 'Anzeigename des Kontakts';

  @override
  String contactsGenerated(int n) {
    return '$n Kontakte hinzugefügt';
  }

  @override
  String get contactAdded => 'Kontakt hinzugefügt';

  @override
  String get contactRemoved => 'Kontakt entfernt';

  @override
  String get decoyContactExists => 'Kontakt existiert bereits';

  @override
  String get decoyContactsCleared => 'Alle Chats gelöscht';

  @override
  String get clearDecoyChats => 'Alle Chats löschen';

  @override
  String get messagesCount => 'Nachrichten';

  @override
  String get add => 'Hinzufügen';

  @override
  String get decoyChatsSubtitle => 'Kontakte mit Nachrichtenverlauf';

  @override
  String get decoyGroupsSection => 'Gruppen & Kanäle';

  @override
  String get decoyGroupsSubtitle => 'Täuschungsgruppen und -kanäle';

  @override
  String get decoyFavoritesSection => 'Favoriten';

  @override
  String get decoyFavoritesSubtitle => 'Angepinnte Favoritenchats';

  @override
  String get noFakeGroups => 'Noch keine Gruppen';

  @override
  String get noFakeFavorites => 'Noch keine Favoriten';

  @override
  String get addFakeGroup => 'Gruppe';

  @override
  String get addFakeChannel => 'Kanal';

  @override
  String get addFakeFavorite => 'Favorit hinzufügen';

  @override
  String get groupType => 'Gruppe';

  @override
  String get channelType => 'Kanal';

  @override
  String get favTitleHint => 'Titel';

  @override
  String get generateAll => 'Alles generieren';

  @override
  String get generateAllConfirm =>
      'Zufälliger Inhalt wird generiert und ersetzt vorhandene Daten.';

  @override
  String get sendFavoritesTitle => 'Favoriten senden';

  @override
  String get sendFavoritesShowQrToReceiver => 'QR-Code für Empfänger anzeigen';

  @override
  String get sendFavoritesScanReceiver => 'QR-Code des Empfängers scannen';

  @override
  String get sendFavoritesSending => 'Favoriten werden gesendet';

  @override
  String get sendFavoritesSelectTitle => 'Chats zum Senden auswählen';

  @override
  String get sendFavoritesHintDesktop =>
      'Der Empfänger muss zuerst auf \"Empfangen\" tippen. Scanne dann den hier angezeigten QR-Code.';

  @override
  String get sendFavoritesHintMobile =>
      'Der Empfänger muss zuerst auf \"Empfangen\" tippen und den QR-Code anzeigen.';

  @override
  String allChatsCount(int n) {
    return 'Alle Chats ($n)';
  }

  @override
  String get sendFavoritesNoFavs => 'Noch keine Favoritenchats.';

  @override
  String get sendFavoritesSelectAtLeastOne => 'Wähle mindestens einen Chat aus';

  @override
  String get sendFavoritesShowQrBtn => 'QR-Code anzeigen';

  @override
  String get sendFavoritesScanQrBtn => 'QR-Code scannen';

  @override
  String get receiveFavoritesTitle => 'Favoriten empfangen';

  @override
  String get receiveFavoritesScanSender => 'QR-Code des Absenders scannen';

  @override
  String get receiveFavoritesScanOnSender =>
      'Auf dem Gerät des Absenders scannen';

  @override
  String get receiveFavoritesInstruction =>
      'Öffne Favoriten beim Absender, tippe auf Sync → Senden und scanne dann diesen Code';

  @override
  String get receiveFavoritesE2E =>
      'Ende-zu-Ende-verschlüsselt · nur lokales Netzwerk';

  @override
  String get receiveFavoritesScanHint =>
      'Richte die Kamera auf den QR-Code, der auf dem Gerät des Absenders angezeigt wird';

  @override
  String get receiveFavoritesScanEncrypted =>
      'Übertragung ist verschlüsselt · nur lokales Netzwerk';

  @override
  String get receiveFavoritesWaiting =>
      'Warte darauf, dass der Absender den QR-Code scannt…';

  @override
  String get receiveFavoritesComplete => 'Übertragung abgeschlossen.';

  @override
  String get receiveFavoritesConnecting =>
      'Verbindung zum Absender wird hergestellt…';

  @override
  String get receiveFavoritesConnected => 'Verbunden! Warte auf Dateien…';

  @override
  String get cancelTransfer => 'Übertragung abbrechen';

  @override
  String get wardLinkTitle => 'WardLink';

  @override
  String get wardLinkSubtitle =>
      'Passive Synchronisierung zwischen deinen Geräten im lokalen Netzwerk';

  @override
  String get wardLinkEnable => 'Passive Synchronisierung';

  @override
  String get wardLinkEnableDesc =>
      'Automatische Synchronisierung mit vertrauenswürdigen Geräten im gleichen Netzwerk. Auf Smartphones funktioniert dies, während die App geöffnet ist; auf dem Desktop läuft es dauerhaft.';

  @override
  String get wardLinkPairedDevices => 'Vertrauenswürdige Geräte';

  @override
  String get wardLinkNoPairedDevices => 'Noch keine gekoppelten Geräte';

  @override
  String get wardLinkAddDevice => 'Hinzufügen';

  @override
  String get wardLinkRemoveDevice => 'Entfernen';

  @override
  String get wardLinkRemoveConfirm =>
      'Synchronisierung mit diesem Gerät beenden?';

  @override
  String get wardLinkFavoritesOnlyNote =>
      'Synchronisiert deine Favoriten — ihre Nachrichten und Medien';

  @override
  String get wardLinkMaxFileSize => 'Maximale Dateigröße';

  @override
  String get wardLinkPairTitle => 'Gerät koppeln';

  @override
  String get wardLinkShowCode => 'Code anzeigen';

  @override
  String get wardLinkScanCode => 'Code scannen';

  @override
  String get wardLinkShowInstruction =>
      'Öffne WardLink auf deinem anderen Gerät und scanne diesen Code';

  @override
  String get wardLinkScanInstruction =>
      'Richte die Kamera auf den WardLink-Code auf dem anderen Gerät';

  @override
  String get wardLinkPairedOk => 'Gerät gekoppelt';

  @override
  String get wardLinkPairFailed => 'Kopplung fehlgeschlagen';

  @override
  String get wardLinkE2E => 'Ende-zu-Ende-verschlüsselt · nur LAN';

  @override
  String get wardLinkSyncingNow => 'Synchronisiert…';

  @override
  String get wardLinkDone => 'Synchronisiert';

  @override
  String get wardLinkCurrentFile => 'Aktuelle Datei';

  @override
  String get wardLinkLog => 'Sync-Protokoll';

  @override
  String get wardLinkLogEmpty => 'Noch keine Ereignisse';

  @override
  String get wardLinkHoldForLog => 'Halte die Blase gedrückt für das Protokoll';

  @override
  String get wardLinkUpToDate => 'Aktuell';

  @override
  String syncedFromDevice(String device) {
    return 'Synchronisiert von $device';
  }

  @override
  String get syncedFromUnknownDevice =>
      'Von einem anderen Gerät synchronisiert';

  @override
  String wardLinkFilesDone(int n) {
    return 'Übertragene Dateien: $n';
  }

  @override
  String get wardLinkNoFilesYet => 'Keine Dateien übertragen';

  @override
  String wardLinkSyncedAgo(String when) {
    return 'Synchronisiert $when';
  }

  @override
  String get wardLinkNeverSynced => 'Noch nicht synchronisiert';

  @override
  String get wardLinkFirewallHintWindows =>
      'Wenn das Telefon diesen PC nicht erreichen kann, erlaube ONYX in der Windows-Firewall (TCP-Port 47832). ONYX versucht, die Regel automatisch hinzuzufügen; falls das fehlschlägt: Windows-Firewall → Erweitert → Eingehende Regeln → Neue Regel → Port → TCP → 47832.';

  @override
  String get wardLinkFirewallHintMac =>
      'Wenn das Telefon diesen Mac nicht erreichen kann, stelle sicher, dass die macOS-Firewall ONYX nicht blockiert: Systemeinstellungen → Netzwerk → Firewall → Optionen → ONYX hinzufügen.';

  @override
  String get wardLinkFirewallHintLinux =>
      'Wenn das Telefon keine Verbindung herstellen kann, öffne TCP-Port 47832 in deiner Firewall. Beispiel: sudo ufw allow 47832/tcp  oder  sudo firewall-cmd --add-port=47832/tcp --permanent';

  @override
  String get wardLinkSyncFromBeginning => 'Von Anfang an synchronisieren';

  @override
  String get wardLinkSyncFromBeginningDesc =>
      'Den gesamten Verlauf abrufen, der noch nicht auf diesem Gerät vorhanden ist';

  @override
  String get wardLinkSyncPending => 'Synchronisierung ausstehend…';

  @override
  String get wardLinkBubbleVisibility => 'Sync-Blase';

  @override
  String get wardLinkBubbleShowAlways => 'Immer anzeigen';

  @override
  String get wardLinkBubbleShowOnErrors => 'Nur bei Fehlern anzeigen';

  @override
  String get wardLinkBubbleSize => 'Blasengröße';

  @override
  String get wardLinkSyncFavoritesToggle => 'Favoriten synchronisieren';

  @override
  String get wardLinkSyncFavoritesToggleDesc =>
      'Synchronisiert deine Favoriten — deren Nachrichten und Medien';

  @override
  String get wardLinkSyncPersonalToggle => 'Meine Nachrichten synchronisieren';

  @override
  String get wardLinkSyncPersonalToggleDesc =>
      'Synchronisiert auf deine anderen Geräte nur die Nachrichten, die DU in persönlichen Chats gesendet hast — die Nachrichten des Kontakts kommen bereits über den Server an und werden nie auf diesem Weg synchronisiert';

  @override
  String get meshSubtitle => 'Offline-Mesh-Netzwerk';

  @override
  String get meshEnable => 'Mesh-Netzwerk aktivieren';

  @override
  String get meshEnableDesc =>
      'Direkte Nachrichten ohne Internet über Wi-Fi oder Bluetooth.\nFunktioniert nur bei Direktnachrichten.';

  @override
  String get meshUnavailable =>
      'Das Mesh-Netzwerk ist auf dieser Plattform nicht verfügbar.';

  @override
  String get meshOpenRadar => 'Radar öffnen';

  @override
  String meshNearbyCount(int n) {
    return 'In der Nähe: $n Geräte';
  }

  @override
  String get meshRadarTitle => 'Mesh-Radar';

  @override
  String get meshRadarScanning => 'Wird gescannt…';

  @override
  String get meshRadarSearchHint => 'Nach Name suchen...';

  @override
  String meshRadarSearchEmpty(String q) {
    return 'Keine Ergebnisse für \"$q\"';
  }

  @override
  String get meshRadarNoDevices =>
      'Keine Geräte in der Nähe.\nMesh scannt alle 20 s.';

  @override
  String get meshRadarDisabled =>
      'Mesh-Modus ist aus.\nAktiviere ihn unter Einstellungen → Mesh.';

  @override
  String get meshRadarStarting => 'BLE-Scan wird gestartet…';

  @override
  String get meshMenuRadar => 'Radar';

  @override
  String get meshMenuDiagnostics => 'Diagnose';

  @override
  String get meshMenuModeAuto => 'Auto';

  @override
  String get meshBluetoothOffTitle => 'Bluetooth ist aus';

  @override
  String get meshBluetoothOffContent =>
      'Der Mesh-Chat wurde in den reinen Bluetooth-Modus versetzt, aber Bluetooth ist ausgeschaltet. Aktiviere es in den Systemeinstellungen, um Geräte in der Nähe zu erreichen.';

  @override
  String get meshOpenSystemSettings => 'Einstellungen öffnen';

  @override
  String get meshModeLabel => 'MODUS';

  @override
  String get meshModeActive => 'Mesh-Modus aktiv';

  @override
  String get meshChatLabel => 'Mesh-Chat';

  @override
  String get meshLocationRequired =>
      'Standortdienste für BLE-Scan aktivieren (Android ≤11)';

  @override
  String get meshChatEmpty =>
      'Noch keine Nachrichten.\nSende die erste Mesh-Nachricht.';

  @override
  String get meshChatInputHint => 'Nachricht…';

  @override
  String get meshChatSend => 'Senden';

  @override
  String get meshChatOutOfRange => 'Außer Reichweite';

  @override
  String get meshStatusSending => 'Wird gesendet…';

  @override
  String get meshStatusSendingWifi => 'Wird über Wi-Fi gesendet…';

  @override
  String get meshStatusSendingBle => 'Wird über Bluetooth gesendet…';

  @override
  String get meshStatusRelayed => 'Unterwegs über Mesh';

  @override
  String get meshStatusDelivered => 'Zugestellt';

  @override
  String get meshStatusFailed => 'Nicht zugestellt';

  @override
  String get meshStatusRetry => 'Erneut versuchen';

  @override
  String get meshStatusFailedHint =>
      'Nachricht hat den Empfänger nicht erreicht';

  @override
  String get meshErrorVideoWifiOnly =>
      'Videos können nur über Wi-Fi gesendet werden. Verbinde dich mit demselben Wi-Fi-Netzwerk wie der Empfänger.';

  @override
  String get meshErrorFileTooLargeForBle =>
      'Die Datei ist zu groß für Bluetooth (max. 10 MB). Verbinde dich mit einem gemeinsamen Wi-Fi-Netzwerk.';

  @override
  String get meshErrorFileTooLarge => 'Die Datei ist zu groß (max. 200 MB).';

  @override
  String get meshErrorAttachmentsUnsupported =>
      'Anhänge werden nur auf Mobilgeräten/Desktop unterstützt';

  @override
  String get meshErrorPickFileFailed => 'Datei konnte nicht ausgewählt werden';

  @override
  String get meshErrorSendFileFailed => 'Datei konnte nicht gesendet werden';

  @override
  String get meshErrorSendVoiceFailed =>
      'Sprachnachricht konnte nicht gesendet werden';

  @override
  String meshErrorOutOfRange(String username) {
    return '$username ist außer Reichweite';
  }

  @override
  String get backupTitle => 'Sicherung';

  @override
  String get backupSubtitle =>
      'Lokale Sicherung und Wiederherstellung deiner Daten';

  @override
  String get backupExport => 'Alle Daten speichern';

  @override
  String get backupRestore => 'Aus Sicherung wiederherstellen';

  @override
  String get backupScope => 'Was gesichert werden soll';

  @override
  String get backupFavorites => 'Favoritenchats';

  @override
  String get backupPersonal => 'Persönliche Chats';

  @override
  String get backupIncludeMedia => 'Medien einschließen';

  @override
  String get backupMediaImages => 'Bilder';

  @override
  String get backupMediaVideos => 'Videos';

  @override
  String get backupMediaVoice => 'Sprachnachrichten & Audio';

  @override
  String get backupMediaOther => 'Andere Dateien';

  @override
  String get backupSchedule => 'Geplante Sicherung';

  @override
  String get backupFreqOff => 'Aus';

  @override
  String get backupFreqDaily => 'Täglich';

  @override
  String get backupFreqWeekly => 'Wöchentlich';

  @override
  String get backupFreqMonthly => 'Monatlich';

  @override
  String get backupFolder => 'Ordner für automatische Sicherung';

  @override
  String get backupChangeFolder => 'Ändern';

  @override
  String get backupLastAuto => 'Letzte automatische Sicherung';

  @override
  String get backupNever => 'nie';

  @override
  String get backupInProgress => 'Sicherung wird erstellt…';

  @override
  String get backupRestoring => 'Wird wiederhergestellt…';

  @override
  String get backupSelectScope => 'Wähle mindestens eine Kategorie aus';

  @override
  String get backupNoAccount => 'Kein aktives Konto';

  @override
  String get backupNoPermission =>
      'Speicherzugriff verweigert. Gewähre \"Zugriff auf alle Dateien\" in den App-Einstellungen.';

  @override
  String get backupOpenFolder => 'Ordner öffnen';

  @override
  String get backupFolderUnsupported =>
      'Auf diesen Ordner kann nicht zugegriffen werden. Bitte wähle einen Ordner auf dem internen Speicher.';

  @override
  String get backupRestoreConfirmTitle => 'Aus Sicherung wiederherstellen?';

  @override
  String get backupRestoreConfirmBody =>
      'Die Daten aus der Datei werden über deine aktuellen Daten (Chats, Favoriten, Einstellungen) wiederhergestellt.';

  @override
  String get backupRestartHint =>
      'Starte die App neu, um die Änderungen zu sehen';

  @override
  String get recycleBinTitle => 'Papierkorb';

  @override
  String get recycleBinSubtitle =>
      'Gelöschte Chats und Schutz vor versehentlichen Sync-Löschungen';

  @override
  String get recycleBinPendingTitle => 'Löschanfragen';

  @override
  String recycleBinPendingDesc(String device, int count) {
    return 'Gerät \"$device\" möchte $count Chat(s) löschen. Anwenden oder behalten?';
  }

  @override
  String get recycleBinApply => 'Löschen anwenden';

  @override
  String get recycleBinKeep => 'Meine Chats behalten';

  @override
  String get recycleBinNoPending => 'Keine ausstehenden Löschanfragen';

  @override
  String get recycleBinResetTitle => 'Löschprotokoll zurücksetzen';

  @override
  String get recycleBinResetDesc =>
      'Löscht die Liste gelöschter Chats. Die Synchronisierung löscht sie dann nicht mehr auf anderen Geräten und kann sie zurückbringen.';

  @override
  String get recycleBinResetButton => 'Gelöschte Liste leeren';

  @override
  String get recycleBinResetDone => 'Löschprotokoll gelöscht';

  @override
  String get recycleBinResetConfirm =>
      'Alle Löschprotokolle für dieses Konto löschen?';

  @override
  String get accountGraph => 'Kontografik';

  @override
  String get accountGraphSubtitleDesktopOn =>
      'Zeigt eine Grafik deiner Chats, Gruppen und Kanäle an, wenn kein Chat geöffnet ist';

  @override
  String get accountGraphSubtitleMobileOn =>
      'Visualisiert dein Konto in einer Planetenansicht';

  @override
  String get accountGraphSubtitleDesktopOff =>
      'Zeigt einen Hinweis an, wenn kein Chat geöffnet ist';

  @override
  String get accountGraphSubtitleMobileOff => 'Kontografik ist deaktiviert';

  @override
  String get orbitSpeed => 'Umlaufgeschwindigkeit';

  @override
  String secOrbit(int s) {
    return '$s Sek./Umlauf';
  }

  @override
  String minOrbit(int m) {
    return '$m Min./Umlauf';
  }

  @override
  String get animateGraph => 'Animieren';

  @override
  String get animateGraphOn => 'Umlaufbahnen drehen sich in Echtzeit';

  @override
  String get animateGraphOff => 'Grafik ist eingefroren / statisch';

  @override
  String get preserveView => 'Ansicht beibehalten';

  @override
  String get preserveViewOn =>
      'Behält Zoom & Position beim Verlassen eines Chats bei';

  @override
  String get preserveViewOff => 'Setzt beim Zurückkehren auf die Mitte zurück';

  @override
  String get migrationTitle => 'Speichermigration';

  @override
  String get migrationBody =>
      'ONYX wechselt zu einer neuen Hochgeschwindigkeits-Speicher-Engine. Chats und Medien laden deutlich schneller.';

  @override
  String get migrationAccounts => 'Konten';

  @override
  String get migrationDataSize => 'Datengröße';

  @override
  String get migrationBackupNote =>
      'Vor der Migration wird eine Sicherung erstellt. Die App kann während dieses Vorgangs vorübergehend nicht reagieren.';

  @override
  String get migrationStart => 'Migration starten';

  @override
  String get migrationSkip => 'Überspringen';

  @override
  String get migrationPhaseBackup => 'Sicherung wird erstellt';

  @override
  String get migrationPhaseImport => 'Daten werden importiert';

  @override
  String get migrationPhaseVerify => 'Wird überprüft';

  @override
  String get migrationPhasePreparing => 'Wird vorbereitet';

  @override
  String get migrationDontClose => 'Die App nicht schließen';

  @override
  String get migrationDoneTitle => 'Fertig!';

  @override
  String get migrationDoneBody =>
      'Speicher aktualisiert. Eine Sicherung wurde im Ordner \"Backups\" gespeichert.';

  @override
  String get migrationDoneNote =>
      'Sobald du bestätigt hast, dass alles funktioniert, kannst du sie manuell löschen.';

  @override
  String get migrationDoneButton => 'Verstanden!';

  @override
  String get migrationErrorTitle => 'Migrationsfehler';

  @override
  String get migrationErrorBody =>
      'Die App wird mit dem alten System fortgesetzt. Die Migration wird beim nächsten Start erneut versucht.';

  @override
  String get migrationErrorButton => 'Verstanden';

  @override
  String get audioTitle => 'Audio';

  @override
  String get audioSubtitle => 'Auswahl des Mikrofon- und Lautsprechergeräts';

  @override
  String get audioMicInput => 'Mikrofon (Eingang)';

  @override
  String get audioSpeakerOutput => 'Lautsprecher (Ausgang)';

  @override
  String get audioSystemDefault => 'Systemstandard';

  @override
  String get audioChangesNote =>
      'Änderungen werden beim nächsten Beitritt zu einem Sprachkanal wirksam.';

  @override
  String get wardlinkReceive => 'Von Gerät empfangen';

  @override
  String get wardlinkReceiveSubtitle =>
      'Einen QR-Code anzeigen — der Absender scannt ihn';

  @override
  String get wardlinkSend => 'An Gerät senden';

  @override
  String get wardlinkSendSubtitle =>
      'Den auf dem Empfänger angezeigten QR-Code scannen';

  @override
  String get react => 'Reagieren';

  @override
  String get pin => 'Anpinnen';

  @override
  String get unpin => 'Loslösen';

  @override
  String get copyImage => 'Bild kopieren';

  @override
  String get forward => 'Weiterleiten';

  @override
  String get showInFileSystem => 'Im Dateisystem anzeigen';

  @override
  String get saveNotSupportedOnWeb => 'Speichern wird im Web nicht unterstützt';

  @override
  String get imageNotLoadedYet => 'Bild noch nicht geladen';

  @override
  String get voiceNotLoadedYet => 'Sprachnachricht noch nicht geladen';

  @override
  String get videoNotLoadedYet => 'Video noch nicht geladen';

  @override
  String get fileNotLoadedYet => 'Datei noch nicht geladen';

  @override
  String get fileNotLoadedOpenFirst =>
      'Die Datei ist nicht auf dieses Gerät heruntergeladen — tippe im Chat darauf, um sie herunterzuladen';

  @override
  String editTimerLabel(int s) {
    return 'Bearbeiten  ·  ${s}s';
  }

  @override
  String deleteTimerLabel(int s) {
    return 'Löschen  ·  ${s}s';
  }

  @override
  String get newChat => 'Neuer Chat';

  @override
  String get newChatSubtitle => 'Einen neuen Favoritenchat erstellen';

  @override
  String get newFolder => 'Neuer Ordner';

  @override
  String get newFolderSubtitle => 'Chats in einem Ordner gruppieren';

  @override
  String get searchEmoji => 'Emoji suchen…';

  @override
  String get syncCompleted => 'Synchronisierung abgeschlossen';

  @override
  String get syncCompletedWithErrors =>
      'Synchronisierung mit Fehlern abgeschlossen';

  @override
  String get receivingFiles => 'Dateien werden empfangen...';

  @override
  String syncFromUser(String sender) {
    return 'von $sender';
  }

  @override
  String get aboutServer => 'SERVER';

  @override
  String get aboutWhatsNew => 'NEUERUNGEN';

  @override
  String get aboutConnected => 'Verbunden';

  @override
  String get aboutConnecting => 'Verbindung wird hergestellt...';

  @override
  String get aboutLoadingLocation => 'Lädt...';

  @override
  String get aboutNoReleaseNotes => 'Keine Versionshinweise verfügbar.';

  @override
  String get aboutCheckForUpdates => 'Nach Updates suchen';

  @override
  String get aboutChecking => 'Wird geprüft...';

  @override
  String get aboutUpToDate => 'Du bist auf dem neuesten Stand!';

  @override
  String aboutUpdateAvailable(String v) {
    return 'Update verfügbar: $v';
  }

  @override
  String get downloadUpdateTitle => 'Update herunterladen';

  @override
  String get downloadUpdateVersion => 'Version';

  @override
  String get downloadUpdateWhatsNew => 'NEUERUNGEN';

  @override
  String get downloadUpdateReady => 'Bereit zum Herunterladen';

  @override
  String get downloadUpdateDownloading => 'Wird heruntergeladen...';

  @override
  String get downloadUpdateComplete => 'Download abgeschlossen!';

  @override
  String get downloadUpdateNoPlatform =>
      'Für diese Plattform ist kein Download verfügbar';

  @override
  String get downloadUpdateInstall => 'Herunterladen & installieren';

  @override
  String get downloadUpdateOpen => 'Öffnen';

  @override
  String get downloadUpdateRetry => 'Erneut versuchen';

  @override
  String get downloadUpdateCancel => 'Download abbrechen';

  @override
  String get editChat => 'Chat bearbeiten';

  @override
  String get chatNameLabel => 'Chatname';

  @override
  String get editFolder => 'Ordner bearbeiten';

  @override
  String get folderNameLabel => 'Ordnername';

  @override
  String get createChat => 'Neuer Chat';

  @override
  String get profileMessage => 'Nachricht';

  @override
  String get tapAvatarHint => 'Zum Ändern tippen • Lang drücken zum Entfernen';

  @override
  String get tapAvatarLongRemove =>
      'Zum Ändern tippen • Lang drücken zum Entfernen';

  @override
  String get e2eeWarnTitle => 'Nicht Ende-zu-Ende-verschlüsselt';

  @override
  String get e2eeWarnUnderstand => 'Verstanden';

  @override
  String get e2eeWarnDoNotShare =>
      'Teile hier keine Passwörter, privaten Dateien oder sensiblen Informationen.';

  @override
  String get e2eeWarnGroupBody =>
      'Nachrichten in dieser Gruppe sind nicht durch Ende-zu-Ende-Verschlüsselung geschützt — der Server kann sie lesen.';

  @override
  String get e2eeWarnGroupMedia =>
      'Angehängte Medien werden auf einen öffentlichen Host (catbox.moe) hochgeladen und sind für jeden erreichbar, der den Link hat.';

  @override
  String get e2eeWarnExtBody =>
      'Nachrichten in dieser Gruppe sind nicht durch Ende-zu-Ende-Verschlüsselung geschützt — der Server des Gruppenbesitzers kann sie lesen.';

  @override
  String get e2eeWarnExtMedia =>
      'Angehängte Medien werden auf den eigenen Server des Besitzers hochgeladen und dort gespeichert, nicht auf ONYX.';

  @override
  String get e2eeWarnExtOnyxUnrelated =>
      'ONYX hat mit dieser Gruppe nichts zu tun und kann ihre Inhalte weder moderieren noch schützen.';

  @override
  String get securityLevelTitle => 'Gerätevertrauensstufe';

  @override
  String get securityLevelEasy => 'Einfach';

  @override
  String get securityLevelEasyDesc =>
      'Ein neues Gerät wird sofort nach der Anmeldung als vertrauenswürdig eingestuft. Geringster Aufwand, aber das Passwort ist deine einzige Verteidigungslinie.';

  @override
  String get securityLevelBalanced => 'Ausgewogen';

  @override
  String get securityLevelBalancedDesc =>
      'Jedes bereits vertrauenswürdige Gerät kann ein neues genehmigen. Für die meisten Personen empfohlen.';

  @override
  String get securityLevelStrict => 'Streng';

  @override
  String get securityLevelStrictDesc =>
      'Ein neues Gerät benötigt die Genehmigung von zwei separaten vertrauenswürdigen Geräten.';

  @override
  String get securityLevelLowerRequiresTrusted =>
      'Zum Herabsetzen der Sicherheitsstufe ist ein vertrauenswürdiges Gerät erforderlich.';

  @override
  String get securityLevelUpdated => 'Sicherheitsstufe aktualisiert';

  @override
  String get sessionTtlTitle => 'Sitzungsdauer';

  @override
  String get sessionTtlSubtitle =>
      'Wie lange, bevor dieses Gerät erneut nach deinem Passwort fragt';

  @override
  String get sessionTtlRecommended => 'empfohlen';

  @override
  String sessionTtlDays(int days) {
    return '$days Tage';
  }

  @override
  String get sessionTtlNever => 'Nie';

  @override
  String get sessionTtlUpdated => 'Sitzungsdauer aktualisiert';

  @override
  String get approvalsProgress => 'Genehmigt';

  @override
  String get pendingDeviceTitleSingle => 'Neues Gerät';

  @override
  String pendingDeviceTitleMulti(int count) {
    return 'Neue Geräte ($count)';
  }

  @override
  String get pendingDeviceApprove => 'Genehmigen';

  @override
  String get pendingDeviceDeny => 'Ablehnen';

  @override
  String get recoveryTitle => 'Kontowiederherstellung';

  @override
  String get recoveryBannerText =>
      'Dieses Gerät ist noch nicht genehmigt. Wenn kein vertrauenswürdiges Gerät erreichbar ist, kannst du mit deinem Passwort und deiner Wiederherstellungsphrase Zugriff wiederherstellen.';

  @override
  String get recoveryBannerButton => 'Zugriff wiederherstellen';

  @override
  String get recoveryIntro =>
      'Gib dein Passwort und die 12-Wort-Wiederherstellungsphrase ein, die dir bei der Registrierung angezeigt wurde. Die Anfrage tritt nicht sofort in Kraft — deine vertrauenswürdigen Geräte erhalten ein Zeitfenster, um sie abzubrechen, falls du es nicht bist.';

  @override
  String get recoveryPasswordLabel => 'Passwort';

  @override
  String get recoveryPassphraseLabel => 'Wiederherstellungsphrase (12 Wörter)';

  @override
  String get recoverySubmit => 'Anfrage senden';

  @override
  String get recoveryInvalid =>
      'Ungültiges Passwort oder ungültige Wiederherstellungsphrase';

  @override
  String get recoveryAlreadyPending =>
      'Es liegt bereits eine ausstehende Anfrage vor';

  @override
  String get recoveryPendingTitle => 'Anfrage gesendet';

  @override
  String recoveryPendingBody(String when) {
    return 'Der Zugriff wird $when wiederhergestellt, sofern kein vertrauenswürdiges Gerät die Anfrage abbricht.';
  }

  @override
  String get recoveryCancelled => 'Wiederherstellungsanfrage abgebrochen';

  @override
  String get recoveryExecuted =>
      'Zugriff wiederhergestellt. Bitte melde dich erneut an, um die Änderung zu übernehmen.';

  @override
  String get recoveryCancelRequiresTrusted =>
      'Nur ein vertrauenswürdiges Gerät kann dies abbrechen. Genehmige dieses Gerät zuerst unter Aktive Geräte.';

  @override
  String get recoveryAlertRequestedTitle =>
      'Jemand hat eine Kontowiederherstellung angefordert';

  @override
  String recoveryAlertRequestedBody(String deviceName, String when) {
    return 'Gerät \"$deviceName\" hat eine Kontowiederherstellung angefordert. Falls du das nicht warst, brich sie jetzt ab. Andernfalls tritt sie $when in Kraft.';
  }

  @override
  String get recoveryAlertCancelButton => 'Abbrechen';

  @override
  String get recoveryAlertIgnoreButton => 'Ich bin es, ignorieren';

  @override
  String get recoveryAlertFailedTitle =>
      'Fehlgeschlagener Wiederherstellungsversuch';

  @override
  String get recoveryAlertFailedBody =>
      'Jemand hat versucht, Zugriff auf dein Konto wiederherzustellen, aber ein falsches Passwort oder eine falsche Wiederherstellungsphrase eingegeben.';

  @override
  String get recoveryAlertExecutedTitle => 'Wiederherstellung abgeschlossen';

  @override
  String get recoveryAlertExecutedBody =>
      'Die Wiederherstellungsanfrage ist in Kraft getreten — das Konto hat ein neues Primärgerät. Falls du das nicht warst, widerrufe sofort die unbekannte Sitzung unter Aktive Geräte.';

  @override
  String get wardLinkSyncSettingsTitle => 'Sync-Einstellungen';

  @override
  String get wardLinkSyncSettingsSubtitle =>
      'Dateigrößenlimit und Blasenbenachrichtigungen';

  @override
  String get wardLinkPairedDevicesSubtitle =>
      'Gekoppelte Geräte hinzufügen und verwalten';

  @override
  String get notifGeneralTitle => 'Allgemein';

  @override
  String get notifGeneralSubtitle =>
      'Benachrichtigungen und Inhaltssichtbarkeit aktivieren';

  @override
  String get notifSoundSubtitle => 'Benachrichtigungston und Audiodatei';

  @override
  String get notifAdvancedTitle => 'Erweitert';

  @override
  String get notifAdvancedSubtitle => 'Startverhalten und Popup-Position';

  @override
  String get securityPrivacyTitle => 'Datenschutz';

  @override
  String get securityPrivacySubtitle => 'Sichtbarkeits- und Sucheinstellungen';

  @override
  String get cacheStorageTitle => 'Speicher';

  @override
  String get cacheStorageSubtitle =>
      'Medien-Cache und Bereinigung ungenutzter Dateien';

  @override
  String get connectionServerTitle => 'Serververbindung';

  @override
  String get connectionServerSubtitle =>
      'Mit dem WebSocket-Server verbinden oder die Verbindung trennen';

  @override
  String get interactPerformanceTitle => 'Leistung';

  @override
  String get interactPerformanceSubtitle =>
      'Scroll-Puffer und Bildvorlade-Fenster';

  @override
  String get interactFilesTitle => 'Dateien & Speicher';

  @override
  String get interactFilesSubtitle => 'Download-Ordner und App-Datenverwaltung';

  @override
  String get appearanceChatDisplayTitle => 'Chat-Anzeige';

  @override
  String get appearanceChatDisplaySubtitle =>
      'Ausrichtung, Avatare und Animationen';

  @override
  String get appearanceLayoutTitle => 'Layout';

  @override
  String get appearanceLayoutSubtitle => 'Navigation, Grafik und Tab-Wischen';

  @override
  String get appearanceLiquidGlassTitle => 'Liquid-Glass-Effekte';

  @override
  String get trashChatsTitle => 'Gelöschte Chats';

  @override
  String get trashChatsSubtitle =>
      'Chats wiederherstellen oder dauerhaft löschen';

  @override
  String get trashMessagesTitle => 'Gelöschte Nachrichten';

  @override
  String get trashMessagesSubtitle =>
      'Nachrichten wiederherstellen oder dauerhaft löschen';

  @override
  String get download => 'Herunterladen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get revoke => 'Widerrufen';

  @override
  String get setup => 'Einrichten';

  @override
  String get current => 'Aktuell';

  @override
  String get select => 'Auswählen';

  @override
  String get token => 'Token';

  @override
  String get always => 'Immer';

  @override
  String favRemoveFromFolderNamed(String folderName) {
    return 'Aus \"$folderName\" entfernen';
  }

  @override
  String get favMoveToFolder => 'In Ordner verschieben';

  @override
  String get favRemoveFromFolder => 'Aus Ordner entfernen';

  @override
  String get favUnlock => 'Entsperren';

  @override
  String get favLock => 'Sperren';

  @override
  String get favUnlockFolder => 'Ordner entsperren';

  @override
  String get favLockFolder => 'Ordner sperren';

  @override
  String favChatsCount(int n) {
    return '$n Chats';
  }

  @override
  String get favNewFolder => 'Neuer Ordner';

  @override
  String get favChatsMovedToTopLevel =>
      'Chats werden auf die oberste Ebene verschoben';

  @override
  String get favDeleteChatQuestion => 'Chat löschen?';

  @override
  String get favRemoveAvatarQuestion => 'Avatar entfernen?';

  @override
  String get favSelectedRemovedFromFavorites =>
      'Ausgewählte Nachrichten werden aus den Favoriten entfernt.';

  @override
  String get favDeleteMessageQuestion => 'Nachricht löschen?';

  @override
  String get favMessageRemovedFromFavorites =>
      'Diese Nachricht wird aus den Favoriten entfernt.';

  @override
  String get favDeleteAvatarQuestion => 'Avatar löschen?';

  @override
  String get favRemoveAvatarConfirm =>
      'Dadurch wird dieser Favoritenavatar entfernt.';

  @override
  String get sendAlbum => 'Album senden';

  @override
  String get sendAlbums => 'Alben senden';

  @override
  String get sendAllMedia => 'Alles senden';

  @override
  String get setAsWallpaper => 'Als Hintergrundbild festlegen';

  @override
  String get sendVoice => 'Sprachnachricht senden';

  @override
  String get cropAndUpload => 'Zuschneiden & hochladen';

  @override
  String get deleteMessagesQuestion => 'Nachrichten löschen?';

  @override
  String get connectionDiagnostics => 'Verbindungsdiagnose';

  @override
  String get voiceChannels => 'Sprachkanäle';

  @override
  String get forwardMessage => 'Nachricht weiterleiten';

  @override
  String get noChats => 'Keine Chats';

  @override
  String get noGroups => 'Keine Gruppen';

  @override
  String get noFavorites => 'Keine Favoriten';

  @override
  String get wifiOnlyOption => 'Nur Wi-Fi';

  @override
  String get emptyTrash => 'Papierkorb leeren';

  @override
  String get performanceReport => 'Leistungsbericht';

  @override
  String get revokeSessionQuestion => 'Sitzung widerrufen?';

  @override
  String get revokeSessionConfirm => 'Dieses Gerät wird sofort abgemeldet.';

  @override
  String get failedToRevokeSession => 'Sitzung konnte nicht widerrufen werden';

  @override
  String get failedToApproveDevice => 'Gerät konnte nicht genehmigt werden';

  @override
  String get noActiveSessionsFound => 'Keine aktiven Sitzungen gefunden';

  @override
  String get quotaExceeded => 'Kontingent überschritten';

  @override
  String get openSettingsAction => 'Einstellungen öffnen';

  @override
  String get trashIsEmpty => 'Papierkorb ist leer';

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
      other: ' $n Medien-Caches gelöscht',
      one: ' $n Medien-Cache gelöscht',
    );
    return '$_temp0';
  }

  @override
  String leaveGroupTitle(String isChannel) {
    String _temp0 = intl.Intl.selectLogic(
      isChannel,
      {
        'true': 'Kanal',
        'other': 'Gruppe',
      },
    );
    return '$_temp0 verlassen?';
  }

  @override
  String cacheFilesDeleted(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Dateien gelöscht',
      one: '$n Datei gelöscht',
    );
    return '$_temp0';
  }

  @override
  String orphanedCleanupDeleted(int files, String freedMb) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files ungenutzte Dateien gelöscht',
      one: '$files ungenutzte Datei gelöscht',
    );
    return '$_temp0 ($freedMb MB freigegeben)';
  }

  @override
  String deletedLogsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Protokolldateien gelöscht.',
      one: '$n Protokolldatei gelöscht.',
    );
    return '$_temp0';
  }

  @override
  String notifEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'Du wirst bei neuen Nachrichten benachrichtigt',
        'other': 'Alle Benachrichtigungen sind stummgeschaltet',
      },
    );
    return '$_temp0';
  }

  @override
  String notifHideContentSubtitle(String hidden) {
    String _temp0 = intl.Intl.selectLogic(
      hidden,
      {
        'true': 'Benachrichtigungen ohne Nachrichtentext',
        'other': 'Nachrichtentext in Benachrichtigungen anzeigen',
      },
    );
    return '$_temp0';
  }

  @override
  String notifSoundEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'Ton aktiviert',
        'other': 'Ton deaktiviert',
      },
    );
    return '$_temp0';
  }

  @override
  String sessionExpiresInDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Sitzung läuft in $n Tagen ab',
      one: 'Sitzung läuft in $n Tag ab',
    );
    return '$_temp0';
  }

  @override
  String sessionExpiresInHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Sitzung läuft in $n Stunden ab',
      one: 'Sitzung läuft in $n Stunde ab',
    );
    return '$_temp0';
  }

  @override
  String sessionActiveForDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Sitzung noch $n weitere Tage gültig',
      one: 'Sitzung noch $n weiteren Tag gültig',
    );
    return '$_temp0';
  }

  @override
  String meshRadarFound(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Geräte in Reichweite',
      one: '$n Gerät in Reichweite',
    );
    return '$_temp0';
  }

  @override
  String trashSummary(int chats, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats Chats',
      one: '$chats Chat',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '$messages Nachrichten',
      one: '$messages Nachricht',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get muteAction => 'Stummschalten';

  @override
  String get unmuteAction => 'Stummschaltung aufheben';

  @override
  String muteUserTitle(String name) {
    return '$name stummschalten';
  }

  @override
  String get durationLabel => 'Dauer';

  @override
  String get duration15Min => '15 Min.';

  @override
  String get duration1Hour => '1 Stunde';

  @override
  String get duration1Day => '1 Tag';

  @override
  String get duration1Week => '1 Woche';

  @override
  String get muteReasonLabel => 'Grund (optional)';

  @override
  String userMuted(String name) {
    return '$name stummgeschaltet';
  }

  @override
  String get failedMute => 'Stummschalten fehlgeschlagen';

  @override
  String failedMuteUser(String name) {
    return 'Stummschalten von $name fehlgeschlagen';
  }

  @override
  String get mutedUsersTitle => 'Stummgeschaltete Nutzer';

  @override
  String get noMutedUsers => 'Keine stummgeschalteten Nutzer';

  @override
  String mutedByLabel(String name) {
    return 'Stummgeschaltet von: $name';
  }

  @override
  String mutedUntilLabel(String date) {
    return 'Bis: $date';
  }

  @override
  String userUnmuted(String name) {
    return 'Stummschaltung von $name aufgehoben';
  }

  @override
  String get failedUnmute => 'Aufheben der Stummschaltung fehlgeschlagen';

  @override
  String failedUnmuteUser(String name) {
    return 'Aufheben der Stummschaltung von $name fehlgeschlagen';
  }

  @override
  String get youAreMutedTitle => 'Du bist stummgeschaltet';

  @override
  String mutedUntilMessage(String date) {
    return 'Du kannst in diesem Chat bis $date keine Nachrichten senden.';
  }

  @override
  String get slowModeLabel => 'Slow-Modus (Sekunden, 0 = aus)';

  @override
  String get slowModeHelper =>
      'Mindestabstand zwischen Nachrichten für normale Mitglieder. Gilt nicht für Admins.';

  @override
  String slowModeSetTo(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Slow-Modus auf $seconds Sekunden eingestellt',
      one: 'Slow-Modus auf $seconds Sekunde eingestellt',
    );
    return '$_temp0';
  }

  @override
  String get slowModeDisabled => 'Slow-Modus deaktiviert';

  @override
  String get failedSetSlowMode => 'Aktivieren des Slow-Modus fehlgeschlagen';

  @override
  String get failedUpdateSlowMode =>
      'Aktualisieren des Slow-Modus fehlgeschlagen';

  @override
  String get donateMenuLabel => 'Spenden';

  @override
  String get pollsMenuLabel => 'Umfragen';

  @override
  String get supportThisCommunityTitle => 'Diese Community unterstützen';

  @override
  String get donationDisclaimer =>
      'ONYX verarbeitet diese Zahlungen nicht und kann sie nicht zurückerstatten. Sende Krypto nur an Adressen, denen du vertraust.';

  @override
  String get noDonationsOwnerHint =>
      'Noch keine Spendenadressen. Tippe auf „Bearbeiten“, um welche hinzuzufügen.';

  @override
  String get noDonationsMemberHint =>
      'Diese Community hat noch keine Spenden eingerichtet.';

  @override
  String get editDonationsTitle => 'Spendenadressen bearbeiten';

  @override
  String get donationCoinLabel => 'Coin (z. B. BTC)';

  @override
  String get donationAddressLabel => 'Adresse';

  @override
  String get addDonationAddress => 'Adresse hinzufügen';

  @override
  String get donationsSaved => 'Spendenadressen gespeichert';

  @override
  String get failedSaveDonations =>
      'Speichern der Spendenadressen fehlgeschlagen';

  @override
  String get noPollsOwnerHint =>
      'Noch keine Umfragen. Tippe auf „Neue Umfrage“, um eine zu erstellen.';

  @override
  String get noPollsHint => 'Noch keine Umfragen.';

  @override
  String get newPollAction => 'Neue Umfrage';

  @override
  String get addPollOption => 'Option hinzufügen';

  @override
  String get pollQuestionLabel => 'Frage';

  @override
  String pollOptionLabel(int number) {
    return 'Option $number';
  }

  @override
  String get multipleChoiceLabel => 'Mehrfachauswahl';

  @override
  String get pollQuestionEmpty => 'Frage darf nicht leer sein';

  @override
  String get pollNeedsTwoOptions => 'Füge mindestens 2 Optionen hinzu';

  @override
  String get failedCreatePoll => 'Erstellen der Umfrage fehlgeschlagen';

  @override
  String get failedVote => 'Abstimmung konnte nicht gesendet werden';

  @override
  String pollVoteCountAnonymous(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stimmen',
      one: '$count Stimme',
    );
    return '$_temp0 • anonym';
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
