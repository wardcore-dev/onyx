// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navChats => 'Chats';

  @override
  String get navGroups => 'Groups';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navSettings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get clear => 'Clear';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get test => 'Test';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get supportOnyx => 'Support ONYX';

  @override
  String get securityTitle => 'Security & Privacy';

  @override
  String get securitySubtitle => 'Tap to view tips and encryption details';

  @override
  String get tipOfTheDay => 'Tip of the day';

  @override
  String get statusSettings => 'Status Settings';

  @override
  String get showDisplayNameInGroups => 'Show my display name in groups';

  @override
  String get showDisplayNameSubtitle =>
      'When off, your messages appear as \"Anonymous\"';

  @override
  String get pinLock => 'PIN Lock';

  @override
  String get enablePinLock => 'Enable PIN Lock';

  @override
  String get enablePinSubtitle =>
      'Require a 4-digit PIN to unlock the app on launch';

  @override
  String get pinLockEnabled => ' PIN Lock enabled';

  @override
  String get pinLockDisabled => 'PIN Lock disabled';

  @override
  String get useBiometrics => 'Use Biometrics';

  @override
  String get useBiometricsSubtitle =>
      'Unlock with fingerprint or face recognition';

  @override
  String get biometricsUnavailable => 'Biometrics not available on this device';

  @override
  String get lockOnResume => 'Lock when backgrounded';

  @override
  String get lockOnResumeSubtitle =>
      'Require PIN every time the app returns to foreground';

  @override
  String get pinScreenSetTitle => 'Set PIN';

  @override
  String get pinScreenConfirmTitle => 'Confirm PIN';

  @override
  String get pinScreenEnterTitle => 'Enter PIN';

  @override
  String get pinScreenChooseSubtitle => 'Choose a 4-digit PIN';

  @override
  String get pinScreenChooseChatSubtitle =>
      'Choose a 4-digit PIN for this chat';

  @override
  String get pinScreenReenterSubtitle => 'Re-enter your PIN to confirm';

  @override
  String get pinScreenUnlockSubtitle => 'Enter your 4-digit PIN to unlock';

  @override
  String get pinScreenGenericSubtitle => 'Enter your 4-digit PIN';

  @override
  String get pinScreenDisableHeader => 'Enter current PIN to disable';

  @override
  String get pinScreenMismatchError => 'PINs do not match. Try again.';

  @override
  String get pinScreenIncorrectError => 'Incorrect PIN';

  @override
  String get searchChatsHint => 'Search chats and messages…';

  @override
  String get searchGroupsHint => 'Search groups and messages…';

  @override
  String get searchFavoritesHint => 'Search favorites…';

  @override
  String get searchSettingsHint => 'Search settings…';

  @override
  String get keyMgmtTitle => 'Key Management';

  @override
  String get keyMgmtSubtitle => 'Rotate or reset your encryption identity';

  @override
  String get keyMgmtDescription =>
      'Rotate your E2EE identity key if you suspect it was compromised. Contacts receive the new key automatically.';

  @override
  String get rotateE2eeKey => 'Rotate E2EE Key';

  @override
  String get rotateE2eeKeyPrimaryOnly =>
      'Rotate E2EE Key (primary device only)';

  @override
  String get rotateKeyDialogTitle => 'Rotate encryption key?';

  @override
  String get rotateKeyDialogContent =>
      'A new X25519 keypair will be generated and uploaded to the server.nnYour session and message history are NOT affected. Contacts will automatically use the new key on their next message.';

  @override
  String get rotateKeyBtn => 'Rotate';

  @override
  String get rotatingKey => ' Rotating key…';

  @override
  String get keyRotated => ' E2EE key rotated and uploaded';

  @override
  String get keyRotationFailed => ' Key rotation failed';

  @override
  String get activeDevices => 'Active Devices';

  @override
  String get activeDevicesSubtitle => 'Devices, password and encryption key';

  @override
  String get activeDevicesPrimaryOnly => 'Active Devices (primary device only)';

  @override
  String get changePassword => 'Change Password';

  @override
  String get changePasswordPrimaryOnly =>
      'Change Password (primary device only)';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle => 'Manage alerts and delivery options';

  @override
  String get notificationsEnabled => 'Enable Notifications';

  @override
  String get notificationsEnabledSubtitle =>
      'Show system notifications for new messages';

  @override
  String get notificationPosition => 'Notification Position';

  @override
  String get notifPosTopLeft => 'Top Left';

  @override
  String get notifPosTopRight => 'Top Right';

  @override
  String get notifPosBottomLeft => 'Bottom Left';

  @override
  String get notifPosBottomRight => 'Bottom Right';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceSubtitle => 'Choose theme and dark mode';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get fontAndTextSize => 'Font & Text Size';

  @override
  String get fontFamily => 'Font Family';

  @override
  String get messageSize => 'Message Size';

  @override
  String get fontPreviewMessage => 'Example';

  @override
  String get ownMessagesRight => 'Own messages: Right';

  @override
  String get ownMessagesLeft => 'Own messages: Left';

  @override
  String get alignAllRight => 'Align all messages right';

  @override
  String get alignAllRightSubtitle =>
      'All messages aligned to the right side like a mirror';

  @override
  String get showAvatarInChats => 'Show avatar in chats list';

  @override
  String get showAccountIndicator => 'Show current account';

  @override
  String get showAccountIndicatorSubtitle =>
      'Display name and username in the app corner';

  @override
  String get showAvatarSubtitle => 'Show contact avatar in chat list';

  @override
  String get chatBackground => 'Chat Background';

  @override
  String get chatBgSubtitle => 'Set an image as chat background';

  @override
  String get chooseImage => 'Choose Image';

  @override
  String get clearBackground => 'Clear Background';

  @override
  String get applyGlobally => 'Apply globally';

  @override
  String get applyGloballySubtitle => 'Use this background in all chats';

  @override
  String get blurBackground => 'Blur background';

  @override
  String get elementOpacity => 'Element Opacity';

  @override
  String get elementBrightness => 'Element Brightness';

  @override
  String get uiLayout => 'UI Layout';

  @override
  String get navBarPosition => 'Navigation Bar Position';

  @override
  String get navLeft => 'Left';

  @override
  String get navBottom => 'Bottom';

  @override
  String get inputBarMaxWidth => 'Input Bar Width';

  @override
  String get minimizeBottomNav => 'Minimize Bottom Nav';

  @override
  String get minimizeBottomNavSubtitle =>
      'Hide labels in bottom navigation bar';

  @override
  String get swipeTabs => 'Swipe between tabs';

  @override
  String get swipeTabsSubtitle => 'Switch tabs with horizontal swipe gesture';

  @override
  String get smoothScroll => 'Smooth Scrolling';

  @override
  String get performanceOptimizations => 'Performance Optimizations';

  @override
  String get macOsWindowStyle => 'Window Style';

  @override
  String get macOsWindowStyleSubtitle => 'Window controls style';

  @override
  String get macOsNativeTitleBar => 'Native macOS (traffic lights)';

  @override
  String get macOsCustomTitleBar => 'Windows-style (right side)';

  @override
  String get updateAvailableLabel => 'Update available';

  @override
  String get updateDownload => 'Download';

  @override
  String get cacheTitle => 'Cache';

  @override
  String get cacheSubtitle => 'Manage local & server media cache';

  @override
  String get mediaCacheSize => 'Media messages cache: ';

  @override
  String get clearLocalCache => 'Clear Local Cache';

  @override
  String get clearLocalCacheTitle => 'Clear local cache';

  @override
  String get clearLocalCacheContent =>
      'Are you sure you want to delete all cached media (voice, images, videos)?nThis does NOT affect server uploads or chat history.';

  @override
  String get clearAll => 'Clear All';

  @override
  String get serverMediaCache => 'Server Media Cache';

  @override
  String get serverMediaCacheSubtitle =>
      'Stored on server: images, voice, video.';

  @override
  String get clearServerCache => 'Clear Server Cache';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get dangerZoneSubtitle =>
      'Delete account from server and/or wipe local data.';

  @override
  String get factoryReset => 'Factory Reset';

  @override
  String get factoryResetHint =>
      'Select what to reset. At least one option must be chosen.';

  @override
  String get resetDeleteAccount => 'Delete account from server';

  @override
  String resetDeleteAccountSubtitle(String username) {
    return 'Permanently deletes @$username — all messages, media and keys from the server.';
  }

  @override
  String get resetNoAccount => 'No account is logged in.';

  @override
  String get resetDeleteLocal => 'Delete local app data';

  @override
  String get resetDeleteLocalSubtitle =>
      'Wipes all local chats, keys, settings, cache and media.';

  @override
  String get reset => 'Reset';

  @override
  String get resetFailed => 'Reset failed';

  @override
  String get resetConfirmStep1Title => 'Are you sure you want to do this?';

  @override
  String get resetConfirmStep1Message =>
      'This will permanently delete the data you selected. This cannot be undone.';

  @override
  String get resetConfirmStep2Title => 'Are you sure?';

  @override
  String get resetConfirmStep2Message =>
      'This is your last chance to cancel. Confirming starts the reset immediately.';

  @override
  String get connectionTitle => 'Connection';

  @override
  String get connectionSubtitle => 'WebSocket status & controls';

  @override
  String get proxyTitle => 'Proxy';

  @override
  String get proxySubtitle => 'Route traffic through HTTP or SOCKS5 proxy';

  @override
  String get enableProxy => 'Enable Proxy';

  @override
  String get proxyType => 'Proxy Type';

  @override
  String get proxyHost => 'Host';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxyUsername => 'Username';

  @override
  String get proxyPassword => 'Password';

  @override
  String get testProxy => 'Test Proxy';

  @override
  String get proxyTesting => 'Testing...';

  @override
  String get proxyOk => ' Proxy OK';

  @override
  String get proxyFailed => ' Proxy unreachable';

  @override
  String get useProxy => 'Use proxy';

  @override
  String get proxyDirectConnection => 'Direct connection';

  @override
  String get proxyRouted => 'Traffic routed through proxy';

  @override
  String get proxyConnectedStatus => 'Connected';

  @override
  String get proxyNotConnectedStatus => 'Not connected';

  @override
  String get proxyLoginOptional => 'Login (optional)';

  @override
  String get proxyPasswordOptional => 'Password (optional)';

  @override
  String get proxyApplyReconnect => 'Apply & Reconnect';

  @override
  String get appDataTitle => 'ONYX data folder';

  @override
  String get appDataSubtitle => 'Move the app data folder to another drive';

  @override
  String get appDataCurrentPath => 'Current folder';

  @override
  String get appDataDefault => 'Default (system folder)';

  @override
  String get appDataMove => 'Move…';

  @override
  String get appDataReset => 'Reset';

  @override
  String get appDataMigrating => 'Moving data…';

  @override
  String get appDataMigrateError => 'Error during move';

  @override
  String get appDataRestartRequired =>
      'Folder changed. Restart ONYX for the change to take effect.';

  @override
  String get appDataRestart => 'Restart ONYX';

  @override
  String get appDataOpenFolder => 'Open folder';

  @override
  String get appDataDeleteOldFolder => 'Delete previous folder';

  @override
  String get appDataDeleteOldFolderSubtitle =>
      'Delete the original system data folder left after migration';

  @override
  String get appDataDeleteOldFolderConfirm =>
      'Delete the original ONYX data folder?nnThis cannot be undone. Make sure data was migrated successfully.';

  @override
  String get appDataDeleteOldFolderSuccess => 'Previous folder deleted';

  @override
  String get appDataDeleteOldFolderError => 'Error deleting: ';

  @override
  String get interactTitle => 'Interaction';

  @override
  String get interactSubtitle => 'File upload confirmations';

  @override
  String get confirmFileUpload => 'Confirm File Upload';

  @override
  String get confirmFileUploadSubtitle =>
      'Show confirmation dialog before sending files';

  @override
  String get confirmVoiceMessage => 'Confirm Voice Message';

  @override
  String get confirmVoiceSubtitle =>
      'Show confirmation dialog before sending voice';

  @override
  String get downloadFolder => 'Download folder';

  @override
  String get downloadFolderSubtitle =>
      'Where to save received files (default: Downloads/ONYX)';

  @override
  String get downloadFolderDefault => 'Default (Downloads/ONYX)';

  @override
  String get downloadFolderChange => 'Choose folder';

  @override
  String get downloadFolderReset => 'Reset';

  @override
  String get contactTitle => 'Contact';

  @override
  String get contactSubtitle => 'Website, repository & feedback';

  @override
  String get contactWebsite => 'Official website';

  @override
  String get contactRepository => 'Source code (client)';

  @override
  String get contactRepositoryServer => 'Source code (self-hosted server)';

  @override
  String get contactEmail => 'Contact us';

  @override
  String get debugTitle => 'Debug/Logs';

  @override
  String get debugSubtitle => 'Real-time performance & logging';

  @override
  String get debugMode => 'Debug Mode';

  @override
  String get debugModeSubtitle => 'Enable performance monitoring & logs';

  @override
  String get enableFileLogging => 'Enable File Logging';

  @override
  String get enableFileLoggingSubtitle =>
      'Write app logs to disk (disable for privacy)';

  @override
  String get deleteAllLogs => 'Delete All Logs';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'App interface language';

  @override
  String get languageChanged => 'Language changed';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get deleteChatTitle => 'Delete chat?';

  @override
  String get blockUserLabel => 'Block user';

  @override
  String get unblockUserLabel => 'Unblock';

  @override
  String get muteUserLabel => 'Mute notifications';

  @override
  String get unmuteUserLabel => 'Unmute notifications';

  @override
  String get blockedByUserMessage =>
      'This user has restricted incoming messages from you.';

  @override
  String unblockUserConfirmContent(String name) {
    return 'Unblock $name?';
  }

  @override
  String blockUserConfirmContent(String name) {
    return 'Block $name? They won\'t be able to send you messages.';
  }

  @override
  String deleteChatContent(String name) {
    return 'Are you sure you want to delete the chat with \"$name\"? This action cannot be undone.';
  }

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get displayName => 'Display Name';

  @override
  String get addAccount => 'Add Account';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String get welcomeTagline => 'Secure end-to-end encrypted messenger';

  @override
  String get otherAccounts => 'Other Accounts';

  @override
  String get tapToSwitch => 'Tap to switch';

  @override
  String get deleteFromRecentTitle => 'Delete account from recent?';

  @override
  String get authUsernameLabel => 'Username (3-16 chars)';

  @override
  String get authPasswordLabel => 'Password (min 16 chars)';

  @override
  String get loginBtn => 'Login';

  @override
  String get registerBtn => 'Register';

  @override
  String get deviceAuthTitle => 'Link Device';

  @override
  String get deviceAuthTabScan => 'Scan';

  @override
  String get deviceAuthTapToScan => 'Tap to scan QR code';

  @override
  String get deviceAuthLanNote =>
      'Both devices must be on the same local network';

  @override
  String get loginWithQr => 'Login via QR';

  @override
  String get qrAuthWaitingTitle => 'Waiting for phone';

  @override
  String get qrAuthWaitingSubtitle =>
      'Scan this code on an authorized device to transfer the session here';

  @override
  String get qrAuthSuccess => 'Device authorized';

  @override
  String get qrAuthFailed => 'QR auth failed';

  @override
  String get qrAuthCancelled => 'QR auth cancelled';

  @override
  String get authorizeDevice => 'Authorize device';

  @override
  String get authorizeDeviceSubtitle =>
      'Allow another device to log in by scanning a QR code';

  @override
  String get authorizeDeviceScanHint =>
      'Point the camera at the QR code shown on the other device';

  @override
  String get authorizeDeviceSuccess => 'Device authorized successfully';

  @override
  String get authorizeDeviceFailed => 'Failed to authorize device';

  @override
  String get authorizeDeviceSending => 'Sending credentials…';

  @override
  String get qrAuthEncryptedNote =>
      'Transfer is encrypted (X25519 + AES-256-GCM)';

  @override
  String get scanFromPc => 'Receive from PC';

  @override
  String get scanFromPcHint =>
      'Point the camera at the QR code shown on another device to sign in here';

  @override
  String get grantDeviceTitle => 'Authorize phone';

  @override
  String get grantDeviceSubtitle =>
      'Scan this code on another device to sign in there with this account';

  @override
  String get grantDeviceSuccess => 'Phone authorized successfully';

  @override
  String get grantDeviceFailed => 'Failed to authorize phone';

  @override
  String get enterUsernameMsg => 'Enter your username';

  @override
  String get loginSuccess => 'Login successful';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get registeringMsg => 'Registering...';

  @override
  String get registrationFailed => ' Registration failed';

  @override
  String get usernameInvalidMsg =>
      'Username: 3-16 chars, only letters, digits, _ . -';

  @override
  String get passwordTooShortMsg => 'Password too short (min 16)';

  @override
  String get generatePasswordTooltip => 'Generate strong password';

  @override
  String get savePasswordWarning =>
      'Make sure to save your password in a safe place — write it down. Recovery without a password is impossible.';

  @override
  String get passphraseWriteDown =>
      'This passphrase will never be shown again. Write down these 12 words by hand and keep them somewhere safe — you\'ll need them to recover your account if you forget your password.';

  @override
  String get passphraseWriteOnPaper =>
      'Write your passphrase on paper right now — there will be no second chance!';

  @override
  String get copyToClipboard => 'Copy to clipboard';

  @override
  String get copiedToClipboard => 'Copied!';

  @override
  String passphraseCountdown(int s) {
    return 'Please read carefully — available in $s s...';
  }

  @override
  String get iSavedIt => 'I\'ve saved it';

  @override
  String deleteFromRecentContent(String acc) {
    return 'Are you sure you want to remove \"$acc\" from the recent list?nThis does not delete the account from the server.';
  }

  @override
  String get createGroupChannel => 'Create Group/Channel';

  @override
  String get channelAdminOnly => 'Channel (only admin posts)';

  @override
  String get viewByToken => 'View by token';

  @override
  String get viewByIp => 'View by IP (external server)';

  @override
  String get createGroupOrChannel => 'Create group or channel';

  @override
  String get removeExternalServerTitle => 'Remove external server?';

  @override
  String removeExternalServerContent(String name) {
    return 'Remove \"$name\" and all its groups from your list? You can rejoin later by entering the server address again.';
  }

  @override
  String get noGroupsYet => 'No groups yet';

  @override
  String get groupNameLabel => 'Group name:';

  @override
  String get groupNameHint => 'Enter name';

  @override
  String get pasteToken => 'Paste token:';

  @override
  String get create => 'Create';

  @override
  String get view => 'View';

  @override
  String get leave => 'Leave';

  @override
  String get remove => 'Remove';

  @override
  String get leaveGroupAction => 'Leave';

  @override
  String leaveGroupContent(String name) {
    return 'Are you sure you want to leave \"$name\"? You will no longer receive messages from it.';
  }

  @override
  String get chooseCrypto => 'Choose a crypto to donate';

  @override
  String get addressCopied => 'address copied';

  @override
  String get hideFromSearch => 'Hide me from search';

  @override
  String get hideFromSearchSubtitle =>
      'Others won\'t find you by username search';

  @override
  String get hideFromSearchSavedOk => ' Privacy settings saved';

  @override
  String get hideFromSearchSavedFail => ' Saved locally, failed to sync';

  @override
  String get statusVisibility => 'Visibility';

  @override
  String get statusShowStatus => 'Show Status';

  @override
  String get statusHideStatus => 'Hide Status';

  @override
  String get statusCustomText => 'Custom Status Text';

  @override
  String get statusWhenOnline => 'When Online';

  @override
  String get statusWhenOffline => 'When Offline';

  @override
  String get statusSavedOk => ' Status settings saved and synced';

  @override
  String get statusSavedFail => ' Saved locally, failed to sync to server';

  @override
  String get clearServerCacheTitle => 'Clear server media?';

  @override
  String get clearServerCacheContent =>
      'This will delete ALL your uploaded media from the server, including:n\'\n        \'• Voice messagesn\'\n        \'• Imagesn\'\n        \'• Videosn\'\n        \'• Filesn\'\n        \'• Avatarnn\'\n        \'Local cache will remain. This action cannot be undone.';

  @override
  String get serverMediaCleared => ' All server media cleared';

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get serverMediaManagerTitle => 'Server Media';

  @override
  String get cacheTabImages => 'Images';

  @override
  String get cacheTabVoice => 'Voice';

  @override
  String get cacheTabAudio => 'Audio';

  @override
  String get cacheTabVideo => 'Video';

  @override
  String get cacheTabFiles => 'Files';

  @override
  String get cacheTabDocuments => 'Documents';

  @override
  String get cacheTabArchives => 'Archives';

  @override
  String get cacheTabData => 'Data';

  @override
  String get cacheTabAvatars => 'Avatars';

  @override
  String get cacheNoFiles => 'No files in this category';

  @override
  String get cacheClearTabTitle => 'Clear category?';

  @override
  String cacheClearTabContent(String typeName) {
    return 'Delete all files in \"$typeName\"? This cannot be undone.';
  }

  @override
  String get cacheFileDeleteFailed => 'Failed to delete file';

  @override
  String get cacheClearAll => 'Clear All';

  @override
  String get cacheClearTab => 'Clear tab';

  @override
  String get cleanUnusedFiles => 'Clean unused files';

  @override
  String get cleaningUnusedFiles => 'Cleaning...';

  @override
  String get orphanedCleanupAppNotReady => 'App not ready';

  @override
  String get orphanedCleanupNoFiles => 'No unused files found';

  @override
  String get manageCacheTitle => 'Manage Cache';

  @override
  String get manageCacheButton => 'Manage Media Cache';

  @override
  String get localCacheTab => 'Local';

  @override
  String get serverCacheTab => 'Server';

  @override
  String get cacheSelectAll => 'Select all';

  @override
  String get cacheDeselectAll => 'Deselect all';

  @override
  String get cacheSelected => 'selected';

  @override
  String get clearLocalCacheDialogTitle => 'Clear local cache';

  @override
  String get clearLocalCacheDialogContent =>
      'Are you sure you want to delete all cached media (voice, images, videos)?nThis does NOT affect server uploads or chat history.';

  @override
  String get deleteAllLogsTitle => 'Delete all logs?';

  @override
  String get deleteAllLogsContent =>
      'This will permanently delete all app log files from disk.\nThis action cannot be undone.';

  @override
  String get noLogsFound => 'No log files found.';

  @override
  String get changePasswordInfo =>
      'Enter your recovery passphrase and current password to set a new password.';

  @override
  String get changePasswordPassphraseLabel => 'Recovery passphrase (12 words)';

  @override
  String get changePasswordCurrentLabel => 'Current password';

  @override
  String get changePasswordNewLabel => 'New password (min 16 chars)';

  @override
  String get changePasswordChange => 'Change';

  @override
  String get changePasswordFieldsRequired => 'All fields are required';

  @override
  String get changePasswordTooShort =>
      'New password must be at least 16 characters';

  @override
  String get changePasswordChanging => 'Changing password...';

  @override
  String get changePasswordSuccess => ' Password changed successfully';

  @override
  String get clearBgTitle => 'Clear background?';

  @override
  String get clearBgContent =>
      'Remove custom chat background and restore default.';

  @override
  String get chatBgSet => ' Chat background set';

  @override
  String get chatBgCleared => 'Background cleared';

  @override
  String get sendAsCodeTitle => 'Send as code?';

  @override
  String get sendAsCodeContent =>
      'This message looks like code. Send it as a formatted code block?';

  @override
  String get sendAsCode => 'Send as code';

  @override
  String get sendAsPlainText => 'Send as text';

  @override
  String get allMessagesLeft => 'All messages: Left';

  @override
  String get allMessagesRight2 => 'All messages: Right';

  @override
  String get allMessagesMixed => 'All messages: Mixed';

  @override
  String get applyBackgroundToApp => 'Apply background to whole app';

  @override
  String get uiElementsOpacityLabel => 'UI Elements Opacity';

  @override
  String get uiElementsBrightnessLabel => 'UI Elements Brightness';

  @override
  String get navPanelPosition => 'Navigation Panel Position';

  @override
  String get navPosBottom => 'Bottom (under chat list)';

  @override
  String get navPosLeft => 'Left (sidebar)';

  @override
  String get tabSwiping => 'Tab Swiping';

  @override
  String get tabSwipingSubtitle => 'Swipe between tabs with a bounce effect';

  @override
  String get showAvatarsInChats => 'Show avatars in chats';

  @override
  String get smoothScrollDown => 'Smooth scroll down';

  @override
  String get messageAnimations => 'Message animations';

  @override
  String get chatListMoveAnimations => 'Chat list move animations';

  @override
  String get scrollDownButtonPosition => 'Scroll-down button position';

  @override
  String get scrollDownButtonPositionLeft => 'Left';

  @override
  String get scrollDownButtonPositionCenter => 'Center';

  @override
  String get scrollDownButtonPositionRight => 'Right';

  @override
  String get scrollDownButtonSize => 'Scroll-down button size';

  @override
  String get loadOlderMessagesOnScroll => 'Load older messages on scroll';

  @override
  String get showSnackbars => 'Show snackbars';

  @override
  String get autoLoadVideos => 'Auto-load videos';

  @override
  String get autoLoadVideosSubtitle =>
      'When off, videos load only on tap — smoother scrolling';

  @override
  String get tapToLoadVideo => 'Tap to load video';

  @override
  String get chooseBackground => 'Choose';

  @override
  String get presetsBackground => 'Presets';

  @override
  String get clearBackground2 => 'Clear';

  @override
  String get liquidGlassSubtitle =>
      'Configure glass effects and quality per element';

  @override
  String get liquidGlassNavBarLabel => 'Navigation Bar';

  @override
  String get liquidGlassNavBarDesc =>
      'Glass effect on the bottom navigation bar';

  @override
  String get liquidGlassCardsLabel => 'Cards & List Items';

  @override
  String get liquidGlassCardsDesc =>
      'Glass effect on chat list and settings cards';

  @override
  String get liquidGlassInputLabel => 'Input Bar';

  @override
  String get liquidGlassInputDesc =>
      'Glass effect on the message composition bar';

  @override
  String get liquidGlassSearchLabel => 'Search';

  @override
  String get liquidGlassSearchDesc =>
      'Spotlight-style glass panel for user search';

  @override
  String get liquidGlassAppBarLabel => 'App Bar Buttons';

  @override
  String get liquidGlassAppBarDesc =>
      'Glass effect on the chat app bar\'s icon buttons';

  @override
  String get sendFavoritesScanHint =>
      'Point the camera at the QR code shown on the receiver device';

  @override
  String get mediaPickerGallery => 'Gallery';

  @override
  String get mediaPickerCamera => 'Camera';

  @override
  String get mediaPickerFile => 'File';

  @override
  String mediaPickerSend(int n) {
    return 'Send $n';
  }

  @override
  String get mediaPickerChooseWallpaper => 'Choose wallpaper';

  @override
  String get mediaPickerFiles => 'Files';

  @override
  String get mediaPickerDeniedTitle => 'Gallery access denied';

  @override
  String get mediaPickerDeniedBody =>
      'Allow access in settings or pick a file directly.';

  @override
  String get mediaPickerPickFile => 'Pick File';

  @override
  String get mediaPickerOpenSettings => 'Open Settings';

  @override
  String get notifWarning =>
      'Notifications are delivered only while the app is running. To never miss a message, keep ONYX minimised to the system tray instead of closing it.';

  @override
  String get backgroundServiceTitle => 'Background service';

  @override
  String get backgroundServiceSubtitle => 'Keep ONYX connected while minimised';

  @override
  String get backgroundServiceEnableLabel => 'Keep running in background';

  @override
  String get backgroundServiceEnableSubtitle =>
      'Shows an ongoing notification so the OS doesn\'t stop ONYX from receiving messages while minimised';

  @override
  String get backgroundServiceTextLabel => 'Notification text';

  @override
  String get backgroundServiceDefaultText => 'Waiting for messages';

  @override
  String get notifPopupPosition => 'Popup position';

  @override
  String get notifPopupPositionSubtitle =>
      'Choose where the notification popup appears on screen';

  @override
  String get notifEnableLabel => 'Enable notifications';

  @override
  String get notifHideContentLabel => 'Hide message content';

  @override
  String get notifSoundEnableLabel => 'Notification sound';

  @override
  String get notifSoundChooseLabel => 'Choose sound';

  @override
  String get notifSoundCustom => 'Upload custom sound...';

  @override
  String get notifSoundCustomLoaded => 'Custom sound set';

  @override
  String get notifSoundCustomError => 'Failed to load sound';

  @override
  String get notifSoundCustomInvalidFormat =>
      'Supported: WAV, MP3, M4A, OGG, AAC';

  @override
  String get resetting => 'Resetting...';

  @override
  String get launchAtStartupLabel => 'Launch at startup';

  @override
  String get launchAtStartupSubtitle =>
      'Automatically start ONYX when you log in';

  @override
  String get launchAtStartupEnabled => 'Launch at startup enabled';

  @override
  String get launchAtStartupDisabled => 'Launch at startup disabled';

  @override
  String get launchAtStartupFailed => 'Failed to change startup setting';

  @override
  String get avatarUpdated => 'Avatar updated';

  @override
  String get fileNotFound => 'File not found';

  @override
  String get fileSent => 'File sent';

  @override
  String get imageSent => 'Image sent';

  @override
  String get videoSent => 'Video sent';

  @override
  String uploadingFile(String name) {
    return 'Uploading $name...';
  }

  @override
  String albumSent(int n) {
    return 'Album sent ($n images)';
  }

  @override
  String get fileEmpty => 'File is empty';

  @override
  String get networkError => 'Network error';

  @override
  String get avatarRemoved => 'Avatar removed';

  @override
  String get uinCopied => 'UIN copied';

  @override
  String get displayNameLength => 'Display name must be 1–16 characters';

  @override
  String get failedSendLan => 'Failed to send via LAN';

  @override
  String get fileCancelled => 'File cancelled';

  @override
  String get doneRestarting => 'Done! Restarting...';

  @override
  String get deleteMessageTitle => 'Delete message?';

  @override
  String get deleteMessageContent =>
      'This message will be deleted for both sides.';

  @override
  String get cannotDeleteMsg =>
      'Cannot delete: message not yet saved on server';

  @override
  String get deleteForMeTitle => 'Delete for me?';

  @override
  String get deleteForMeContent =>
      'This will only remove the message from your device. The other person will still see it.';

  @override
  String get deleteFavMessageContent =>
      'This message will be removed from favorites.';

  @override
  String get pinnedMessage => 'Pinned Message';

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
  String get msgCopied => 'Copied';

  @override
  String copiedUsername(String name) {
    return 'Copied @$name';
  }

  @override
  String get deliveryModeTitle => 'Choose delivery mode';

  @override
  String get deliveryInternet => 'Internet';

  @override
  String get deliveryInternetSubtitle => 'Send via server (encrypted)';

  @override
  String get deliveryLanSubtitle => 'Send via local network (direct)';

  @override
  String get deliveryUserNotInLan => 'User not found in LAN';

  @override
  String get fastChange => 'Fast change';

  @override
  String get fastChangeSubtitle => 'Toggle mode on long press';

  @override
  String get lanModeEnabled => 'LAN mode enabled';

  @override
  String get internetModeEnabled => 'Internet mode enabled';

  @override
  String get previewMessageTitle => 'Preview Message';

  @override
  String get previewYourMessage => 'Your message:';

  @override
  String replyingTo(String name) {
    return 'Replying to: $name';
  }

  @override
  String get send => 'Send';

  @override
  String get fileSentLan => 'File sent via LAN';

  @override
  String uploadingImages(int n) {
    return 'Uploading $n images...';
  }

  @override
  String get albumUploadFailed => 'Album upload failed';

  @override
  String get message => 'Message';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get voiceCallsTitle => 'Voice Calls';

  @override
  String get voiceCallsContent =>
      'Voice calls currently work only over LAN (local network).\n\nWe are raising funds for central server maintenance and development of an alternative.';

  @override
  String get supportOnyxBtn => 'Support ONYX';

  @override
  String get call => 'Call';

  @override
  String get securityCheckTitle => 'Security check';

  @override
  String securityCheckContent(String name) {
    return 'Compare these emojis with $name.\nIf they match — your chat is secure.';
  }

  @override
  String get failedToFetchPubkey => 'Failed to fetch pubkey';

  @override
  String get userHasNoPubkey => 'User has no pubkey';

  @override
  String get galleryMenuLabel => 'Gallery';

  @override
  String get galleryTitle => 'Gallery';

  @override
  String get galleryTabMedia => 'Media';

  @override
  String get galleryTabVoice => 'Voice';

  @override
  String get galleryTabFiles => 'Files';

  @override
  String get galleryEmptyMedia => 'No photos or videos yet';

  @override
  String get galleryEmptyVoice => 'No voice messages yet';

  @override
  String get galleryEmptyFiles => 'No files yet';

  @override
  String get galleryShowInChat => 'Show in chat';

  @override
  String get failedDelete => 'Failed to delete';

  @override
  String get failedEdit => 'Failed to edit message';

  @override
  String get failedReaction => 'Failed to add reaction';

  @override
  String get noInternetCached => 'No internet — showing cached messages';

  @override
  String get sendFailed => 'Send failed';

  @override
  String get mediaUploadNotSupportedWeb => 'Media upload not supported on web';

  @override
  String get localFileRequired => 'Local file required';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get voiceUploadFailed => 'Voice upload failed';

  @override
  String get voiceCancelled => 'Voice message cancelled';

  @override
  String get uploadingVoice => 'Uploading voice...';

  @override
  String uploadingAlbumProgress(int done, int total) {
    return 'Uploading album: $done/$total photos';
  }

  @override
  String get uploadingImageLabel => 'Uploading image...';

  @override
  String get uploadingVideoLabel => 'Uploading video...';

  @override
  String get uploadingAudioLabel => 'Uploading audio...';

  @override
  String get uploadingFileLabel => 'Uploading file...';

  @override
  String get leftGroup => 'You have left the group';

  @override
  String get failedLeaveGroup => 'Failed to leave group';

  @override
  String get avatarOnlyOwnerMod =>
      'Only owners and moderators can change the avatar';

  @override
  String get failedReadFile => 'Failed to read file';

  @override
  String get uploadingAvatar => 'Uploading avatar...';

  @override
  String get avatarUpdatedGroup => 'Group avatar updated';

  @override
  String get avatarDeleted => 'Avatar deleted';

  @override
  String get failedDeleteAvatar => 'Failed to delete avatar';

  @override
  String get copyLink => 'Copy link';

  @override
  String get tokenCopied => 'Token copied';

  @override
  String get groupNameLength => 'Group name must be 1–50 chars';

  @override
  String get groupUpdated => 'Group updated';

  @override
  String get failedUpdateGroup => 'Failed to update group';

  @override
  String get deleteAvatarTitle => 'Delete avatar?';

  @override
  String get deleteAvatarContent =>
      'This will remove the group avatar for everyone.';

  @override
  String get deleteGroupMsgContent =>
      'This message will be deleted for everyone.';

  @override
  String get reply => 'Reply';

  @override
  String get edit => 'Edit';

  @override
  String get editGroupTitle => 'Edit group';

  @override
  String get editChannelTitle => 'Edit channel';

  @override
  String get groupInfoTitle => 'Group';

  @override
  String get channelInfoTitle => 'Channel';

  @override
  String get channelNameLabel => 'Channel name';

  @override
  String get channelNameHint => 'Enter channel name';

  @override
  String unsupportedFileType(String ext) {
    return 'Unsupported file type: $ext';
  }

  @override
  String failedToConnect(String e) {
    return 'Failed to connect: $e';
  }

  @override
  String roleChanged(String role) {
    return 'Your role was changed to $role';
  }

  @override
  String get unbannedReconnecting => 'You have been unbanned! Reconnecting...';

  @override
  String get onlyModsCanPost =>
      'Only owner and moderators can post in channels';

  @override
  String get failedSendMessage => 'Failed to send message';

  @override
  String get uploadFailedConnectionAborted =>
      'Upload failed: Connection aborted. Try smaller file or check server settings.';

  @override
  String get failedSendMedia => 'Failed to send media';

  @override
  String get joinedGroup => 'You have joined the group!';

  @override
  String get failedJoinGroup => 'Failed to join group';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get avatarWillBeDeleted => 'Avatar will be deleted';

  @override
  String get ipCopied => 'IP copied';

  @override
  String get nameCannotBeEmpty => 'Name cannot be empty';

  @override
  String get groupRenamed => 'Group renamed successfully';

  @override
  String errorMsg(String e) {
    return 'Error: $e';
  }

  @override
  String get failedRename => 'Failed to rename';

  @override
  String get imageTooLarge => 'Image too large (max 5MB)';

  @override
  String get avatarUpdatedSuccessfully => 'Avatar updated successfully';

  @override
  String get failedUploadAvatar => 'Failed to upload avatar';

  @override
  String get deletingAvatar => 'Deleting avatar...';

  @override
  String get avatarDeletedSuccessfully => 'Avatar deleted successfully';

  @override
  String userBanned(String name) {
    return '$name banned';
  }

  @override
  String get failedBan => 'Failed to ban';

  @override
  String roleUpdated(String role) {
    return 'Role updated to $role';
  }

  @override
  String get failedChangeRole => 'Failed to change role';

  @override
  String userUnbanned(String name) {
    return '$name unbanned';
  }

  @override
  String get failedUnban => 'Failed to unban';

  @override
  String get youHaveBeenBanned => 'You have been banned';

  @override
  String get renameGroupTitle => 'Rename Group';

  @override
  String get rename => 'Rename';

  @override
  String get join => 'Join';

  @override
  String get manageMembers => 'Manage members';

  @override
  String get banMemberTitle => 'Ban Member';

  @override
  String get ban => 'Ban';

  @override
  String get selectNewRole => 'Select new role:';

  @override
  String get moderator => 'Moderator';

  @override
  String get memberRole => 'Member';

  @override
  String get manageMembersTitle => 'Manage Members';

  @override
  String get viewBans => 'View Bans';

  @override
  String get unbanUserTitle => 'Unban User';

  @override
  String get unban => 'Unban';

  @override
  String get bannedUsersTitle => 'Banned Users';

  @override
  String get bannedFromGroup => 'You have been banned from this group.';

  @override
  String bannedReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get noBannedUsers => 'No banned users';

  @override
  String bannedBy(String name) {
    return 'Banned by: $name';
  }

  @override
  String bannedDate(String date) {
    return 'Date: $date';
  }

  @override
  String banConfirm(String name) {
    return 'Ban $name from the group?';
  }

  @override
  String get banReason => 'Reason (optional)';

  @override
  String changeRoleTitle(String name) {
    return 'Change role for $name';
  }

  @override
  String currentRoleLabel(String role) {
    return 'Current role: $role';
  }

  @override
  String ownerCount(int n) {
    return 'Owners: $n/3';
  }

  @override
  String get ownerCurrent => 'Owner (current)';

  @override
  String get ownerLimitReached => 'Owner (limit reached)';

  @override
  String get owner => 'Owner';

  @override
  String get cannotDemoteLastOwner => 'Cannot demote the last owner';

  @override
  String get noMembersYet => 'No members';

  @override
  String get changeRole => 'Change role';

  @override
  String unbanConfirm(String name) {
    return 'Unban $name?';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get failedCreateGroup => 'Failed to create group';

  @override
  String get invalidInviteLinkFormat => 'Invalid invite link format';

  @override
  String get invalidInviteLink => 'Invalid invite link';

  @override
  String get groupAddedForViewing => 'Group added for viewing!';

  @override
  String get failedAddGroup => 'Failed to add group';

  @override
  String serverRemoved(String name) {
    return 'Server \"$name\" removed';
  }

  @override
  String get channelAdminOnlySubtitle => 'Channel (admin only)';

  @override
  String get groupSubtitle => 'Group';

  @override
  String get newGroup => 'New group';

  @override
  String get externalGroup => 'External Group';

  @override
  String get externalChannel => 'External Channel';

  @override
  String get joinExternalServer => 'Join External Server';

  @override
  String get enterServerAddress => 'Enter server address';

  @override
  String get enterValidIp => 'Enter a valid IP address or hostname';

  @override
  String couldNotConnect(String host) {
    return 'Could not connect to $host';
  }

  @override
  String get usernameRequiredMsg =>
      'Username is required. Please make sure you have created an account in the app.';

  @override
  String get passwordRequiredForGroups => 'Password is required for groups';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String connectionFailed(String e) {
    return 'Connection failed: $e';
  }

  @override
  String connectedToServer(String type, String name) {
    return 'Connected to $type \"$name\"';
  }

  @override
  String get externalGroupType => 'external group';

  @override
  String get externalChannelType => 'external channel';

  @override
  String get identityVisible => 'Your identity will be visible to the server';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get noPasswordForChannels => 'No password required for channels';

  @override
  String get noRegistrationRequired => 'No registration required.';

  @override
  String get back => 'Back';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectBtn => 'Connect';

  @override
  String get serverInfoGroups => 'Groups';

  @override
  String get serverInfoMembers => 'Members';

  @override
  String get serverInfoMedia => 'Media';

  @override
  String get serverInfoMaxFile => 'Max file size';

  @override
  String get profilePresets => 'Identity';

  @override
  String get profilePresetsSubtitle =>
      'Saved identities for joining external servers';

  @override
  String get newPreset => 'New Identity';

  @override
  String get editPreset => 'Edit Identity';

  @override
  String get deletePreset => 'Delete Identity';

  @override
  String deletePresetConfirm(String label) {
    return 'Delete the identity \"$label\"?';
  }

  @override
  String get presetLabel => 'Identity name';

  @override
  String get presetLabelHint => 'e.g. Work, Gaming';

  @override
  String get presetNote => 'Note';

  @override
  String get presetNoteHint => 'What is this identity for? (optional)';

  @override
  String get presetColor => 'Tag color';

  @override
  String get presetLabelRequired => 'Enter a name for the identity';

  @override
  String get noPresetsYet => 'No identities yet';

  @override
  String get noPresetsYetSubtitle =>
      'Save a username and password combo once, reuse it on any external server';

  @override
  String get myPresets => 'My identities';

  @override
  String get usePreset => 'Use identity';

  @override
  String get saveAsPreset => 'Save as identity';

  @override
  String get presetSaved => 'Identity saved';

  @override
  String get presetDeleted => 'Identity deleted';

  @override
  String get thirdPartyServer => 'THIRD-PARTY SERVER';

  @override
  String get thirdPartyWarning =>
      'This server is not operated by ONYX. Only connect if you trust the owner.';

  @override
  String get serverWillKnow => 'Server will know:';

  @override
  String get serverWillNotReceive => 'Server will NOT receive:';

  @override
  String get knowIpAddress => 'Your IP address';

  @override
  String get knowUsername => 'Your chosen username';

  @override
  String get knowMessages => 'Content of your messages in this server';

  @override
  String get notReceiveAccount => 'Your ONYX account or password';

  @override
  String get notReceiveContacts => 'Your contacts and private chats';

  @override
  String get notReceiveKeys => 'Your encryption keys';

  @override
  String get yourPassphraseTitle => 'Your Recovery Passphrase';

  @override
  String get sessionExpiredBanner => 'Session expired — please log in again';

  @override
  String get sessionExpiredTitle => 'Session expired';

  @override
  String get sessionExpiredSubtitle => 'Please sign in again';

  @override
  String get sessionSignIn => 'Sign in';

  @override
  String get sessionRenewSoon => 'Re-login will be required soon';

  @override
  String get sessionStillValid => 'Authorization token is valid';

  @override
  String get blockedUsersTitle => 'Blocked Users';

  @override
  String get blockedUsersSubtitle => 'Manage blocked users';

  @override
  String get blockedUsersEmpty => 'No blocked users';

  @override
  String get unblockAction => 'Unblock';

  @override
  String get writeMessage => 'Write';

  @override
  String get fakePinTitle => 'Fake PIN';

  @override
  String get fakePinSubtitle => 'Open a decoy account under duress';

  @override
  String get fakePinSheetTitle => 'Fake PIN Setup';

  @override
  String get fakePinStatusActive => 'Active';

  @override
  String get fakePinStatusOff => 'Off';

  @override
  String get fakePinDescription =>
      'When this PIN is entered at the lock screen, the app opens showing your decoy account instead of your real one.';

  @override
  String get setFakePin => 'Set Fake PIN';

  @override
  String get disableFakePin => 'Disable Fake PIN';

  @override
  String get changeFakePin => 'Change Fake PIN';

  @override
  String get disableFakePinTitle => 'Disable Fake PIN?';

  @override
  String get disableFakePinContent =>
      'The fake PIN will be removed. Your decoy account settings will be kept.';

  @override
  String get fakePinEnabledSnack => 'Fake PIN enabled';

  @override
  String get fakePinDisabledSnack => 'Fake PIN disabled';

  @override
  String get fakePinCannotMatchReal => 'Fake PIN cannot match your real PIN';

  @override
  String get decoyAccountSection => 'Decoy Account';

  @override
  String get decoyAccountSubtitle =>
      'This account will be shown when the fake PIN is used';

  @override
  String get decoyDisplayNameLabel => 'Display name';

  @override
  String get decoyUsernameLabel => 'Username';

  @override
  String get decoyDisplayNameHint => 'Enter display name';

  @override
  String get decoyUsernameHint => 'Enter username';

  @override
  String get saveDecoyAccount => 'Save decoy account';

  @override
  String get decoyAccountSaved => 'Decoy account saved';

  @override
  String get decoyFieldsRequired => 'Username and display name cannot be empty';

  @override
  String get removeAvatar => 'Remove avatar';

  @override
  String get fakePinSecurityNote =>
      'The fake PIN must differ from your real PIN. The decoy account has no server connection — it only shows the profile you configured here.';

  @override
  String get decoyNoChats => 'No chats yet';

  @override
  String get decoyNoGroups => 'No groups yet';

  @override
  String get decoyNoFavorites => 'No favorites yet';

  @override
  String get decoyOtherAccounts => 'Other accounts';

  @override
  String get decoyNoOtherAccounts => 'No other accounts';

  @override
  String get lock => 'Lock';

  @override
  String get decoyAppearance => 'Appearance';

  @override
  String get decoyNotifications => 'Notifications';

  @override
  String get decoyStorage => 'Storage';

  @override
  String get decoyAppearanceSubtitle => 'Theme and display options';

  @override
  String get decoyNotificationsSubtitle => 'Sound and alert settings';

  @override
  String get decoyStorageSubtitle => 'Manage cached files';

  @override
  String get decoyContactsSection => 'Fake Chats';

  @override
  String get decoyContactsSubtitle =>
      'Add contacts with messages — they appear when the decoy account is opened';

  @override
  String get generateContacts => 'Generate Contacts';

  @override
  String get addDecoyContact => 'Add Contact';

  @override
  String get decoyNoContacts => 'No fake chats yet';

  @override
  String get decoyContactUsername => 'Contact username';

  @override
  String get decoyContactDisplayName => 'Contact display name';

  @override
  String contactsGenerated(int n) {
    return 'Added $n contacts';
  }

  @override
  String get contactAdded => 'Contact added';

  @override
  String get contactRemoved => 'Contact removed';

  @override
  String get decoyContactExists => 'Contact already exists';

  @override
  String get decoyContactsCleared => 'All chats cleared';

  @override
  String get clearDecoyChats => 'Clear All Chats';

  @override
  String get messagesCount => 'messages';

  @override
  String get add => 'Add';

  @override
  String get decoyChatsSubtitle => 'Contacts with message history';

  @override
  String get decoyGroupsSection => 'Groups & Channels';

  @override
  String get decoyGroupsSubtitle => 'Fake groups and channels';

  @override
  String get decoyFavoritesSection => 'Favorites';

  @override
  String get decoyFavoritesSubtitle => 'Pinned favorite chats';

  @override
  String get noFakeGroups => 'No groups yet';

  @override
  String get noFakeFavorites => 'No favorites yet';

  @override
  String get addFakeGroup => 'Group';

  @override
  String get addFakeChannel => 'Channel';

  @override
  String get addFakeFavorite => 'Add Favorite';

  @override
  String get groupType => 'Group';

  @override
  String get channelType => 'Channel';

  @override
  String get favTitleHint => 'Title';

  @override
  String get generateAll => 'Generate All';

  @override
  String get generateAllConfirm =>
      'Random content will be generated, replacing existing data.';

  @override
  String get sendFavoritesTitle => 'Send Favorites';

  @override
  String get sendFavoritesShowQrToReceiver => 'Show QR to Receiver';

  @override
  String get sendFavoritesScanReceiver => 'Scan Receiver QR';

  @override
  String get sendFavoritesSending => 'Sending Favorites';

  @override
  String get sendFavoritesSelectTitle => 'Select chats to send';

  @override
  String get sendFavoritesHintDesktop =>
      'The receiver must press \"Receive\" first. Then scan the QR code shown here.';

  @override
  String get sendFavoritesHintMobile =>
      'The receiver must press \"Receive\" first and show the QR code.';

  @override
  String allChatsCount(int n) {
    return 'All chats ($n)';
  }

  @override
  String get sendFavoritesNoFavs => 'No favourite chats yet.';

  @override
  String get sendFavoritesSelectAtLeastOne => 'Select at least one chat';

  @override
  String get sendFavoritesShowQrBtn => 'Show QR';

  @override
  String get sendFavoritesScanQrBtn => 'Scan QR';

  @override
  String get receiveFavoritesTitle => 'Receive Favorites';

  @override
  String get receiveFavoritesScanSender => 'Scan Sender QR';

  @override
  String get receiveFavoritesScanOnSender => 'Scan on sender device';

  @override
  String get receiveFavoritesInstruction =>
      'Open Favorites on the sender, tap Sync → Send, then scan this code';

  @override
  String get receiveFavoritesE2E => 'End-to-end encrypted · local network only';

  @override
  String get receiveFavoritesScanHint =>
      'Point the camera at the QR code shown on the sender device';

  @override
  String get receiveFavoritesScanEncrypted =>
      'Transfer is encrypted · local network only';

  @override
  String get receiveFavoritesWaiting => 'Waiting for sender to scan QR code…';

  @override
  String get receiveFavoritesComplete => 'Transfer complete.';

  @override
  String get receiveFavoritesConnecting => 'Connecting to sender…';

  @override
  String get receiveFavoritesConnected => 'Connected! Waiting for files…';

  @override
  String get cancelTransfer => 'Cancel transfer';

  @override
  String get wardLinkTitle => 'WardLink';

  @override
  String get wardLinkSubtitle =>
      'Passive sync between your devices on the local network';

  @override
  String get wardLinkEnable => 'Passive sync';

  @override
  String get wardLinkEnableDesc =>
      'Automatically sync with trusted devices on the same network. On phones this works while the app is open; on desktop it runs continuously.';

  @override
  String get wardLinkPairedDevices => 'Trusted devices';

  @override
  String get wardLinkNoPairedDevices => 'No paired devices yet';

  @override
  String get wardLinkAddDevice => 'Add';

  @override
  String get wardLinkRemoveDevice => 'Remove';

  @override
  String get wardLinkRemoveConfirm => 'Stop syncing with this device?';

  @override
  String get wardLinkFavoritesOnlyNote =>
      'Syncs your Favorites — their messages and media';

  @override
  String get wardLinkMaxFileSize => 'Max file size';

  @override
  String get wardLinkPairTitle => 'Pair device';

  @override
  String get wardLinkShowCode => 'Show code';

  @override
  String get wardLinkScanCode => 'Scan code';

  @override
  String get wardLinkShowInstruction =>
      'Open WardLink on your other device and scan this code';

  @override
  String get wardLinkScanInstruction =>
      'Point the camera at the WardLink code on the other device';

  @override
  String get wardLinkPairedOk => 'Device paired';

  @override
  String get wardLinkPairFailed => 'Pairing failed';

  @override
  String get wardLinkE2E => 'End-to-end encrypted · LAN only';

  @override
  String get wardLinkSyncingNow => 'Syncing…';

  @override
  String get wardLinkDone => 'Synced';

  @override
  String get wardLinkCurrentFile => 'Current file';

  @override
  String get wardLinkLog => 'Sync log';

  @override
  String get wardLinkLogEmpty => 'No events yet';

  @override
  String get wardLinkHoldForLog => 'Hold the bubble for the log';

  @override
  String get wardLinkUpToDate => 'Up to date';

  @override
  String syncedFromDevice(String device) {
    return 'Synced from $device';
  }

  @override
  String get syncedFromUnknownDevice => 'Synced from another device';

  @override
  String wardLinkFilesDone(int n) {
    return 'Files transferred: $n';
  }

  @override
  String get wardLinkNoFilesYet => 'No files transferred';

  @override
  String wardLinkSyncedAgo(String when) {
    return 'Synced $when';
  }

  @override
  String get wardLinkNeverSynced => 'Not synced yet';

  @override
  String get wardLinkFirewallHintWindows =>
      'If the phone cannot reach this PC, allow ONYX in Windows Firewall (TCP port 47832). ONYX tries to add the rule automatically; if it fails: Windows Firewall → Advanced → Inbound Rules → New Rule → Port → TCP → 47832.';

  @override
  String get wardLinkFirewallHintMac =>
      'If the phone cannot reach this Mac, make sure the macOS firewall is not blocking ONYX: System Settings → Network → Firewall → Options → add ONYX.';

  @override
  String get wardLinkFirewallHintLinux =>
      'If the phone cannot connect, open TCP port 47832 in your firewall. Example: sudo ufw allow 47832/tcp  or  sudo firewall-cmd --add-port=47832/tcp --permanent';

  @override
  String get wardLinkSyncFromBeginning => 'Sync from beginning';

  @override
  String get wardLinkSyncFromBeginningDesc =>
      'Pull all history not yet on this device';

  @override
  String get wardLinkSyncPending => 'Sync pending…';

  @override
  String get wardLinkBubbleVisibility => 'Sync bubble';

  @override
  String get wardLinkBubbleShowAlways => 'Show always';

  @override
  String get wardLinkBubbleShowOnErrors => 'Show on errors only';

  @override
  String get wardLinkBubbleSize => 'Bubble size';

  @override
  String get wardLinkSyncFavoritesToggle => 'Sync Favorites';

  @override
  String get wardLinkSyncFavoritesToggleDesc =>
      'Sync your Favorites — their messages and media';

  @override
  String get wardLinkSyncPersonalToggle => 'Sync my personal messages';

  @override
  String get wardLinkSyncPersonalToggleDesc =>
      'Sync only the messages YOU sent in personal chats to your other devices — the contact\'s messages already arrive via the server and are never synced this way';

  @override
  String get meshSubtitle => 'Offline mesh network';

  @override
  String get meshEnable => 'Enable Mesh network';

  @override
  String get meshEnableDesc =>
      'Direct messaging without internet via Wi-Fi or Bluetooth.\nWorks only in direct messages.';

  @override
  String get meshUnavailable =>
      'Mesh network is not available on this platform.';

  @override
  String get meshOpenRadar => 'Open Radar';

  @override
  String meshNearbyCount(int n) {
    return 'Nearby: $n devices';
  }

  @override
  String get meshRadarTitle => 'Mesh Radar';

  @override
  String get meshRadarScanning => 'Scanning…';

  @override
  String get meshRadarSearchHint => 'Search by name...';

  @override
  String meshRadarSearchEmpty(String q) {
    return 'No results for \"$q\"';
  }

  @override
  String get meshRadarNoDevices => 'No devices nearby.\nMesh scans every 20 s.';

  @override
  String get meshRadarDisabled =>
      'Mesh mode is off.\nEnable it in Settings → Mesh.';

  @override
  String get meshRadarStarting => 'Starting BLE scan…';

  @override
  String get meshMenuRadar => 'Radar';

  @override
  String get meshMenuDiagnostics => 'Diagnostics';

  @override
  String get meshMenuModeAuto => 'Auto';

  @override
  String get meshBluetoothOffTitle => 'Bluetooth is off';

  @override
  String get meshBluetoothOffContent =>
      'Mesh chat was switched to Bluetooth-only mode, but Bluetooth is turned off. Enable it in system settings to reach nearby devices.';

  @override
  String get meshOpenSystemSettings => 'Open Settings';

  @override
  String get meshModeLabel => 'MODE';

  @override
  String get meshModeActive => 'Mesh mode active';

  @override
  String get meshChatLabel => 'Mesh Chat';

  @override
  String get meshLocationRequired =>
      'Enable location services for BLE scanning (Android ≤11)';

  @override
  String get meshChatEmpty => 'No messages yet.\nSend the first mesh message.';

  @override
  String get meshChatInputHint => 'Message…';

  @override
  String get meshChatSend => 'Send';

  @override
  String get meshChatOutOfRange => 'Out of range';

  @override
  String get meshStatusSending => 'Sending…';

  @override
  String get meshStatusSendingWifi => 'Sending via Wi-Fi…';

  @override
  String get meshStatusSendingBle => 'Sending via Bluetooth…';

  @override
  String get meshStatusRelayed => 'In transit via mesh';

  @override
  String get meshStatusDelivered => 'Delivered';

  @override
  String get meshStatusFailed => 'Not delivered';

  @override
  String get meshStatusRetry => 'Retry';

  @override
  String get meshStatusFailedHint => 'Message did not reach the recipient';

  @override
  String get meshErrorVideoWifiOnly =>
      'Video can only be sent over Wi-Fi. Connect to the same Wi-Fi network as the recipient.';

  @override
  String get meshErrorFileTooLargeForBle =>
      'File is too large for Bluetooth (max 10 MB). Connect to a shared Wi-Fi network.';

  @override
  String get meshErrorFileTooLarge => 'File is too large (max 200 MB).';

  @override
  String get meshErrorAttachmentsUnsupported =>
      'Attachments are only supported on mobile/desktop';

  @override
  String get meshErrorPickFileFailed => 'Failed to pick file';

  @override
  String get meshErrorSendFileFailed => 'Failed to send file';

  @override
  String get meshErrorSendVoiceFailed => 'Failed to send voice message';

  @override
  String meshErrorOutOfRange(String username) {
    return '$username is out of range';
  }

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupSubtitle => 'Local backup and restore of your data';

  @override
  String get backupExport => 'Save all data';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String get backupScope => 'What to back up';

  @override
  String get backupFavorites => 'Favorite chats';

  @override
  String get backupPersonal => 'Personal chats';

  @override
  String get backupIncludeMedia => 'Include media';

  @override
  String get backupMediaImages => 'Images';

  @override
  String get backupMediaVideos => 'Videos';

  @override
  String get backupMediaVoice => 'Voice & audio';

  @override
  String get backupMediaOther => 'Other files';

  @override
  String get backupSchedule => 'Scheduled backup';

  @override
  String get backupFreqOff => 'Off';

  @override
  String get backupFreqDaily => 'Daily';

  @override
  String get backupFreqWeekly => 'Weekly';

  @override
  String get backupFreqMonthly => 'Monthly';

  @override
  String get backupFolder => 'Auto-backup folder';

  @override
  String get backupChangeFolder => 'Change';

  @override
  String get backupLastAuto => 'Last auto-backup';

  @override
  String get backupNever => 'never';

  @override
  String get backupInProgress => 'Creating backup…';

  @override
  String get backupRestoring => 'Restoring…';

  @override
  String get backupSelectScope => 'Select at least one category';

  @override
  String get backupNoAccount => 'No active account';

  @override
  String get backupNoPermission =>
      'Storage access denied. Grant \"All files access\" in app settings.';

  @override
  String get backupOpenFolder => 'Open folder';

  @override
  String get backupFolderUnsupported =>
      'This folder is not accessible. Please pick a folder on internal storage.';

  @override
  String get backupRestoreConfirmTitle => 'Restore from backup?';

  @override
  String get backupRestoreConfirmBody =>
      'Data from the file will be restored over your current data (chats, favorites, settings).';

  @override
  String get backupRestartHint => 'Restart the app to see the changes';

  @override
  String get recycleBinTitle => 'Trash';

  @override
  String get recycleBinSubtitle =>
      'Deleted chats and protection from accidental sync deletions';

  @override
  String get recycleBinPendingTitle => 'Deletion requests';

  @override
  String recycleBinPendingDesc(String device, int count) {
    return 'Device \"$device\" wants to delete $count chat(s). Apply or keep?';
  }

  @override
  String get recycleBinApply => 'Apply delete';

  @override
  String get recycleBinKeep => 'Keep my chats';

  @override
  String get recycleBinNoPending => 'No pending deletion requests';

  @override
  String get recycleBinResetTitle => 'Reset deletion records';

  @override
  String get recycleBinResetDesc =>
      'Clears the list of deleted chats. Sync will stop re-deleting them on other devices and can bring them back.';

  @override
  String get recycleBinResetButton => 'Clear deleted list';

  @override
  String get recycleBinResetDone => 'Deletion records cleared';

  @override
  String get recycleBinResetConfirm =>
      'Clear all deletion records for this account?';

  @override
  String get accountGraph => 'Account Graph';

  @override
  String get accountGraphSubtitleDesktopOn =>
      'Shows a graph of your chats, groups and channels when no chat is open';

  @override
  String get accountGraphSubtitleMobileOn =>
      'Visualizing your account in planetary view';

  @override
  String get accountGraphSubtitleDesktopOff =>
      'Shows a hint when no chat is open';

  @override
  String get accountGraphSubtitleMobileOff => 'Account Graph is disabled';

  @override
  String get orbitSpeed => 'Orbit Speed';

  @override
  String secOrbit(int s) {
    return '$s sec/orbit';
  }

  @override
  String minOrbit(int m) {
    return '$m min/orbit';
  }

  @override
  String get animateGraph => 'Animate';

  @override
  String get animateGraphOn => 'Orbits rotate in real time';

  @override
  String get animateGraphOff => 'Graph is frozen / static';

  @override
  String get preserveView => 'Preserve View';

  @override
  String get preserveViewOn => 'Keeps zoom & position when leaving a chat';

  @override
  String get preserveViewOff => 'Resets to center when returning';

  @override
  String get migrationTitle => 'Storage Migration';

  @override
  String get migrationBody =>
      'ONYX is switching to a new high-speed storage engine. Chats and media will load much faster.';

  @override
  String get migrationAccounts => 'Accounts';

  @override
  String get migrationDataSize => 'Data size';

  @override
  String get migrationBackupNote =>
      'A backup will be created before migration. The app may be temporarily unresponsive during this process.';

  @override
  String get migrationStart => 'Start Migration';

  @override
  String get migrationSkip => 'Skip';

  @override
  String get migrationPhaseBackup => 'Creating backup';

  @override
  String get migrationPhaseImport => 'Importing data';

  @override
  String get migrationPhaseVerify => 'Verifying';

  @override
  String get migrationPhasePreparing => 'Preparing';

  @override
  String get migrationDontClose => 'Do not close the app';

  @override
  String get migrationDoneTitle => 'Done!';

  @override
  String get migrationDoneBody =>
      'Storage updated. A backup has been saved to the Backups folder.';

  @override
  String get migrationDoneNote =>
      'Once you confirm everything works — you can delete it manually.';

  @override
  String get migrationDoneButton => 'Great!';

  @override
  String get migrationErrorTitle => 'Migration Error';

  @override
  String get migrationErrorBody =>
      'The app will continue on the old system. Migration will be retried on next launch.';

  @override
  String get migrationErrorButton => 'Got it';

  @override
  String get audioTitle => 'Audio';

  @override
  String get audioSubtitle => 'Microphone and speaker device selection';

  @override
  String get audioMicInput => 'Microphone (input)';

  @override
  String get audioSpeakerOutput => 'Speaker (output)';

  @override
  String get audioSystemDefault => 'System default';

  @override
  String get audioChangesNote =>
      'Changes take effect on the next voice channel join.';

  @override
  String get wardlinkReceive => 'Receive from device';

  @override
  String get wardlinkReceiveSubtitle => 'Show a QR code — the sender scans it';

  @override
  String get wardlinkSend => 'Send to device';

  @override
  String get wardlinkSendSubtitle => 'Scan the QR code shown on the receiver';

  @override
  String get react => 'React';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get copyImage => 'Copy Image';

  @override
  String get forward => 'Forward';

  @override
  String get showInFileSystem => 'Show in file system';

  @override
  String get saveNotSupportedOnWeb => 'Save not supported on web';

  @override
  String get imageNotLoadedYet => 'Image not loaded yet';

  @override
  String get voiceNotLoadedYet => 'Voice not loaded yet';

  @override
  String get videoNotLoadedYet => 'Video not loaded yet';

  @override
  String get fileNotLoadedYet => 'File not loaded yet';

  @override
  String get fileNotLoadedOpenFirst =>
      'File isn\'t downloaded to this device — tap it in the chat to download it';

  @override
  String editTimerLabel(int s) {
    return 'Edit  ·  ${s}s';
  }

  @override
  String deleteTimerLabel(int s) {
    return 'Delete  ·  ${s}s';
  }

  @override
  String get newChat => 'New chat';

  @override
  String get newChatSubtitle => 'Create a new favorite chat';

  @override
  String get newFolder => 'New folder';

  @override
  String get newFolderSubtitle => 'Group chats into a folder';

  @override
  String get searchEmoji => 'Search emoji…';

  @override
  String get syncCompleted => 'Sync completed';

  @override
  String get syncCompletedWithErrors => 'Sync completed with errors';

  @override
  String get receivingFiles => 'Receiving files...';

  @override
  String syncFromUser(String sender) {
    return 'from $sender';
  }

  @override
  String get aboutServer => 'SERVER';

  @override
  String get aboutWhatsNew => 'WHAT\'S NEW';

  @override
  String get aboutConnected => 'Connected';

  @override
  String get aboutConnecting => 'Connecting...';

  @override
  String get aboutLoadingLocation => 'Loading...';

  @override
  String get aboutNoReleaseNotes => 'No release notes available.';

  @override
  String get aboutCheckForUpdates => 'Check for updates';

  @override
  String get aboutChecking => 'Checking...';

  @override
  String get aboutUpToDate => 'You\'re up to date!';

  @override
  String aboutUpdateAvailable(String v) {
    return 'Update available: $v';
  }

  @override
  String get downloadUpdateTitle => 'Download Update';

  @override
  String get downloadUpdateVersion => 'Version';

  @override
  String get downloadUpdateWhatsNew => 'WHAT\'S NEW';

  @override
  String get downloadUpdateReady => 'Ready to download';

  @override
  String get downloadUpdateDownloading => 'Downloading...';

  @override
  String get downloadUpdateComplete => 'Download complete!';

  @override
  String get downloadUpdateNoPlatform =>
      'No download available for this platform';

  @override
  String get downloadUpdateInstall => 'Download & Install';

  @override
  String get downloadUpdateOpen => 'Open';

  @override
  String get downloadUpdateRetry => 'Retry';

  @override
  String get downloadUpdateCancel => 'Cancel download';

  @override
  String get editChat => 'Edit chat';

  @override
  String get chatNameLabel => 'Chat name';

  @override
  String get editFolder => 'Edit folder';

  @override
  String get folderNameLabel => 'Folder name';

  @override
  String get createChat => 'New chat';

  @override
  String get profileMessage => 'Message';

  @override
  String get tapAvatarHint => 'Tap avatar to change • Long-press to remove';

  @override
  String get tapAvatarLongRemove => 'Tap to change • Long-press to remove';

  @override
  String get e2eeWarnTitle => 'Not end-to-end encrypted';

  @override
  String get e2eeWarnUnderstand => 'I understand';

  @override
  String get e2eeWarnDoNotShare =>
      'Do not share passwords, private files or sensitive information here.';

  @override
  String get e2eeWarnGroupBody =>
      'Messages in this group are not protected by end-to-end encryption — the server can read them.';

  @override
  String get e2eeWarnGroupMedia =>
      'Attached media is uploaded to a public host (catbox.moe) and is reachable by anyone who has the link.';

  @override
  String get e2eeWarnExtBody =>
      'Messages in this group are not protected by end-to-end encryption — the group owner\'s server can read them.';

  @override
  String get e2eeWarnExtMedia =>
      'Attached media is uploaded to and stored on the owner\'s own server, not on ONYX.';

  @override
  String get e2eeWarnExtOnyxUnrelated =>
      'ONYX has nothing to do with this group and cannot moderate or protect its content.';

  @override
  String get securityLevelTitle => 'Device trust level';

  @override
  String get securityLevelEasy => 'Easy';

  @override
  String get securityLevelEasyDesc =>
      'A new device is trusted immediately after login. Least friction, but the password is your only line of defense.';

  @override
  String get securityLevelBalanced => 'Balanced';

  @override
  String get securityLevelBalancedDesc =>
      'Any already-trusted device can approve a new one. Recommended for most people.';

  @override
  String get securityLevelStrict => 'Strict';

  @override
  String get securityLevelStrictDesc =>
      'A new device needs approval from two separate trusted devices.';

  @override
  String get securityLevelLowerRequiresTrusted =>
      'Lowering the security level requires a trusted device.';

  @override
  String get securityLevelUpdated => 'Security level updated';

  @override
  String get sessionTtlTitle => 'Session lifetime';

  @override
  String get sessionTtlSubtitle =>
      'How long before this device asks for your password again';

  @override
  String get sessionTtlRecommended => 'recommended';

  @override
  String sessionTtlDays(int days) {
    return '$days days';
  }

  @override
  String get sessionTtlNever => 'Never';

  @override
  String get sessionTtlUpdated => 'Session lifetime updated';

  @override
  String get approvalsProgress => 'Approved';

  @override
  String get pendingDeviceTitleSingle => 'New device';

  @override
  String pendingDeviceTitleMulti(int count) {
    return 'New devices ($count)';
  }

  @override
  String get pendingDeviceApprove => 'Approve';

  @override
  String get pendingDeviceDeny => 'Deny';

  @override
  String get recoveryTitle => 'Account recovery';

  @override
  String get recoveryBannerText =>
      'This device isn\'t approved yet. If no trusted device is reachable, you can recover access with your password and recovery phrase.';

  @override
  String get recoveryBannerButton => 'Recover access';

  @override
  String get recoveryIntro =>
      'Enter your password and the 12-word recovery phrase shown to you at registration. The request won\'t take effect immediately — your trusted devices get a window to cancel it if this isn\'t you.';

  @override
  String get recoveryPasswordLabel => 'Password';

  @override
  String get recoveryPassphraseLabel => 'Recovery phrase (12 words)';

  @override
  String get recoverySubmit => 'Submit request';

  @override
  String get recoveryInvalid => 'Invalid password or recovery phrase';

  @override
  String get recoveryAlreadyPending => 'A request is already pending';

  @override
  String get recoveryPendingTitle => 'Request submitted';

  @override
  String recoveryPendingBody(String when) {
    return 'Access will be restored $when unless a trusted device cancels the request.';
  }

  @override
  String get recoveryCancelled => 'Recovery request cancelled';

  @override
  String get recoveryExecuted =>
      'Access restored. Please re-login to apply the change.';

  @override
  String get recoveryCancelRequiresTrusted =>
      'Only a trusted device can cancel this. Approve this device in Active Devices first.';

  @override
  String get recoveryAlertRequestedTitle =>
      'Someone requested account recovery';

  @override
  String recoveryAlertRequestedBody(String deviceName, String when) {
    return 'Device \"$deviceName\" requested account recovery. If this wasn\'t you, cancel it now. Otherwise it takes effect $when.';
  }

  @override
  String get recoveryAlertCancelButton => 'Cancel';

  @override
  String get recoveryAlertIgnoreButton => 'It\'s me, ignore';

  @override
  String get recoveryAlertFailedTitle => 'Failed recovery attempt';

  @override
  String get recoveryAlertFailedBody =>
      'Someone tried to recover access to your account but entered the wrong password or recovery phrase.';

  @override
  String get recoveryAlertExecutedTitle => 'Recovery completed';

  @override
  String get recoveryAlertExecutedBody =>
      'The recovery request has taken effect — the account has a new primary device. If this wasn\'t you, revoke the unfamiliar session in Active Devices immediately.';

  @override
  String get wardLinkSyncSettingsTitle => 'Sync Settings';

  @override
  String get wardLinkSyncSettingsSubtitle =>
      'File size limit and bubble notifications';

  @override
  String get wardLinkPairedDevicesSubtitle => 'Add and manage paired devices';

  @override
  String get notifGeneralTitle => 'General';

  @override
  String get notifGeneralSubtitle =>
      'Enable notifications and content visibility';

  @override
  String get notifSoundSubtitle => 'Notification sound and audio file';

  @override
  String get notifAdvancedTitle => 'Advanced';

  @override
  String get notifAdvancedSubtitle => 'Startup behavior and popup position';

  @override
  String get securityPrivacyTitle => 'Privacy';

  @override
  String get securityPrivacySubtitle => 'Visibility and search settings';

  @override
  String get cacheStorageTitle => 'Storage';

  @override
  String get cacheStorageSubtitle => 'Media cache and unused file cleanup';

  @override
  String get connectionServerTitle => 'Server Connection';

  @override
  String get connectionServerSubtitle =>
      'Connect or disconnect from the WebSocket server';

  @override
  String get interactPerformanceTitle => 'Performance';

  @override
  String get interactPerformanceSubtitle =>
      'Scroll buffer and image preload window';

  @override
  String get interactFilesTitle => 'Files & Storage';

  @override
  String get interactFilesSubtitle => 'Download folder and app data management';

  @override
  String get appearanceChatDisplayTitle => 'Chat Display';

  @override
  String get appearanceChatDisplaySubtitle =>
      'Alignment, avatars and animations';

  @override
  String get appearanceLayoutTitle => 'Layout';

  @override
  String get appearanceLayoutSubtitle => 'Navigation, graph and tab swiping';

  @override
  String get appearanceLiquidGlassTitle => 'Liquid Glass Effects';

  @override
  String get trashChatsTitle => 'Deleted Chats';

  @override
  String get trashChatsSubtitle => 'Restore or permanently delete chats';

  @override
  String get trashMessagesTitle => 'Deleted Messages';

  @override
  String get trashMessagesSubtitle => 'Restore or permanently delete messages';

  @override
  String get download => 'Download';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get revoke => 'Revoke';

  @override
  String get setup => 'Setup';

  @override
  String get current => 'Current';

  @override
  String get select => 'Select';

  @override
  String get token => 'Token';

  @override
  String get always => 'Always';

  @override
  String favRemoveFromFolderNamed(String folderName) {
    return 'Remove from \"$folderName\"';
  }

  @override
  String get favMoveToFolder => 'Move to folder';

  @override
  String get favRemoveFromFolder => 'Remove from folder';

  @override
  String get favUnlock => 'Unlock';

  @override
  String get favLock => 'Lock';

  @override
  String get favUnlockFolder => 'Unlock folder';

  @override
  String get favLockFolder => 'Lock folder';

  @override
  String favChatsCount(int n) {
    return '$n chats';
  }

  @override
  String get favNewFolder => 'New folder';

  @override
  String get favChatsMovedToTopLevel => 'Chats will be moved to top level';

  @override
  String get favDeleteChatQuestion => 'Delete chat?';

  @override
  String get favRemoveAvatarQuestion => 'Remove avatar?';

  @override
  String get favSelectedRemovedFromFavorites =>
      'Selected messages will be removed from favorites.';

  @override
  String get favDeleteMessageQuestion => 'Delete message?';

  @override
  String get favMessageRemovedFromFavorites =>
      'This message will be removed from favorites.';

  @override
  String get favDeleteAvatarQuestion => 'Delete avatar?';

  @override
  String get favRemoveAvatarConfirm => 'This will remove this favorite avatar.';

  @override
  String get sendAlbum => 'Send Album';

  @override
  String get sendAlbums => 'Send Albums';

  @override
  String get sendAllMedia => 'Send All';

  @override
  String get setAsWallpaper => 'Set as wallpaper';

  @override
  String get sendVoice => 'Send Voice';

  @override
  String get cropAndUpload => 'Crop & Upload';

  @override
  String get deleteMessagesQuestion => 'Delete messages?';

  @override
  String get connectionDiagnostics => 'Connection Diagnostics';

  @override
  String get voiceChannels => 'Voice channels';

  @override
  String get forwardMessage => 'Forward message';

  @override
  String get noChats => 'No chats';

  @override
  String get noGroups => 'No groups';

  @override
  String get noFavorites => 'No favorites';

  @override
  String get wifiOnlyOption => 'Wi-Fi only';

  @override
  String get emptyTrash => 'Empty Trash';

  @override
  String get performanceReport => 'Performance Report';

  @override
  String get revokeSessionQuestion => 'Revoke session?';

  @override
  String get revokeSessionConfirm =>
      'This device will be immediately logged out.';

  @override
  String get failedToRevokeSession => 'Failed to revoke session';

  @override
  String get failedToApproveDevice => 'Failed to approve device';

  @override
  String get noActiveSessionsFound => 'No active sessions found';

  @override
  String get quotaExceeded => 'Quota exceeded';

  @override
  String get openSettingsAction => 'Open Settings';

  @override
  String get trashIsEmpty => 'Trash is empty';

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
      other: ' Cleared $n media caches',
      one: ' Cleared $n media cache',
    );
    return '$_temp0';
  }

  @override
  String leaveGroupTitle(String isChannel) {
    String _temp0 = intl.Intl.selectLogic(
      isChannel,
      {
        'true': 'channel',
        'other': 'group',
      },
    );
    return 'Leave $_temp0?';
  }

  @override
  String cacheFilesDeleted(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Deleted $n files',
      one: 'Deleted $n file',
    );
    return '$_temp0';
  }

  @override
  String orphanedCleanupDeleted(int files, String freedMb) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: 'Deleted $files unused files',
      one: 'Deleted $files unused file',
    );
    return '$_temp0 ($freedMb MB freed)';
  }

  @override
  String deletedLogsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Deleted $n log files.',
      one: 'Deleted $n log file.',
    );
    return '$_temp0';
  }

  @override
  String notifEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'You will be alerted for new messages',
        'other': 'All notifications are silenced',
      },
    );
    return '$_temp0';
  }

  @override
  String notifHideContentSubtitle(String hidden) {
    String _temp0 = intl.Intl.selectLogic(
      hidden,
      {
        'true': 'Notifications without message text',
        'other': 'Show message text in notifications',
      },
    );
    return '$_temp0';
  }

  @override
  String notifSoundEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'Sound enabled',
        'other': 'Sound disabled',
      },
    );
    return '$_temp0';
  }

  @override
  String sessionExpiresInDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Session expires in $n days',
      one: 'Session expires in $n day',
    );
    return '$_temp0';
  }

  @override
  String sessionExpiresInHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Session expires in $n hours',
      one: 'Session expires in $n hour',
    );
    return '$_temp0';
  }

  @override
  String sessionActiveForDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Session valid for $n more days',
      one: 'Session valid for $n more day',
    );
    return '$_temp0';
  }

  @override
  String meshRadarFound(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n devices in range',
      one: '$n device in range',
    );
    return '$_temp0';
  }

  @override
  String trashSummary(int chats, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats chats',
      one: '$chats chat',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '$messages messages',
      one: '$messages message',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get muteAction => 'Mute';

  @override
  String get unmuteAction => 'Unmute';

  @override
  String muteUserTitle(String name) {
    return 'Mute $name';
  }

  @override
  String get durationLabel => 'Duration';

  @override
  String get duration15Min => '15 min';

  @override
  String get duration1Hour => '1 hour';

  @override
  String get duration1Day => '1 day';

  @override
  String get duration1Week => '1 week';

  @override
  String get muteReasonLabel => 'Reason (optional)';

  @override
  String userMuted(String name) {
    return '$name muted';
  }

  @override
  String get failedMute => 'Failed to mute';

  @override
  String failedMuteUser(String name) {
    return 'Failed to mute $name';
  }

  @override
  String get mutedUsersTitle => 'Muted Users';

  @override
  String get noMutedUsers => 'No muted users';

  @override
  String mutedByLabel(String name) {
    return 'Muted by: $name';
  }

  @override
  String mutedUntilLabel(String date) {
    return 'Until: $date';
  }

  @override
  String userUnmuted(String name) {
    return '$name unmuted';
  }

  @override
  String get failedUnmute => 'Failed to unmute';

  @override
  String failedUnmuteUser(String name) {
    return 'Failed to unmute $name';
  }

  @override
  String get youAreMutedTitle => 'You are muted';

  @override
  String mutedUntilMessage(String date) {
    return 'You can\'t send messages in this chat until $date.';
  }

  @override
  String get slowModeLabel => 'Slow mode (seconds, 0 = off)';

  @override
  String get slowModeHelper =>
      'Minimum delay between messages for regular members. Admins are never limited.';

  @override
  String slowModeSetTo(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Slow mode set to $seconds seconds',
      one: 'Slow mode set to $seconds second',
    );
    return '$_temp0';
  }

  @override
  String get slowModeDisabled => 'Slow mode disabled';

  @override
  String get failedSetSlowMode => 'Failed to set slow mode';

  @override
  String get failedUpdateSlowMode => 'Failed to update slow mode';

  @override
  String get donateMenuLabel => 'Donate';

  @override
  String get pollsMenuLabel => 'Polls';

  @override
  String get supportThisCommunityTitle => 'Support this community';

  @override
  String get donationDisclaimer =>
      'ONYX does not process these payments and cannot refund them. Only send crypto to addresses you trust.';

  @override
  String get noDonationsOwnerHint =>
      'No donation addresses yet. Tap \"Edit\" to add some.';

  @override
  String get noDonationsMemberHint =>
      'This community has not set up donations yet.';

  @override
  String get editDonationsTitle => 'Edit donation addresses';

  @override
  String get donationCoinLabel => 'Coin (e.g. BTC)';

  @override
  String get donationAddressLabel => 'Address';

  @override
  String get addDonationAddress => 'Add address';

  @override
  String get donationsSaved => 'Donation addresses saved';

  @override
  String get failedSaveDonations => 'Failed to save donation addresses';

  @override
  String get noPollsOwnerHint =>
      'No polls yet. Tap \"New poll\" to create one.';

  @override
  String get noPollsHint => 'No polls yet.';

  @override
  String get newPollAction => 'New poll';

  @override
  String get addPollOption => 'Add option';

  @override
  String get pollQuestionLabel => 'Question';

  @override
  String pollOptionLabel(int number) {
    return 'Option $number';
  }

  @override
  String get multipleChoiceLabel => 'Multiple choice';

  @override
  String get pollQuestionEmpty => 'Question cannot be empty';

  @override
  String get pollNeedsTwoOptions => 'Add at least 2 options';

  @override
  String get failedCreatePoll => 'Failed to create poll';

  @override
  String get failedVote => 'Failed to submit vote';

  @override
  String pollVoteCountAnonymous(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
    );
    return '$_temp0 • anonymous';
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
