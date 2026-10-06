import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
    Locale('ru')
  ];

  /// No description provided for @navChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// No description provided for @navGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get navGroups;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @supportOnyx.
  ///
  /// In en, this message translates to:
  /// **'Support ONYX'**
  String get supportOnyx;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get securityTitle;

  /// No description provided for @securitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to view tips and encryption details'**
  String get securitySubtitle;

  /// No description provided for @tipOfTheDay.
  ///
  /// In en, this message translates to:
  /// **'Tip of the day'**
  String get tipOfTheDay;

  /// No description provided for @statusSettings.
  ///
  /// In en, this message translates to:
  /// **'Status Settings'**
  String get statusSettings;

  /// No description provided for @showDisplayNameInGroups.
  ///
  /// In en, this message translates to:
  /// **'Show my display name in groups'**
  String get showDisplayNameInGroups;

  /// No description provided for @showDisplayNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, your messages appear as \"Anonymous\"'**
  String get showDisplayNameSubtitle;

  /// No description provided for @pinLock.
  ///
  /// In en, this message translates to:
  /// **'PIN Lock'**
  String get pinLock;

  /// No description provided for @enablePinLock.
  ///
  /// In en, this message translates to:
  /// **'Enable PIN Lock'**
  String get enablePinLock;

  /// No description provided for @enablePinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require a 4-digit PIN to unlock the app on launch'**
  String get enablePinSubtitle;

  /// No description provided for @pinLockEnabled.
  ///
  /// In en, this message translates to:
  /// **' PIN Lock enabled'**
  String get pinLockEnabled;

  /// No description provided for @pinLockDisabled.
  ///
  /// In en, this message translates to:
  /// **'PIN Lock disabled'**
  String get pinLockDisabled;

  /// No description provided for @useBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use Biometrics'**
  String get useBiometrics;

  /// No description provided for @useBiometricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint or face recognition'**
  String get useBiometricsSubtitle;

  /// No description provided for @biometricsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometrics not available on this device'**
  String get biometricsUnavailable;

  /// No description provided for @lockOnResume.
  ///
  /// In en, this message translates to:
  /// **'Lock when backgrounded'**
  String get lockOnResume;

  /// No description provided for @lockOnResumeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require PIN every time the app returns to foreground'**
  String get lockOnResumeSubtitle;

  /// No description provided for @pinScreenSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get pinScreenSetTitle;

  /// No description provided for @pinScreenConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinScreenConfirmTitle;

  /// No description provided for @pinScreenEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get pinScreenEnterTitle;

  /// No description provided for @pinScreenChooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4-digit PIN'**
  String get pinScreenChooseSubtitle;

  /// No description provided for @pinScreenChooseChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4-digit PIN for this chat'**
  String get pinScreenChooseChatSubtitle;

  /// No description provided for @pinScreenReenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your PIN to confirm'**
  String get pinScreenReenterSubtitle;

  /// No description provided for @pinScreenUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit PIN to unlock'**
  String get pinScreenUnlockSubtitle;

  /// No description provided for @pinScreenGenericSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit PIN'**
  String get pinScreenGenericSubtitle;

  /// No description provided for @pinScreenDisableHeader.
  ///
  /// In en, this message translates to:
  /// **'Enter current PIN to disable'**
  String get pinScreenDisableHeader;

  /// No description provided for @pinScreenMismatchError.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match. Try again.'**
  String get pinScreenMismatchError;

  /// No description provided for @pinScreenIncorrectError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get pinScreenIncorrectError;

  /// No description provided for @searchChatsHint.
  ///
  /// In en, this message translates to:
  /// **'Search chats and messages…'**
  String get searchChatsHint;

  /// No description provided for @searchGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Search groups and messages…'**
  String get searchGroupsHint;

  /// No description provided for @searchFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Search favorites…'**
  String get searchFavoritesHint;

  /// No description provided for @searchSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Search settings…'**
  String get searchSettingsHint;

  /// No description provided for @keyMgmtTitle.
  ///
  /// In en, this message translates to:
  /// **'Key Management'**
  String get keyMgmtTitle;

  /// No description provided for @keyMgmtSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rotate or reset your encryption identity'**
  String get keyMgmtSubtitle;

  /// No description provided for @keyMgmtDescription.
  ///
  /// In en, this message translates to:
  /// **'Rotate your E2EE identity key if you suspect it was compromised. Contacts receive the new key automatically.'**
  String get keyMgmtDescription;

  /// No description provided for @rotateE2eeKey.
  ///
  /// In en, this message translates to:
  /// **'Rotate E2EE Key'**
  String get rotateE2eeKey;

  /// No description provided for @rotateE2eeKeyPrimaryOnly.
  ///
  /// In en, this message translates to:
  /// **'Rotate E2EE Key (primary device only)'**
  String get rotateE2eeKeyPrimaryOnly;

  /// No description provided for @rotateKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rotate encryption key?'**
  String get rotateKeyDialogTitle;

  /// No description provided for @rotateKeyDialogContent.
  ///
  /// In en, this message translates to:
  /// **'A new X25519 keypair will be generated and uploaded to the server.nnYour session and message history are NOT affected. Contacts will automatically use the new key on their next message.'**
  String get rotateKeyDialogContent;

  /// No description provided for @rotateKeyBtn.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotateKeyBtn;

  /// No description provided for @rotatingKey.
  ///
  /// In en, this message translates to:
  /// **' Rotating key…'**
  String get rotatingKey;

  /// No description provided for @keyRotated.
  ///
  /// In en, this message translates to:
  /// **' E2EE key rotated and uploaded'**
  String get keyRotated;

  /// No description provided for @keyRotationFailed.
  ///
  /// In en, this message translates to:
  /// **' Key rotation failed'**
  String get keyRotationFailed;

  /// No description provided for @activeDevices.
  ///
  /// In en, this message translates to:
  /// **'Active Devices'**
  String get activeDevices;

  /// No description provided for @activeDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Devices, password and encryption key'**
  String get activeDevicesSubtitle;

  /// No description provided for @activeDevicesPrimaryOnly.
  ///
  /// In en, this message translates to:
  /// **'Active Devices (primary device only)'**
  String get activeDevicesPrimaryOnly;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @changePasswordPrimaryOnly.
  ///
  /// In en, this message translates to:
  /// **'Change Password (primary device only)'**
  String get changePasswordPrimaryOnly;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage alerts and delivery options'**
  String get notificationsSubtitle;

  /// No description provided for @notificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get notificationsEnabled;

  /// No description provided for @notificationsEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show system notifications for new messages'**
  String get notificationsEnabledSubtitle;

  /// No description provided for @notificationPosition.
  ///
  /// In en, this message translates to:
  /// **'Notification Position'**
  String get notificationPosition;

  /// No description provided for @notifPosTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Top Left'**
  String get notifPosTopLeft;

  /// No description provided for @notifPosTopRight.
  ///
  /// In en, this message translates to:
  /// **'Top Right'**
  String get notifPosTopRight;

  /// No description provided for @notifPosBottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom Left'**
  String get notifPosBottomLeft;

  /// No description provided for @notifPosBottomRight.
  ///
  /// In en, this message translates to:
  /// **'Bottom Right'**
  String get notifPosBottomRight;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose theme and dark mode'**
  String get appearanceSubtitle;

  /// No description provided for @selectTheme.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @fontAndTextSize.
  ///
  /// In en, this message translates to:
  /// **'Font & Text Size'**
  String get fontAndTextSize;

  /// No description provided for @fontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font Family'**
  String get fontFamily;

  /// No description provided for @messageSize.
  ///
  /// In en, this message translates to:
  /// **'Message Size'**
  String get messageSize;

  /// No description provided for @fontPreviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get fontPreviewMessage;

  /// No description provided for @ownMessagesRight.
  ///
  /// In en, this message translates to:
  /// **'Own messages: Right'**
  String get ownMessagesRight;

  /// No description provided for @ownMessagesLeft.
  ///
  /// In en, this message translates to:
  /// **'Own messages: Left'**
  String get ownMessagesLeft;

  /// No description provided for @alignAllRight.
  ///
  /// In en, this message translates to:
  /// **'Align all messages right'**
  String get alignAllRight;

  /// No description provided for @alignAllRightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All messages aligned to the right side like a mirror'**
  String get alignAllRightSubtitle;

  /// No description provided for @showAvatarInChats.
  ///
  /// In en, this message translates to:
  /// **'Show avatar in chats list'**
  String get showAvatarInChats;

  /// No description provided for @showAccountIndicator.
  ///
  /// In en, this message translates to:
  /// **'Show current account'**
  String get showAccountIndicator;

  /// No description provided for @showAccountIndicatorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display name and username in the app corner'**
  String get showAccountIndicatorSubtitle;

  /// No description provided for @showAvatarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show contact avatar in chat list'**
  String get showAvatarSubtitle;

  /// No description provided for @chatBackground.
  ///
  /// In en, this message translates to:
  /// **'Chat Background'**
  String get chatBackground;

  /// No description provided for @chatBgSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set an image as chat background'**
  String get chatBgSubtitle;

  /// No description provided for @chooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose Image'**
  String get chooseImage;

  /// No description provided for @clearBackground.
  ///
  /// In en, this message translates to:
  /// **'Clear Background'**
  String get clearBackground;

  /// No description provided for @applyGlobally.
  ///
  /// In en, this message translates to:
  /// **'Apply globally'**
  String get applyGlobally;

  /// No description provided for @applyGloballySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this background in all chats'**
  String get applyGloballySubtitle;

  /// No description provided for @blurBackground.
  ///
  /// In en, this message translates to:
  /// **'Blur background'**
  String get blurBackground;

  /// No description provided for @elementOpacity.
  ///
  /// In en, this message translates to:
  /// **'Element Opacity'**
  String get elementOpacity;

  /// No description provided for @elementBrightness.
  ///
  /// In en, this message translates to:
  /// **'Element Brightness'**
  String get elementBrightness;

  /// No description provided for @uiLayout.
  ///
  /// In en, this message translates to:
  /// **'UI Layout'**
  String get uiLayout;

  /// No description provided for @navBarPosition.
  ///
  /// In en, this message translates to:
  /// **'Navigation Bar Position'**
  String get navBarPosition;

  /// No description provided for @navLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get navLeft;

  /// No description provided for @navBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get navBottom;

  /// No description provided for @inputBarMaxWidth.
  ///
  /// In en, this message translates to:
  /// **'Input Bar Width'**
  String get inputBarMaxWidth;

  /// No description provided for @minimizeBottomNav.
  ///
  /// In en, this message translates to:
  /// **'Minimize Bottom Nav'**
  String get minimizeBottomNav;

  /// No description provided for @minimizeBottomNavSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide labels in bottom navigation bar'**
  String get minimizeBottomNavSubtitle;

  /// No description provided for @swipeTabs.
  ///
  /// In en, this message translates to:
  /// **'Swipe between tabs'**
  String get swipeTabs;

  /// No description provided for @swipeTabsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch tabs with horizontal swipe gesture'**
  String get swipeTabsSubtitle;

  /// No description provided for @smoothScroll.
  ///
  /// In en, this message translates to:
  /// **'Smooth Scrolling'**
  String get smoothScroll;

  /// No description provided for @performanceOptimizations.
  ///
  /// In en, this message translates to:
  /// **'Performance Optimizations'**
  String get performanceOptimizations;

  /// No description provided for @macOsWindowStyle.
  ///
  /// In en, this message translates to:
  /// **'Window Style'**
  String get macOsWindowStyle;

  /// No description provided for @macOsWindowStyleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Window controls style'**
  String get macOsWindowStyleSubtitle;

  /// No description provided for @macOsNativeTitleBar.
  ///
  /// In en, this message translates to:
  /// **'Native macOS (traffic lights)'**
  String get macOsNativeTitleBar;

  /// No description provided for @macOsCustomTitleBar.
  ///
  /// In en, this message translates to:
  /// **'Windows-style (right side)'**
  String get macOsCustomTitleBar;

  /// No description provided for @updateAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableLabel;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateDownload;

  /// No description provided for @cacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cacheTitle;

  /// No description provided for @cacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage local media cache'**
  String get cacheSubtitle;

  /// No description provided for @mediaCacheSize.
  ///
  /// In en, this message translates to:
  /// **'Media messages cache: '**
  String get mediaCacheSize;

  /// No description provided for @clearLocalCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Local Cache'**
  String get clearLocalCache;

  /// No description provided for @clearLocalCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear local cache'**
  String get clearLocalCacheTitle;

  /// No description provided for @clearLocalCacheContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all cached media (voice, images, videos)?nThis does NOT affect server uploads or chat history.'**
  String get clearLocalCacheContent;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @serverMediaCache.
  ///
  /// In en, this message translates to:
  /// **'Server Media Cache'**
  String get serverMediaCache;

  /// No description provided for @serverMediaCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stored on server: images, voice, video.'**
  String get serverMediaCacheSubtitle;

  /// No description provided for @clearServerCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Server Cache'**
  String get clearServerCache;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @dangerZoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wipe local data.'**
  String get dangerZoneSubtitle;

  /// No description provided for @factoryReset.
  ///
  /// In en, this message translates to:
  /// **'Factory Reset'**
  String get factoryReset;

  /// No description provided for @factoryResetHint.
  ///
  /// In en, this message translates to:
  /// **'Select what to reset. At least one option must be chosen.'**
  String get factoryResetHint;

  /// No description provided for @resetDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account from server'**
  String get resetDeleteAccount;

  /// No description provided for @resetDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes @{username} — all messages, media and keys from the server.'**
  String resetDeleteAccountSubtitle(String username);

  /// No description provided for @resetNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account is logged in.'**
  String get resetNoAccount;

  /// No description provided for @resetDeleteLocal.
  ///
  /// In en, this message translates to:
  /// **'Delete local app data'**
  String get resetDeleteLocal;

  /// No description provided for @resetDeleteLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wipes all local chats, keys, settings, cache and media.'**
  String get resetDeleteLocalSubtitle;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed'**
  String get resetFailed;

  /// No description provided for @resetConfirmStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to do this?'**
  String get resetConfirmStep1Title;

  /// No description provided for @resetConfirmStep1Message.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the data you selected. This cannot be undone.'**
  String get resetConfirmStep1Message;

  /// No description provided for @resetConfirmStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get resetConfirmStep2Title;

  /// No description provided for @resetConfirmStep2Message.
  ///
  /// In en, this message translates to:
  /// **'This is your last chance to cancel. Confirming starts the reset immediately.'**
  String get resetConfirmStep2Message;

  /// No description provided for @connectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionTitle;

  /// No description provided for @connectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'WebSocket status & controls'**
  String get connectionSubtitle;

  /// No description provided for @appDataTitle.
  ///
  /// In en, this message translates to:
  /// **'ONYX data folder'**
  String get appDataTitle;

  /// No description provided for @appDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Move the app data folder to another drive'**
  String get appDataSubtitle;

  /// No description provided for @appDataCurrentPath.
  ///
  /// In en, this message translates to:
  /// **'Current folder'**
  String get appDataCurrentPath;

  /// No description provided for @appDataDefault.
  ///
  /// In en, this message translates to:
  /// **'Default (system folder)'**
  String get appDataDefault;

  /// No description provided for @appDataMove.
  ///
  /// In en, this message translates to:
  /// **'Move…'**
  String get appDataMove;

  /// No description provided for @appDataReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get appDataReset;

  /// No description provided for @appDataMigrating.
  ///
  /// In en, this message translates to:
  /// **'Moving data…'**
  String get appDataMigrating;

  /// No description provided for @appDataMigrateError.
  ///
  /// In en, this message translates to:
  /// **'Error during move'**
  String get appDataMigrateError;

  /// No description provided for @appDataRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'Folder changed. Restart ONYX for the change to take effect.'**
  String get appDataRestartRequired;

  /// No description provided for @appDataRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart ONYX'**
  String get appDataRestart;

  /// No description provided for @appDataOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get appDataOpenFolder;

  /// No description provided for @appDataDeleteOldFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete previous folder'**
  String get appDataDeleteOldFolder;

  /// No description provided for @appDataDeleteOldFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the original system data folder left after migration'**
  String get appDataDeleteOldFolderSubtitle;

  /// No description provided for @appDataDeleteOldFolderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the original ONYX data folder?nnThis cannot be undone. Make sure data was migrated successfully.'**
  String get appDataDeleteOldFolderConfirm;

  /// No description provided for @appDataDeleteOldFolderSuccess.
  ///
  /// In en, this message translates to:
  /// **'Previous folder deleted'**
  String get appDataDeleteOldFolderSuccess;

  /// No description provided for @appDataDeleteOldFolderError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting: '**
  String get appDataDeleteOldFolderError;

  /// No description provided for @interactTitle.
  ///
  /// In en, this message translates to:
  /// **'Interaction'**
  String get interactTitle;

  /// No description provided for @interactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'File upload confirmations'**
  String get interactSubtitle;

  /// No description provided for @confirmFileUpload.
  ///
  /// In en, this message translates to:
  /// **'Confirm File Upload'**
  String get confirmFileUpload;

  /// No description provided for @confirmFileUploadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show confirmation dialog before sending files'**
  String get confirmFileUploadSubtitle;

  /// No description provided for @confirmVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirm Voice Message'**
  String get confirmVoiceMessage;

  /// No description provided for @confirmVoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show confirmation dialog before sending voice'**
  String get confirmVoiceSubtitle;

  /// No description provided for @downloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get downloadFolder;

  /// No description provided for @downloadFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where to save received files (default: Downloads/ONYX)'**
  String get downloadFolderSubtitle;

  /// No description provided for @downloadFolderDefault.
  ///
  /// In en, this message translates to:
  /// **'Default (Downloads/ONYX)'**
  String get downloadFolderDefault;

  /// No description provided for @downloadFolderChange.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get downloadFolderChange;

  /// No description provided for @downloadFolderReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get downloadFolderReset;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactTitle;

  /// No description provided for @contactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Website, repository & feedback'**
  String get contactSubtitle;

  /// No description provided for @contactWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official website'**
  String get contactWebsite;

  /// No description provided for @contactRepository.
  ///
  /// In en, this message translates to:
  /// **'Source code (client)'**
  String get contactRepository;

  /// No description provided for @contactRepositoryServer.
  ///
  /// In en, this message translates to:
  /// **'Source code (self-hosted server)'**
  String get contactRepositoryServer;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactEmail;

  /// No description provided for @debugTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug/Logs'**
  String get debugTitle;

  /// No description provided for @debugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Real-time performance & logging'**
  String get debugSubtitle;

  /// No description provided for @debugMode.
  ///
  /// In en, this message translates to:
  /// **'Debug Mode'**
  String get debugMode;

  /// No description provided for @debugModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable performance monitoring & logs'**
  String get debugModeSubtitle;

  /// No description provided for @enableFileLogging.
  ///
  /// In en, this message translates to:
  /// **'Enable File Logging'**
  String get enableFileLogging;

  /// No description provided for @enableFileLoggingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write app logs to disk (disable for privacy)'**
  String get enableFileLoggingSubtitle;

  /// No description provided for @deleteAllLogs.
  ///
  /// In en, this message translates to:
  /// **'Delete All Logs'**
  String get deleteAllLogs;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App interface language'**
  String get languageSubtitle;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed'**
  String get languageChanged;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// No description provided for @deleteChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get deleteChatTitle;

  /// No description provided for @removeFromContacts.
  ///
  /// In en, this message translates to:
  /// **'Remove from contacts'**
  String get removeFromContacts;

  /// No description provided for @blockUserLabel.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get blockUserLabel;

  /// No description provided for @unblockUserLabel.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockUserLabel;

  /// No description provided for @muteUserLabel.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get muteUserLabel;

  /// No description provided for @unmuteUserLabel.
  ///
  /// In en, this message translates to:
  /// **'Unmute notifications'**
  String get unmuteUserLabel;

  /// No description provided for @blockedByUserMessage.
  ///
  /// In en, this message translates to:
  /// **'This user has restricted incoming messages from you.'**
  String get blockedByUserMessage;

  /// No description provided for @unblockUserConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Unblock {name}?'**
  String unblockUserConfirmContent(String name);

  /// No description provided for @blockUserConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Block {name}? They won\'t be able to send you messages.'**
  String blockUserConfirmContent(String name);

  /// No description provided for @deleteChatContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the chat with \"{name}\"? This action cannot be undone.'**
  String deleteChatContent(String name);

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// No description provided for @identityNewIdentityButton.
  ///
  /// In en, this message translates to:
  /// **'New Identity'**
  String get identityNewIdentityButton;

  /// No description provided for @identityInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'How does this work?'**
  String get identityInfoTooltip;

  /// No description provided for @identityInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'A new way to message'**
  String get identityInfoTitle;

  /// No description provided for @identityInfoBody.
  ///
  /// In en, this message translates to:
  /// **'ONYX is moving to a fully decentralized model. Instead of an account on a central server, your identity is now a cryptographic key generated on your own device — a Tor address only you control.\n\nThere is no password and no server that knows who you are. A 12-word seed phrase is the only way to restore this identity on a new device.\n\nMessages to contacts who already have your new address are delivered directly over Tor, peer-to-peer, without passing through any central server. Contacts still on the old system will need to share their new address with you once, the same way you\'d share a phone number.'**
  String get identityInfoBody;

  /// No description provided for @identityTitleChoose.
  ///
  /// In en, this message translates to:
  /// **'Create an identity'**
  String get identityTitleChoose;

  /// No description provided for @identityChooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The key and address are generated locally on this device.'**
  String get identityChooseSubtitle;

  /// No description provided for @identityCreateNewButton.
  ///
  /// In en, this message translates to:
  /// **'New Identity'**
  String get identityCreateNewButton;

  /// No description provided for @identityRestoreLinkButton.
  ///
  /// In en, this message translates to:
  /// **'I already have a seed phrase'**
  String get identityRestoreLinkButton;

  /// No description provided for @identityTitleMnemonic.
  ///
  /// In en, this message translates to:
  /// **'Your seed phrase'**
  String get identityTitleMnemonic;

  /// No description provided for @identityMnemonicIntro.
  ///
  /// In en, this message translates to:
  /// **'Write down these 12 words and keep them somewhere safe.'**
  String get identityMnemonicIntro;

  /// No description provided for @identityMnemonicRestoreNote.
  ///
  /// In en, this message translates to:
  /// **'This is the only way to restore your identity on a new device.'**
  String get identityMnemonicRestoreNote;

  /// No description provided for @identityCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get identityCopyButton;

  /// No description provided for @identityCopiedSnack.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get identityCopiedSnack;

  /// No description provided for @identitySavedConfirm.
  ///
  /// In en, this message translates to:
  /// **'I saved the phrase somewhere safe'**
  String get identitySavedConfirm;

  /// No description provided for @identityContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get identityContinueButton;

  /// No description provided for @identityTitleRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore identity'**
  String get identityTitleRestore;

  /// No description provided for @identityRestoreHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your seed phrase (12 words separated by spaces).'**
  String get identityRestoreHint;

  /// No description provided for @identityRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get identityRestoreButton;

  /// No description provided for @identityBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get identityBackButton;

  /// No description provided for @identityTitleDone.
  ///
  /// In en, this message translates to:
  /// **'Identity ready'**
  String get identityTitleDone;

  /// No description provided for @identityAccountIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get identityAccountIdLabel;

  /// No description provided for @identityAccountIdExplain.
  ///
  /// In en, this message translates to:
  /// **'A stable identifier derived from your key — this is what ties your devices and messages together instead of a username.'**
  String get identityAccountIdExplain;

  /// No description provided for @identityFingerprintLabel.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get identityFingerprintLabel;

  /// No description provided for @identityFingerprintExplain.
  ///
  /// In en, this message translates to:
  /// **'A short code your contacts can use to verify it\'s really you.'**
  String get identityFingerprintExplain;

  /// No description provided for @identityDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get identityDoneButton;

  /// No description provided for @tapToCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy address'**
  String get tapToCopyAddress;

  /// No description provided for @identityErrorCreatePrefix.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create identity'**
  String get identityErrorCreatePrefix;

  /// No description provided for @identityErrorRestorePrefix.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore identity'**
  String get identityErrorRestorePrefix;

  /// No description provided for @identityTitleSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile'**
  String get identityTitleSetup;

  /// No description provided for @identityDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get identityDisplayNameLabel;

  /// No description provided for @identityDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'How contacts will see you'**
  String get identityDisplayNameHint;

  /// No description provided for @identityCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get identityCreateAccountButton;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeTitle;

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Secure end-to-end encrypted messenger'**
  String get welcomeTagline;

  /// No description provided for @otherAccounts.
  ///
  /// In en, this message translates to:
  /// **'Other Identities'**
  String get otherAccounts;

  /// No description provided for @tapToSwitch.
  ///
  /// In en, this message translates to:
  /// **'Tap to switch'**
  String get tapToSwitch;

  /// No description provided for @deleteFromRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account from recent?'**
  String get deleteFromRecentTitle;

  /// No description provided for @authUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username (3-16 chars)'**
  String get authUsernameLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password (min 16 chars)'**
  String get authPasswordLabel;

  /// No description provided for @loginBtn.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginBtn;

  /// No description provided for @registerBtn.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerBtn;

  /// No description provided for @deviceAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Device'**
  String get deviceAuthTitle;

  /// No description provided for @deviceAuthTabScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get deviceAuthTabScan;

  /// No description provided for @deviceAuthTapToScan.
  ///
  /// In en, this message translates to:
  /// **'Tap to scan QR code'**
  String get deviceAuthTapToScan;

  /// No description provided for @deviceAuthLanNote.
  ///
  /// In en, this message translates to:
  /// **'Both devices must be on the same local network'**
  String get deviceAuthLanNote;

  /// No description provided for @loginWithQr.
  ///
  /// In en, this message translates to:
  /// **'Login via QR'**
  String get loginWithQr;

  /// No description provided for @qrAuthWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for phone'**
  String get qrAuthWaitingTitle;

  /// No description provided for @qrAuthWaitingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan this code on an authorized device to transfer the session here'**
  String get qrAuthWaitingSubtitle;

  /// No description provided for @qrAuthSuccess.
  ///
  /// In en, this message translates to:
  /// **'Device authorized'**
  String get qrAuthSuccess;

  /// No description provided for @qrAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'QR auth failed'**
  String get qrAuthFailed;

  /// No description provided for @qrAuthCancelled.
  ///
  /// In en, this message translates to:
  /// **'QR auth cancelled'**
  String get qrAuthCancelled;

  /// No description provided for @authorizeDevice.
  ///
  /// In en, this message translates to:
  /// **'Authorize device'**
  String get authorizeDevice;

  /// No description provided for @authorizeDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow another device to log in by scanning a QR code'**
  String get authorizeDeviceSubtitle;

  /// No description provided for @authorizeDeviceScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code shown on the other device'**
  String get authorizeDeviceScanHint;

  /// No description provided for @authorizeDeviceSuccess.
  ///
  /// In en, this message translates to:
  /// **'Device authorized successfully'**
  String get authorizeDeviceSuccess;

  /// No description provided for @authorizeDeviceFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to authorize device'**
  String get authorizeDeviceFailed;

  /// No description provided for @authorizeDeviceSending.
  ///
  /// In en, this message translates to:
  /// **'Sending credentials…'**
  String get authorizeDeviceSending;

  /// No description provided for @qrAuthEncryptedNote.
  ///
  /// In en, this message translates to:
  /// **'Transfer is encrypted (X25519 + AES-256-GCM)'**
  String get qrAuthEncryptedNote;

  /// No description provided for @scanFromPc.
  ///
  /// In en, this message translates to:
  /// **'Receive from PC'**
  String get scanFromPc;

  /// No description provided for @scanFromPcHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code shown on another device to sign in here'**
  String get scanFromPcHint;

  /// No description provided for @grantDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Authorize phone'**
  String get grantDeviceTitle;

  /// No description provided for @grantDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan this code on another device to sign in there with this account'**
  String get grantDeviceSubtitle;

  /// No description provided for @grantDeviceSuccess.
  ///
  /// In en, this message translates to:
  /// **'Phone authorized successfully'**
  String get grantDeviceSuccess;

  /// No description provided for @grantDeviceFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to authorize phone'**
  String get grantDeviceFailed;

  /// No description provided for @enterUsernameMsg.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get enterUsernameMsg;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get loginSuccess;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @registeringMsg.
  ///
  /// In en, this message translates to:
  /// **'Registering...'**
  String get registeringMsg;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **' Registration failed'**
  String get registrationFailed;

  /// No description provided for @usernameInvalidMsg.
  ///
  /// In en, this message translates to:
  /// **'Username: 3-16 chars, only letters, digits, _ . -'**
  String get usernameInvalidMsg;

  /// No description provided for @passwordTooShortMsg.
  ///
  /// In en, this message translates to:
  /// **'Password too short (min 16)'**
  String get passwordTooShortMsg;

  /// No description provided for @generatePasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Generate strong password'**
  String get generatePasswordTooltip;

  /// No description provided for @savePasswordWarning.
  ///
  /// In en, this message translates to:
  /// **'Make sure to save your password in a safe place — write it down. Recovery without a password is impossible.'**
  String get savePasswordWarning;

  /// No description provided for @passphraseWriteDown.
  ///
  /// In en, this message translates to:
  /// **'This passphrase will never be shown again. Write down these 12 words by hand and keep them somewhere safe — you\'ll need them to recover your account if you forget your password.'**
  String get passphraseWriteDown;

  /// No description provided for @passphraseWriteOnPaper.
  ///
  /// In en, this message translates to:
  /// **'Write your passphrase on paper right now — there will be no second chance!'**
  String get passphraseWriteOnPaper;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyToClipboard;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get copiedToClipboard;

  /// No description provided for @passphraseCountdown.
  ///
  /// In en, this message translates to:
  /// **'Please read carefully — available in {s} s...'**
  String passphraseCountdown(int s);

  /// No description provided for @iSavedIt.
  ///
  /// In en, this message translates to:
  /// **'I\'ve saved it'**
  String get iSavedIt;

  /// No description provided for @deleteFromRecentContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{acc}\" from the recent list?'**
  String deleteFromRecentContent(String acc);

  /// No description provided for @createGroupChannel.
  ///
  /// In en, this message translates to:
  /// **'Create Group/Channel'**
  String get createGroupChannel;

  /// No description provided for @channelAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Channel (only admin posts)'**
  String get channelAdminOnly;

  /// No description provided for @viewByToken.
  ///
  /// In en, this message translates to:
  /// **'View by token'**
  String get viewByToken;

  /// No description provided for @viewByIp.
  ///
  /// In en, this message translates to:
  /// **'View by IP (external server)'**
  String get viewByIp;

  /// No description provided for @createGroupOrChannel.
  ///
  /// In en, this message translates to:
  /// **'Create group or channel'**
  String get createGroupOrChannel;

  /// No description provided for @removeExternalServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove external server?'**
  String get removeExternalServerTitle;

  /// No description provided for @removeExternalServerContent.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" and all its groups from your list? You can rejoin later by entering the server address again.'**
  String removeExternalServerContent(String name);

  /// No description provided for @noGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get noGroupsYet;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name:'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get groupNameHint;

  /// No description provided for @pasteToken.
  ///
  /// In en, this message translates to:
  /// **'Paste token:'**
  String get pasteToken;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @leaveGroupAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveGroupAction;

  /// No description provided for @leaveGroupContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave \"{name}\"? You will no longer receive messages from it.'**
  String leaveGroupContent(String name);

  /// No description provided for @chooseCrypto.
  ///
  /// In en, this message translates to:
  /// **'Choose a crypto to donate'**
  String get chooseCrypto;

  /// No description provided for @addressCopied.
  ///
  /// In en, this message translates to:
  /// **'address copied'**
  String get addressCopied;

  /// No description provided for @hideFromSearch.
  ///
  /// In en, this message translates to:
  /// **'Hide me from search'**
  String get hideFromSearch;

  /// No description provided for @hideFromSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Others won\'t find you by username search'**
  String get hideFromSearchSubtitle;

  /// No description provided for @hideFromSearchSavedOk.
  ///
  /// In en, this message translates to:
  /// **' Privacy settings saved'**
  String get hideFromSearchSavedOk;

  /// No description provided for @hideFromSearchSavedFail.
  ///
  /// In en, this message translates to:
  /// **' Saved locally, failed to sync'**
  String get hideFromSearchSavedFail;

  /// No description provided for @statusVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get statusVisibility;

  /// No description provided for @statusShowStatus.
  ///
  /// In en, this message translates to:
  /// **'Show Status'**
  String get statusShowStatus;

  /// No description provided for @statusHideStatus.
  ///
  /// In en, this message translates to:
  /// **'Hide Status'**
  String get statusHideStatus;

  /// No description provided for @statusCustomText.
  ///
  /// In en, this message translates to:
  /// **'Custom Status Text'**
  String get statusCustomText;

  /// No description provided for @statusWhenOnline.
  ///
  /// In en, this message translates to:
  /// **'When Online'**
  String get statusWhenOnline;

  /// No description provided for @statusWhenOffline.
  ///
  /// In en, this message translates to:
  /// **'When Offline'**
  String get statusWhenOffline;

  /// No description provided for @statusSavedOk.
  ///
  /// In en, this message translates to:
  /// **' Status settings saved and synced'**
  String get statusSavedOk;

  /// No description provided for @statusSavedFail.
  ///
  /// In en, this message translates to:
  /// **' Saved locally, failed to sync to server'**
  String get statusSavedFail;

  /// No description provided for @clearServerCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear server media?'**
  String get clearServerCacheTitle;

  /// No description provided for @clearServerCacheContent.
  ///
  /// In en, this message translates to:
  /// **'This will delete ALL your uploaded media from the server, including:n\'\n        \'• Voice messagesn\'\n        \'• Imagesn\'\n        \'• Videosn\'\n        \'• Filesn\'\n        \'• Avatarnn\'\n        \'Local cache will remain. This action cannot be undone.'**
  String get clearServerCacheContent;

  /// No description provided for @serverMediaCleared.
  ///
  /// In en, this message translates to:
  /// **' All server media cleared'**
  String get serverMediaCleared;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// No description provided for @serverMediaManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Media'**
  String get serverMediaManagerTitle;

  /// No description provided for @cacheTabImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get cacheTabImages;

  /// No description provided for @cacheTabVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get cacheTabVoice;

  /// No description provided for @cacheTabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get cacheTabAudio;

  /// No description provided for @cacheTabVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get cacheTabVideo;

  /// No description provided for @cacheTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get cacheTabFiles;

  /// No description provided for @cacheTabDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get cacheTabDocuments;

  /// No description provided for @cacheTabArchives.
  ///
  /// In en, this message translates to:
  /// **'Archives'**
  String get cacheTabArchives;

  /// No description provided for @cacheTabData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get cacheTabData;

  /// No description provided for @cacheTabAvatars.
  ///
  /// In en, this message translates to:
  /// **'Avatars'**
  String get cacheTabAvatars;

  /// No description provided for @cacheNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files in this category'**
  String get cacheNoFiles;

  /// No description provided for @cacheClearTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear category?'**
  String get cacheClearTabTitle;

  /// No description provided for @cacheClearTabContent.
  ///
  /// In en, this message translates to:
  /// **'Delete all files in \"{typeName}\"? This cannot be undone.'**
  String cacheClearTabContent(String typeName);

  /// No description provided for @cacheFileDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete file'**
  String get cacheFileDeleteFailed;

  /// No description provided for @cacheClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get cacheClearAll;

  /// No description provided for @cacheClearTab.
  ///
  /// In en, this message translates to:
  /// **'Clear tab'**
  String get cacheClearTab;

  /// No description provided for @cleanUnusedFiles.
  ///
  /// In en, this message translates to:
  /// **'Clean unused files'**
  String get cleanUnusedFiles;

  /// No description provided for @cleaningUnusedFiles.
  ///
  /// In en, this message translates to:
  /// **'Cleaning...'**
  String get cleaningUnusedFiles;

  /// No description provided for @orphanedCleanupAppNotReady.
  ///
  /// In en, this message translates to:
  /// **'App not ready'**
  String get orphanedCleanupAppNotReady;

  /// No description provided for @orphanedCleanupNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No unused files found'**
  String get orphanedCleanupNoFiles;

  /// No description provided for @manageCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Cache'**
  String get manageCacheTitle;

  /// No description provided for @manageCacheButton.
  ///
  /// In en, this message translates to:
  /// **'Manage Media Cache'**
  String get manageCacheButton;

  /// No description provided for @localCacheTab.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localCacheTab;

  /// No description provided for @serverCacheTab.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverCacheTab;

  /// No description provided for @cacheSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get cacheSelectAll;

  /// No description provided for @cacheDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get cacheDeselectAll;

  /// No description provided for @cacheSelected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get cacheSelected;

  /// No description provided for @clearLocalCacheDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear local cache'**
  String get clearLocalCacheDialogTitle;

  /// No description provided for @clearLocalCacheDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all cached media (voice, images, videos)?\nThis does NOT affect chat history.'**
  String get clearLocalCacheDialogContent;

  /// No description provided for @deleteAllLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all logs?'**
  String get deleteAllLogsTitle;

  /// No description provided for @deleteAllLogsContent.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all app log files from disk.\nThis action cannot be undone.'**
  String get deleteAllLogsContent;

  /// No description provided for @noLogsFound.
  ///
  /// In en, this message translates to:
  /// **'No log files found.'**
  String get noLogsFound;

  /// No description provided for @changePasswordInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery passphrase and current password to set a new password.'**
  String get changePasswordInfo;

  /// No description provided for @changePasswordPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery passphrase (12 words)'**
  String get changePasswordPassphraseLabel;

  /// No description provided for @changePasswordCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changePasswordCurrentLabel;

  /// No description provided for @changePasswordNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New password (min 16 chars)'**
  String get changePasswordNewLabel;

  /// No description provided for @changePasswordChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changePasswordChange;

  /// No description provided for @changePasswordFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'All fields are required'**
  String get changePasswordFieldsRequired;

  /// No description provided for @changePasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'New password must be at least 16 characters'**
  String get changePasswordTooShort;

  /// No description provided for @changePasswordChanging.
  ///
  /// In en, this message translates to:
  /// **'Changing password...'**
  String get changePasswordChanging;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **' Password changed successfully'**
  String get changePasswordSuccess;

  /// No description provided for @clearBgTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear background?'**
  String get clearBgTitle;

  /// No description provided for @clearBgContent.
  ///
  /// In en, this message translates to:
  /// **'Remove custom chat background and restore default.'**
  String get clearBgContent;

  /// No description provided for @chatBgSet.
  ///
  /// In en, this message translates to:
  /// **' Chat background set'**
  String get chatBgSet;

  /// No description provided for @chatBgCleared.
  ///
  /// In en, this message translates to:
  /// **'Background cleared'**
  String get chatBgCleared;

  /// No description provided for @sendAsCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Send as code?'**
  String get sendAsCodeTitle;

  /// No description provided for @sendAsCodeContent.
  ///
  /// In en, this message translates to:
  /// **'This message looks like code. Send it as a formatted code block?'**
  String get sendAsCodeContent;

  /// No description provided for @sendAsCode.
  ///
  /// In en, this message translates to:
  /// **'Send as code'**
  String get sendAsCode;

  /// No description provided for @sendAsPlainText.
  ///
  /// In en, this message translates to:
  /// **'Send as text'**
  String get sendAsPlainText;

  /// No description provided for @allMessagesLeft.
  ///
  /// In en, this message translates to:
  /// **'All messages: Left'**
  String get allMessagesLeft;

  /// No description provided for @allMessagesRight2.
  ///
  /// In en, this message translates to:
  /// **'All messages: Right'**
  String get allMessagesRight2;

  /// No description provided for @allMessagesMixed.
  ///
  /// In en, this message translates to:
  /// **'All messages: Mixed'**
  String get allMessagesMixed;

  /// No description provided for @applyBackgroundToApp.
  ///
  /// In en, this message translates to:
  /// **'Apply background to whole app'**
  String get applyBackgroundToApp;

  /// No description provided for @uiElementsOpacityLabel.
  ///
  /// In en, this message translates to:
  /// **'UI Elements Opacity'**
  String get uiElementsOpacityLabel;

  /// No description provided for @uiElementsBrightnessLabel.
  ///
  /// In en, this message translates to:
  /// **'UI Elements Brightness'**
  String get uiElementsBrightnessLabel;

  /// No description provided for @navPanelPosition.
  ///
  /// In en, this message translates to:
  /// **'Navigation Panel Position'**
  String get navPanelPosition;

  /// No description provided for @navPosBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom (under chat list)'**
  String get navPosBottom;

  /// No description provided for @navPosLeft.
  ///
  /// In en, this message translates to:
  /// **'Left (sidebar)'**
  String get navPosLeft;

  /// No description provided for @tabSwiping.
  ///
  /// In en, this message translates to:
  /// **'Tab Swiping'**
  String get tabSwiping;

  /// No description provided for @tabSwipingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe between tabs with a bounce effect'**
  String get tabSwipingSubtitle;

  /// No description provided for @showAvatarsInChats.
  ///
  /// In en, this message translates to:
  /// **'Show avatars in chats'**
  String get showAvatarsInChats;

  /// No description provided for @smoothScrollDown.
  ///
  /// In en, this message translates to:
  /// **'Smooth scroll down'**
  String get smoothScrollDown;

  /// No description provided for @messageAnimations.
  ///
  /// In en, this message translates to:
  /// **'Message animations'**
  String get messageAnimations;

  /// No description provided for @chatListMoveAnimations.
  ///
  /// In en, this message translates to:
  /// **'Chat list move animations'**
  String get chatListMoveAnimations;

  /// No description provided for @scrollDownButtonPosition.
  ///
  /// In en, this message translates to:
  /// **'Scroll-down button position'**
  String get scrollDownButtonPosition;

  /// No description provided for @scrollDownButtonPositionLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get scrollDownButtonPositionLeft;

  /// No description provided for @scrollDownButtonPositionCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get scrollDownButtonPositionCenter;

  /// No description provided for @scrollDownButtonPositionRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get scrollDownButtonPositionRight;

  /// No description provided for @scrollDownButtonSize.
  ///
  /// In en, this message translates to:
  /// **'Scroll-down button size'**
  String get scrollDownButtonSize;

  /// No description provided for @loadOlderMessagesOnScroll.
  ///
  /// In en, this message translates to:
  /// **'Load older messages on scroll'**
  String get loadOlderMessagesOnScroll;

  /// No description provided for @showSnackbars.
  ///
  /// In en, this message translates to:
  /// **'Show snackbars'**
  String get showSnackbars;

  /// No description provided for @autoLoadVideos.
  ///
  /// In en, this message translates to:
  /// **'Auto-load videos'**
  String get autoLoadVideos;

  /// No description provided for @autoLoadVideosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, videos load only on tap — smoother scrolling'**
  String get autoLoadVideosSubtitle;

  /// No description provided for @tapToLoadVideo.
  ///
  /// In en, this message translates to:
  /// **'Tap to load video'**
  String get tapToLoadVideo;

  /// No description provided for @chooseBackground.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get chooseBackground;

  /// No description provided for @presetsBackground.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presetsBackground;

  /// No description provided for @clearBackground2.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearBackground2;

  /// No description provided for @liquidGlassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure glass effects and quality per element'**
  String get liquidGlassSubtitle;

  /// No description provided for @liquidGlassNavBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Navigation Bar'**
  String get liquidGlassNavBarLabel;

  /// No description provided for @liquidGlassNavBarDesc.
  ///
  /// In en, this message translates to:
  /// **'Glass effect on the bottom navigation bar'**
  String get liquidGlassNavBarDesc;

  /// No description provided for @liquidGlassInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Input Bar'**
  String get liquidGlassInputLabel;

  /// No description provided for @liquidGlassInputDesc.
  ///
  /// In en, this message translates to:
  /// **'Glass effect on the message composition bar'**
  String get liquidGlassInputDesc;

  /// No description provided for @liquidGlassSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get liquidGlassSearchLabel;

  /// No description provided for @liquidGlassSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Spotlight-style glass panel for user search'**
  String get liquidGlassSearchDesc;

  /// No description provided for @liquidGlassAppBarLabel.
  ///
  /// In en, this message translates to:
  /// **'App Bar Buttons'**
  String get liquidGlassAppBarLabel;

  /// No description provided for @liquidGlassAppBarDesc.
  ///
  /// In en, this message translates to:
  /// **'Glass effect on the chat app bar\'s icon buttons'**
  String get liquidGlassAppBarDesc;

  /// No description provided for @sendFavoritesScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code shown on the receiver device'**
  String get sendFavoritesScanHint;

  /// No description provided for @mediaPickerGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get mediaPickerGallery;

  /// No description provided for @mediaPickerCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get mediaPickerCamera;

  /// No description provided for @mediaPickerFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get mediaPickerFile;

  /// No description provided for @mediaPickerSend.
  ///
  /// In en, this message translates to:
  /// **'Send {n}'**
  String mediaPickerSend(int n);

  /// No description provided for @mediaPickerChooseWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Choose wallpaper'**
  String get mediaPickerChooseWallpaper;

  /// No description provided for @mediaPickerFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get mediaPickerFiles;

  /// No description provided for @mediaPickerDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery access denied'**
  String get mediaPickerDeniedTitle;

  /// No description provided for @mediaPickerDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Allow access in settings or pick a file directly.'**
  String get mediaPickerDeniedBody;

  /// No description provided for @mediaPickerPickFile.
  ///
  /// In en, this message translates to:
  /// **'Pick File'**
  String get mediaPickerPickFile;

  /// No description provided for @mediaPickerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get mediaPickerOpenSettings;

  /// No description provided for @notifWarning.
  ///
  /// In en, this message translates to:
  /// **'Notifications are delivered only while the app is running. To never miss a message, keep ONYX minimised to the system tray instead of closing it.'**
  String get notifWarning;

  /// No description provided for @backgroundServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Background service'**
  String get backgroundServiceTitle;

  /// No description provided for @backgroundServiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep ONYX connected while minimised'**
  String get backgroundServiceSubtitle;

  /// No description provided for @backgroundServiceEnableLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep running in background'**
  String get backgroundServiceEnableLabel;

  /// No description provided for @backgroundServiceEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows an ongoing notification so the OS doesn\'t stop ONYX from receiving messages while minimised'**
  String get backgroundServiceEnableSubtitle;

  /// No description provided for @backgroundServiceTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification text'**
  String get backgroundServiceTextLabel;

  /// No description provided for @backgroundServiceDefaultText.
  ///
  /// In en, this message translates to:
  /// **'Waiting for messages'**
  String get backgroundServiceDefaultText;

  /// No description provided for @notifPopupPosition.
  ///
  /// In en, this message translates to:
  /// **'Popup position'**
  String get notifPopupPosition;

  /// No description provided for @notifPopupPositionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose where the notification popup appears on screen'**
  String get notifPopupPositionSubtitle;

  /// No description provided for @notifEnableLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get notifEnableLabel;

  /// No description provided for @notifHideContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Hide message content'**
  String get notifHideContentLabel;

  /// No description provided for @notifSoundEnableLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification sound'**
  String get notifSoundEnableLabel;

  /// No description provided for @notifSoundChooseLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose sound'**
  String get notifSoundChooseLabel;

  /// No description provided for @notifSoundCustom.
  ///
  /// In en, this message translates to:
  /// **'Upload custom sound...'**
  String get notifSoundCustom;

  /// No description provided for @notifSoundCustomLoaded.
  ///
  /// In en, this message translates to:
  /// **'Custom sound set'**
  String get notifSoundCustomLoaded;

  /// No description provided for @notifSoundCustomError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sound'**
  String get notifSoundCustomError;

  /// No description provided for @notifSoundCustomInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Supported: WAV, MP3, M4A, OGG, AAC'**
  String get notifSoundCustomInvalidFormat;

  /// No description provided for @resetting.
  ///
  /// In en, this message translates to:
  /// **'Resetting...'**
  String get resetting;

  /// No description provided for @launchAtStartupLabel.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup'**
  String get launchAtStartupLabel;

  /// No description provided for @launchAtStartupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically start ONYX when you log in'**
  String get launchAtStartupSubtitle;

  /// No description provided for @launchAtStartupEnabled.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup enabled'**
  String get launchAtStartupEnabled;

  /// No description provided for @launchAtStartupDisabled.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup disabled'**
  String get launchAtStartupDisabled;

  /// No description provided for @launchAtStartupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change startup setting'**
  String get launchAtStartupFailed;

  /// No description provided for @avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get avatarUpdated;

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// No description provided for @fileSent.
  ///
  /// In en, this message translates to:
  /// **'File sent'**
  String get fileSent;

  /// No description provided for @imageSent.
  ///
  /// In en, this message translates to:
  /// **'Image sent'**
  String get imageSent;

  /// No description provided for @videoSent.
  ///
  /// In en, this message translates to:
  /// **'Video sent'**
  String get videoSent;

  /// No description provided for @uploadingFile.
  ///
  /// In en, this message translates to:
  /// **'Uploading {name}...'**
  String uploadingFile(String name);

  /// No description provided for @albumSent.
  ///
  /// In en, this message translates to:
  /// **'Album sent ({n} images)'**
  String albumSent(int n);

  /// No description provided for @fileEmpty.
  ///
  /// In en, this message translates to:
  /// **'File is empty'**
  String get fileEmpty;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get networkError;

  /// No description provided for @avatarRemoved.
  ///
  /// In en, this message translates to:
  /// **'Avatar removed'**
  String get avatarRemoved;

  /// No description provided for @uinCopied.
  ///
  /// In en, this message translates to:
  /// **'UIN copied'**
  String get uinCopied;

  /// No description provided for @displayNameLength.
  ///
  /// In en, this message translates to:
  /// **'Display name must be 1–16 characters'**
  String get displayNameLength;

  /// No description provided for @displayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name can\'t be empty'**
  String get displayNameRequired;

  /// No description provided for @displayNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Display name updated'**
  String get displayNameUpdated;

  /// No description provided for @failedSendLan.
  ///
  /// In en, this message translates to:
  /// **'Failed to send via LAN'**
  String get failedSendLan;

  /// No description provided for @fileCancelled.
  ///
  /// In en, this message translates to:
  /// **'File cancelled'**
  String get fileCancelled;

  /// No description provided for @doneRestarting.
  ///
  /// In en, this message translates to:
  /// **'Done! Restarting...'**
  String get doneRestarting;

  /// No description provided for @deleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get deleteMessageTitle;

  /// No description provided for @deleteMessageContent.
  ///
  /// In en, this message translates to:
  /// **'This message will be deleted for both sides.'**
  String get deleteMessageContent;

  /// No description provided for @cannotDeleteMsg.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete: message not yet saved on server'**
  String get cannotDeleteMsg;

  /// No description provided for @deleteForMeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete for me?'**
  String get deleteForMeTitle;

  /// No description provided for @deleteForMeContent.
  ///
  /// In en, this message translates to:
  /// **'This will only remove the message from your device. The other person will still see it.'**
  String get deleteForMeContent;

  /// No description provided for @deleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete message?} other{Delete {count} messages?}}'**
  String deleteSelectedTitle(int count);

  /// No description provided for @deleteSelectedForBoth.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This message will be deleted for both sides.} other{These messages will be deleted for both sides.}}'**
  String deleteSelectedForBoth(int count);

  /// No description provided for @deleteSelectedForMe.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This message will be deleted only for you. The other person will still see it.} other{These messages will be deleted only for you. The other person will still see them.}}'**
  String deleteSelectedForMe(int count);

  /// No description provided for @deleteSelectedMixed.
  ///
  /// In en, this message translates to:
  /// **'Your messages ({mine}) will be deleted for both sides. Messages from the other person ({theirs}) will be deleted only for you.'**
  String deleteSelectedMixed(int mine, int theirs);

  /// No description provided for @deleteFavMessageContent.
  ///
  /// In en, this message translates to:
  /// **'This message will be removed from favorites.'**
  String get deleteFavMessageContent;

  /// No description provided for @pinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'Pinned Message'**
  String get pinnedMessage;

  /// No description provided for @setReminder.
  ///
  /// In en, this message translates to:
  /// **'Set Reminder'**
  String get setReminder;

  /// No description provided for @cancelReminder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Reminder'**
  String get cancelReminder;

  /// No description provided for @reminderSet.
  ///
  /// In en, this message translates to:
  /// **'Reminder set'**
  String get reminderSet;

  /// No description provided for @reminderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Reminder cancelled'**
  String get reminderCancelled;

  /// No description provided for @reminderNotificationPrefix.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderNotificationPrefix;

  /// No description provided for @reminderGenericBody.
  ///
  /// In en, this message translates to:
  /// **'You have a reminder'**
  String get reminderGenericBody;

  /// No description provided for @reminderHourLabel.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get reminderHourLabel;

  /// No description provided for @reminderMinuteLabel.
  ///
  /// In en, this message translates to:
  /// **'Minute'**
  String get reminderMinuteLabel;

  /// No description provided for @reminderPickDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get reminderPickDate;

  /// No description provided for @reminderDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get reminderDateToday;

  /// No description provided for @reminderDateTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get reminderDateTomorrow;

  /// No description provided for @reminderInvalidTime.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid time'**
  String get reminderInvalidTime;

  /// No description provided for @reminderPastTime.
  ///
  /// In en, this message translates to:
  /// **'This time has already passed'**
  String get reminderPastTime;

  /// No description provided for @msgCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get msgCopied;

  /// No description provided for @copiedUsername.
  ///
  /// In en, this message translates to:
  /// **'Copied @{name}'**
  String copiedUsername(String name);

  /// No description provided for @deliveryModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose delivery mode'**
  String get deliveryModeTitle;

  /// No description provided for @deliveryInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get deliveryInternet;

  /// No description provided for @deliveryInternetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send via server (encrypted)'**
  String get deliveryInternetSubtitle;

  /// No description provided for @deliveryLanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send via local network (direct)'**
  String get deliveryLanSubtitle;

  /// No description provided for @deliveryUserNotInLan.
  ///
  /// In en, this message translates to:
  /// **'User not found in LAN'**
  String get deliveryUserNotInLan;

  /// No description provided for @fastChange.
  ///
  /// In en, this message translates to:
  /// **'Fast change'**
  String get fastChange;

  /// No description provided for @fastChangeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Toggle mode on long press'**
  String get fastChangeSubtitle;

  /// No description provided for @lanModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'LAN mode enabled'**
  String get lanModeEnabled;

  /// No description provided for @internetModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Internet mode enabled'**
  String get internetModeEnabled;

  /// No description provided for @previewMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview Message'**
  String get previewMessageTitle;

  /// No description provided for @previewYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Your message:'**
  String get previewYourMessage;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to: {name}'**
  String replyingTo(String name);

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @fileSentLan.
  ///
  /// In en, this message translates to:
  /// **'File sent via LAN'**
  String get fileSentLan;

  /// No description provided for @uploadingImages.
  ///
  /// In en, this message translates to:
  /// **'Uploading {n} images...'**
  String uploadingImages(int n);

  /// No description provided for @albumUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Album upload failed'**
  String get albumUploadFailed;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @voiceCallsTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Calls'**
  String get voiceCallsTitle;

  /// No description provided for @voiceCallsContent.
  ///
  /// In en, this message translates to:
  /// **'Voice calls currently work only over LAN (local network).'**
  String get voiceCallsContent;

  /// No description provided for @supportOnyxBtn.
  ///
  /// In en, this message translates to:
  /// **'Support ONYX'**
  String get supportOnyxBtn;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @securityCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Security check'**
  String get securityCheckTitle;

  /// No description provided for @securityCheckContent.
  ///
  /// In en, this message translates to:
  /// **'Compare these emojis with {name}.\nIf they match — your chat is secure.'**
  String securityCheckContent(String name);

  /// No description provided for @failedToFetchPubkey.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch pubkey'**
  String get failedToFetchPubkey;

  /// No description provided for @userHasNoPubkey.
  ///
  /// In en, this message translates to:
  /// **'User has no pubkey'**
  String get userHasNoPubkey;

  /// No description provided for @galleryMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryMenuLabel;

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryTitle;

  /// No description provided for @galleryTabMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get galleryTabMedia;

  /// No description provided for @galleryTabVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get galleryTabVoice;

  /// No description provided for @galleryTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get galleryTabFiles;

  /// No description provided for @galleryEmptyMedia.
  ///
  /// In en, this message translates to:
  /// **'No photos or videos yet'**
  String get galleryEmptyMedia;

  /// No description provided for @galleryEmptyVoice.
  ///
  /// In en, this message translates to:
  /// **'No voice messages yet'**
  String get galleryEmptyVoice;

  /// No description provided for @galleryEmptyFiles.
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get galleryEmptyFiles;

  /// No description provided for @galleryShowInChat.
  ///
  /// In en, this message translates to:
  /// **'Show in chat'**
  String get galleryShowInChat;

  /// No description provided for @failedDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get failedDelete;

  /// No description provided for @failedEdit.
  ///
  /// In en, this message translates to:
  /// **'Failed to edit message'**
  String get failedEdit;

  /// No description provided for @failedReaction.
  ///
  /// In en, this message translates to:
  /// **'Failed to add reaction'**
  String get failedReaction;

  /// No description provided for @noInternetCached.
  ///
  /// In en, this message translates to:
  /// **'No internet — showing cached messages'**
  String get noInternetCached;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get sendFailed;

  /// No description provided for @mediaUploadNotSupportedWeb.
  ///
  /// In en, this message translates to:
  /// **'Media upload not supported on web'**
  String get mediaUploadNotSupportedWeb;

  /// No description provided for @localFileRequired.
  ///
  /// In en, this message translates to:
  /// **'Local file required'**
  String get localFileRequired;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @voiceUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice upload failed'**
  String get voiceUploadFailed;

  /// No description provided for @voiceCancelled.
  ///
  /// In en, this message translates to:
  /// **'Voice message cancelled'**
  String get voiceCancelled;

  /// No description provided for @uploadingVoice.
  ///
  /// In en, this message translates to:
  /// **'Uploading voice...'**
  String get uploadingVoice;

  /// No description provided for @uploadingAlbumProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading album: {done}/{total} photos'**
  String uploadingAlbumProgress(int done, int total);

  /// No description provided for @uploadingImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploading image...'**
  String get uploadingImageLabel;

  /// No description provided for @uploadingVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploading video...'**
  String get uploadingVideoLabel;

  /// No description provided for @uploadingAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploading audio...'**
  String get uploadingAudioLabel;

  /// No description provided for @uploadingFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploading file...'**
  String get uploadingFileLabel;

  /// No description provided for @leftGroup.
  ///
  /// In en, this message translates to:
  /// **'You have left the group'**
  String get leftGroup;

  /// No description provided for @failedLeaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave group'**
  String get failedLeaveGroup;

  /// No description provided for @avatarOnlyOwnerMod.
  ///
  /// In en, this message translates to:
  /// **'Only owners and moderators can change the avatar'**
  String get avatarOnlyOwnerMod;

  /// No description provided for @failedReadFile.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file'**
  String get failedReadFile;

  /// No description provided for @uploadingAvatar.
  ///
  /// In en, this message translates to:
  /// **'Uploading avatar...'**
  String get uploadingAvatar;

  /// No description provided for @avatarUpdatedGroup.
  ///
  /// In en, this message translates to:
  /// **'Group avatar updated'**
  String get avatarUpdatedGroup;

  /// No description provided for @avatarDeleted.
  ///
  /// In en, this message translates to:
  /// **'Avatar deleted'**
  String get avatarDeleted;

  /// No description provided for @failedDeleteAvatar.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete avatar'**
  String get failedDeleteAvatar;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @tokenCopied.
  ///
  /// In en, this message translates to:
  /// **'Token copied'**
  String get tokenCopied;

  /// No description provided for @groupNameLength.
  ///
  /// In en, this message translates to:
  /// **'Group name must be 1–50 chars'**
  String get groupNameLength;

  /// No description provided for @groupUpdated.
  ///
  /// In en, this message translates to:
  /// **'Group updated'**
  String get groupUpdated;

  /// No description provided for @failedUpdateGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to update group'**
  String get failedUpdateGroup;

  /// No description provided for @deleteAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete avatar?'**
  String get deleteAvatarTitle;

  /// No description provided for @deleteAvatarContent.
  ///
  /// In en, this message translates to:
  /// **'This will remove the group avatar for everyone.'**
  String get deleteAvatarContent;

  /// No description provided for @deleteGroupMsgContent.
  ///
  /// In en, this message translates to:
  /// **'This message will be deleted for everyone.'**
  String get deleteGroupMsgContent;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get editGroupTitle;

  /// No description provided for @editChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit channel'**
  String get editChannelTitle;

  /// No description provided for @groupInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupInfoTitle;

  /// No description provided for @channelInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channelInfoTitle;

  /// No description provided for @channelNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get channelNameLabel;

  /// No description provided for @channelNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter channel name'**
  String get channelNameHint;

  /// No description provided for @unsupportedFileType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type: {ext}'**
  String unsupportedFileType(String ext);

  /// No description provided for @failedToConnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect: {e}'**
  String failedToConnect(String e);

  /// No description provided for @roleChanged.
  ///
  /// In en, this message translates to:
  /// **'Your role was changed to {role}'**
  String roleChanged(String role);

  /// No description provided for @unbannedReconnecting.
  ///
  /// In en, this message translates to:
  /// **'You have been unbanned! Reconnecting...'**
  String get unbannedReconnecting;

  /// No description provided for @onlyModsCanPost.
  ///
  /// In en, this message translates to:
  /// **'Only owner and moderators can post in channels'**
  String get onlyModsCanPost;

  /// No description provided for @failedSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message'**
  String get failedSendMessage;

  /// No description provided for @uploadFailedConnectionAborted.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: Connection aborted. Try smaller file or check server settings.'**
  String get uploadFailedConnectionAborted;

  /// No description provided for @failedSendMedia.
  ///
  /// In en, this message translates to:
  /// **'Failed to send media'**
  String get failedSendMedia;

  /// No description provided for @joinedGroup.
  ///
  /// In en, this message translates to:
  /// **'You have joined the group!'**
  String get joinedGroup;

  /// No description provided for @failedJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to join group'**
  String get failedJoinGroup;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @avatarWillBeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Avatar will be deleted'**
  String get avatarWillBeDeleted;

  /// No description provided for @ipCopied.
  ///
  /// In en, this message translates to:
  /// **'IP copied'**
  String get ipCopied;

  /// No description provided for @nameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get nameCannotBeEmpty;

  /// No description provided for @groupRenamed.
  ///
  /// In en, this message translates to:
  /// **'Group renamed successfully'**
  String get groupRenamed;

  /// No description provided for @errorMsg.
  ///
  /// In en, this message translates to:
  /// **'Error: {e}'**
  String errorMsg(String e);

  /// No description provided for @failedRename.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename'**
  String get failedRename;

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image too large (max 5MB)'**
  String get imageTooLarge;

  /// No description provided for @avatarUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated successfully'**
  String get avatarUpdatedSuccessfully;

  /// No description provided for @failedUploadAvatar.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload avatar'**
  String get failedUploadAvatar;

  /// No description provided for @deletingAvatar.
  ///
  /// In en, this message translates to:
  /// **'Deleting avatar...'**
  String get deletingAvatar;

  /// No description provided for @avatarDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Avatar deleted successfully'**
  String get avatarDeletedSuccessfully;

  /// No description provided for @userBanned.
  ///
  /// In en, this message translates to:
  /// **'{name} banned'**
  String userBanned(String name);

  /// No description provided for @failedBan.
  ///
  /// In en, this message translates to:
  /// **'Failed to ban'**
  String get failedBan;

  /// No description provided for @roleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Role updated to {role}'**
  String roleUpdated(String role);

  /// No description provided for @failedChangeRole.
  ///
  /// In en, this message translates to:
  /// **'Failed to change role'**
  String get failedChangeRole;

  /// No description provided for @userUnbanned.
  ///
  /// In en, this message translates to:
  /// **'{name} unbanned'**
  String userUnbanned(String name);

  /// No description provided for @failedUnban.
  ///
  /// In en, this message translates to:
  /// **'Failed to unban'**
  String get failedUnban;

  /// No description provided for @youHaveBeenBanned.
  ///
  /// In en, this message translates to:
  /// **'You have been banned'**
  String get youHaveBeenBanned;

  /// No description provided for @renameGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Group'**
  String get renameGroupTitle;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @manageMembers.
  ///
  /// In en, this message translates to:
  /// **'Manage members'**
  String get manageMembers;

  /// No description provided for @banMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Ban Member'**
  String get banMemberTitle;

  /// No description provided for @ban.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get ban;

  /// No description provided for @selectNewRole.
  ///
  /// In en, this message translates to:
  /// **'Select new role:'**
  String get selectNewRole;

  /// No description provided for @moderator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get moderator;

  /// No description provided for @memberRole.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get memberRole;

  /// No description provided for @manageMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Members'**
  String get manageMembersTitle;

  /// No description provided for @viewBans.
  ///
  /// In en, this message translates to:
  /// **'View Bans'**
  String get viewBans;

  /// No description provided for @unbanUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Unban User'**
  String get unbanUserTitle;

  /// No description provided for @unban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get unban;

  /// No description provided for @bannedUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Banned Users'**
  String get bannedUsersTitle;

  /// No description provided for @bannedFromGroup.
  ///
  /// In en, this message translates to:
  /// **'You have been banned from this group.'**
  String get bannedFromGroup;

  /// No description provided for @bannedReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String bannedReason(String reason);

  /// No description provided for @noBannedUsers.
  ///
  /// In en, this message translates to:
  /// **'No banned users'**
  String get noBannedUsers;

  /// No description provided for @bannedBy.
  ///
  /// In en, this message translates to:
  /// **'Banned by: {name}'**
  String bannedBy(String name);

  /// No description provided for @bannedDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String bannedDate(String date);

  /// No description provided for @banConfirm.
  ///
  /// In en, this message translates to:
  /// **'Ban {name} from the group?'**
  String banConfirm(String name);

  /// No description provided for @banReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get banReason;

  /// No description provided for @changeRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Change role for {name}'**
  String changeRoleTitle(String name);

  /// No description provided for @currentRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Current role: {role}'**
  String currentRoleLabel(String role);

  /// No description provided for @ownerCount.
  ///
  /// In en, this message translates to:
  /// **'Owners: {n}/3'**
  String ownerCount(int n);

  /// No description provided for @ownerCurrent.
  ///
  /// In en, this message translates to:
  /// **'Owner (current)'**
  String get ownerCurrent;

  /// No description provided for @ownerLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Owner (limit reached)'**
  String get ownerLimitReached;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @cannotDemoteLastOwner.
  ///
  /// In en, this message translates to:
  /// **'Cannot demote the last owner'**
  String get cannotDemoteLastOwner;

  /// No description provided for @noMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get noMembersYet;

  /// No description provided for @changeRole.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get changeRole;

  /// No description provided for @unbanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unban {name}?'**
  String unbanConfirm(String name);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @failedCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group'**
  String get failedCreateGroup;

  /// No description provided for @invalidInviteLinkFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid invite link format'**
  String get invalidInviteLinkFormat;

  /// No description provided for @invalidInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid invite link'**
  String get invalidInviteLink;

  /// No description provided for @groupAddedForViewing.
  ///
  /// In en, this message translates to:
  /// **'Group added for viewing!'**
  String get groupAddedForViewing;

  /// No description provided for @failedAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Failed to add group'**
  String get failedAddGroup;

  /// No description provided for @serverRemoved.
  ///
  /// In en, this message translates to:
  /// **'Server \"{name}\" removed'**
  String serverRemoved(String name);

  /// No description provided for @channelAdminOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Channel (admin only)'**
  String get channelAdminOnlySubtitle;

  /// No description provided for @groupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupSubtitle;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @externalGroup.
  ///
  /// In en, this message translates to:
  /// **'External Group'**
  String get externalGroup;

  /// No description provided for @externalChannel.
  ///
  /// In en, this message translates to:
  /// **'External Channel'**
  String get externalChannel;

  /// No description provided for @joinExternalServer.
  ///
  /// In en, this message translates to:
  /// **'Join External Server'**
  String get joinExternalServer;

  /// No description provided for @enterServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter server address'**
  String get enterServerAddress;

  /// No description provided for @enterValidIp.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IP address or hostname'**
  String get enterValidIp;

  /// No description provided for @couldNotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to {host}'**
  String couldNotConnect(String host);

  /// No description provided for @usernameRequiredMsg.
  ///
  /// In en, this message translates to:
  /// **'Username is required. Please make sure you have created an account in the app.'**
  String get usernameRequiredMsg;

  /// No description provided for @passwordRequiredForGroups.
  ///
  /// In en, this message translates to:
  /// **'Password is required for groups'**
  String get passwordRequiredForGroups;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {e}'**
  String connectionFailed(String e);

  /// No description provided for @connectedToServer.
  ///
  /// In en, this message translates to:
  /// **'Connected to {type} \"{name}\"'**
  String connectedToServer(String type, String name);

  /// No description provided for @externalGroupType.
  ///
  /// In en, this message translates to:
  /// **'external group'**
  String get externalGroupType;

  /// No description provided for @externalChannelType.
  ///
  /// In en, this message translates to:
  /// **'external channel'**
  String get externalChannelType;

  /// No description provided for @identityVisible.
  ///
  /// In en, this message translates to:
  /// **'Your identity will be visible to the server'**
  String get identityVisible;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @noPasswordForChannels.
  ///
  /// In en, this message translates to:
  /// **'No password required for channels'**
  String get noPasswordForChannels;

  /// No description provided for @noRegistrationRequired.
  ///
  /// In en, this message translates to:
  /// **'No registration required.'**
  String get noRegistrationRequired;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @connectBtn.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectBtn;

  /// No description provided for @serverInfoGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get serverInfoGroups;

  /// No description provided for @serverInfoMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get serverInfoMembers;

  /// No description provided for @serverInfoMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get serverInfoMedia;

  /// No description provided for @serverInfoMaxFile.
  ///
  /// In en, this message translates to:
  /// **'Max file size'**
  String get serverInfoMaxFile;

  /// No description provided for @profilePresets.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get profilePresets;

  /// No description provided for @profilePresetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved identities for joining external servers'**
  String get profilePresetsSubtitle;

  /// No description provided for @newPreset.
  ///
  /// In en, this message translates to:
  /// **'New Identity'**
  String get newPreset;

  /// No description provided for @editPreset.
  ///
  /// In en, this message translates to:
  /// **'Edit Identity'**
  String get editPreset;

  /// No description provided for @deletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete Identity'**
  String get deletePreset;

  /// No description provided for @deletePresetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the identity \"{label}\"?'**
  String deletePresetConfirm(String label);

  /// No description provided for @presetLabel.
  ///
  /// In en, this message translates to:
  /// **'Identity name'**
  String get presetLabel;

  /// No description provided for @presetLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Work, Gaming'**
  String get presetLabelHint;

  /// No description provided for @presetNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get presetNote;

  /// No description provided for @presetNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What is this identity for? (optional)'**
  String get presetNoteHint;

  /// No description provided for @presetColor.
  ///
  /// In en, this message translates to:
  /// **'Tag color'**
  String get presetColor;

  /// No description provided for @presetLabelRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the identity'**
  String get presetLabelRequired;

  /// No description provided for @noPresetsYet.
  ///
  /// In en, this message translates to:
  /// **'No identities yet'**
  String get noPresetsYet;

  /// No description provided for @noPresetsYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a username and password combo once, reuse it on any external server'**
  String get noPresetsYetSubtitle;

  /// No description provided for @myPresets.
  ///
  /// In en, this message translates to:
  /// **'My identities'**
  String get myPresets;

  /// No description provided for @usePreset.
  ///
  /// In en, this message translates to:
  /// **'Use identity'**
  String get usePreset;

  /// No description provided for @saveAsPreset.
  ///
  /// In en, this message translates to:
  /// **'Save as identity'**
  String get saveAsPreset;

  /// No description provided for @presetSaved.
  ///
  /// In en, this message translates to:
  /// **'Identity saved'**
  String get presetSaved;

  /// No description provided for @presetDeleted.
  ///
  /// In en, this message translates to:
  /// **'Identity deleted'**
  String get presetDeleted;

  /// No description provided for @thirdPartyServer.
  ///
  /// In en, this message translates to:
  /// **'THIRD-PARTY SERVER'**
  String get thirdPartyServer;

  /// No description provided for @thirdPartyWarning.
  ///
  /// In en, this message translates to:
  /// **'This server is not operated by ONYX. Only connect if you trust the owner.'**
  String get thirdPartyWarning;

  /// No description provided for @serverWillKnow.
  ///
  /// In en, this message translates to:
  /// **'Server will know:'**
  String get serverWillKnow;

  /// No description provided for @serverWillNotReceive.
  ///
  /// In en, this message translates to:
  /// **'Server will NOT receive:'**
  String get serverWillNotReceive;

  /// No description provided for @knowIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Your IP address'**
  String get knowIpAddress;

  /// No description provided for @knowUsername.
  ///
  /// In en, this message translates to:
  /// **'Your chosen username'**
  String get knowUsername;

  /// No description provided for @knowMessages.
  ///
  /// In en, this message translates to:
  /// **'Content of your messages in this server'**
  String get knowMessages;

  /// No description provided for @notReceiveAccount.
  ///
  /// In en, this message translates to:
  /// **'Your ONYX account or password'**
  String get notReceiveAccount;

  /// No description provided for @notReceiveContacts.
  ///
  /// In en, this message translates to:
  /// **'Your contacts and private chats'**
  String get notReceiveContacts;

  /// No description provided for @notReceiveKeys.
  ///
  /// In en, this message translates to:
  /// **'Your encryption keys'**
  String get notReceiveKeys;

  /// No description provided for @yourPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Recovery Passphrase'**
  String get yourPassphraseTitle;

  /// No description provided for @sessionExpiredBanner.
  ///
  /// In en, this message translates to:
  /// **'Session expired — please log in again'**
  String get sessionExpiredBanner;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get sessionExpiredTitle;

  /// No description provided for @sessionExpiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get sessionExpiredSubtitle;

  /// No description provided for @sessionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get sessionSignIn;

  /// No description provided for @sessionRenewSoon.
  ///
  /// In en, this message translates to:
  /// **'Re-login will be required soon'**
  String get sessionRenewSoon;

  /// No description provided for @sessionStillValid.
  ///
  /// In en, this message translates to:
  /// **'Authorization token is valid'**
  String get sessionStillValid;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsersTitle;

  /// No description provided for @blockedUsersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage blocked users'**
  String get blockedUsersSubtitle;

  /// No description provided for @blockedUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get blockedUsersEmpty;

  /// No description provided for @unblockAction.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockAction;

  /// No description provided for @writeMessage.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get writeMessage;

  /// No description provided for @fakePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Fake PIN'**
  String get fakePinTitle;

  /// No description provided for @fakePinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open a decoy account under duress'**
  String get fakePinSubtitle;

  /// No description provided for @fakePinSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Fake PIN Setup'**
  String get fakePinSheetTitle;

  /// No description provided for @fakePinStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get fakePinStatusActive;

  /// No description provided for @fakePinStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get fakePinStatusOff;

  /// No description provided for @fakePinDescription.
  ///
  /// In en, this message translates to:
  /// **'When this PIN is entered at the lock screen, the app opens showing your decoy account instead of your real one.'**
  String get fakePinDescription;

  /// No description provided for @setFakePin.
  ///
  /// In en, this message translates to:
  /// **'Set Fake PIN'**
  String get setFakePin;

  /// No description provided for @disableFakePin.
  ///
  /// In en, this message translates to:
  /// **'Disable Fake PIN'**
  String get disableFakePin;

  /// No description provided for @changeFakePin.
  ///
  /// In en, this message translates to:
  /// **'Change Fake PIN'**
  String get changeFakePin;

  /// No description provided for @disableFakePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable Fake PIN?'**
  String get disableFakePinTitle;

  /// No description provided for @disableFakePinContent.
  ///
  /// In en, this message translates to:
  /// **'The fake PIN will be removed. Your decoy account settings will be kept.'**
  String get disableFakePinContent;

  /// No description provided for @fakePinEnabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Fake PIN enabled'**
  String get fakePinEnabledSnack;

  /// No description provided for @fakePinDisabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Fake PIN disabled'**
  String get fakePinDisabledSnack;

  /// No description provided for @fakePinCannotMatchReal.
  ///
  /// In en, this message translates to:
  /// **'Fake PIN cannot match your real PIN'**
  String get fakePinCannotMatchReal;

  /// No description provided for @decoyAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Decoy Account'**
  String get decoyAccountSection;

  /// No description provided for @decoyAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This account will be shown when the fake PIN is used'**
  String get decoyAccountSubtitle;

  /// No description provided for @decoyDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get decoyDisplayNameLabel;

  /// No description provided for @decoyUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get decoyUsernameLabel;

  /// No description provided for @decoyDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter display name'**
  String get decoyDisplayNameHint;

  /// No description provided for @decoyUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get decoyUsernameHint;

  /// No description provided for @saveDecoyAccount.
  ///
  /// In en, this message translates to:
  /// **'Save decoy account'**
  String get saveDecoyAccount;

  /// No description provided for @decoyAccountSaved.
  ///
  /// In en, this message translates to:
  /// **'Decoy account saved'**
  String get decoyAccountSaved;

  /// No description provided for @decoyFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Username and display name cannot be empty'**
  String get decoyFieldsRequired;

  /// No description provided for @removeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Remove avatar'**
  String get removeAvatar;

  /// No description provided for @fakePinSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'The fake PIN must differ from your real PIN. The decoy account has no server connection — it only shows the profile you configured here.'**
  String get fakePinSecurityNote;

  /// No description provided for @decoyNoChats.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get decoyNoChats;

  /// No description provided for @decoyNoGroups.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get decoyNoGroups;

  /// No description provided for @decoyNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get decoyNoFavorites;

  /// No description provided for @decoyOtherAccounts.
  ///
  /// In en, this message translates to:
  /// **'Other accounts'**
  String get decoyOtherAccounts;

  /// No description provided for @decoyNoOtherAccounts.
  ///
  /// In en, this message translates to:
  /// **'No other accounts'**
  String get decoyNoOtherAccounts;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @decoyAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get decoyAppearance;

  /// No description provided for @decoyNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get decoyNotifications;

  /// No description provided for @decoyStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get decoyStorage;

  /// No description provided for @decoyAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme and display options'**
  String get decoyAppearanceSubtitle;

  /// No description provided for @decoyNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sound and alert settings'**
  String get decoyNotificationsSubtitle;

  /// No description provided for @decoyStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage cached files'**
  String get decoyStorageSubtitle;

  /// No description provided for @decoyContactsSection.
  ///
  /// In en, this message translates to:
  /// **'Fake Chats'**
  String get decoyContactsSection;

  /// No description provided for @decoyContactsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add contacts with messages — they appear when the decoy account is opened'**
  String get decoyContactsSubtitle;

  /// No description provided for @generateContacts.
  ///
  /// In en, this message translates to:
  /// **'Generate Contacts'**
  String get generateContacts;

  /// No description provided for @addDecoyContact.
  ///
  /// In en, this message translates to:
  /// **'Add Contact'**
  String get addDecoyContact;

  /// No description provided for @decoyNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No fake chats yet'**
  String get decoyNoContacts;

  /// No description provided for @decoyContactUsername.
  ///
  /// In en, this message translates to:
  /// **'Contact username'**
  String get decoyContactUsername;

  /// No description provided for @decoyContactDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Contact display name'**
  String get decoyContactDisplayName;

  /// No description provided for @contactsGenerated.
  ///
  /// In en, this message translates to:
  /// **'Added {n} contacts'**
  String contactsGenerated(int n);

  /// No description provided for @contactAdded.
  ///
  /// In en, this message translates to:
  /// **'Contact added'**
  String get contactAdded;

  /// No description provided for @contactRemoved.
  ///
  /// In en, this message translates to:
  /// **'Contact removed'**
  String get contactRemoved;

  /// No description provided for @decoyContactExists.
  ///
  /// In en, this message translates to:
  /// **'Contact already exists'**
  String get decoyContactExists;

  /// No description provided for @decoyContactsCleared.
  ///
  /// In en, this message translates to:
  /// **'All chats cleared'**
  String get decoyContactsCleared;

  /// No description provided for @clearDecoyChats.
  ///
  /// In en, this message translates to:
  /// **'Clear All Chats'**
  String get clearDecoyChats;

  /// No description provided for @messagesCount.
  ///
  /// In en, this message translates to:
  /// **'messages'**
  String get messagesCount;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @decoyChatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts with message history'**
  String get decoyChatsSubtitle;

  /// No description provided for @decoyGroupsSection.
  ///
  /// In en, this message translates to:
  /// **'Groups & Channels'**
  String get decoyGroupsSection;

  /// No description provided for @decoyGroupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fake groups and channels'**
  String get decoyGroupsSubtitle;

  /// No description provided for @decoyFavoritesSection.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get decoyFavoritesSection;

  /// No description provided for @decoyFavoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned favorite chats'**
  String get decoyFavoritesSubtitle;

  /// No description provided for @noFakeGroups.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get noFakeGroups;

  /// No description provided for @noFakeFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFakeFavorites;

  /// No description provided for @addFakeGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get addFakeGroup;

  /// No description provided for @addFakeChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get addFakeChannel;

  /// No description provided for @addFakeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add Favorite'**
  String get addFakeFavorite;

  /// No description provided for @groupType.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupType;

  /// No description provided for @channelType.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channelType;

  /// No description provided for @favTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get favTitleHint;

  /// No description provided for @generateAll.
  ///
  /// In en, this message translates to:
  /// **'Generate All'**
  String get generateAll;

  /// No description provided for @generateAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Random content will be generated, replacing existing data.'**
  String get generateAllConfirm;

  /// No description provided for @sendFavoritesSendChat.
  ///
  /// In en, this message translates to:
  /// **'Send chat'**
  String get sendFavoritesSendChat;

  /// No description provided for @sendFavoritesQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Show to receiver device'**
  String get sendFavoritesQrTitle;

  /// No description provided for @sendFavoritesQrInstruction.
  ///
  /// In en, this message translates to:
  /// **'Open Favorites on the other device → Sync → Receive, then scan this code'**
  String get sendFavoritesQrInstruction;

  /// No description provided for @sendFavoritesWaitingScan.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other device to scan the QR code…'**
  String get sendFavoritesWaitingScan;

  /// No description provided for @sendFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Favorites'**
  String get sendFavoritesTitle;

  /// No description provided for @sendFavoritesShowQrToReceiver.
  ///
  /// In en, this message translates to:
  /// **'Show QR to Receiver'**
  String get sendFavoritesShowQrToReceiver;

  /// No description provided for @sendFavoritesScanReceiver.
  ///
  /// In en, this message translates to:
  /// **'Scan QR\nof the Receiver'**
  String get sendFavoritesScanReceiver;

  /// No description provided for @sendFavoritesSending.
  ///
  /// In en, this message translates to:
  /// **'Sending Favorites'**
  String get sendFavoritesSending;

  /// No description provided for @sendFavoritesSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select chats to send'**
  String get sendFavoritesSelectTitle;

  /// No description provided for @sendFavoritesHintDesktop.
  ///
  /// In en, this message translates to:
  /// **'The receiver must press \"Receive\" first. Then scan the QR code shown here.'**
  String get sendFavoritesHintDesktop;

  /// No description provided for @sendFavoritesHintMobile.
  ///
  /// In en, this message translates to:
  /// **'The receiver must press \"Receive\" first and show the QR code.'**
  String get sendFavoritesHintMobile;

  /// No description provided for @allChatsCount.
  ///
  /// In en, this message translates to:
  /// **'All chats ({n})'**
  String allChatsCount(int n);

  /// No description provided for @sendFavoritesNoFavs.
  ///
  /// In en, this message translates to:
  /// **'No favourite chats yet.'**
  String get sendFavoritesNoFavs;

  /// No description provided for @sendFavoritesSelectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Select at least one chat'**
  String get sendFavoritesSelectAtLeastOne;

  /// No description provided for @sendFavoritesShowQrBtn.
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get sendFavoritesShowQrBtn;

  /// No description provided for @sendFavoritesScanQrBtn.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get sendFavoritesScanQrBtn;

  /// No description provided for @receiveFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive Favorites'**
  String get receiveFavoritesTitle;

  /// No description provided for @receiveFavoritesScanSender.
  ///
  /// In en, this message translates to:
  /// **'Scan QR\nof the Sender'**
  String get receiveFavoritesScanSender;

  /// No description provided for @receiveFavoritesScanOnSender.
  ///
  /// In en, this message translates to:
  /// **'Scan on sender device'**
  String get receiveFavoritesScanOnSender;

  /// No description provided for @receiveFavoritesInstruction.
  ///
  /// In en, this message translates to:
  /// **'Open Favorites on the sender, tap Sync → Send, then scan this code'**
  String get receiveFavoritesInstruction;

  /// No description provided for @receiveFavoritesE2E.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted · local network only'**
  String get receiveFavoritesE2E;

  /// No description provided for @receiveFavoritesScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code shown on the sender device'**
  String get receiveFavoritesScanHint;

  /// No description provided for @receiveFavoritesScanEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Transfer is encrypted · local network only'**
  String get receiveFavoritesScanEncrypted;

  /// No description provided for @receiveFavoritesWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for sender to scan QR code…'**
  String get receiveFavoritesWaiting;

  /// No description provided for @receiveFavoritesComplete.
  ///
  /// In en, this message translates to:
  /// **'Transfer complete.'**
  String get receiveFavoritesComplete;

  /// No description provided for @receiveFavoritesConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to sender…'**
  String get receiveFavoritesConnecting;

  /// No description provided for @receiveFavoritesConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected! Waiting for files…'**
  String get receiveFavoritesConnected;

  /// No description provided for @cancelTransfer.
  ///
  /// In en, this message translates to:
  /// **'Cancel transfer'**
  String get cancelTransfer;

  /// No description provided for @wardLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'WardLink'**
  String get wardLinkTitle;

  /// No description provided for @wardLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Passive sync between your devices on the local network'**
  String get wardLinkSubtitle;

  /// No description provided for @wardLinkEnable.
  ///
  /// In en, this message translates to:
  /// **'Passive sync'**
  String get wardLinkEnable;

  /// No description provided for @wardLinkEnableDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync with trusted devices on the same network. On phones this works while the app is open; on desktop it runs continuously.'**
  String get wardLinkEnableDesc;

  /// No description provided for @wardLinkPairedDevices.
  ///
  /// In en, this message translates to:
  /// **'Trusted devices'**
  String get wardLinkPairedDevices;

  /// No description provided for @wardLinkNoPairedDevices.
  ///
  /// In en, this message translates to:
  /// **'No paired devices yet'**
  String get wardLinkNoPairedDevices;

  /// No description provided for @wardLinkAddDevice.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get wardLinkAddDevice;

  /// No description provided for @wardLinkRemoveDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get wardLinkRemoveDevice;

  /// No description provided for @wardLinkRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop syncing with this device?'**
  String get wardLinkRemoveConfirm;

  /// No description provided for @wardLinkFavoritesOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Syncs your Favorites — their messages and media'**
  String get wardLinkFavoritesOnlyNote;

  /// No description provided for @wardLinkMaxFileSize.
  ///
  /// In en, this message translates to:
  /// **'Max file size'**
  String get wardLinkMaxFileSize;

  /// No description provided for @wardLinkPairTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair device'**
  String get wardLinkPairTitle;

  /// No description provided for @wardLinkShowCode.
  ///
  /// In en, this message translates to:
  /// **'Show code'**
  String get wardLinkShowCode;

  /// No description provided for @wardLinkScanCode.
  ///
  /// In en, this message translates to:
  /// **'Scan code'**
  String get wardLinkScanCode;

  /// No description provided for @wardLinkShowInstruction.
  ///
  /// In en, this message translates to:
  /// **'Open WardLink on your other device and scan this code'**
  String get wardLinkShowInstruction;

  /// No description provided for @wardLinkScanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the WardLink code on the other device'**
  String get wardLinkScanInstruction;

  /// No description provided for @wardLinkPairedOk.
  ///
  /// In en, this message translates to:
  /// **'Device paired'**
  String get wardLinkPairedOk;

  /// No description provided for @wardLinkPairFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed'**
  String get wardLinkPairFailed;

  /// No description provided for @wardLinkE2E.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted · LAN only'**
  String get wardLinkE2E;

  /// No description provided for @wardLinkSyncingNow.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get wardLinkSyncingNow;

  /// No description provided for @wardLinkDone.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get wardLinkDone;

  /// No description provided for @wardLinkCurrentFile.
  ///
  /// In en, this message translates to:
  /// **'Current file'**
  String get wardLinkCurrentFile;

  /// No description provided for @wardLinkLog.
  ///
  /// In en, this message translates to:
  /// **'Sync log'**
  String get wardLinkLog;

  /// No description provided for @wardLinkLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get wardLinkLogEmpty;

  /// No description provided for @wardLinkHoldForLog.
  ///
  /// In en, this message translates to:
  /// **'Hold the bubble for the log'**
  String get wardLinkHoldForLog;

  /// No description provided for @wardLinkUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get wardLinkUpToDate;

  /// No description provided for @syncedFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Synced from {device}'**
  String syncedFromDevice(String device);

  /// No description provided for @syncedFromUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Synced from another device'**
  String get syncedFromUnknownDevice;

  /// No description provided for @wardLinkFilesDone.
  ///
  /// In en, this message translates to:
  /// **'Files transferred: {n}'**
  String wardLinkFilesDone(int n);

  /// No description provided for @wardLinkNoFilesYet.
  ///
  /// In en, this message translates to:
  /// **'No files transferred'**
  String get wardLinkNoFilesYet;

  /// No description provided for @wardLinkSyncedAgo.
  ///
  /// In en, this message translates to:
  /// **'Synced {when}'**
  String wardLinkSyncedAgo(String when);

  /// No description provided for @wardLinkNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get wardLinkNeverSynced;

  /// No description provided for @wardLinkFirewallHintWindows.
  ///
  /// In en, this message translates to:
  /// **'If the phone cannot reach this PC, allow ONYX in Windows Firewall (TCP port 47832). ONYX tries to add the rule automatically; if it fails: Windows Firewall → Advanced → Inbound Rules → New Rule → Port → TCP → 47832.'**
  String get wardLinkFirewallHintWindows;

  /// No description provided for @wardLinkFirewallHintMac.
  ///
  /// In en, this message translates to:
  /// **'If the phone cannot reach this Mac, make sure the macOS firewall is not blocking ONYX: System Settings → Network → Firewall → Options → add ONYX.'**
  String get wardLinkFirewallHintMac;

  /// No description provided for @wardLinkFirewallHintLinux.
  ///
  /// In en, this message translates to:
  /// **'If the phone cannot connect, open TCP port 47832 in your firewall. Example: sudo ufw allow 47832/tcp  or  sudo firewall-cmd --add-port=47832/tcp --permanent'**
  String get wardLinkFirewallHintLinux;

  /// No description provided for @wardLinkSyncFromBeginning.
  ///
  /// In en, this message translates to:
  /// **'Sync from beginning'**
  String get wardLinkSyncFromBeginning;

  /// No description provided for @wardLinkSyncFromBeginningDesc.
  ///
  /// In en, this message translates to:
  /// **'Pull all history not yet on this device'**
  String get wardLinkSyncFromBeginningDesc;

  /// No description provided for @wardLinkSyncPending.
  ///
  /// In en, this message translates to:
  /// **'Sync pending…'**
  String get wardLinkSyncPending;

  /// No description provided for @wardLinkBubbleVisibility.
  ///
  /// In en, this message translates to:
  /// **'Sync bubble'**
  String get wardLinkBubbleVisibility;

  /// No description provided for @wardLinkBubbleShowAlways.
  ///
  /// In en, this message translates to:
  /// **'Show always'**
  String get wardLinkBubbleShowAlways;

  /// No description provided for @wardLinkBubbleShowOnErrors.
  ///
  /// In en, this message translates to:
  /// **'Show on errors only'**
  String get wardLinkBubbleShowOnErrors;

  /// No description provided for @wardLinkBubbleSize.
  ///
  /// In en, this message translates to:
  /// **'Bubble size'**
  String get wardLinkBubbleSize;

  /// No description provided for @wardLinkSyncFavoritesToggle.
  ///
  /// In en, this message translates to:
  /// **'Sync Favorites'**
  String get wardLinkSyncFavoritesToggle;

  /// No description provided for @wardLinkSyncFavoritesToggleDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync your Favorites — their messages and media'**
  String get wardLinkSyncFavoritesToggleDesc;

  /// No description provided for @wardLinkSyncPersonalToggle.
  ///
  /// In en, this message translates to:
  /// **'Sync my personal messages'**
  String get wardLinkSyncPersonalToggle;

  /// No description provided for @wardLinkSyncIncomingToggle.
  ///
  /// In en, this message translates to:
  /// **'Sync incoming messages'**
  String get wardLinkSyncIncomingToggle;

  /// No description provided for @pairOverTor.
  ///
  /// In en, this message translates to:
  /// **'Pair over Tor'**
  String get pairOverTor;

  /// No description provided for @addContactQr.
  ///
  /// In en, this message translates to:
  /// **'Add contact · QR'**
  String get addContactQr;

  /// No description provided for @contactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contactsTitle;

  /// No description provided for @contactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet.'**
  String get contactsEmpty;

  /// No description provided for @myDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'My devices'**
  String get myDevicesTitle;

  /// No description provided for @myDevicesThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get myDevicesThisDevice;

  /// No description provided for @myDevicesHint.
  ///
  /// In en, this message translates to:
  /// **'Link another device with “Link device” on its login screen. Each device has its own Tor address, and your messages reach all of them.'**
  String get myDevicesHint;

  /// No description provided for @myDevicesUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get myDevicesUnlink;

  /// No description provided for @myDevicesUnlinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unlink this device from your account? It stops receiving your messages, and your contacts drop it too.'**
  String get myDevicesUnlinkConfirm;

  /// No description provided for @contactsRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {username} from your contacts?'**
  String contactsRemoveConfirm(String username);

  /// No description provided for @contactsRemoveDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this pairing with {name}\'s device? Their other paired device is unaffected.'**
  String contactsRemoveDeviceConfirm(String name);

  /// No description provided for @pairScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan their pairing code'**
  String get pairScanTitle;

  /// No description provided for @pairScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the other person\'s pairing QR code'**
  String get pairScanHint;

  /// No description provided for @pairShowHint.
  ///
  /// In en, this message translates to:
  /// **'Have the other person scan this code with their Onyx app'**
  String get pairShowHint;

  /// No description provided for @pairEncrypted.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted, direct over Tor'**
  String get pairEncrypted;

  /// No description provided for @pairScanCode.
  ///
  /// In en, this message translates to:
  /// **'Scan code'**
  String get pairScanCode;

  /// No description provided for @pairedOverTor.
  ///
  /// In en, this message translates to:
  /// **'Paired over Tor'**
  String get pairedOverTor;

  /// No description provided for @pairing.
  ///
  /// In en, this message translates to:
  /// **'Pairing...'**
  String get pairing;

  /// No description provided for @pairFailedWith.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed: {error}'**
  String pairFailedWith(String error);

  /// No description provided for @pairStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start Tor: {error}'**
  String pairStartFailed(String error);

  /// No description provided for @pairRetry.
  ///
  /// In en, this message translates to:
  /// **'Still trying to reach them ({attempt}/{max}) — their address may still be publishing on Tor...'**
  String pairRetry(int attempt, int max);

  /// No description provided for @peerShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR'**
  String get peerShowQr;

  /// No description provided for @peerHideQr.
  ///
  /// In en, this message translates to:
  /// **'Hide QR'**
  String get peerHideQr;

  /// No description provided for @peerAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get peerAddressCopied;

  /// No description provided for @wardLinkSyncPersonalToggleDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync only the messages YOU sent in personal chats to your other devices'**
  String get wardLinkSyncPersonalToggleDesc;

  /// No description provided for @meshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offline mesh network'**
  String get meshSubtitle;

  /// No description provided for @meshEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Mesh network'**
  String get meshEnable;

  /// No description provided for @meshEnableDesc.
  ///
  /// In en, this message translates to:
  /// **'Direct messaging without internet via Wi-Fi or Bluetooth.\nWorks only in direct messages.'**
  String get meshEnableDesc;

  /// No description provided for @meshUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Mesh network is not available on this platform.'**
  String get meshUnavailable;

  /// No description provided for @meshOpenRadar.
  ///
  /// In en, this message translates to:
  /// **'Open Radar'**
  String get meshOpenRadar;

  /// No description provided for @meshNearbyCount.
  ///
  /// In en, this message translates to:
  /// **'Nearby: {n} devices'**
  String meshNearbyCount(int n);

  /// No description provided for @meshRadarTitle.
  ///
  /// In en, this message translates to:
  /// **'Mesh Radar'**
  String get meshRadarTitle;

  /// No description provided for @meshRadarScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get meshRadarScanning;

  /// No description provided for @meshRadarSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get meshRadarSearchHint;

  /// No description provided for @meshRadarSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{q}\"'**
  String meshRadarSearchEmpty(String q);

  /// No description provided for @meshRadarNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices nearby.\nMesh scans every 20 s.'**
  String get meshRadarNoDevices;

  /// No description provided for @meshRadarDisabled.
  ///
  /// In en, this message translates to:
  /// **'Mesh mode is off.\nEnable it in Settings → Mesh.'**
  String get meshRadarDisabled;

  /// No description provided for @meshRadarStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting BLE scan…'**
  String get meshRadarStarting;

  /// No description provided for @meshMenuRadar.
  ///
  /// In en, this message translates to:
  /// **'Radar'**
  String get meshMenuRadar;

  /// No description provided for @meshMenuDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get meshMenuDiagnostics;

  /// No description provided for @meshMenuModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get meshMenuModeAuto;

  /// No description provided for @meshBluetoothOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off'**
  String get meshBluetoothOffTitle;

  /// No description provided for @meshBluetoothOffContent.
  ///
  /// In en, this message translates to:
  /// **'Mesh chat was switched to Bluetooth-only mode, but Bluetooth is turned off. Enable it in system settings to reach nearby devices.'**
  String get meshBluetoothOffContent;

  /// No description provided for @meshOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get meshOpenSystemSettings;

  /// No description provided for @meshModeLabel.
  ///
  /// In en, this message translates to:
  /// **'MODE'**
  String get meshModeLabel;

  /// No description provided for @meshModeActive.
  ///
  /// In en, this message translates to:
  /// **'Mesh mode active'**
  String get meshModeActive;

  /// No description provided for @meshChatLabel.
  ///
  /// In en, this message translates to:
  /// **'Mesh Chat'**
  String get meshChatLabel;

  /// No description provided for @meshLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Enable location services for BLE scanning (Android ≤11)'**
  String get meshLocationRequired;

  /// No description provided for @meshChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.\nSend the first mesh message.'**
  String get meshChatEmpty;

  /// No description provided for @meshChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get meshChatInputHint;

  /// No description provided for @meshChatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get meshChatSend;

  /// No description provided for @meshChatOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Out of range'**
  String get meshChatOutOfRange;

  /// No description provided for @meshStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get meshStatusSending;

  /// No description provided for @meshStatusSendingWifi.
  ///
  /// In en, this message translates to:
  /// **'Sending via Wi-Fi…'**
  String get meshStatusSendingWifi;

  /// No description provided for @meshStatusSendingBle.
  ///
  /// In en, this message translates to:
  /// **'Sending via Bluetooth…'**
  String get meshStatusSendingBle;

  /// No description provided for @meshStatusRelayed.
  ///
  /// In en, this message translates to:
  /// **'In transit via mesh'**
  String get meshStatusRelayed;

  /// No description provided for @meshStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get meshStatusDelivered;

  /// No description provided for @meshStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Not delivered'**
  String get meshStatusFailed;

  /// No description provided for @meshStatusRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get meshStatusRetry;

  /// No description provided for @meshStatusFailedHint.
  ///
  /// In en, this message translates to:
  /// **'Message did not reach the recipient'**
  String get meshStatusFailedHint;

  /// No description provided for @meshErrorVideoWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Video can only be sent over Wi-Fi. Connect to the same Wi-Fi network as the recipient.'**
  String get meshErrorVideoWifiOnly;

  /// No description provided for @meshErrorFileTooLargeForBle.
  ///
  /// In en, this message translates to:
  /// **'File is too large for Bluetooth (max 10 MB). Connect to a shared Wi-Fi network.'**
  String get meshErrorFileTooLargeForBle;

  /// No description provided for @meshErrorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is too large (max 200 MB).'**
  String get meshErrorFileTooLarge;

  /// No description provided for @meshErrorAttachmentsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Attachments are only supported on mobile/desktop'**
  String get meshErrorAttachmentsUnsupported;

  /// No description provided for @meshErrorPickFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick file'**
  String get meshErrorPickFileFailed;

  /// No description provided for @meshErrorSendFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send file'**
  String get meshErrorSendFileFailed;

  /// No description provided for @meshErrorSendVoiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send voice message'**
  String get meshErrorSendVoiceFailed;

  /// No description provided for @meshErrorOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'{username} is out of range'**
  String meshErrorOutOfRange(String username);

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local backup and restore of your data'**
  String get backupSubtitle;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Save all data'**
  String get backupExport;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get backupRestore;

  /// No description provided for @backupScope.
  ///
  /// In en, this message translates to:
  /// **'What to back up'**
  String get backupScope;

  /// No description provided for @backupFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorite chats'**
  String get backupFavorites;

  /// No description provided for @backupPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal chats'**
  String get backupPersonal;

  /// No description provided for @backupIncludeMedia.
  ///
  /// In en, this message translates to:
  /// **'Include media'**
  String get backupIncludeMedia;

  /// No description provided for @backupMediaImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get backupMediaImages;

  /// No description provided for @backupMediaVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get backupMediaVideos;

  /// No description provided for @backupMediaVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice & audio'**
  String get backupMediaVoice;

  /// No description provided for @backupMediaOther.
  ///
  /// In en, this message translates to:
  /// **'Other files'**
  String get backupMediaOther;

  /// No description provided for @backupSchedule.
  ///
  /// In en, this message translates to:
  /// **'Scheduled backup'**
  String get backupSchedule;

  /// No description provided for @backupFreqOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get backupFreqOff;

  /// No description provided for @backupFreqDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get backupFreqDaily;

  /// No description provided for @backupFreqWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get backupFreqWeekly;

  /// No description provided for @backupFreqMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get backupFreqMonthly;

  /// No description provided for @backupFolder.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup folder'**
  String get backupFolder;

  /// No description provided for @backupChangeFolder.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get backupChangeFolder;

  /// No description provided for @backupLastAuto.
  ///
  /// In en, this message translates to:
  /// **'Last auto-backup'**
  String get backupLastAuto;

  /// No description provided for @backupNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get backupNever;

  /// No description provided for @backupInProgress.
  ///
  /// In en, this message translates to:
  /// **'Creating backup…'**
  String get backupInProgress;

  /// No description provided for @backupRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get backupRestoring;

  /// No description provided for @backupSelectScope.
  ///
  /// In en, this message translates to:
  /// **'Select at least one category'**
  String get backupSelectScope;

  /// No description provided for @backupNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No active account'**
  String get backupNoAccount;

  /// No description provided for @backupNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Storage access denied. Grant \"All files access\" in app settings.'**
  String get backupNoPermission;

  /// No description provided for @backupOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get backupOpenFolder;

  /// No description provided for @backupFolderUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This folder is not accessible. Please pick a folder on internal storage.'**
  String get backupFolderUnsupported;

  /// No description provided for @backupRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup?'**
  String get backupRestoreConfirmTitle;

  /// No description provided for @backupRestoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Data from the file will be restored over your current data (chats, favorites, settings).'**
  String get backupRestoreConfirmBody;

  /// No description provided for @backupRestartHint.
  ///
  /// In en, this message translates to:
  /// **'Restart the app to see the changes'**
  String get backupRestartHint;

  /// No description provided for @recycleBinTitle.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get recycleBinTitle;

  /// No description provided for @recycleBinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted chats and protection from accidental sync deletions'**
  String get recycleBinSubtitle;

  /// No description provided for @recycleBinPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Deletion requests'**
  String get recycleBinPendingTitle;

  /// No description provided for @recycleBinPendingDesc.
  ///
  /// In en, this message translates to:
  /// **'Device \"{device}\" wants to delete {count} chat(s). Apply or keep?'**
  String recycleBinPendingDesc(String device, int count);

  /// No description provided for @recycleBinApply.
  ///
  /// In en, this message translates to:
  /// **'Apply delete'**
  String get recycleBinApply;

  /// No description provided for @recycleBinKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep my chats'**
  String get recycleBinKeep;

  /// No description provided for @recycleBinNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending deletion requests'**
  String get recycleBinNoPending;

  /// No description provided for @recycleBinResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset deletion records'**
  String get recycleBinResetTitle;

  /// No description provided for @recycleBinResetDesc.
  ///
  /// In en, this message translates to:
  /// **'Clears the list of deleted chats. Sync will stop re-deleting them on other devices and can bring them back.'**
  String get recycleBinResetDesc;

  /// No description provided for @recycleBinResetButton.
  ///
  /// In en, this message translates to:
  /// **'Clear deleted list'**
  String get recycleBinResetButton;

  /// No description provided for @recycleBinResetDone.
  ///
  /// In en, this message translates to:
  /// **'Deletion records cleared'**
  String get recycleBinResetDone;

  /// No description provided for @recycleBinResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all deletion records for this account?'**
  String get recycleBinResetConfirm;

  /// No description provided for @accountGraph.
  ///
  /// In en, this message translates to:
  /// **'Account Graph'**
  String get accountGraph;

  /// No description provided for @accountGraphSubtitleDesktopOn.
  ///
  /// In en, this message translates to:
  /// **'Shows a graph of your chats, groups and channels when no chat is open'**
  String get accountGraphSubtitleDesktopOn;

  /// No description provided for @accountGraphSubtitleMobileOn.
  ///
  /// In en, this message translates to:
  /// **'Visualizing your account in planetary view'**
  String get accountGraphSubtitleMobileOn;

  /// No description provided for @accountGraphSubtitleDesktopOff.
  ///
  /// In en, this message translates to:
  /// **'Shows a hint when no chat is open'**
  String get accountGraphSubtitleDesktopOff;

  /// No description provided for @accountGraphSubtitleMobileOff.
  ///
  /// In en, this message translates to:
  /// **'Account Graph is disabled'**
  String get accountGraphSubtitleMobileOff;

  /// No description provided for @orbitSpeed.
  ///
  /// In en, this message translates to:
  /// **'Orbit Speed'**
  String get orbitSpeed;

  /// No description provided for @secOrbit.
  ///
  /// In en, this message translates to:
  /// **'{s} sec/orbit'**
  String secOrbit(int s);

  /// No description provided for @minOrbit.
  ///
  /// In en, this message translates to:
  /// **'{m} min/orbit'**
  String minOrbit(int m);

  /// No description provided for @animateGraph.
  ///
  /// In en, this message translates to:
  /// **'Animate'**
  String get animateGraph;

  /// No description provided for @animateGraphOn.
  ///
  /// In en, this message translates to:
  /// **'Orbits rotate in real time'**
  String get animateGraphOn;

  /// No description provided for @animateGraphOff.
  ///
  /// In en, this message translates to:
  /// **'Graph is frozen / static'**
  String get animateGraphOff;

  /// No description provided for @preserveView.
  ///
  /// In en, this message translates to:
  /// **'Preserve View'**
  String get preserveView;

  /// No description provided for @preserveViewOn.
  ///
  /// In en, this message translates to:
  /// **'Keeps zoom & position when leaving a chat'**
  String get preserveViewOn;

  /// No description provided for @preserveViewOff.
  ///
  /// In en, this message translates to:
  /// **'Resets to center when returning'**
  String get preserveViewOff;

  /// No description provided for @migrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Migration'**
  String get migrationTitle;

  /// No description provided for @migrationBody.
  ///
  /// In en, this message translates to:
  /// **'ONYX is switching to a new high-speed storage engine. Chats and media will load much faster.'**
  String get migrationBody;

  /// No description provided for @migrationAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get migrationAccounts;

  /// No description provided for @migrationDataSize.
  ///
  /// In en, this message translates to:
  /// **'Data size'**
  String get migrationDataSize;

  /// No description provided for @migrationBackupNote.
  ///
  /// In en, this message translates to:
  /// **'A backup will be created before migration. The app may be temporarily unresponsive during this process.'**
  String get migrationBackupNote;

  /// No description provided for @migrationStart.
  ///
  /// In en, this message translates to:
  /// **'Start Migration'**
  String get migrationStart;

  /// No description provided for @migrationSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get migrationSkip;

  /// No description provided for @migrationPhaseBackup.
  ///
  /// In en, this message translates to:
  /// **'Creating backup'**
  String get migrationPhaseBackup;

  /// No description provided for @migrationPhaseImport.
  ///
  /// In en, this message translates to:
  /// **'Importing data'**
  String get migrationPhaseImport;

  /// No description provided for @migrationPhaseVerify.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get migrationPhaseVerify;

  /// No description provided for @migrationPhasePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get migrationPhasePreparing;

  /// No description provided for @migrationDontClose.
  ///
  /// In en, this message translates to:
  /// **'Do not close the app'**
  String get migrationDontClose;

  /// No description provided for @migrationDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get migrationDoneTitle;

  /// No description provided for @migrationDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Storage updated. A backup has been saved to the Backups folder.'**
  String get migrationDoneBody;

  /// No description provided for @migrationDoneNote.
  ///
  /// In en, this message translates to:
  /// **'Once you confirm everything works — you can delete it manually.'**
  String get migrationDoneNote;

  /// No description provided for @migrationDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get migrationDoneButton;

  /// No description provided for @migrationErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Migration Error'**
  String get migrationErrorTitle;

  /// No description provided for @migrationErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The app will continue on the old system. Migration will be retried on next launch.'**
  String get migrationErrorBody;

  /// No description provided for @migrationErrorButton.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get migrationErrorButton;

  /// No description provided for @audioTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audioTitle;

  /// No description provided for @audioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone and speaker device selection'**
  String get audioSubtitle;

  /// No description provided for @audioMicInput.
  ///
  /// In en, this message translates to:
  /// **'Microphone (input)'**
  String get audioMicInput;

  /// No description provided for @audioSpeakerOutput.
  ///
  /// In en, this message translates to:
  /// **'Speaker (output)'**
  String get audioSpeakerOutput;

  /// No description provided for @audioSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get audioSystemDefault;

  /// No description provided for @audioChangesNote.
  ///
  /// In en, this message translates to:
  /// **'Changes take effect on the next voice channel join.'**
  String get audioChangesNote;

  /// No description provided for @wardlinkReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive from device'**
  String get wardlinkReceive;

  /// No description provided for @wardlinkReceiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a QR code — the sender scans it'**
  String get wardlinkReceiveSubtitle;

  /// No description provided for @wardlinkSend.
  ///
  /// In en, this message translates to:
  /// **'Send to device'**
  String get wardlinkSend;

  /// No description provided for @wardlinkSendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code shown on the receiver'**
  String get wardlinkSendSubtitle;

  /// No description provided for @react.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get react;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @copyImage.
  ///
  /// In en, this message translates to:
  /// **'Copy Image'**
  String get copyImage;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @showInFileSystem.
  ///
  /// In en, this message translates to:
  /// **'Show in file system'**
  String get showInFileSystem;

  /// No description provided for @saveNotSupportedOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Save not supported on web'**
  String get saveNotSupportedOnWeb;

  /// No description provided for @imageNotLoadedYet.
  ///
  /// In en, this message translates to:
  /// **'Image not loaded yet'**
  String get imageNotLoadedYet;

  /// No description provided for @voiceNotLoadedYet.
  ///
  /// In en, this message translates to:
  /// **'Voice not loaded yet'**
  String get voiceNotLoadedYet;

  /// No description provided for @videoNotLoadedYet.
  ///
  /// In en, this message translates to:
  /// **'Video not loaded yet'**
  String get videoNotLoadedYet;

  /// No description provided for @fileNotLoadedYet.
  ///
  /// In en, this message translates to:
  /// **'File not loaded yet'**
  String get fileNotLoadedYet;

  /// No description provided for @fileNotLoadedOpenFirst.
  ///
  /// In en, this message translates to:
  /// **'File isn\'t downloaded to this device — tap it in the chat to download it'**
  String get fileNotLoadedOpenFirst;

  /// No description provided for @editTimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit  ·  {s}s'**
  String editTimerLabel(int s);

  /// No description provided for @deleteTimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete  ·  {s}s'**
  String deleteTimerLabel(int s);

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @newChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new favorite chat'**
  String get newChatSubtitle;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @newFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Group chats into a folder'**
  String get newFolderSubtitle;

  /// No description provided for @searchEmoji.
  ///
  /// In en, this message translates to:
  /// **'Search emoji…'**
  String get searchEmoji;

  /// No description provided for @syncCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sync completed'**
  String get syncCompleted;

  /// No description provided for @syncCompletedWithErrors.
  ///
  /// In en, this message translates to:
  /// **'Sync completed with errors'**
  String get syncCompletedWithErrors;

  /// No description provided for @receivingFiles.
  ///
  /// In en, this message translates to:
  /// **'Receiving files...'**
  String get receivingFiles;

  /// No description provided for @syncFromUser.
  ///
  /// In en, this message translates to:
  /// **'from {sender}'**
  String syncFromUser(String sender);

  /// No description provided for @aboutServer.
  ///
  /// In en, this message translates to:
  /// **'SERVER'**
  String get aboutServer;

  /// No description provided for @aboutWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S NEW'**
  String get aboutWhatsNew;

  /// No description provided for @aboutConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get aboutConnected;

  /// No description provided for @aboutConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get aboutConnecting;

  /// No description provided for @aboutLoadingLocation.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get aboutLoadingLocation;

  /// No description provided for @aboutNoReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'No release notes available.'**
  String get aboutNoReleaseNotes;

  /// No description provided for @aboutCheckForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get aboutCheckForUpdates;

  /// No description provided for @aboutChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get aboutChecking;

  /// No description provided for @aboutUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date!'**
  String get aboutUpToDate;

  /// No description provided for @aboutUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: {v}'**
  String aboutUpdateAvailable(String v);

  /// No description provided for @downloadUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Update'**
  String get downloadUpdateTitle;

  /// No description provided for @downloadUpdateVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get downloadUpdateVersion;

  /// No description provided for @downloadUpdateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S NEW'**
  String get downloadUpdateWhatsNew;

  /// No description provided for @downloadUpdateReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to download'**
  String get downloadUpdateReady;

  /// No description provided for @downloadUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloadUpdateDownloading;

  /// No description provided for @downloadUpdateComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete!'**
  String get downloadUpdateComplete;

  /// No description provided for @downloadUpdateNoPlatform.
  ///
  /// In en, this message translates to:
  /// **'No download available for this platform'**
  String get downloadUpdateNoPlatform;

  /// No description provided for @downloadUpdateInstall.
  ///
  /// In en, this message translates to:
  /// **'Download & Install'**
  String get downloadUpdateInstall;

  /// No description provided for @downloadUpdateOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get downloadUpdateOpen;

  /// No description provided for @downloadUpdateRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloadUpdateRetry;

  /// No description provided for @downloadUpdateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get downloadUpdateCancel;

  /// No description provided for @editChat.
  ///
  /// In en, this message translates to:
  /// **'Edit chat'**
  String get editChat;

  /// No description provided for @chatNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat name'**
  String get chatNameLabel;

  /// No description provided for @editFolder.
  ///
  /// In en, this message translates to:
  /// **'Edit folder'**
  String get editFolder;

  /// No description provided for @folderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderNameLabel;

  /// No description provided for @createChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get createChat;

  /// No description provided for @profileMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileMessage;

  /// No description provided for @tapAvatarHint.
  ///
  /// In en, this message translates to:
  /// **'Tap avatar to change • Long-press to remove'**
  String get tapAvatarHint;

  /// No description provided for @tapAvatarLongRemove.
  ///
  /// In en, this message translates to:
  /// **'Tap to change • Long-press to remove'**
  String get tapAvatarLongRemove;

  /// No description provided for @e2eeWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Not end-to-end encrypted'**
  String get e2eeWarnTitle;

  /// No description provided for @e2eeWarnUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get e2eeWarnUnderstand;

  /// No description provided for @e2eeWarnDoNotShare.
  ///
  /// In en, this message translates to:
  /// **'Do not share passwords, private files or sensitive information here.'**
  String get e2eeWarnDoNotShare;

  /// No description provided for @e2eeWarnGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Messages in this group are not protected by end-to-end encryption — the server can read them.'**
  String get e2eeWarnGroupBody;

  /// No description provided for @e2eeWarnGroupMedia.
  ///
  /// In en, this message translates to:
  /// **'Attached media is uploaded to a public host (catbox.moe) and is reachable by anyone who has the link.'**
  String get e2eeWarnGroupMedia;

  /// No description provided for @e2eeWarnExtBody.
  ///
  /// In en, this message translates to:
  /// **'Messages in this group are not protected by end-to-end encryption — the group owner\'s server can read them.'**
  String get e2eeWarnExtBody;

  /// No description provided for @e2eeWarnExtMedia.
  ///
  /// In en, this message translates to:
  /// **'Attached media is uploaded to and stored on the owner\'s own server, not on ONYX.'**
  String get e2eeWarnExtMedia;

  /// No description provided for @e2eeWarnExtOnyxUnrelated.
  ///
  /// In en, this message translates to:
  /// **'ONYX has nothing to do with this group and cannot moderate or protect its content.'**
  String get e2eeWarnExtOnyxUnrelated;

  /// No description provided for @securityLevelTitle.
  ///
  /// In en, this message translates to:
  /// **'Device trust level'**
  String get securityLevelTitle;

  /// No description provided for @securityLevelEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get securityLevelEasy;

  /// No description provided for @securityLevelEasyDesc.
  ///
  /// In en, this message translates to:
  /// **'A new device is trusted immediately after login. Least friction, but the password is your only line of defense.'**
  String get securityLevelEasyDesc;

  /// No description provided for @securityLevelBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get securityLevelBalanced;

  /// No description provided for @securityLevelBalancedDesc.
  ///
  /// In en, this message translates to:
  /// **'Any already-trusted device can approve a new one. Recommended for most people.'**
  String get securityLevelBalancedDesc;

  /// No description provided for @securityLevelStrict.
  ///
  /// In en, this message translates to:
  /// **'Strict'**
  String get securityLevelStrict;

  /// No description provided for @securityLevelStrictDesc.
  ///
  /// In en, this message translates to:
  /// **'A new device needs approval from two separate trusted devices.'**
  String get securityLevelStrictDesc;

  /// No description provided for @securityLevelLowerRequiresTrusted.
  ///
  /// In en, this message translates to:
  /// **'Lowering the security level requires a trusted device.'**
  String get securityLevelLowerRequiresTrusted;

  /// No description provided for @securityLevelUpdated.
  ///
  /// In en, this message translates to:
  /// **'Security level updated'**
  String get securityLevelUpdated;

  /// No description provided for @sessionTtlTitle.
  ///
  /// In en, this message translates to:
  /// **'Session lifetime'**
  String get sessionTtlTitle;

  /// No description provided for @sessionTtlSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long before this device asks for your password again'**
  String get sessionTtlSubtitle;

  /// No description provided for @sessionTtlRecommended.
  ///
  /// In en, this message translates to:
  /// **'recommended'**
  String get sessionTtlRecommended;

  /// No description provided for @sessionTtlDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String sessionTtlDays(int days);

  /// No description provided for @sessionTtlNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get sessionTtlNever;

  /// No description provided for @sessionTtlUpdated.
  ///
  /// In en, this message translates to:
  /// **'Session lifetime updated'**
  String get sessionTtlUpdated;

  /// No description provided for @approvalsProgress.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approvalsProgress;

  /// No description provided for @pendingDeviceTitleSingle.
  ///
  /// In en, this message translates to:
  /// **'New device'**
  String get pendingDeviceTitleSingle;

  /// No description provided for @pendingDeviceTitleMulti.
  ///
  /// In en, this message translates to:
  /// **'New devices ({count})'**
  String pendingDeviceTitleMulti(int count);

  /// No description provided for @pendingDeviceApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get pendingDeviceApprove;

  /// No description provided for @pendingDeviceDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get pendingDeviceDeny;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Account recovery'**
  String get recoveryTitle;

  /// No description provided for @recoveryBannerText.
  ///
  /// In en, this message translates to:
  /// **'This device isn\'t approved yet. If no trusted device is reachable, you can recover access with your password and recovery phrase.'**
  String get recoveryBannerText;

  /// No description provided for @recoveryBannerButton.
  ///
  /// In en, this message translates to:
  /// **'Recover access'**
  String get recoveryBannerButton;

  /// No description provided for @recoveryIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your password and the 12-word recovery phrase shown to you at registration. The request won\'t take effect immediately — your trusted devices get a window to cancel it if this isn\'t you.'**
  String get recoveryIntro;

  /// No description provided for @recoveryPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get recoveryPasswordLabel;

  /// No description provided for @recoveryPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase (12 words)'**
  String get recoveryPassphraseLabel;

  /// No description provided for @recoverySubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get recoverySubmit;

  /// No description provided for @recoveryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid password or recovery phrase'**
  String get recoveryInvalid;

  /// No description provided for @recoveryAlreadyPending.
  ///
  /// In en, this message translates to:
  /// **'A request is already pending'**
  String get recoveryAlreadyPending;

  /// No description provided for @recoveryPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Request submitted'**
  String get recoveryPendingTitle;

  /// No description provided for @recoveryPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Access will be restored {when} unless a trusted device cancels the request.'**
  String recoveryPendingBody(String when);

  /// No description provided for @recoveryCancelled.
  ///
  /// In en, this message translates to:
  /// **'Recovery request cancelled'**
  String get recoveryCancelled;

  /// No description provided for @recoveryExecuted.
  ///
  /// In en, this message translates to:
  /// **'Access restored. Please re-login to apply the change.'**
  String get recoveryExecuted;

  /// No description provided for @recoveryCancelRequiresTrusted.
  ///
  /// In en, this message translates to:
  /// **'Only a trusted device can cancel this. Approve this device in Active Devices first.'**
  String get recoveryCancelRequiresTrusted;

  /// No description provided for @recoveryAlertRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone requested account recovery'**
  String get recoveryAlertRequestedTitle;

  /// No description provided for @recoveryAlertRequestedBody.
  ///
  /// In en, this message translates to:
  /// **'Device \"{deviceName}\" requested account recovery. If this wasn\'t you, cancel it now. Otherwise it takes effect {when}.'**
  String recoveryAlertRequestedBody(String deviceName, String when);

  /// No description provided for @recoveryAlertCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get recoveryAlertCancelButton;

  /// No description provided for @recoveryAlertIgnoreButton.
  ///
  /// In en, this message translates to:
  /// **'It\'s me, ignore'**
  String get recoveryAlertIgnoreButton;

  /// No description provided for @recoveryAlertFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed recovery attempt'**
  String get recoveryAlertFailedTitle;

  /// No description provided for @recoveryAlertFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Someone tried to recover access to your account but entered the wrong password or recovery phrase.'**
  String get recoveryAlertFailedBody;

  /// No description provided for @recoveryAlertExecutedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery completed'**
  String get recoveryAlertExecutedTitle;

  /// No description provided for @recoveryAlertExecutedBody.
  ///
  /// In en, this message translates to:
  /// **'The recovery request has taken effect — the account has a new primary device. If this wasn\'t you, revoke the unfamiliar session in Active Devices immediately.'**
  String get recoveryAlertExecutedBody;

  /// No description provided for @wardLinkSyncSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Settings'**
  String get wardLinkSyncSettingsTitle;

  /// No description provided for @wardLinkSyncSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'File size limit and bubble notifications'**
  String get wardLinkSyncSettingsSubtitle;

  /// No description provided for @wardLinkPairedDevicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add and manage paired devices'**
  String get wardLinkPairedDevicesSubtitle;

  /// No description provided for @notifGeneralTitle.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get notifGeneralTitle;

  /// No description provided for @notifGeneralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications and content visibility'**
  String get notifGeneralSubtitle;

  /// No description provided for @notifSoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notification sound and audio file'**
  String get notifSoundSubtitle;

  /// No description provided for @notifAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get notifAdvancedTitle;

  /// No description provided for @notifAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Startup behavior and popup position'**
  String get notifAdvancedSubtitle;

  /// No description provided for @securityPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get securityPrivacyTitle;

  /// No description provided for @securityPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visibility and search settings'**
  String get securityPrivacySubtitle;

  /// No description provided for @cacheStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get cacheStorageTitle;

  /// No description provided for @cacheStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Media cache and unused file cleanup'**
  String get cacheStorageSubtitle;

  /// No description provided for @connectionServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Connection'**
  String get connectionServerTitle;

  /// No description provided for @connectionServerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect or disconnect from the WebSocket server'**
  String get connectionServerSubtitle;

  /// No description provided for @interactPerformanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get interactPerformanceTitle;

  /// No description provided for @interactPerformanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scroll buffer and image preload window'**
  String get interactPerformanceSubtitle;

  /// No description provided for @interactFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files & Storage'**
  String get interactFilesTitle;

  /// No description provided for @interactFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download folder and app data management'**
  String get interactFilesSubtitle;

  /// No description provided for @appearanceChatDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Display'**
  String get appearanceChatDisplayTitle;

  /// No description provided for @appearanceChatDisplaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alignment, avatars and animations'**
  String get appearanceChatDisplaySubtitle;

  /// No description provided for @appearanceLayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get appearanceLayoutTitle;

  /// No description provided for @appearanceLayoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Navigation, graph and tab swiping'**
  String get appearanceLayoutSubtitle;

  /// No description provided for @appearanceLiquidGlassTitle.
  ///
  /// In en, this message translates to:
  /// **'Liquid Glass Effects'**
  String get appearanceLiquidGlassTitle;

  /// No description provided for @trashChatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted Chats'**
  String get trashChatsTitle;

  /// No description provided for @trashChatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore or permanently delete chats'**
  String get trashChatsSubtitle;

  /// No description provided for @trashMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted Messages'**
  String get trashMessagesTitle;

  /// No description provided for @trashMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore or permanently delete messages'**
  String get trashMessagesSubtitle;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @setup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get setup;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @token.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get token;

  /// No description provided for @always.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get always;

  /// No description provided for @favRemoveFromFolderNamed.
  ///
  /// In en, this message translates to:
  /// **'Remove from \"{folderName}\"'**
  String favRemoveFromFolderNamed(String folderName);

  /// No description provided for @favMoveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get favMoveToFolder;

  /// No description provided for @favRemoveFromFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove from folder'**
  String get favRemoveFromFolder;

  /// No description provided for @favUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get favUnlock;

  /// No description provided for @favLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get favLock;

  /// No description provided for @favUnlockFolder.
  ///
  /// In en, this message translates to:
  /// **'Unlock folder'**
  String get favUnlockFolder;

  /// No description provided for @favLockFolder.
  ///
  /// In en, this message translates to:
  /// **'Lock folder'**
  String get favLockFolder;

  /// No description provided for @favChatsCount.
  ///
  /// In en, this message translates to:
  /// **'{n} chats'**
  String favChatsCount(int n);

  /// No description provided for @favNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get favNewFolder;

  /// No description provided for @favChatsMovedToTopLevel.
  ///
  /// In en, this message translates to:
  /// **'Chats will be moved to top level'**
  String get favChatsMovedToTopLevel;

  /// No description provided for @favDeleteChatQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get favDeleteChatQuestion;

  /// No description provided for @favRemoveAvatarQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove avatar?'**
  String get favRemoveAvatarQuestion;

  /// No description provided for @favSelectedRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Selected messages will be removed from favorites.'**
  String get favSelectedRemovedFromFavorites;

  /// No description provided for @favDeleteMessageQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get favDeleteMessageQuestion;

  /// No description provided for @favMessageRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'This message will be removed from favorites.'**
  String get favMessageRemovedFromFavorites;

  /// No description provided for @favDeleteAvatarQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete avatar?'**
  String get favDeleteAvatarQuestion;

  /// No description provided for @favRemoveAvatarConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove this favorite avatar.'**
  String get favRemoveAvatarConfirm;

  /// No description provided for @sendAlbum.
  ///
  /// In en, this message translates to:
  /// **'Send Album'**
  String get sendAlbum;

  /// No description provided for @sendAlbums.
  ///
  /// In en, this message translates to:
  /// **'Send Albums'**
  String get sendAlbums;

  /// No description provided for @sendAllMedia.
  ///
  /// In en, this message translates to:
  /// **'Send All'**
  String get sendAllMedia;

  /// No description provided for @setAsWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Set as wallpaper'**
  String get setAsWallpaper;

  /// No description provided for @sendVoice.
  ///
  /// In en, this message translates to:
  /// **'Send Voice'**
  String get sendVoice;

  /// No description provided for @cropAndUpload.
  ///
  /// In en, this message translates to:
  /// **'Crop & Upload'**
  String get cropAndUpload;

  /// No description provided for @deleteMessagesQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete messages?'**
  String get deleteMessagesQuestion;

  /// No description provided for @connectionDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Connection Diagnostics'**
  String get connectionDiagnostics;

  /// No description provided for @voiceChannels.
  ///
  /// In en, this message translates to:
  /// **'Voice channels'**
  String get voiceChannels;

  /// No description provided for @forwardMessage.
  ///
  /// In en, this message translates to:
  /// **'Forward message'**
  String get forwardMessage;

  /// No description provided for @noChats.
  ///
  /// In en, this message translates to:
  /// **'No chats'**
  String get noChats;

  /// No description provided for @noGroups.
  ///
  /// In en, this message translates to:
  /// **'No groups'**
  String get noGroups;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites'**
  String get noFavorites;

  /// No description provided for @wifiOnlyOption.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get wifiOnlyOption;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash'**
  String get emptyTrash;

  /// No description provided for @performanceReport.
  ///
  /// In en, this message translates to:
  /// **'Performance Report'**
  String get performanceReport;

  /// No description provided for @revokeSessionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Revoke session?'**
  String get revokeSessionQuestion;

  /// No description provided for @revokeSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'This device will be immediately logged out.'**
  String get revokeSessionConfirm;

  /// No description provided for @failedToRevokeSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to revoke session'**
  String get failedToRevokeSession;

  /// No description provided for @failedToApproveDevice.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve device'**
  String get failedToApproveDevice;

  /// No description provided for @noActiveSessionsFound.
  ///
  /// In en, this message translates to:
  /// **'No active sessions found'**
  String get noActiveSessionsFound;

  /// No description provided for @quotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'Quota exceeded'**
  String get quotaExceeded;

  /// No description provided for @openSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettingsAction;

  /// No description provided for @trashIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashIsEmpty;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @deviceAuthTabQr.
  ///
  /// In en, this message translates to:
  /// **'QR'**
  String get deviceAuthTabQr;

  /// No description provided for @meshTitle.
  ///
  /// In en, this message translates to:
  /// **'Mesh'**
  String get meshTitle;

  /// No description provided for @meshMenuModeWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get meshMenuModeWifi;

  /// No description provided for @meshMenuModeBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get meshMenuModeBluetooth;

  /// No description provided for @mediaCachesCleared.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{ Cleared {n} media cache} other{ Cleared {n} media caches}}'**
  String mediaCachesCleared(int n);

  /// No description provided for @leaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {isChannel, select, true{channel} other{group}}?'**
  String leaveGroupTitle(String isChannel);

  /// No description provided for @cacheFilesDeleted.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Deleted {n} file} other{Deleted {n} files}}'**
  String cacheFilesDeleted(int n);

  /// No description provided for @orphanedCleanupDeleted.
  ///
  /// In en, this message translates to:
  /// **'{files, plural, one{Deleted {files} unused file} other{Deleted {files} unused files}} ({freedMb} MB freed)'**
  String orphanedCleanupDeleted(int files, String freedMb);

  /// No description provided for @deletedLogsCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Deleted {n} log file.} other{Deleted {n} log files.}}'**
  String deletedLogsCount(int n);

  /// No description provided for @notifEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{enabled, select, true{You will be alerted for new messages} other{All notifications are silenced}}'**
  String notifEnabledSubtitle(String enabled);

  /// No description provided for @notifHideContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{hidden, select, true{Notifications without message text} other{Show message text in notifications}}'**
  String notifHideContentSubtitle(String hidden);

  /// No description provided for @notifSoundEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{enabled, select, true{Sound enabled} other{Sound disabled}}'**
  String notifSoundEnabledSubtitle(String enabled);

  /// No description provided for @sessionExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Session expires in {n} day} other{Session expires in {n} days}}'**
  String sessionExpiresInDays(int n);

  /// No description provided for @sessionExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Session expires in {n} hour} other{Session expires in {n} hours}}'**
  String sessionExpiresInHours(int n);

  /// No description provided for @sessionActiveForDays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{Session valid for {n} more day} other{Session valid for {n} more days}}'**
  String sessionActiveForDays(int n);

  /// No description provided for @meshRadarFound.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, one{{n} device in range} other{{n} devices in range}}'**
  String meshRadarFound(int n);

  /// No description provided for @trashSummary.
  ///
  /// In en, this message translates to:
  /// **'{chats, plural, one{{chats} chat} other{{chats} chats}}, {messages, plural, one{{messages} message} other{{messages} messages}}'**
  String trashSummary(int chats, int messages);

  /// No description provided for @muteAction.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get muteAction;

  /// No description provided for @unmuteAction.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmuteAction;

  /// No description provided for @muteUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Mute {name}'**
  String muteUserTitle(String name);

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @duration15Min.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get duration15Min;

  /// No description provided for @duration1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get duration1Hour;

  /// No description provided for @duration1Day.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get duration1Day;

  /// No description provided for @duration1Week.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get duration1Week;

  /// No description provided for @muteReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get muteReasonLabel;

  /// No description provided for @userMuted.
  ///
  /// In en, this message translates to:
  /// **'{name} muted'**
  String userMuted(String name);

  /// No description provided for @failedMute.
  ///
  /// In en, this message translates to:
  /// **'Failed to mute'**
  String get failedMute;

  /// No description provided for @failedMuteUser.
  ///
  /// In en, this message translates to:
  /// **'Failed to mute {name}'**
  String failedMuteUser(String name);

  /// No description provided for @mutedUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Muted Users'**
  String get mutedUsersTitle;

  /// No description provided for @noMutedUsers.
  ///
  /// In en, this message translates to:
  /// **'No muted users'**
  String get noMutedUsers;

  /// No description provided for @mutedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Muted by: {name}'**
  String mutedByLabel(String name);

  /// No description provided for @mutedUntilLabel.
  ///
  /// In en, this message translates to:
  /// **'Until: {date}'**
  String mutedUntilLabel(String date);

  /// No description provided for @userUnmuted.
  ///
  /// In en, this message translates to:
  /// **'{name} unmuted'**
  String userUnmuted(String name);

  /// No description provided for @failedUnmute.
  ///
  /// In en, this message translates to:
  /// **'Failed to unmute'**
  String get failedUnmute;

  /// No description provided for @failedUnmuteUser.
  ///
  /// In en, this message translates to:
  /// **'Failed to unmute {name}'**
  String failedUnmuteUser(String name);

  /// No description provided for @youAreMutedTitle.
  ///
  /// In en, this message translates to:
  /// **'You are muted'**
  String get youAreMutedTitle;

  /// No description provided for @mutedUntilMessage.
  ///
  /// In en, this message translates to:
  /// **'You can\'t send messages in this chat until {date}.'**
  String mutedUntilMessage(String date);

  /// No description provided for @slowModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Slow mode (seconds, 0 = off)'**
  String get slowModeLabel;

  /// No description provided for @slowModeHelper.
  ///
  /// In en, this message translates to:
  /// **'Minimum delay between messages for regular members. Admins are never limited.'**
  String get slowModeHelper;

  /// No description provided for @slowModeSetTo.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, one{Slow mode set to {seconds} second} other{Slow mode set to {seconds} seconds}}'**
  String slowModeSetTo(int seconds);

  /// No description provided for @slowModeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Slow mode disabled'**
  String get slowModeDisabled;

  /// No description provided for @failedSetSlowMode.
  ///
  /// In en, this message translates to:
  /// **'Failed to set slow mode'**
  String get failedSetSlowMode;

  /// No description provided for @failedUpdateSlowMode.
  ///
  /// In en, this message translates to:
  /// **'Failed to update slow mode'**
  String get failedUpdateSlowMode;

  /// No description provided for @donateMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donateMenuLabel;

  /// No description provided for @pollsMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get pollsMenuLabel;

  /// No description provided for @supportThisCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Support this community'**
  String get supportThisCommunityTitle;

  /// No description provided for @donationDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'ONYX does not process these payments and cannot refund them. Only send crypto to addresses you trust.'**
  String get donationDisclaimer;

  /// No description provided for @noDonationsOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'No donation addresses yet. Tap \"Edit\" to add some.'**
  String get noDonationsOwnerHint;

  /// No description provided for @noDonationsMemberHint.
  ///
  /// In en, this message translates to:
  /// **'This community has not set up donations yet.'**
  String get noDonationsMemberHint;

  /// No description provided for @editDonationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit donation addresses'**
  String get editDonationsTitle;

  /// No description provided for @donationCoinLabel.
  ///
  /// In en, this message translates to:
  /// **'Coin (e.g. BTC)'**
  String get donationCoinLabel;

  /// No description provided for @donationAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get donationAddressLabel;

  /// No description provided for @addDonationAddress.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addDonationAddress;

  /// No description provided for @donationsSaved.
  ///
  /// In en, this message translates to:
  /// **'Donation addresses saved'**
  String get donationsSaved;

  /// No description provided for @failedSaveDonations.
  ///
  /// In en, this message translates to:
  /// **'Failed to save donation addresses'**
  String get failedSaveDonations;

  /// No description provided for @noPollsOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'No polls yet. Tap \"New poll\" to create one.'**
  String get noPollsOwnerHint;

  /// No description provided for @noPollsHint.
  ///
  /// In en, this message translates to:
  /// **'No polls yet.'**
  String get noPollsHint;

  /// No description provided for @newPollAction.
  ///
  /// In en, this message translates to:
  /// **'New poll'**
  String get newPollAction;

  /// No description provided for @addPollOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addPollOption;

  /// No description provided for @pollQuestionLabel.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get pollQuestionLabel;

  /// No description provided for @pollOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String pollOptionLabel(int number);

  /// No description provided for @multipleChoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get multipleChoiceLabel;

  /// No description provided for @pollQuestionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Question cannot be empty'**
  String get pollQuestionEmpty;

  /// No description provided for @pollNeedsTwoOptions.
  ///
  /// In en, this message translates to:
  /// **'Add at least 2 options'**
  String get pollNeedsTwoOptions;

  /// No description provided for @failedCreatePoll.
  ///
  /// In en, this message translates to:
  /// **'Failed to create poll'**
  String get failedCreatePoll;

  /// No description provided for @failedVote.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit vote'**
  String get failedVote;

  /// No description provided for @pollVoteCountAnonymous.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} vote} other{{count} votes}} • anonymous'**
  String pollVoteCountAnonymous(int count);

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What is this group about?'**
  String get descriptionHint;

  /// No description provided for @noDescriptionSet.
  ///
  /// In en, this message translates to:
  /// **'No description set.'**
  String get noDescriptionSet;

  /// No description provided for @limitsHeader.
  ///
  /// In en, this message translates to:
  /// **'Limits'**
  String get limitsHeader;

  /// No description provided for @maxMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Max members'**
  String get maxMembersLabel;

  /// No description provided for @maxMessageLengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Max message length'**
  String get maxMessageLengthLabel;

  /// No description provided for @maxMessagesPerMinuteLabel.
  ///
  /// In en, this message translates to:
  /// **'Max messages per minute'**
  String get maxMessagesPerMinuteLabel;

  /// No description provided for @invalidLimitValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get invalidLimitValue;

  /// No description provided for @defaultRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Default role for new members'**
  String get defaultRoleLabel;

  /// No description provided for @rolesHeader.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get rolesHeader;

  /// No description provided for @addRoleAction.
  ///
  /// In en, this message translates to:
  /// **'Add role'**
  String get addRoleAction;

  /// No description provided for @deleteRoleConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete role?'**
  String get deleteRoleConfirmTitle;

  /// No description provided for @deleteRoleConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Members with this role will be moved to Member.'**
  String get deleteRoleConfirmContent;

  /// No description provided for @roleEditorCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create role'**
  String get roleEditorCreateTitle;

  /// No description provided for @roleEditorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit role'**
  String get roleEditorEditTitle;

  /// No description provided for @roleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Role name'**
  String get roleNameLabel;

  /// No description provided for @roleColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get roleColorLabel;

  /// No description provided for @rolePermissionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get rolePermissionsLabel;

  /// No description provided for @roleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} permissions · {members} members'**
  String roleSubtitle(int count, int members);

  /// No description provided for @settingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Settings updated'**
  String get settingsUpdated;

  /// No description provided for @failedUpdateSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to update settings'**
  String get failedUpdateSettings;

  /// No description provided for @roleSaved.
  ///
  /// In en, this message translates to:
  /// **'Role saved'**
  String get roleSaved;

  /// No description provided for @failedSaveRole.
  ///
  /// In en, this message translates to:
  /// **'Failed to save role'**
  String get failedSaveRole;

  /// No description provided for @roleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Role deleted'**
  String get roleDeleted;

  /// No description provided for @failedDeleteRole.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete role'**
  String get failedDeleteRole;

  /// No description provided for @addCommentAction.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get addCommentAction;

  /// No description provided for @commentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String commentsCount(int count);

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @writeCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get writeCommentHint;

  /// No description provided for @failedLoadComments.
  ///
  /// In en, this message translates to:
  /// **'Failed to load comments'**
  String get failedLoadComments;

  /// No description provided for @failedPostComment.
  ///
  /// In en, this message translates to:
  /// **'Failed to post comment'**
  String get failedPostComment;

  /// No description provided for @failedDeleteComment.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete comment'**
  String get failedDeleteComment;

  /// No description provided for @failedEditComment.
  ///
  /// In en, this message translates to:
  /// **'Failed to edit comment'**
  String get failedEditComment;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noCommentsYet;

  /// No description provided for @permKickMembers.
  ///
  /// In en, this message translates to:
  /// **'Kick members'**
  String get permKickMembers;

  /// No description provided for @permBanMembers.
  ///
  /// In en, this message translates to:
  /// **'Ban members'**
  String get permBanMembers;

  /// No description provided for @permMuteMembers.
  ///
  /// In en, this message translates to:
  /// **'Mute members'**
  String get permMuteMembers;

  /// No description provided for @permManageRoles.
  ///
  /// In en, this message translates to:
  /// **'Manage roles'**
  String get permManageRoles;

  /// No description provided for @permManageSettings.
  ///
  /// In en, this message translates to:
  /// **'Manage settings'**
  String get permManageSettings;

  /// No description provided for @permManageDonations.
  ///
  /// In en, this message translates to:
  /// **'Manage donations'**
  String get permManageDonations;

  /// No description provided for @permCreatePolls.
  ///
  /// In en, this message translates to:
  /// **'Create polls'**
  String get permCreatePolls;

  /// No description provided for @permPostInChannel.
  ///
  /// In en, this message translates to:
  /// **'Post in channel'**
  String get permPostInChannel;

  /// No description provided for @permDeleteMessages.
  ///
  /// In en, this message translates to:
  /// **'Delete messages'**
  String get permDeleteMessages;

  /// No description provided for @permManageMembers.
  ///
  /// In en, this message translates to:
  /// **'Manage members'**
  String get permManageMembers;

  /// No description provided for @permManageSlowMode.
  ///
  /// In en, this message translates to:
  /// **'Manage slow mode'**
  String get permManageSlowMode;

  /// No description provided for @permViewBanList.
  ///
  /// In en, this message translates to:
  /// **'Manage ban list'**
  String get permViewBanList;

  /// No description provided for @permViewMuteList.
  ///
  /// In en, this message translates to:
  /// **'Manage mute list'**
  String get permViewMuteList;

  /// No description provided for @permViewInviteLink.
  ///
  /// In en, this message translates to:
  /// **'View invite link'**
  String get permViewInviteLink;

  /// No description provided for @manageMembersRequiresChild.
  ///
  /// In en, this message translates to:
  /// **'Select at least one of Manage Ban List, Manage Mute List, or Manage Roles'**
  String get manageMembersRequiresChild;

  /// No description provided for @onionRetryWaiting.
  ///
  /// In en, this message translates to:
  /// **'Not connected · will send when connected'**
  String get onionRetryWaiting;

  /// No description provided for @onionRetryNow.
  ///
  /// In en, this message translates to:
  /// **'Sending… (attempt #{n})'**
  String onionRetryNow(int n);

  /// No description provided for @onionRetryIn.
  ///
  /// In en, this message translates to:
  /// **'Not online · retry #{n} in {s}s'**
  String onionRetryIn(int n, int s);

  /// No description provided for @onionOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact is not online'**
  String get onionOfflineTitle;

  /// No description provided for @onionOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'Your message could not be delivered right now because your contact is not online. It is saved on this device and will be resent automatically every {seconds} seconds until they come online. Keep the app open for retries to continue.\n\nYou can change the retry interval in Settings → Interaction → Messages.'**
  String onionOfflineMessage(int seconds);

  /// No description provided for @messagesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesSectionTitle;

  /// No description provided for @messagesSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery retries when a contact is offline'**
  String get messagesSectionSubtitle;

  /// No description provided for @retryIntervalTitle.
  ///
  /// In en, this message translates to:
  /// **'Retry interval'**
  String get retryIntervalTitle;

  /// No description provided for @retryIntervalDesc.
  ///
  /// In en, this message translates to:
  /// **'When a contact is not online, undelivered messages are resent automatically at this interval until they arrive.'**
  String get retryIntervalDesc;

  /// No description provided for @intervalSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n} seconds'**
  String intervalSeconds(int n);

  /// No description provided for @intervalMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String intervalMinutes(int n);

  /// No description provided for @statusOnlineLabel.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get statusOnlineLabel;

  /// No description provided for @statusOfflineLabel.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get statusOfflineLabel;

  /// No description provided for @statusConnectingLabel.
  ///
  /// In en, this message translates to:
  /// **'connecting…'**
  String get statusConnectingLabel;

  /// No description provided for @onionCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Call over Tor'**
  String get onionCallTitle;

  /// No description provided for @onionCallHideIp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t reveal my IP address'**
  String get onionCallHideIp;

  /// No description provided for @onionCallHideIpHint.
  ///
  /// In en, this message translates to:
  /// **'The call goes through Tor: your IP address stays hidden, but expect a delay of about a second. Video is not available.'**
  String get onionCallHideIpHint;

  /// No description provided for @onionCallDirectHint.
  ///
  /// In en, this message translates to:
  /// **'Lower delay, but the other person will see your IP address. A direct connection is only used if they allow it too; otherwise the call still goes through Tor.'**
  String get onionCallDirectHint;

  /// No description provided for @onionCallStart.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get onionCallStart;

  /// No description provided for @onionCallPeerOffline.
  ///
  /// In en, this message translates to:
  /// **'Contact is not connected — calling is not possible right now'**
  String get onionCallPeerOffline;

  /// No description provided for @onionCallNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get onionCallNoAnswer;

  /// No description provided for @onionCallFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not establish the call connection'**
  String get onionCallFailed;

  /// No description provided for @callIncomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get callIncomingTitle;

  /// No description provided for @callAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get callAccept;

  /// No description provided for @callDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get callDecline;

  /// No description provided for @callLogOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Outgoing call'**
  String get callLogOutgoing;

  /// No description provided for @callLogIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get callLogIncoming;

  /// No description provided for @callLogMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get callLogMissed;

  /// No description provided for @callLogCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled call'**
  String get callLogCancelled;

  /// No description provided for @callLogDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined call'**
  String get callLogDeclined;

  /// No description provided for @callLogBusy.
  ///
  /// In en, this message translates to:
  /// **'Line busy'**
  String get callLogBusy;

  /// No description provided for @callLogNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get callLogNoAnswer;

  /// No description provided for @callStatusCalling.
  ///
  /// In en, this message translates to:
  /// **'Calling'**
  String get callStatusCalling;

  /// No description provided for @callStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get callStatusConnecting;

  /// No description provided for @callPathRelay.
  ///
  /// In en, this message translates to:
  /// **'Via server'**
  String get callPathRelay;

  /// No description provided for @callEnd.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get callEnd;

  /// No description provided for @callMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get callMinimize;

  /// No description provided for @callRestore.
  ///
  /// In en, this message translates to:
  /// **'Open call'**
  String get callRestore;

  /// No description provided for @callFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callFallbackName;

  /// No description provided for @contactRequestNew.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to chat with you'**
  String contactRequestNew(String name);

  /// No description provided for @contactRequestsEntry.
  ///
  /// In en, this message translates to:
  /// **'Contact requests'**
  String get contactRequestsEntry;

  /// No description provided for @contactRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get contactRequestsTitle;

  /// No description provided for @contactRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get contactRequestsEmpty;

  /// No description provided for @contactRequestAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get contactRequestAccept;

  /// No description provided for @contactRequestDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get contactRequestDecline;

  /// No description provided for @contactRequestDeclineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline request?'**
  String get contactRequestDeclineTitle;

  /// No description provided for @contactRequestDeclineBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to message you or send you a new request. You can still add them yourself later.'**
  String get contactRequestDeclineBody;

  /// No description provided for @contactRequestNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No comment'**
  String get contactRequestNoMessages;

  /// No description provided for @contactRequestNameClash.
  ///
  /// In en, this message translates to:
  /// **'You already have a contact @{username} with a different key. It may be their new device, or someone impersonating them. Accept only if you are sure.'**
  String contactRequestNameClash(String username);

  /// No description provided for @contactRequestInfo.
  ///
  /// In en, this message translates to:
  /// **'Until you accept, they can\'t see when you\'re online, can\'t see your profile and can\'t call you.'**
  String get contactRequestInfo;

  /// No description provided for @contactRequestAddress.
  ///
  /// In en, this message translates to:
  /// **'Onion address'**
  String get contactRequestAddress;

  /// No description provided for @contactRequestKey.
  ///
  /// In en, this message translates to:
  /// **'Key fingerprint'**
  String get contactRequestKey;

  /// No description provided for @contactRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} added to contacts'**
  String contactRequestAccepted(String name);

  /// No description provided for @contactRequestFileHidden.
  ///
  /// In en, this message translates to:
  /// **'File (not accepted from non-contacts)'**
  String get contactRequestFileHidden;

  /// No description provided for @contactRequestMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get contactRequestMessages;

  /// No description provided for @forwardDone.
  ///
  /// In en, this message translates to:
  /// **'Message forwarded'**
  String get forwardDone;

  /// No description provided for @forwardFileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The file isn\'t on this device, so it can\'t be forwarded'**
  String get forwardFileUnavailable;

  /// No description provided for @contactRequestDeclineChoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Decline: the request disappears, but they can send a new one later. Decline and block: they will never be able to message you or send requests again.'**
  String get contactRequestDeclineChoiceBody;

  /// No description provided for @contactRequestDeclineAndBlock.
  ///
  /// In en, this message translates to:
  /// **'Decline and block'**
  String get contactRequestDeclineAndBlock;

  /// No description provided for @blockedFromRequests.
  ///
  /// In en, this message translates to:
  /// **'blocked request'**
  String get blockedFromRequests;

  /// No description provided for @contactRequestComposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact request'**
  String get contactRequestComposeTitle;

  /// No description provided for @contactRequestComposeBody.
  ///
  /// In en, this message translates to:
  /// **'Add a comment to your request — {name} will see it in their requests. You can write to each other once they accept.'**
  String contactRequestComposeBody(String name);

  /// No description provided for @contactRequestComposeHint.
  ///
  /// In en, this message translates to:
  /// **'Comment…'**
  String get contactRequestComposeHint;

  /// No description provided for @contactRequestSend.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get contactRequestSend;

  /// No description provided for @contactRequestSkip.
  ///
  /// In en, this message translates to:
  /// **'Without a comment'**
  String get contactRequestSkip;

  /// No description provided for @contactRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get contactRequestSent;

  /// No description provided for @contactRequestAttached.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get contactRequestAttached;

  /// No description provided for @contactRequestPendingSnack.
  ///
  /// In en, this message translates to:
  /// **'Your request hasn\'t been accepted yet — you can write once it is.'**
  String get contactRequestPendingSnack;

  /// No description provided for @contactRequestPendingCall.
  ///
  /// In en, this message translates to:
  /// **'You can call once they accept your request'**
  String get contactRequestPendingCall;

  /// No description provided for @contactRequestQueued.
  ///
  /// In en, this message translates to:
  /// **'They\'re offline — the request will be sent as soon as they\'re online'**
  String get contactRequestQueued;

  /// No description provided for @contactRequestDelivered.
  ///
  /// In en, this message translates to:
  /// **'Your request to {name} was delivered'**
  String contactRequestDelivered(String name);

  /// No description provided for @contactRequestResend.
  ///
  /// In en, this message translates to:
  /// **'Send the request again'**
  String get contactRequestResend;

  /// No description provided for @contactRequestUpdated.
  ///
  /// In en, this message translates to:
  /// **'Request updated'**
  String get contactRequestUpdated;

  /// No description provided for @contactRecordAcceptedBoth.
  ///
  /// In en, this message translates to:
  /// **'Contact request accepted'**
  String get contactRecordAcceptedBoth;

  /// No description provided for @contactRequestAlreadySent.
  ///
  /// In en, this message translates to:
  /// **'You already sent a request — it\'s waiting for their approval'**
  String get contactRequestAlreadySent;

  /// No description provided for @contactRequestAlreadySentShort.
  ///
  /// In en, this message translates to:
  /// **'Request already sent'**
  String get contactRequestAlreadySentShort;

  /// No description provided for @contactRecordAccepted.
  ///
  /// In en, this message translates to:
  /// **'You accepted the contact request'**
  String get contactRecordAccepted;

  /// No description provided for @contactRecordAcceptedByThem.
  ///
  /// In en, this message translates to:
  /// **'Your contact request was accepted'**
  String get contactRecordAcceptedByThem;

  /// No description provided for @contactRecordPreview.
  ///
  /// In en, this message translates to:
  /// **'Contact added'**
  String get contactRecordPreview;

  /// No description provided for @contactRequestAcceptedByThem.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your request'**
  String contactRequestAcceptedByThem(String name);

  /// No description provided for @searchOnionHint.
  ///
  /// In en, this message translates to:
  /// **'Paste an xxxx.onion address to send a request'**
  String get searchOnionHint;

  /// No description provided for @searchNeedOnionAddress.
  ///
  /// In en, this message translates to:
  /// **'That\'s not an onion address — paste one like xxxx.onion'**
  String get searchNeedOnionAddress;

  /// No description provided for @searchConnectingTor.
  ///
  /// In en, this message translates to:
  /// **'Connecting over Tor…'**
  String get searchConnectingTor;

  /// No description provided for @searchStillTrying.
  ///
  /// In en, this message translates to:
  /// **'Still trying to reach them ({attempt}/{max})…'**
  String searchStillTrying(int attempt, int max);

  /// No description provided for @contactRemovedYou.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in this person\'s contacts anymore — the message can\'t be delivered'**
  String get contactRemovedYou;

  /// No description provided for @contactNotInContacts.
  ///
  /// In en, this message translates to:
  /// **'This person isn\'t in your contacts — the message wasn\'t sent'**
  String get contactNotInContacts;

  /// No description provided for @contactRequestCommentFailed.
  ///
  /// In en, this message translates to:
  /// **'Request sent, but the comment didn\'t get through — they went offline'**
  String get contactRequestCommentFailed;

  /// No description provided for @callMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get callMute;

  /// No description provided for @callVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get callVideo;

  /// No description provided for @callSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get callSpeaker;

  /// No description provided for @callPathDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct connection'**
  String get callPathDirect;

  /// No description provided for @callPathTor.
  ///
  /// In en, this message translates to:
  /// **'Through Tor'**
  String get callPathTor;

  /// No description provided for @callVideoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Connection too weak — video is not available'**
  String get callVideoUnavailable;

  /// No description provided for @callVideoPaused.
  ///
  /// In en, this message translates to:
  /// **'Video turned off because the connection got weak'**
  String get callVideoPaused;

  /// No description provided for @statusShowMyStatus.
  ///
  /// In en, this message translates to:
  /// **'Show my online status'**
  String get statusShowMyStatus;

  /// No description provided for @statusShowMyStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Contacts see when you are online. When off, they see nothing and you also stop sharing your status.'**
  String get statusShowMyStatusHint;

  /// No description provided for @viewCircuitTitle.
  ///
  /// In en, this message translates to:
  /// **'View Circuit'**
  String get viewCircuitTitle;

  /// No description provided for @viewCircuitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The Tor relays your traffic is currently routed through'**
  String get viewCircuitSubtitle;

  /// No description provided for @viewCircuitEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active circuits yet. Try again in a moment.'**
  String get viewCircuitEmpty;

  /// No description provided for @circuitThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get circuitThisDevice;

  /// No description provided for @circuitRoleGuard.
  ///
  /// In en, this message translates to:
  /// **'guard'**
  String get circuitRoleGuard;

  /// No description provided for @circuitRoleIntro.
  ///
  /// In en, this message translates to:
  /// **'introduction point'**
  String get circuitRoleIntro;

  /// No description provided for @circuitRoleRend.
  ///
  /// In en, this message translates to:
  /// **'rendezvous point'**
  String get circuitRoleRend;

  /// No description provided for @circuitUnknownRelay.
  ///
  /// In en, this message translates to:
  /// **'Unknown relay'**
  String get circuitUnknownRelay;

  /// No description provided for @circuitOnionRelay.
  ///
  /// In en, this message translates to:
  /// **'Onion service relay'**
  String get circuitOnionRelay;

  /// No description provided for @circuitModeSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get circuitModeSimple;

  /// No description provided for @circuitModeAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get circuitModeAdvanced;

  /// No description provided for @mediaSendFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Send File'**
  String get mediaSendFileTitle;

  /// No description provided for @mediaSendFileDetails.
  ///
  /// In en, this message translates to:
  /// **'FILE DETAILS'**
  String get mediaSendFileDetails;

  /// No description provided for @mediaSendAlbumHeading.
  ///
  /// In en, this message translates to:
  /// **'ALBUM'**
  String get mediaSendAlbumHeading;

  /// No description provided for @mediaSendName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get mediaSendName;

  /// No description provided for @mediaSendSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get mediaSendSize;

  /// No description provided for @mediaSendType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get mediaSendType;

  /// No description provided for @mediaSendUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get mediaSendUnknown;

  /// No description provided for @mediaSendImagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get mediaSendImagesLabel;

  /// No description provided for @mediaSendImagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 image} other{{count} images}}'**
  String mediaSendImagesCount(int count);

  /// No description provided for @mediaSendConfirmAlbum.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to send these images as an album?'**
  String get mediaSendConfirmAlbum;

  /// No description provided for @mediaSendConfirmFile.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to send this file?'**
  String get mediaSendConfirmFile;

  /// No description provided for @mediaSendVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Voice Message'**
  String get mediaSendVoiceTitle;

  /// No description provided for @mediaSendVoiceHeading.
  ///
  /// In en, this message translates to:
  /// **'VOICE MESSAGE'**
  String get mediaSendVoiceHeading;

  /// No description provided for @mediaSendDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get mediaSendDuration;

  /// No description provided for @mediaSendConfirmVoice.
  ///
  /// In en, this message translates to:
  /// **'Send this voice message?'**
  String get mediaSendConfirmVoice;

  /// No description provided for @glassSimpleTitle.
  ///
  /// In en, this message translates to:
  /// **'Glass settings'**
  String get glassSimpleTitle;

  /// No description provided for @glassSimpleDesc.
  ///
  /// In en, this message translates to:
  /// **'One set of values for the navigation bar, input bar, search and app-bar buttons'**
  String get glassSimpleDesc;

  /// No description provided for @glassResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all to defaults'**
  String get glassResetAll;

  /// No description provided for @favDeleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 chat?} other{Delete {count} chats?}}'**
  String favDeleteSelectedTitle(int count);

  /// No description provided for @favDeleteSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected chats and all their messages will be removed from favorites.'**
  String get favDeleteSelectedMessage;

  /// No description provided for @glassMasterTitle.
  ///
  /// In en, this message translates to:
  /// **'Liquid Glass effects'**
  String get glassMasterTitle;

  /// No description provided for @glassMasterDesc.
  ///
  /// In en, this message translates to:
  /// **'Turn all glass effects on or off'**
  String get glassMasterDesc;

  /// No description provided for @glassTabGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get glassTabGeneral;

  /// No description provided for @glassTabAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get glassTabAdvanced;

  /// No description provided for @glassBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get glassBlur;

  /// No description provided for @glassBlurDesc.
  ///
  /// In en, this message translates to:
  /// **'Frosted blur intensity behind the glass'**
  String get glassBlurDesc;

  /// No description provided for @glassTint.
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get glassTint;

  /// No description provided for @glassTintDesc.
  ///
  /// In en, this message translates to:
  /// **'Adaptive tint opacity (auto dark/light)'**
  String get glassTintDesc;

  /// No description provided for @glassSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get glassSaturation;

  /// No description provided for @glassSaturationDesc.
  ///
  /// In en, this message translates to:
  /// **'Color vibrancy picked up from background'**
  String get glassSaturationDesc;

  /// No description provided for @glassChromatic.
  ///
  /// In en, this message translates to:
  /// **'Chromatic Aberration'**
  String get glassChromatic;

  /// No description provided for @glassChromaticDesc.
  ///
  /// In en, this message translates to:
  /// **'Color fringing on glass edges (lens effect)'**
  String get glassChromaticDesc;

  /// No description provided for @glassRefractive.
  ///
  /// In en, this message translates to:
  /// **'Refractive Index'**
  String get glassRefractive;

  /// No description provided for @glassRefractiveDesc.
  ///
  /// In en, this message translates to:
  /// **'How much the glass bends light behind it'**
  String get glassRefractiveDesc;

  /// No description provided for @glassLight.
  ///
  /// In en, this message translates to:
  /// **'Light Intensity'**
  String get glassLight;

  /// No description provided for @glassLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Strength of the specular highlight on glass'**
  String get glassLightDesc;

  /// No description provided for @glassThickness.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get glassThickness;

  /// No description provided for @glassThicknessDesc.
  ///
  /// In en, this message translates to:
  /// **'Glass depth — affects refraction and edge glow'**
  String get glassThicknessDesc;

  /// No description provided for @glassJelly.
  ///
  /// In en, this message translates to:
  /// **'Jelly Stretch Amount'**
  String get glassJelly;

  /// No description provided for @glassJellyDesc.
  ///
  /// In en, this message translates to:
  /// **'Indicator expansion when dragging between tabs'**
  String get glassJellyDesc;

  /// No description provided for @glassQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Glass Quality'**
  String get glassQualityTitle;

  /// No description provided for @glassQualityFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get glassQualityFast;

  /// No description provided for @glassQualityFastDesc.
  ///
  /// In en, this message translates to:
  /// **'Lightweight\nBest perf'**
  String get glassQualityFastDesc;

  /// No description provided for @glassQualityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get glassQualityMedium;

  /// No description provided for @glassQualityMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'No shaders\nBlur only'**
  String get glassQualityMediumDesc;

  /// No description provided for @glassQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get glassQualityHigh;

  /// No description provided for @glassQualityHighDesc.
  ///
  /// In en, this message translates to:
  /// **'Full shaders\nBest visuals'**
  String get glassQualityHighDesc;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'pt',
        'ru'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
