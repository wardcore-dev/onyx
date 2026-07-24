// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navChats => 'Discussions';

  @override
  String get navGroups => 'Groupes';

  @override
  String get navFavorites => 'Favoris';

  @override
  String get navAccounts => 'Comptes';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get close => 'Fermer';

  @override
  String get confirm => 'Confirmer';

  @override
  String get delete => 'Supprimer';

  @override
  String get clear => 'Effacer';

  @override
  String get loading => 'Chargement...';

  @override
  String get error => 'Erreur';

  @override
  String get success => 'Succès';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get test => 'Tester';

  @override
  String get connect => 'Connecter';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get enabled => 'Activé';

  @override
  String get disabled => 'Désactivé';

  @override
  String get on => 'Activé';

  @override
  String get off => 'Désactivé';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get supportOnyx => 'Soutenir ONYX';

  @override
  String get securityTitle => 'Sécurité et confidentialité';

  @override
  String get securitySubtitle =>
      'Appuyez pour voir les conseils et les détails du chiffrement';

  @override
  String get tipOfTheDay => 'Astuce du jour';

  @override
  String get statusSettings => 'Paramètres de statut';

  @override
  String get showDisplayNameInGroups =>
      'Afficher mon nom d\'affichage dans les groupes';

  @override
  String get showDisplayNameSubtitle =>
      'Si désactivé, vos messages apparaissent comme \"Anonyme\"';

  @override
  String get pinLock => 'Verrouillage par code PIN';

  @override
  String get enablePinLock => 'Activer le verrouillage par code PIN';

  @override
  String get enablePinSubtitle =>
      'Exiger un code PIN à 4 chiffres pour déverrouiller l\'application au démarrage';

  @override
  String get pinLockEnabled => ' Verrouillage par code PIN activé';

  @override
  String get pinLockDisabled => 'Verrouillage par code PIN désactivé';

  @override
  String get useBiometrics => 'Utiliser la biométrie';

  @override
  String get useBiometricsSubtitle =>
      'Déverrouiller par empreinte digitale ou reconnaissance faciale';

  @override
  String get biometricsUnavailable =>
      'Biométrie non disponible sur cet appareil';

  @override
  String get lockOnResume => 'Verrouiller en arrière-plan';

  @override
  String get lockOnResumeSubtitle =>
      'Exiger le code PIN à chaque retour de l\'application au premier plan';

  @override
  String get pinScreenSetTitle => 'Définir le code PIN';

  @override
  String get pinScreenConfirmTitle => 'Confirmer le code PIN';

  @override
  String get pinScreenEnterTitle => 'Entrer le code PIN';

  @override
  String get pinScreenChooseSubtitle => 'Choisissez un code PIN à 4 chiffres';

  @override
  String get pinScreenChooseChatSubtitle =>
      'Choisissez un code PIN à 4 chiffres pour cette discussion';

  @override
  String get pinScreenReenterSubtitle =>
      'Ressaisissez votre code PIN pour confirmer';

  @override
  String get pinScreenUnlockSubtitle =>
      'Entrez votre code PIN à 4 chiffres pour déverrouiller';

  @override
  String get pinScreenGenericSubtitle => 'Entrez votre code PIN à 4 chiffres';

  @override
  String get pinScreenDisableHeader =>
      'Entrez le code PIN actuel pour désactiver';

  @override
  String get pinScreenMismatchError =>
      'Les codes PIN ne correspondent pas. Réessayez.';

  @override
  String get pinScreenIncorrectError => 'Code PIN incorrect';

  @override
  String get searchChatsHint => 'Rechercher des discussions et des messages…';

  @override
  String get searchGroupsHint => 'Rechercher des groupes et des messages…';

  @override
  String get searchFavoritesHint => 'Rechercher dans les favoris…';

  @override
  String get searchSettingsHint => 'Rechercher dans les paramètres…';

  @override
  String get keyMgmtTitle => 'Gestion des clés';

  @override
  String get keyMgmtSubtitle =>
      'Renouveler ou réinitialiser votre identité de chiffrement';

  @override
  String get keyMgmtDescription =>
      'Renouvelez votre clé d\'identité E2EE si vous pensez qu\'elle a été compromise. Vos contacts reçoivent automatiquement la nouvelle clé.';

  @override
  String get rotateE2eeKey => 'Renouveler la clé E2EE';

  @override
  String get rotateE2eeKeyPrimaryOnly =>
      'Renouveler la clé E2EE (appareil principal uniquement)';

  @override
  String get rotateKeyDialogTitle => 'Renouveler la clé de chiffrement ?';

  @override
  String get rotateKeyDialogContent =>
      'Une nouvelle paire de clés X25519 sera générée et envoyée au serveur.nnVotre session et l\'historique des messages ne sont PAS affectés. Vos contacts utiliseront automatiquement la nouvelle clé pour leur prochain message.';

  @override
  String get rotateKeyBtn => 'Renouveler';

  @override
  String get rotatingKey => ' Renouvellement de la clé…';

  @override
  String get keyRotated => ' Clé E2EE renouvelée et envoyée';

  @override
  String get keyRotationFailed => ' Échec du renouvellement de la clé';

  @override
  String get activeDevices => 'Appareils actifs';

  @override
  String get activeDevicesSubtitle =>
      'Appareils, mot de passe et clé de chiffrement';

  @override
  String get activeDevicesPrimaryOnly =>
      'Appareils actifs (appareil principal uniquement)';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get changePasswordPrimaryOnly =>
      'Changer le mot de passe (appareil principal uniquement)';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'Gérer les alertes et les options de remise';

  @override
  String get notificationsEnabled => 'Activer les notifications';

  @override
  String get notificationsEnabledSubtitle =>
      'Afficher les notifications système pour les nouveaux messages';

  @override
  String get notificationPosition => 'Position des notifications';

  @override
  String get notifPosTopLeft => 'En haut à gauche';

  @override
  String get notifPosTopRight => 'En haut à droite';

  @override
  String get notifPosBottomLeft => 'En bas à gauche';

  @override
  String get notifPosBottomRight => 'En bas à droite';

  @override
  String get appearanceTitle => 'Apparence';

  @override
  String get appearanceSubtitle => 'Choisir le thème et le mode sombre';

  @override
  String get selectTheme => 'Choisir un thème';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get fontAndTextSize => 'Police et taille du texte';

  @override
  String get fontFamily => 'Police';

  @override
  String get messageSize => 'Taille des messages';

  @override
  String get fontPreviewMessage => 'Exemple';

  @override
  String get ownMessagesRight => 'Mes messages : à droite';

  @override
  String get ownMessagesLeft => 'Mes messages : à gauche';

  @override
  String get alignAllRight => 'Aligner tous les messages à droite';

  @override
  String get alignAllRightSubtitle =>
      'Tous les messages sont alignés à droite, comme un miroir';

  @override
  String get showAvatarInChats =>
      'Afficher l\'avatar dans la liste des discussions';

  @override
  String get showAccountIndicator => 'Afficher le compte actuel';

  @override
  String get showAccountIndicatorSubtitle =>
      'Afficher le nom et le nom d\'utilisateur dans le coin de l\'application';

  @override
  String get showAvatarSubtitle =>
      'Afficher l\'avatar du contact dans la liste des discussions';

  @override
  String get chatBackground => 'Arrière-plan de discussion';

  @override
  String get chatBgSubtitle =>
      'Définir une image comme arrière-plan de discussion';

  @override
  String get chooseImage => 'Choisir une image';

  @override
  String get clearBackground => 'Effacer l\'arrière-plan';

  @override
  String get applyGlobally => 'Appliquer globalement';

  @override
  String get applyGloballySubtitle =>
      'Utiliser cet arrière-plan dans toutes les discussions';

  @override
  String get blurBackground => 'Flouter l\'arrière-plan';

  @override
  String get elementOpacity => 'Opacité des éléments';

  @override
  String get elementBrightness => 'Luminosité des éléments';

  @override
  String get uiLayout => 'Disposition de l\'interface';

  @override
  String get navBarPosition => 'Position de la barre de navigation';

  @override
  String get navLeft => 'Gauche';

  @override
  String get navBottom => 'Bas';

  @override
  String get inputBarMaxWidth => 'Largeur de la barre de saisie';

  @override
  String get minimizeBottomNav => 'Réduire la barre de navigation inférieure';

  @override
  String get minimizeBottomNavSubtitle =>
      'Masquer les libellés dans la barre de navigation inférieure';

  @override
  String get swipeTabs => 'Balayer entre les onglets';

  @override
  String get swipeTabsSubtitle =>
      'Changer d\'onglet par un geste de balayage horizontal';

  @override
  String get smoothScroll => 'Défilement fluide';

  @override
  String get performanceOptimizations => 'Optimisations de performance';

  @override
  String get macOsWindowStyle => 'Style de fenêtre';

  @override
  String get macOsWindowStyleSubtitle => 'Style des contrôles de fenêtre';

  @override
  String get macOsNativeTitleBar => 'macOS natif (feux tricolores)';

  @override
  String get macOsCustomTitleBar => 'Style Windows (côté droit)';

  @override
  String get updateAvailableLabel => 'Mise à jour disponible';

  @override
  String get updateDownload => 'Télécharger';

  @override
  String get cacheTitle => 'Cache';

  @override
  String get cacheSubtitle => 'Gérer le cache multimédia local et serveur';

  @override
  String get mediaCacheSize => 'Cache des messages multimédias : ';

  @override
  String get clearLocalCache => 'Vider le cache local';

  @override
  String get clearLocalCacheTitle => 'Vider le cache local';

  @override
  String get clearLocalCacheContent =>
      'Voulez-vous vraiment supprimer tous les médias mis en cache (messages vocaux, images, vidéos) ?nCela n\'affecte PAS les fichiers envoyés sur le serveur ni l\'historique des discussions.';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get serverMediaCache => 'Cache multimédia du serveur';

  @override
  String get serverMediaCacheSubtitle =>
      'Stocké sur le serveur : images, messages vocaux, vidéos.';

  @override
  String get clearServerCache => 'Vider le cache du serveur';

  @override
  String get dangerZone => 'Zone de danger';

  @override
  String get dangerZoneSubtitle =>
      'Supprimer le compte du serveur et/ou effacer les données locales.';

  @override
  String get factoryReset => 'Réinitialisation d\'usine';

  @override
  String get factoryResetHint =>
      'Sélectionnez ce qu\'il faut réinitialiser. Au moins une option doit être choisie.';

  @override
  String get resetDeleteAccount => 'Supprimer le compte du serveur';

  @override
  String resetDeleteAccountSubtitle(String username) {
    return 'Supprime définitivement @$username — tous les messages, médias et clés du serveur.';
  }

  @override
  String get resetNoAccount => 'Aucun compte n\'est connecté.';

  @override
  String get resetDeleteLocal =>
      'Supprimer les données locales de l\'application';

  @override
  String get resetDeleteLocalSubtitle =>
      'Efface toutes les discussions, clés, paramètres, caches et médias locaux.';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get resetFailed => 'Échec de la réinitialisation';

  @override
  String get connectionTitle => 'Connexion';

  @override
  String get connectionSubtitle =>
      'État et contrôles de la connexion WebSocket';

  @override
  String get proxyTitle => 'Proxy';

  @override
  String get proxySubtitle => 'Acheminer le trafic via un proxy HTTP ou SOCKS5';

  @override
  String get enableProxy => 'Activer le proxy';

  @override
  String get proxyType => 'Type de proxy';

  @override
  String get proxyHost => 'Hôte';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxyUsername => 'Nom d\'utilisateur';

  @override
  String get proxyPassword => 'Mot de passe';

  @override
  String get testProxy => 'Tester le proxy';

  @override
  String get proxyTesting => 'Test en cours...';

  @override
  String get proxyOk => ' Proxy OK';

  @override
  String get proxyFailed => ' Proxy inaccessible';

  @override
  String get useProxy => 'Utiliser le proxy';

  @override
  String get proxyDirectConnection => 'Connexion directe';

  @override
  String get proxyRouted => 'Trafic acheminé via le proxy';

  @override
  String get proxyConnectedStatus => 'Connecté';

  @override
  String get proxyNotConnectedStatus => 'Non connecté';

  @override
  String get proxyLoginOptional => 'Identifiant (facultatif)';

  @override
  String get proxyPasswordOptional => 'Mot de passe (facultatif)';

  @override
  String get proxyApplyReconnect => 'Appliquer et se reconnecter';

  @override
  String get appDataTitle => 'Dossier de données ONYX';

  @override
  String get appDataSubtitle =>
      'Déplacer le dossier de données de l\'application vers un autre lecteur';

  @override
  String get appDataCurrentPath => 'Dossier actuel';

  @override
  String get appDataDefault => 'Par défaut (dossier système)';

  @override
  String get appDataMove => 'Déplacer…';

  @override
  String get appDataReset => 'Réinitialiser';

  @override
  String get appDataMigrating => 'Déplacement des données…';

  @override
  String get appDataMigrateError => 'Erreur lors du déplacement';

  @override
  String get appDataRestartRequired =>
      'Dossier modifié. Redémarrez ONYX pour appliquer le changement.';

  @override
  String get appDataRestart => 'Redémarrer ONYX';

  @override
  String get appDataOpenFolder => 'Ouvrir le dossier';

  @override
  String get appDataDeleteOldFolder => 'Supprimer l\'ancien dossier';

  @override
  String get appDataDeleteOldFolderSubtitle =>
      'Supprime le dossier système d\'origine laissé après la migration';

  @override
  String get appDataDeleteOldFolderConfirm =>
      'Supprimer le dossier de données ONYX d\'origine ?nnCette action est irréversible. Assurez-vous que les données ont bien été migrées.';

  @override
  String get appDataDeleteOldFolderSuccess => 'Ancien dossier supprimé';

  @override
  String get appDataDeleteOldFolderError => 'Erreur lors de la suppression : ';

  @override
  String get interactTitle => 'Interaction';

  @override
  String get interactSubtitle => 'Confirmations d\'envoi de fichiers';

  @override
  String get confirmFileUpload => 'Confirmer l\'envoi de fichiers';

  @override
  String get confirmFileUploadSubtitle =>
      'Afficher une boîte de dialogue de confirmation avant l\'envoi de fichiers';

  @override
  String get confirmVoiceMessage => 'Confirmer les messages vocaux';

  @override
  String get confirmVoiceSubtitle =>
      'Afficher une boîte de dialogue de confirmation avant l\'envoi d\'un message vocal';

  @override
  String get downloadFolder => 'Dossier de téléchargement';

  @override
  String get downloadFolderSubtitle =>
      'Emplacement de sauvegarde des fichiers reçus (par défaut : Téléchargements/ONYX)';

  @override
  String get downloadFolderDefault => 'Par défaut (Téléchargements/ONYX)';

  @override
  String get downloadFolderChange => 'Choisir un dossier';

  @override
  String get downloadFolderReset => 'Réinitialiser';

  @override
  String get contactTitle => 'Contact';

  @override
  String get contactSubtitle => 'Site web, dépôt et retours';

  @override
  String get contactWebsite => 'Site officiel';

  @override
  String get contactRepository => 'Code source (client)';

  @override
  String get contactRepositoryServer => 'Code source (serveur auto-hébergé)';

  @override
  String get contactEmail => 'Nous contacter';

  @override
  String get debugTitle => 'Débogage/Journaux';

  @override
  String get debugSubtitle => 'Performance et journalisation en temps réel';

  @override
  String get debugMode => 'Mode débogage';

  @override
  String get debugModeSubtitle =>
      'Activer le suivi des performances et les journaux';

  @override
  String get enableFileLogging => 'Activer la journalisation dans un fichier';

  @override
  String get enableFileLoggingSubtitle =>
      'Écrire les journaux de l\'application sur le disque (désactivez pour préserver la confidentialité)';

  @override
  String get deleteAllLogs => 'Supprimer tous les journaux';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageSubtitle => 'Langue de l\'interface de l\'application';

  @override
  String get languageChanged => 'Langue modifiée';

  @override
  String get noChatsYet => 'Aucune discussion pour le moment';

  @override
  String get deleteChatTitle => 'Supprimer la discussion ?';

  @override
  String get blockUserLabel => 'Bloquer l\'utilisateur';

  @override
  String get unblockUserLabel => 'Débloquer';

  @override
  String get muteUserLabel => 'Désactiver les notifications';

  @override
  String get unmuteUserLabel => 'Réactiver les notifications';

  @override
  String get blockedByUserMessage =>
      'Cet utilisateur a restreint les messages entrants de votre part.';

  @override
  String unblockUserConfirmContent(String name) {
    return 'Débloquer $name ?';
  }

  @override
  String blockUserConfirmContent(String name) {
    return 'Bloquer $name ? Cette personne ne pourra plus vous envoyer de messages.';
  }

  @override
  String deleteChatContent(String name) {
    return 'Voulez-vous vraiment supprimer la discussion avec \"$name\" ? Cette action est irréversible.';
  }

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get displayName => 'Nom d\'affichage';

  @override
  String get addAccount => 'Ajouter un compte';

  @override
  String get welcomeTitle => 'Bienvenue';

  @override
  String get welcomeTagline => 'Messagerie sécurisée chiffrée de bout en bout';

  @override
  String get otherAccounts => 'Autres comptes';

  @override
  String get tapToSwitch => 'Appuyez pour changer';

  @override
  String get deleteFromRecentTitle => 'Supprimer le compte des récents ?';

  @override
  String get authUsernameLabel => 'Nom d\'utilisateur (3 à 16 caractères)';

  @override
  String get authPasswordLabel => 'Mot de passe (16 caractères min.)';

  @override
  String get loginBtn => 'Se connecter';

  @override
  String get registerBtn => 'S\'inscrire';

  @override
  String get deviceAuthTitle => 'Associer un appareil';

  @override
  String get deviceAuthTabScan => 'Scanner';

  @override
  String get deviceAuthLanNote =>
      'Les deux appareils doivent être sur le même réseau local';

  @override
  String get loginWithQr => 'Connexion par QR code';

  @override
  String get qrAuthWaitingTitle => 'En attente du téléphone';

  @override
  String get qrAuthWaitingSubtitle =>
      'Scannez ce code sur un appareil autorisé pour transférer la session ici';

  @override
  String get qrAuthSuccess => 'Appareil autorisé';

  @override
  String get qrAuthFailed => 'Échec de l\'authentification par QR code';

  @override
  String get qrAuthCancelled => 'Authentification par QR code annulée';

  @override
  String get authorizeDevice => 'Autoriser un appareil';

  @override
  String get authorizeDeviceSubtitle =>
      'Autoriser un autre appareil à se connecter en scannant un QR code';

  @override
  String get authorizeDeviceScanHint =>
      'Pointez la caméra vers le QR code affiché sur l\'autre appareil';

  @override
  String get authorizeDeviceSuccess => 'Appareil autorisé avec succès';

  @override
  String get authorizeDeviceFailed => 'Échec de l\'autorisation de l\'appareil';

  @override
  String get authorizeDeviceSending => 'Envoi des identifiants…';

  @override
  String get qrAuthEncryptedNote =>
      'Le transfert est chiffré (X25519 + AES-256-GCM)';

  @override
  String get scanFromPc => 'Recevoir depuis un PC';

  @override
  String get scanFromPcHint =>
      'Pointez la caméra vers le QR code affiché sur un autre appareil pour vous connecter ici';

  @override
  String get grantDeviceTitle => 'Autoriser un téléphone';

  @override
  String get grantDeviceSubtitle =>
      'Scannez ce code sur un autre appareil pour vous y connecter avec ce compte';

  @override
  String get grantDeviceSuccess => 'Téléphone autorisé avec succès';

  @override
  String get grantDeviceFailed => 'Échec de l\'autorisation du téléphone';

  @override
  String get enterUsernameMsg => 'Entrez votre nom d\'utilisateur';

  @override
  String get loginSuccess => 'Connexion réussie';

  @override
  String get loginFailed => 'Échec de la connexion';

  @override
  String get registeringMsg => 'Inscription en cours...';

  @override
  String get registrationFailed => ' Échec de l\'inscription';

  @override
  String get usernameInvalidMsg =>
      'Nom d\'utilisateur : 3 à 16 caractères, lettres, chiffres, _ . - uniquement';

  @override
  String get passwordTooShortMsg => 'Mot de passe trop court (16 min.)';

  @override
  String get generatePasswordTooltip => 'Générer un mot de passe fort';

  @override
  String get savePasswordWarning =>
      'Veillez à enregistrer votre mot de passe dans un endroit sûr — notez-le. La récupération sans mot de passe est impossible.';

  @override
  String get passphraseWriteDown =>
      'Cette phrase de récupération ne sera plus jamais affichée. Notez ces 12 mots à la main et conservez-les en lieu sûr — vous en aurez besoin pour récupérer votre compte si vous oubliez votre mot de passe.';

  @override
  String get passphraseWriteOnPaper =>
      'Notez votre phrase de récupération sur papier dès maintenant — il n\'y aura pas de seconde chance !';

  @override
  String get copyToClipboard => 'Copier dans le presse-papiers';

  @override
  String get copiedToClipboard => 'Copié !';

  @override
  String passphraseCountdown(int s) {
    return 'Veuillez lire attentivement — disponible dans $s s...';
  }

  @override
  String get iSavedIt => 'Je l\'ai enregistrée';

  @override
  String deleteFromRecentContent(String acc) {
    return 'Voulez-vous vraiment retirer \"$acc\" de la liste récente ?nCela ne supprime pas le compte du serveur.';
  }

  @override
  String get createGroupChannel => 'Créer un groupe/canal';

  @override
  String get channelAdminOnly => 'Canal (seuls les admins publient)';

  @override
  String get viewByToken => 'Voir par jeton';

  @override
  String get viewByIp => 'Voir par IP (serveur externe)';

  @override
  String get createGroupOrChannel => 'Créer un groupe ou un canal';

  @override
  String get removeExternalServerTitle => 'Retirer le serveur externe ?';

  @override
  String removeExternalServerContent(String name) {
    return 'Retirer \"$name\" et tous ses groupes de votre liste ? Vous pourrez le rejoindre plus tard en saisissant à nouveau l\'adresse du serveur.';
  }

  @override
  String get noGroupsYet => 'Aucun groupe pour le moment';

  @override
  String get groupNameLabel => 'Nom du groupe :';

  @override
  String get groupNameHint => 'Entrez un nom';

  @override
  String get pasteToken => 'Coller le jeton :';

  @override
  String get create => 'Créer';

  @override
  String get view => 'Voir';

  @override
  String get leave => 'Quitter';

  @override
  String get remove => 'Retirer';

  @override
  String get leaveGroupAction => 'Quitter';

  @override
  String leaveGroupContent(String name) {
    return 'Voulez-vous vraiment quitter \"$name\" ? Vous ne recevrez plus de messages de ce groupe.';
  }

  @override
  String get chooseCrypto => 'Choisir une cryptomonnaie à donner';

  @override
  String get addressCopied => 'adresse copiée';

  @override
  String get hideFromSearch => 'Me masquer de la recherche';

  @override
  String get hideFromSearchSubtitle =>
      'Les autres ne pourront pas vous trouver par recherche de nom d\'utilisateur';

  @override
  String get hideFromSearchSavedOk =>
      ' Paramètres de confidentialité enregistrés';

  @override
  String get hideFromSearchSavedFail =>
      ' Enregistré localement, échec de la synchronisation';

  @override
  String get statusVisibility => 'Visibilité';

  @override
  String get statusShowStatus => 'Afficher le statut';

  @override
  String get statusHideStatus => 'Masquer le statut';

  @override
  String get statusCustomText => 'Texte de statut personnalisé';

  @override
  String get statusWhenOnline => 'En ligne';

  @override
  String get statusWhenOffline => 'Hors ligne';

  @override
  String get statusSavedOk =>
      ' Paramètres de statut enregistrés et synchronisés';

  @override
  String get statusSavedFail =>
      ' Enregistré localement, échec de la synchronisation avec le serveur';

  @override
  String get clearServerCacheTitle => 'Vider les médias du serveur ?';

  @override
  String get clearServerCacheContent =>
      'Cela supprimera TOUS vos médias envoyés sur le serveur, y compris :n\'\n        \'• Messages vocauxn\'\n        \'• Imagesn\'\n        \'• Vidéosn\'\n        \'• Fichiersn\'\n        \'• Avatarnn\'\n        \'Le cache local sera conservé. Cette action est irréversible.';

  @override
  String get serverMediaCleared =>
      ' Tous les médias du serveur ont été supprimés';

  @override
  String get notLoggedIn => 'Non connecté';

  @override
  String get serverMediaManagerTitle => 'Médias du serveur';

  @override
  String get cacheTabImages => 'Images';

  @override
  String get cacheTabVoice => 'Vocaux';

  @override
  String get cacheTabAudio => 'Audio';

  @override
  String get cacheTabVideo => 'Vidéo';

  @override
  String get cacheTabFiles => 'Fichiers';

  @override
  String get cacheTabDocuments => 'Documents';

  @override
  String get cacheTabArchives => 'Archives';

  @override
  String get cacheTabData => 'Données';

  @override
  String get cacheTabAvatars => 'Avatars';

  @override
  String get cacheNoFiles => 'Aucun fichier dans cette catégorie';

  @override
  String get cacheClearTabTitle => 'Vider la catégorie ?';

  @override
  String cacheClearTabContent(String typeName) {
    return 'Supprimer tous les fichiers dans \"$typeName\" ? Cette action est irréversible.';
  }

  @override
  String get cacheFileDeleteFailed => 'Échec de la suppression du fichier';

  @override
  String get cacheClearAll => 'Tout effacer';

  @override
  String get cacheClearTab => 'Vider l\'onglet';

  @override
  String get cleanUnusedFiles => 'Nettoyer les fichiers inutilisés';

  @override
  String get cleaningUnusedFiles => 'Nettoyage...';

  @override
  String get orphanedCleanupAppNotReady => 'Application non prête';

  @override
  String get orphanedCleanupNoFiles => 'Aucun fichier inutilisé trouvé';

  @override
  String get manageCacheTitle => 'Gérer le cache';

  @override
  String get manageCacheButton => 'Gérer le cache multimédia';

  @override
  String get localCacheTab => 'Local';

  @override
  String get serverCacheTab => 'Serveur';

  @override
  String get cacheSelectAll => 'Tout sélectionner';

  @override
  String get cacheDeselectAll => 'Tout désélectionner';

  @override
  String get cacheSelected => 'sélectionné(s)';

  @override
  String get clearLocalCacheDialogTitle => 'Vider le cache local';

  @override
  String get clearLocalCacheDialogContent =>
      'Voulez-vous vraiment supprimer tous les médias mis en cache (messages vocaux, images, vidéos) ?nCela n\'affecte PAS les fichiers envoyés sur le serveur ni l\'historique des discussions.';

  @override
  String get deleteAllLogsTitle => 'Supprimer tous les journaux ?';

  @override
  String get deleteAllLogsContent =>
      'Cela supprimera définitivement tous les fichiers journaux de l\'application du disque.\nCette action est irréversible.';

  @override
  String get noLogsFound => 'Aucun fichier journal trouvé.';

  @override
  String get changePasswordInfo =>
      'Entrez votre phrase de récupération et votre mot de passe actuel pour définir un nouveau mot de passe.';

  @override
  String get changePasswordPassphraseLabel =>
      'Phrase de récupération (12 mots)';

  @override
  String get changePasswordCurrentLabel => 'Mot de passe actuel';

  @override
  String get changePasswordNewLabel =>
      'Nouveau mot de passe (16 caractères min.)';

  @override
  String get changePasswordChange => 'Changer';

  @override
  String get changePasswordFieldsRequired =>
      'Tous les champs sont obligatoires';

  @override
  String get changePasswordTooShort =>
      'Le nouveau mot de passe doit comporter au moins 16 caractères';

  @override
  String get changePasswordChanging => 'Changement du mot de passe...';

  @override
  String get changePasswordSuccess => ' Mot de passe changé avec succès';

  @override
  String get clearBgTitle => 'Effacer l\'arrière-plan ?';

  @override
  String get clearBgContent =>
      'Retirer l\'arrière-plan de discussion personnalisé et restaurer celui par défaut.';

  @override
  String get chatBgSet => ' Arrière-plan de discussion défini';

  @override
  String get chatBgCleared => 'Arrière-plan effacé';

  @override
  String get allMessagesLeft => 'Tous les messages : à gauche';

  @override
  String get allMessagesRight2 => 'Tous les messages : à droite';

  @override
  String get allMessagesMixed => 'Tous les messages : mixte';

  @override
  String get applyBackgroundToApp =>
      'Appliquer l\'arrière-plan à toute l\'application';

  @override
  String get uiElementsOpacityLabel => 'Opacité des éléments d\'interface';

  @override
  String get uiElementsBrightnessLabel =>
      'Luminosité des éléments d\'interface';

  @override
  String get navPanelPosition => 'Position du panneau de navigation';

  @override
  String get navPosBottom => 'Bas (sous la liste des discussions)';

  @override
  String get navPosLeft => 'Gauche (barre latérale)';

  @override
  String get tabSwiping => 'Balayage des onglets';

  @override
  String get tabSwipingSubtitle =>
      'Balayer entre les onglets avec un effet de rebond';

  @override
  String get showAvatarsInChats => 'Afficher les avatars dans les discussions';

  @override
  String get smoothScrollDown => 'Défilement fluide vers le bas';

  @override
  String get messageAnimations => 'Animations des messages';

  @override
  String get chatListMoveAnimations =>
      'Animations de déplacement dans la liste des discussions';

  @override
  String get scrollDownButtonPosition =>
      'Position du bouton de défilement vers le bas';

  @override
  String get scrollDownButtonPositionLeft => 'Gauche';

  @override
  String get scrollDownButtonPositionCenter => 'Centre';

  @override
  String get scrollDownButtonPositionRight => 'Droite';

  @override
  String get scrollDownButtonSize =>
      'Taille du bouton de défilement vers le bas';

  @override
  String get loadOlderMessagesOnScroll =>
      'Charger les anciens messages en défilant';

  @override
  String get showSnackbars => 'Afficher les notifications ponctuelles';

  @override
  String get autoLoadVideos => 'Chargement automatique des vidéos';

  @override
  String get autoLoadVideosSubtitle =>
      'Si désactivé, les vidéos ne se chargent qu\'au toucher — défilement plus fluide';

  @override
  String get tapToLoadVideo => 'Appuyez pour charger la vidéo';

  @override
  String get chooseBackground => 'Choisir';

  @override
  String get presetsBackground => 'Préréglages';

  @override
  String get clearBackground2 => 'Effacer';

  @override
  String get liquidGlassSubtitle =>
      'Configurer les effets de verre et la qualité par élément';

  @override
  String get liquidGlassNavBarLabel => 'Barre de navigation';

  @override
  String get liquidGlassNavBarDesc =>
      'Effet de verre sur la barre de navigation inférieure';

  @override
  String get liquidGlassCardsLabel => 'Cartes et éléments de liste';

  @override
  String get liquidGlassCardsDesc =>
      'Effet de verre sur la liste des discussions et les cartes de paramètres';

  @override
  String get liquidGlassInputLabel => 'Barre de saisie';

  @override
  String get liquidGlassInputDesc =>
      'Effet de verre sur la barre de composition des messages';

  @override
  String get liquidGlassSearchLabel => 'Recherche';

  @override
  String get liquidGlassSearchDesc =>
      'Panneau de verre façon Spotlight pour la recherche d\'utilisateurs';

  @override
  String get liquidGlassAppBarLabel => 'Boutons de la barre d\'application';

  @override
  String get liquidGlassAppBarDesc =>
      'Effet de verre sur les boutons d\'icônes de la barre d\'application de discussion';

  @override
  String get sendFavoritesScanHint =>
      'Pointez la caméra vers le QR code affiché sur l\'appareil du destinataire';

  @override
  String get mediaPickerGallery => 'Galerie';

  @override
  String get mediaPickerCamera => 'Appareil photo';

  @override
  String get mediaPickerFile => 'Fichier';

  @override
  String mediaPickerSend(int n) {
    return 'Envoyer $n';
  }

  @override
  String get mediaPickerChooseWallpaper => 'Choisir un fond d\'écran';

  @override
  String get mediaPickerFiles => 'Fichiers';

  @override
  String get mediaPickerDeniedTitle => 'Accès à la galerie refusé';

  @override
  String get mediaPickerDeniedBody =>
      'Autorisez l\'accès dans les paramètres ou choisissez directement un fichier.';

  @override
  String get mediaPickerPickFile => 'Choisir un fichier';

  @override
  String get mediaPickerOpenSettings => 'Ouvrir les paramètres';

  @override
  String get notifWarning =>
      'Les notifications ne sont livrées que lorsque l\'application est en cours d\'exécution. Pour ne jamais manquer un message, laissez ONYX réduit dans la barre système au lieu de le fermer.';

  @override
  String get backgroundServiceTitle => 'Service en arrière-plan';

  @override
  String get backgroundServiceSubtitle =>
      'Garder ONYX connecté une fois réduit';

  @override
  String get backgroundServiceEnableLabel =>
      'Continuer à fonctionner en arrière-plan';

  @override
  String get backgroundServiceEnableSubtitle =>
      'Affiche une notification permanente pour empêcher le système d\'arrêter la réception des messages par ONYX en arrière-plan';

  @override
  String get backgroundServiceTextLabel => 'Texte de la notification';

  @override
  String get backgroundServiceDefaultText => 'En attente de messages';

  @override
  String get notifPopupPosition => 'Position de la fenêtre contextuelle';

  @override
  String get notifPopupPositionSubtitle =>
      'Choisissez où la notification apparaît à l\'écran';

  @override
  String get notifEnableLabel => 'Activer les notifications';

  @override
  String get notifHideContentLabel => 'Masquer le contenu du message';

  @override
  String get notifSoundEnableLabel => 'Son de notification';

  @override
  String get notifSoundChooseLabel => 'Choisir un son';

  @override
  String get notifSoundCustom => 'Importer un son personnalisé...';

  @override
  String get notifSoundCustomLoaded => 'Son personnalisé défini';

  @override
  String get notifSoundCustomError => 'Échec du chargement du son';

  @override
  String get notifSoundCustomInvalidFormat =>
      'Formats pris en charge : WAV, MP3, M4A, OGG, AAC';

  @override
  String get resetting => 'Réinitialisation...';

  @override
  String get launchAtStartupLabel => 'Démarrer au lancement du système';

  @override
  String get launchAtStartupSubtitle =>
      'Démarrer automatiquement ONYX à l\'ouverture de session';

  @override
  String get launchAtStartupEnabled => 'Démarrage automatique activé';

  @override
  String get launchAtStartupDisabled => 'Démarrage automatique désactivé';

  @override
  String get launchAtStartupFailed =>
      'Échec de la modification du paramètre de démarrage';

  @override
  String get avatarUpdated => 'Avatar mis à jour';

  @override
  String get fileNotFound => 'Fichier introuvable';

  @override
  String get fileSent => 'Fichier envoyé';

  @override
  String get imageSent => 'Image envoyée';

  @override
  String get videoSent => 'Vidéo envoyée';

  @override
  String uploadingFile(String name) {
    return 'Envoi de $name...';
  }

  @override
  String albumSent(int n) {
    return 'Album envoyé ($n images)';
  }

  @override
  String get fileEmpty => 'Le fichier est vide';

  @override
  String get networkError => 'Erreur réseau';

  @override
  String get avatarRemoved => 'Avatar retiré';

  @override
  String get uinCopied => 'UIN copié';

  @override
  String get displayNameLength =>
      'Le nom d\'affichage doit comporter entre 1 et 16 caractères';

  @override
  String get failedSendLan => 'Échec de l\'envoi via le réseau local';

  @override
  String get fileCancelled => 'Fichier annulé';

  @override
  String get doneRestarting => 'Terminé ! Redémarrage...';

  @override
  String get deleteMessageTitle => 'Supprimer le message ?';

  @override
  String get deleteMessageContent =>
      'Ce message sera supprimé pour les deux parties.';

  @override
  String get cannotDeleteMsg =>
      'Impossible de supprimer : message pas encore enregistré sur le serveur';

  @override
  String get deleteForMeTitle => 'Supprimer pour moi ?';

  @override
  String get deleteForMeContent =>
      'Cela ne supprimera le message que de votre appareil. L\'autre personne le verra toujours.';

  @override
  String get deleteFavMessageContent => 'Ce message sera retiré des favoris.';

  @override
  String get pinnedMessage => 'Message épinglé';

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
  String get msgCopied => 'Copié';

  @override
  String copiedUsername(String name) {
    return '@$name copié';
  }

  @override
  String get deliveryModeTitle => 'Choisir le mode d\'envoi';

  @override
  String get deliveryInternet => 'Internet';

  @override
  String get deliveryInternetSubtitle => 'Envoyer via le serveur (chiffré)';

  @override
  String get deliveryLanSubtitle => 'Envoyer via le réseau local (direct)';

  @override
  String get deliveryUserNotInLan =>
      'Utilisateur introuvable sur le réseau local';

  @override
  String get fastChange => 'Changement rapide';

  @override
  String get fastChangeSubtitle => 'Basculer le mode par appui long';

  @override
  String get lanModeEnabled => 'Mode réseau local activé';

  @override
  String get internetModeEnabled => 'Mode Internet activé';

  @override
  String get previewMessageTitle => 'Aperçu du message';

  @override
  String get previewYourMessage => 'Votre message :';

  @override
  String replyingTo(String name) {
    return 'Réponse à : $name';
  }

  @override
  String get send => 'Envoyer';

  @override
  String get fileSentLan => 'Fichier envoyé via le réseau local';

  @override
  String uploadingImages(int n) {
    return 'Envoi de $n images...';
  }

  @override
  String get albumUploadFailed => 'Échec de l\'envoi de l\'album';

  @override
  String get message => 'Message';

  @override
  String get noMessagesYet => 'Aucun message pour le moment';

  @override
  String get voiceCallsTitle => 'Appels vocaux';

  @override
  String get voiceCallsContent =>
      'Les appels vocaux ne fonctionnent actuellement que sur le réseau local (LAN).\n\nNous levons des fonds pour la maintenance du serveur central et le développement d\'une alternative.';

  @override
  String get supportOnyxBtn => 'Soutenir ONYX';

  @override
  String get call => 'Appeler';

  @override
  String get securityCheckTitle => 'Vérification de sécurité';

  @override
  String securityCheckContent(String name) {
    return 'Comparez ces emojis avec $name.\nS\'ils correspondent, votre discussion est sécurisée.';
  }

  @override
  String get failedToFetchPubkey =>
      'Échec de la récupération de la clé publique';

  @override
  String get userHasNoPubkey => 'L\'utilisateur n\'a pas de clé publique';

  @override
  String get galleryMenuLabel => 'Galerie';

  @override
  String get galleryTitle => 'Galerie';

  @override
  String get galleryTabMedia => 'Médias';

  @override
  String get galleryTabVoice => 'Vocaux';

  @override
  String get galleryTabFiles => 'Fichiers';

  @override
  String get galleryEmptyMedia => 'Aucune photo ou vidéo pour le moment';

  @override
  String get galleryEmptyVoice => 'Aucun message vocal pour le moment';

  @override
  String get galleryEmptyFiles => 'Aucun fichier pour le moment';

  @override
  String get galleryShowInChat => 'Afficher dans la discussion';

  @override
  String get failedDelete => 'Échec de la suppression';

  @override
  String get failedEdit => 'Échec de la modification du message';

  @override
  String get noInternetCached =>
      'Pas d\'Internet — affichage des messages en cache';

  @override
  String get sendFailed => 'Échec de l\'envoi';

  @override
  String get mediaUploadNotSupportedWeb =>
      'L\'envoi de médias n\'est pas pris en charge sur le web';

  @override
  String get localFileRequired => 'Fichier local requis';

  @override
  String get uploadFailed => 'Échec de l\'envoi';

  @override
  String get voiceUploadFailed => 'Échec de l\'envoi du message vocal';

  @override
  String get voiceCancelled => 'Message vocal annulé';

  @override
  String get uploadingVoice => 'Envoi du message vocal...';

  @override
  String uploadingAlbumProgress(int done, int total) {
    return 'Envoi de l\'album : $done/$total photos';
  }

  @override
  String get uploadingImageLabel => 'Envoi de l\'image...';

  @override
  String get uploadingVideoLabel => 'Envoi de la vidéo...';

  @override
  String get uploadingAudioLabel => 'Envoi de l\'audio...';

  @override
  String get uploadingFileLabel => 'Envoi du fichier...';

  @override
  String get leftGroup => 'Vous avez quitté le groupe';

  @override
  String get failedLeaveGroup => 'Échec de la sortie du groupe';

  @override
  String get avatarOnlyOwnerMod =>
      'Seuls les propriétaires et modérateurs peuvent changer l\'avatar';

  @override
  String get failedReadFile => 'Échec de la lecture du fichier';

  @override
  String get uploadingAvatar => 'Envoi de l\'avatar...';

  @override
  String get avatarUpdatedGroup => 'Avatar du groupe mis à jour';

  @override
  String get avatarDeleted => 'Avatar supprimé';

  @override
  String get failedDeleteAvatar => 'Échec de la suppression de l\'avatar';

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get tokenCopied => 'Jeton copié';

  @override
  String get groupNameLength =>
      'Le nom du groupe doit comporter entre 1 et 50 caractères';

  @override
  String get groupUpdated => 'Groupe mis à jour';

  @override
  String get failedUpdateGroup => 'Échec de la mise à jour du groupe';

  @override
  String get deleteAvatarTitle => 'Supprimer l\'avatar ?';

  @override
  String get deleteAvatarContent =>
      'Cela retirera l\'avatar du groupe pour tout le monde.';

  @override
  String get deleteGroupMsgContent =>
      'Ce message sera supprimé pour tout le monde.';

  @override
  String get reply => 'Répondre';

  @override
  String get edit => 'Modifier';

  @override
  String get editGroupTitle => 'Modifier le groupe';

  @override
  String get editChannelTitle => 'Modifier le canal';

  @override
  String get channelNameLabel => 'Nom du canal';

  @override
  String get channelNameHint => 'Entrez le nom du canal';

  @override
  String unsupportedFileType(String ext) {
    return 'Type de fichier non pris en charge : $ext';
  }

  @override
  String failedToConnect(String e) {
    return 'Échec de la connexion : $e';
  }

  @override
  String roleChanged(String role) {
    return 'Votre rôle a été changé en $role';
  }

  @override
  String get unbannedReconnecting => 'Vous n\'êtes plus banni ! Reconnexion...';

  @override
  String get onlyModsCanPost =>
      'Seuls le propriétaire et les modérateurs peuvent publier dans les canaux';

  @override
  String get failedSendMessage => 'Échec de l\'envoi du message';

  @override
  String get uploadFailedConnectionAborted =>
      'Échec de l\'envoi : connexion interrompue. Essayez un fichier plus petit ou vérifiez les paramètres du serveur.';

  @override
  String get failedSendMedia => 'Échec de l\'envoi du média';

  @override
  String get joinedGroup => 'Vous avez rejoint le groupe !';

  @override
  String get failedJoinGroup => 'Échec de l\'adhésion au groupe';

  @override
  String get cancelled => 'Annulé';

  @override
  String get avatarWillBeDeleted => 'L\'avatar sera supprimé';

  @override
  String get ipCopied => 'IP copiée';

  @override
  String get nameCannotBeEmpty => 'Le nom ne peut pas être vide';

  @override
  String get groupRenamed => 'Groupe renommé avec succès';

  @override
  String errorMsg(String e) {
    return 'Erreur : $e';
  }

  @override
  String get failedRename => 'Échec du renommage';

  @override
  String get imageTooLarge => 'Image trop volumineuse (5 Mo max.)';

  @override
  String get avatarUpdatedSuccessfully => 'Avatar mis à jour avec succès';

  @override
  String get failedUploadAvatar => 'Échec de l\'envoi de l\'avatar';

  @override
  String get deletingAvatar => 'Suppression de l\'avatar...';

  @override
  String get avatarDeletedSuccessfully => 'Avatar supprimé avec succès';

  @override
  String userBanned(String name) {
    return '$name banni';
  }

  @override
  String get failedBan => 'Échec du bannissement';

  @override
  String roleUpdated(String role) {
    return 'Rôle mis à jour en $role';
  }

  @override
  String get failedChangeRole => 'Échec du changement de rôle';

  @override
  String userUnbanned(String name) {
    return '$name n\'est plus banni';
  }

  @override
  String get failedUnban => 'Échec de la levée du bannissement';

  @override
  String get youHaveBeenBanned => 'Vous avez été banni';

  @override
  String get renameGroupTitle => 'Renommer le groupe';

  @override
  String get rename => 'Renommer';

  @override
  String get join => 'Rejoindre';

  @override
  String get manageMembers => 'Gérer les membres';

  @override
  String get banMemberTitle => 'Bannir le membre';

  @override
  String get ban => 'Bannir';

  @override
  String get selectNewRole => 'Sélectionner un nouveau rôle :';

  @override
  String get moderator => 'Modérateur';

  @override
  String get memberRole => 'Membre';

  @override
  String get manageMembersTitle => 'Gérer les membres';

  @override
  String get viewBans => 'Voir les bannissements';

  @override
  String get unbanUserTitle => 'Lever le bannissement';

  @override
  String get unban => 'Lever le bannissement';

  @override
  String get bannedUsersTitle => 'Utilisateurs bannis';

  @override
  String get bannedFromGroup => 'Vous avez été banni de ce groupe.';

  @override
  String bannedReason(String reason) {
    return 'Motif : $reason';
  }

  @override
  String get noBannedUsers => 'Aucun utilisateur banni';

  @override
  String bannedBy(String name) {
    return 'Banni par : $name';
  }

  @override
  String bannedDate(String date) {
    return 'Date : $date';
  }

  @override
  String banConfirm(String name) {
    return 'Bannir $name du groupe ?';
  }

  @override
  String get banReason => 'Motif (facultatif)';

  @override
  String changeRoleTitle(String name) {
    return 'Changer le rôle de $name';
  }

  @override
  String currentRoleLabel(String role) {
    return 'Rôle actuel : $role';
  }

  @override
  String ownerCount(int n) {
    return 'Propriétaires : $n/3';
  }

  @override
  String get ownerCurrent => 'Propriétaire (actuel)';

  @override
  String get ownerLimitReached => 'Propriétaire (limite atteinte)';

  @override
  String get owner => 'Propriétaire';

  @override
  String get cannotDemoteLastOwner =>
      'Impossible de rétrograder le dernier propriétaire';

  @override
  String get noMembersYet => 'Aucun membre';

  @override
  String get changeRole => 'Changer de rôle';

  @override
  String unbanConfirm(String name) {
    return 'Lever le bannissement de $name ?';
  }

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String get failedCreateGroup => 'Échec de la création du groupe';

  @override
  String get invalidInviteLinkFormat => 'Format de lien d\'invitation invalide';

  @override
  String get invalidInviteLink => 'Lien d\'invitation invalide';

  @override
  String get groupAddedForViewing => 'Groupe ajouté pour consultation !';

  @override
  String get failedAddGroup => 'Échec de l\'ajout du groupe';

  @override
  String serverRemoved(String name) {
    return 'Serveur \"$name\" retiré';
  }

  @override
  String get channelAdminOnlySubtitle => 'Canal (admin uniquement)';

  @override
  String get groupSubtitle => 'Groupe';

  @override
  String get newGroup => 'Nouveau groupe';

  @override
  String get externalGroup => 'Groupe externe';

  @override
  String get externalChannel => 'Canal externe';

  @override
  String get joinExternalServer => 'Rejoindre un serveur externe';

  @override
  String get enterServerAddress => 'Entrez l\'adresse du serveur';

  @override
  String get enterValidIp => 'Entrez une adresse IP ou un nom d\'hôte valide';

  @override
  String couldNotConnect(String host) {
    return 'Impossible de se connecter à $host';
  }

  @override
  String get usernameRequiredMsg =>
      'Le nom d\'utilisateur est requis. Assurez-vous d\'avoir créé un compte dans l\'application.';

  @override
  String get passwordRequiredForGroups =>
      'Un mot de passe est requis pour les groupes';

  @override
  String connectionFailed(String e) {
    return 'Échec de la connexion : $e';
  }

  @override
  String connectedToServer(String type, String name) {
    return 'Connecté à $type \"$name\"';
  }

  @override
  String get externalGroupType => 'groupe externe';

  @override
  String get externalChannelType => 'canal externe';

  @override
  String get identityVisible => 'Votre identité sera visible par le serveur';

  @override
  String get usernameLabel => 'Nom d\'utilisateur';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get noPasswordForChannels =>
      'Aucun mot de passe requis pour les canaux';

  @override
  String get noRegistrationRequired => 'Aucune inscription requise.';

  @override
  String get back => 'Retour';

  @override
  String get connecting => 'Connexion en cours...';

  @override
  String get connectBtn => 'Connecter';

  @override
  String get serverInfoGroups => 'Groupes';

  @override
  String get serverInfoMembers => 'Membres';

  @override
  String get serverInfoMedia => 'Médias';

  @override
  String get serverInfoMaxFile => 'Taille de fichier max.';

  @override
  String get thirdPartyServer => 'SERVEUR TIERS';

  @override
  String get thirdPartyWarning =>
      'Ce serveur n\'est pas exploité par ONYX. Ne vous y connectez que si vous faites confiance à son propriétaire.';

  @override
  String get serverWillKnow => 'Le serveur saura :';

  @override
  String get serverWillNotReceive => 'Le serveur NE recevra PAS :';

  @override
  String get knowIpAddress => 'Votre adresse IP';

  @override
  String get knowUsername => 'Le nom d\'utilisateur que vous avez choisi';

  @override
  String get knowMessages => 'Le contenu de vos messages sur ce serveur';

  @override
  String get notReceiveAccount => 'Votre compte ONYX ou votre mot de passe';

  @override
  String get notReceiveContacts => 'Vos contacts et discussions privées';

  @override
  String get notReceiveKeys => 'Vos clés de chiffrement';

  @override
  String get yourPassphraseTitle => 'Votre phrase de récupération';

  @override
  String get sessionExpiredBanner =>
      'Session expirée — veuillez vous reconnecter';

  @override
  String get sessionExpiredTitle => 'Session expirée';

  @override
  String get sessionExpiredSubtitle => 'Veuillez vous reconnecter';

  @override
  String get sessionSignIn => 'Se connecter';

  @override
  String get sessionRenewSoon => 'Une reconnexion sera bientôt nécessaire';

  @override
  String get sessionStillValid => 'Le jeton d\'autorisation est valide';

  @override
  String get blockedUsersTitle => 'Utilisateurs bloqués';

  @override
  String get blockedUsersSubtitle => 'Gérer les utilisateurs bloqués';

  @override
  String get blockedUsersEmpty => 'Aucun utilisateur bloqué';

  @override
  String get unblockAction => 'Débloquer';

  @override
  String get writeMessage => 'Écrire';

  @override
  String get fakePinTitle => 'Code PIN leurre';

  @override
  String get fakePinSubtitle => 'Ouvrir un compte leurre sous la contrainte';

  @override
  String get fakePinSheetTitle => 'Configuration du code PIN leurre';

  @override
  String get fakePinStatusActive => 'Actif';

  @override
  String get fakePinStatusOff => 'Désactivé';

  @override
  String get fakePinDescription =>
      'Lorsque ce code PIN est saisi sur l\'écran de verrouillage, l\'application s\'ouvre sur votre compte leurre au lieu de votre compte réel.';

  @override
  String get setFakePin => 'Définir un code PIN leurre';

  @override
  String get disableFakePin => 'Désactiver le code PIN leurre';

  @override
  String get changeFakePin => 'Changer le code PIN leurre';

  @override
  String get disableFakePinTitle => 'Désactiver le code PIN leurre ?';

  @override
  String get disableFakePinContent =>
      'Le code PIN leurre sera supprimé. Les paramètres du compte leurre seront conservés.';

  @override
  String get fakePinEnabledSnack => 'Code PIN leurre activé';

  @override
  String get fakePinDisabledSnack => 'Code PIN leurre désactivé';

  @override
  String get fakePinCannotMatchReal =>
      'Le code PIN leurre ne peut pas être identique à votre code PIN réel';

  @override
  String get decoyAccountSection => 'Compte leurre';

  @override
  String get decoyAccountSubtitle =>
      'Ce compte sera affiché lorsque le code PIN leurre est utilisé';

  @override
  String get decoyDisplayNameLabel => 'Nom d\'affichage';

  @override
  String get decoyUsernameLabel => 'Nom d\'utilisateur';

  @override
  String get decoyDisplayNameHint => 'Entrez un nom d\'affichage';

  @override
  String get decoyUsernameHint => 'Entrez un nom d\'utilisateur';

  @override
  String get saveDecoyAccount => 'Enregistrer le compte leurre';

  @override
  String get decoyAccountSaved => 'Compte leurre enregistré';

  @override
  String get decoyFieldsRequired =>
      'Le nom d\'utilisateur et le nom d\'affichage ne peuvent pas être vides';

  @override
  String get removeAvatar => 'Retirer l\'avatar';

  @override
  String get fakePinSecurityNote =>
      'Le code PIN leurre doit être différent de votre code PIN réel. Le compte leurre n\'a aucune connexion au serveur — il affiche uniquement le profil que vous avez configuré ici.';

  @override
  String get decoyNoChats => 'Aucune discussion pour le moment';

  @override
  String get decoyNoGroups => 'Aucun groupe pour le moment';

  @override
  String get decoyNoFavorites => 'Aucun favori pour le moment';

  @override
  String get decoyOtherAccounts => 'Autres comptes';

  @override
  String get decoyNoOtherAccounts => 'Aucun autre compte';

  @override
  String get lock => 'Verrouiller';

  @override
  String get decoyAppearance => 'Apparence';

  @override
  String get decoyNotifications => 'Notifications';

  @override
  String get decoyStorage => 'Stockage';

  @override
  String get decoyAppearanceSubtitle => 'Thème et options d\'affichage';

  @override
  String get decoyNotificationsSubtitle => 'Paramètres de son et d\'alerte';

  @override
  String get decoyStorageSubtitle => 'Gérer les fichiers mis en cache';

  @override
  String get decoyContactsSection => 'Fausses discussions';

  @override
  String get decoyContactsSubtitle =>
      'Ajoutez des contacts avec des messages — ils apparaissent à l\'ouverture du compte leurre';

  @override
  String get generateContacts => 'Générer des contacts';

  @override
  String get addDecoyContact => 'Ajouter un contact';

  @override
  String get decoyNoContacts => 'Aucune fausse discussion pour le moment';

  @override
  String get decoyContactUsername => 'Nom d\'utilisateur du contact';

  @override
  String get decoyContactDisplayName => 'Nom d\'affichage du contact';

  @override
  String contactsGenerated(int n) {
    return '$n contacts ajoutés';
  }

  @override
  String get contactAdded => 'Contact ajouté';

  @override
  String get contactRemoved => 'Contact retiré';

  @override
  String get decoyContactExists => 'Le contact existe déjà';

  @override
  String get decoyContactsCleared => 'Toutes les discussions ont été effacées';

  @override
  String get clearDecoyChats => 'Effacer toutes les discussions';

  @override
  String get messagesCount => 'messages';

  @override
  String get add => 'Ajouter';

  @override
  String get decoyChatsSubtitle => 'Contacts avec historique de messages';

  @override
  String get decoyGroupsSection => 'Groupes et canaux';

  @override
  String get decoyGroupsSubtitle => 'Faux groupes et canaux';

  @override
  String get decoyFavoritesSection => 'Favoris';

  @override
  String get decoyFavoritesSubtitle => 'Discussions favorites épinglées';

  @override
  String get noFakeGroups => 'Aucun groupe pour le moment';

  @override
  String get noFakeFavorites => 'Aucun favori pour le moment';

  @override
  String get addFakeGroup => 'Groupe';

  @override
  String get addFakeChannel => 'Canal';

  @override
  String get addFakeFavorite => 'Ajouter un favori';

  @override
  String get groupType => 'Groupe';

  @override
  String get channelType => 'Canal';

  @override
  String get favTitleHint => 'Titre';

  @override
  String get generateAll => 'Tout générer';

  @override
  String get generateAllConfirm =>
      'Un contenu aléatoire sera généré, remplaçant les données existantes.';

  @override
  String get sendFavoritesTitle => 'Envoyer les favoris';

  @override
  String get sendFavoritesShowQrToReceiver =>
      'Afficher le QR code au destinataire';

  @override
  String get sendFavoritesScanReceiver => 'Scanner le QR code du destinataire';

  @override
  String get sendFavoritesSending => 'Envoi des favoris';

  @override
  String get sendFavoritesSelectTitle =>
      'Sélectionner les discussions à envoyer';

  @override
  String get sendFavoritesHintDesktop =>
      'Le destinataire doit d\'abord appuyer sur \"Recevoir\". Scannez ensuite le QR code affiché ici.';

  @override
  String get sendFavoritesHintMobile =>
      'Le destinataire doit d\'abord appuyer sur \"Recevoir\" et afficher le QR code.';

  @override
  String allChatsCount(int n) {
    return 'Toutes les discussions ($n)';
  }

  @override
  String get sendFavoritesNoFavs =>
      'Aucune discussion favorite pour le moment.';

  @override
  String get sendFavoritesSelectAtLeastOne =>
      'Sélectionnez au moins une discussion';

  @override
  String get sendFavoritesShowQrBtn => 'Afficher le QR code';

  @override
  String get sendFavoritesScanQrBtn => 'Scanner le QR code';

  @override
  String get receiveFavoritesTitle => 'Recevoir les favoris';

  @override
  String get receiveFavoritesScanSender =>
      'Scanner le QR code de l\'expéditeur';

  @override
  String get receiveFavoritesScanOnSender =>
      'Scanner sur l\'appareil de l\'expéditeur';

  @override
  String get receiveFavoritesInstruction =>
      'Ouvrez les Favoris chez l\'expéditeur, appuyez sur Synchroniser → Envoyer, puis scannez ce code';

  @override
  String get receiveFavoritesE2E =>
      'Chiffré de bout en bout · réseau local uniquement';

  @override
  String get receiveFavoritesScanHint =>
      'Pointez la caméra vers le QR code affiché sur l\'appareil de l\'expéditeur';

  @override
  String get receiveFavoritesScanEncrypted =>
      'Le transfert est chiffré · réseau local uniquement';

  @override
  String get receiveFavoritesWaiting =>
      'En attente que l\'expéditeur scanne le QR code…';

  @override
  String get receiveFavoritesComplete => 'Transfert terminé.';

  @override
  String get receiveFavoritesConnecting => 'Connexion à l\'expéditeur…';

  @override
  String get receiveFavoritesConnected => 'Connecté ! En attente des fichiers…';

  @override
  String get cancelTransfer => 'Annuler le transfert';

  @override
  String get wardLinkTitle => 'WardLink';

  @override
  String get wardLinkSubtitle =>
      'Synchronisation passive entre vos appareils sur le réseau local';

  @override
  String get wardLinkEnable => 'Synchronisation passive';

  @override
  String get wardLinkEnableDesc =>
      'Synchronisez automatiquement avec les appareils de confiance sur le même réseau. Sur téléphone, cela fonctionne tant que l\'application est ouverte ; sur ordinateur, cela s\'exécute en continu.';

  @override
  String get wardLinkPairedDevices => 'Appareils de confiance';

  @override
  String get wardLinkNoPairedDevices => 'Aucun appareil associé pour le moment';

  @override
  String get wardLinkAddDevice => 'Ajouter';

  @override
  String get wardLinkRemoveDevice => 'Retirer';

  @override
  String get wardLinkRemoveConfirm =>
      'Arrêter la synchronisation avec cet appareil ?';

  @override
  String get wardLinkFavoritesOnlyNote =>
      'Synchronise vos Favoris — leurs messages et médias';

  @override
  String get wardLinkMaxFileSize => 'Taille de fichier max.';

  @override
  String get wardLinkPairTitle => 'Associer un appareil';

  @override
  String get wardLinkShowCode => 'Afficher le code';

  @override
  String get wardLinkScanCode => 'Scanner le code';

  @override
  String get wardLinkShowInstruction =>
      'Ouvrez WardLink sur votre autre appareil et scannez ce code';

  @override
  String get wardLinkScanInstruction =>
      'Pointez la caméra vers le code WardLink sur l\'autre appareil';

  @override
  String get wardLinkPairedOk => 'Appareil associé';

  @override
  String get wardLinkPairFailed => 'Échec de l\'association';

  @override
  String get wardLinkE2E => 'Chiffré de bout en bout · réseau local uniquement';

  @override
  String get wardLinkSyncingNow => 'Synchronisation…';

  @override
  String get wardLinkDone => 'Synchronisé';

  @override
  String get wardLinkCurrentFile => 'Fichier actuel';

  @override
  String get wardLinkLog => 'Journal de synchronisation';

  @override
  String get wardLinkLogEmpty => 'Aucun événement pour le moment';

  @override
  String get wardLinkHoldForLog => 'Maintenez la bulle pour voir le journal';

  @override
  String get wardLinkUpToDate => 'À jour';

  @override
  String wardLinkFilesDone(int n) {
    return 'Fichiers transférés : $n';
  }

  @override
  String get wardLinkNoFilesYet => 'Aucun fichier transféré';

  @override
  String wardLinkSyncedAgo(String when) {
    return 'Synchronisé $when';
  }

  @override
  String get wardLinkNeverSynced => 'Pas encore synchronisé';

  @override
  String get wardLinkFirewallHintWindows =>
      'Si le téléphone ne parvient pas à joindre ce PC, autorisez ONYX dans le Pare-feu Windows (port TCP 47832). ONYX tente d\'ajouter la règle automatiquement ; en cas d\'échec : Pare-feu Windows → Paramètres avancés → Règles de trafic entrant → Nouvelle règle → Port → TCP → 47832.';

  @override
  String get wardLinkFirewallHintMac =>
      'Si le téléphone ne parvient pas à joindre ce Mac, assurez-vous que le pare-feu macOS ne bloque pas ONYX : Réglages Système → Réseau → Coupe-feu → Options → ajoutez ONYX.';

  @override
  String get wardLinkFirewallHintLinux =>
      'Si le téléphone ne parvient pas à se connecter, ouvrez le port TCP 47832 dans votre pare-feu. Exemple : sudo ufw allow 47832/tcp ou sudo firewall-cmd --add-port=47832/tcp --permanent';

  @override
  String get wardLinkSyncFromBeginning => 'Synchroniser depuis le début';

  @override
  String get wardLinkSyncFromBeginningDesc =>
      'Récupérer tout l\'historique absent de cet appareil';

  @override
  String get wardLinkSyncPending => 'Synchronisation en attente…';

  @override
  String get wardLinkBubbleVisibility => 'Bulle de synchronisation';

  @override
  String get wardLinkBubbleShowAlways => 'Toujours afficher';

  @override
  String get wardLinkBubbleShowOnErrors =>
      'Afficher uniquement en cas d\'erreur';

  @override
  String get wardLinkBubbleSize => 'Taille de la bulle';

  @override
  String get meshSubtitle => 'Réseau maillé hors ligne';

  @override
  String get meshEnable => 'Activer le réseau maillé';

  @override
  String get meshEnableDesc =>
      'Messagerie directe sans Internet via Wi-Fi ou Bluetooth.\nFonctionne uniquement en messages directs.';

  @override
  String get meshUnavailable =>
      'Le réseau maillé n\'est pas disponible sur cette plateforme.';

  @override
  String get meshOpenRadar => 'Ouvrir le radar';

  @override
  String meshNearbyCount(int n) {
    return 'À proximité : $n appareils';
  }

  @override
  String get meshRadarTitle => 'Radar maillé';

  @override
  String get meshRadarScanning => 'Analyse en cours…';

  @override
  String get meshRadarSearchHint => 'Rechercher par nom...';

  @override
  String meshRadarSearchEmpty(String q) {
    return 'Aucun résultat pour \"$q\"';
  }

  @override
  String get meshRadarNoDevices =>
      'Aucun appareil à proximité.\nLe réseau maillé effectue un balayage toutes les 20 s.';

  @override
  String get meshRadarDisabled =>
      'Le mode maillé est désactivé.\nActivez-le dans Paramètres → Réseau maillé.';

  @override
  String get meshRadarStarting => 'Démarrage du balayage BLE…';

  @override
  String get meshMenuRadar => 'Radar';

  @override
  String get meshMenuDiagnostics => 'Diagnostics';

  @override
  String get meshMenuModeAuto => 'Auto';

  @override
  String get meshBluetoothOffTitle => 'Bluetooth désactivé';

  @override
  String get meshBluetoothOffContent =>
      'La discussion maillée est passée en mode Bluetooth uniquement, mais le Bluetooth est désactivé. Activez-le dans les paramètres système pour joindre les appareils à proximité.';

  @override
  String get meshOpenSystemSettings => 'Ouvrir les paramètres';

  @override
  String get meshModeLabel => 'MODE';

  @override
  String get meshModeActive => 'Mode maillé actif';

  @override
  String get meshChatLabel => 'Discussion maillée';

  @override
  String get meshLocationRequired =>
      'Activez les services de localisation pour le balayage BLE (Android ≤11)';

  @override
  String get meshChatEmpty =>
      'Aucun message pour le moment.\nEnvoyez le premier message maillé.';

  @override
  String get meshChatInputHint => 'Message…';

  @override
  String get meshChatSend => 'Envoyer';

  @override
  String get meshChatOutOfRange => 'Hors de portée';

  @override
  String get meshStatusSending => 'Envoi en cours…';

  @override
  String get meshStatusSendingWifi => 'Envoi via Wi-Fi…';

  @override
  String get meshStatusSendingBle => 'Envoi via Bluetooth…';

  @override
  String get meshStatusRelayed => 'En transit via le réseau maillé';

  @override
  String get meshStatusDelivered => 'Livré';

  @override
  String get meshStatusFailed => 'Non livré';

  @override
  String get meshStatusRetry => 'Réessayer';

  @override
  String get meshStatusFailedHint =>
      'Le message n\'a pas atteint le destinataire';

  @override
  String get meshErrorVideoWifiOnly =>
      'La vidéo ne peut être envoyée que via Wi-Fi. Connectez-vous au même réseau Wi-Fi que le destinataire.';

  @override
  String get meshErrorFileTooLargeForBle =>
      'Fichier trop volumineux pour le Bluetooth (10 Mo max.). Connectez-vous à un réseau Wi-Fi partagé.';

  @override
  String get meshErrorFileTooLarge => 'Fichier trop volumineux (200 Mo max.).';

  @override
  String get meshErrorAttachmentsUnsupported =>
      'Les pièces jointes ne sont prises en charge que sur mobile/ordinateur';

  @override
  String get meshErrorPickFileFailed => 'Échec de la sélection du fichier';

  @override
  String get meshErrorSendFileFailed => 'Échec de l\'envoi du fichier';

  @override
  String get meshErrorSendVoiceFailed => 'Échec de l\'envoi du message vocal';

  @override
  String meshErrorOutOfRange(String username) {
    return '$username est hors de portée';
  }

  @override
  String get backupTitle => 'Sauvegarde';

  @override
  String get backupSubtitle =>
      'Sauvegarde et restauration locales de vos données';

  @override
  String get backupExport => 'Enregistrer toutes les données';

  @override
  String get backupRestore => 'Restaurer à partir d\'une sauvegarde';

  @override
  String get backupScope => 'Éléments à sauvegarder';

  @override
  String get backupFavorites => 'Discussions favorites';

  @override
  String get backupPersonal => 'Discussions personnelles';

  @override
  String get backupIncludeMedia => 'Inclure les médias';

  @override
  String get backupMediaImages => 'Images';

  @override
  String get backupMediaVideos => 'Vidéos';

  @override
  String get backupMediaVoice => 'Vocaux et audio';

  @override
  String get backupMediaOther => 'Autres fichiers';

  @override
  String get backupSchedule => 'Sauvegarde planifiée';

  @override
  String get backupFreqOff => 'Désactivée';

  @override
  String get backupFreqDaily => 'Quotidienne';

  @override
  String get backupFreqWeekly => 'Hebdomadaire';

  @override
  String get backupFreqMonthly => 'Mensuelle';

  @override
  String get backupFolder => 'Dossier de sauvegarde automatique';

  @override
  String get backupChangeFolder => 'Changer';

  @override
  String get backupLastAuto => 'Dernière sauvegarde automatique';

  @override
  String get backupNever => 'jamais';

  @override
  String get backupInProgress => 'Création de la sauvegarde…';

  @override
  String get backupRestoring => 'Restauration…';

  @override
  String get backupSelectScope => 'Sélectionnez au moins une catégorie';

  @override
  String get backupNoAccount => 'Aucun compte actif';

  @override
  String get backupNoPermission =>
      'Accès au stockage refusé. Accordez \"Accès à tous les fichiers\" dans les paramètres de l\'application.';

  @override
  String get backupOpenFolder => 'Ouvrir le dossier';

  @override
  String get backupFolderUnsupported =>
      'Ce dossier est inaccessible. Veuillez choisir un dossier sur le stockage interne.';

  @override
  String get backupRestoreConfirmTitle =>
      'Restaurer à partir d\'une sauvegarde ?';

  @override
  String get backupRestoreConfirmBody =>
      'Les données du fichier remplaceront vos données actuelles (discussions, favoris, paramètres).';

  @override
  String get backupRestartHint =>
      'Redémarrez l\'application pour voir les changements';

  @override
  String get recycleBinTitle => 'Corbeille';

  @override
  String get recycleBinSubtitle =>
      'Discussions supprimées et protection contre les suppressions accidentelles par synchronisation';

  @override
  String get recycleBinPendingTitle => 'Demandes de suppression';

  @override
  String recycleBinPendingDesc(String device, int count) {
    return 'L\'appareil \"$device\" souhaite supprimer $count discussion(s). Appliquer ou conserver ?';
  }

  @override
  String get recycleBinApply => 'Appliquer la suppression';

  @override
  String get recycleBinKeep => 'Conserver mes discussions';

  @override
  String get recycleBinNoPending => 'Aucune demande de suppression en attente';

  @override
  String get recycleBinResetTitle =>
      'Réinitialiser les enregistrements de suppression';

  @override
  String get recycleBinResetDesc =>
      'Efface la liste des discussions supprimées. La synchronisation cessera de les supprimer à nouveau sur les autres appareils et peut les restaurer.';

  @override
  String get recycleBinResetButton => 'Effacer la liste des suppressions';

  @override
  String get recycleBinResetDone => 'Enregistrements de suppression effacés';

  @override
  String get recycleBinResetConfirm =>
      'Effacer tous les enregistrements de suppression de ce compte ?';

  @override
  String get accountGraph => 'Graphe de compte';

  @override
  String get accountGraphSubtitleDesktopOn =>
      'Affiche un graphe de vos discussions, groupes et canaux lorsqu\'aucune discussion n\'est ouverte';

  @override
  String get accountGraphSubtitleMobileOn =>
      'Visualisation de votre compte en vue planétaire';

  @override
  String get accountGraphSubtitleDesktopOff =>
      'Affiche une astuce lorsqu\'aucune discussion n\'est ouverte';

  @override
  String get accountGraphSubtitleMobileOff =>
      'Le graphe de compte est désactivé';

  @override
  String get orbitSpeed => 'Vitesse orbitale';

  @override
  String secOrbit(int s) {
    return '$s s/orbite';
  }

  @override
  String minOrbit(int m) {
    return '$m min/orbite';
  }

  @override
  String get animateGraph => 'Animer';

  @override
  String get animateGraphOn => 'Les orbites tournent en temps réel';

  @override
  String get animateGraphOff => 'Le graphe est figé / statique';

  @override
  String get preserveView => 'Conserver la vue';

  @override
  String get preserveViewOn =>
      'Conserve le zoom et la position en quittant une discussion';

  @override
  String get preserveViewOff => 'Revient au centre au retour';

  @override
  String get migrationTitle => 'Migration du stockage';

  @override
  String get migrationBody =>
      'ONYX passe à un nouveau moteur de stockage haute vitesse. Les discussions et médias se chargeront beaucoup plus vite.';

  @override
  String get migrationAccounts => 'Comptes';

  @override
  String get migrationDataSize => 'Taille des données';

  @override
  String get migrationBackupNote =>
      'Une sauvegarde sera créée avant la migration. L\'application peut être temporairement non réactive pendant ce processus.';

  @override
  String get migrationStart => 'Démarrer la migration';

  @override
  String get migrationSkip => 'Ignorer';

  @override
  String get migrationPhaseBackup => 'Création de la sauvegarde';

  @override
  String get migrationPhaseImport => 'Importation des données';

  @override
  String get migrationPhaseVerify => 'Vérification';

  @override
  String get migrationPhasePreparing => 'Préparation';

  @override
  String get migrationDontClose => 'Ne fermez pas l\'application';

  @override
  String get migrationDoneTitle => 'Terminé !';

  @override
  String get migrationDoneBody =>
      'Le stockage a été mis à jour. Une sauvegarde a été enregistrée dans le dossier Sauvegardes.';

  @override
  String get migrationDoneNote =>
      'Une fois que vous avez confirmé que tout fonctionne, vous pouvez la supprimer manuellement.';

  @override
  String get migrationDoneButton => 'Parfait !';

  @override
  String get migrationErrorTitle => 'Erreur de migration';

  @override
  String get migrationErrorBody =>
      'L\'application continuera sur l\'ancien système. La migration sera retentée au prochain lancement.';

  @override
  String get migrationErrorButton => 'Compris';

  @override
  String get audioTitle => 'Audio';

  @override
  String get audioSubtitle => 'Sélection du microphone et du haut-parleur';

  @override
  String get audioMicInput => 'Microphone (entrée)';

  @override
  String get audioSpeakerOutput => 'Haut-parleur (sortie)';

  @override
  String get audioSystemDefault => 'Système par défaut';

  @override
  String get audioChangesNote =>
      'Les changements prennent effet à la prochaine connexion au canal vocal.';

  @override
  String get wardlinkReceive => 'Recevoir depuis un appareil';

  @override
  String get wardlinkReceiveSubtitle =>
      'Afficher un QR code — l\'expéditeur le scanne';

  @override
  String get wardlinkSend => 'Envoyer vers un appareil';

  @override
  String get wardlinkSendSubtitle =>
      'Scannez le QR code affiché sur le destinataire';

  @override
  String get react => 'Réagir';

  @override
  String get pin => 'Épingler';

  @override
  String get unpin => 'Désépingler';

  @override
  String get copyImage => 'Copier l\'image';

  @override
  String get forward => 'Transférer';

  @override
  String get showInFileSystem => 'Afficher dans le système de fichiers';

  @override
  String get saveNotSupportedOnWeb =>
      'L\'enregistrement n\'est pas pris en charge sur le web';

  @override
  String get imageNotLoadedYet => 'Image pas encore chargée';

  @override
  String get voiceNotLoadedYet => 'Message vocal pas encore chargé';

  @override
  String get videoNotLoadedYet => 'Vidéo pas encore chargée';

  @override
  String get fileNotLoadedYet => 'Fichier pas encore chargé';

  @override
  String get fileNotLoadedOpenFirst =>
      'Le fichier n\'est pas téléchargé sur cet appareil — appuyez dessus dans la discussion pour le télécharger';

  @override
  String editTimerLabel(int s) {
    return 'Modifier  ·  ${s}s';
  }

  @override
  String deleteTimerLabel(int s) {
    return 'Supprimer  ·  ${s}s';
  }

  @override
  String get newChat => 'Nouvelle discussion';

  @override
  String get newChatSubtitle => 'Créer une nouvelle discussion favorite';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get newFolderSubtitle => 'Regrouper des discussions dans un dossier';

  @override
  String get searchEmoji => 'Rechercher un emoji…';

  @override
  String get syncCompleted => 'Synchronisation terminée';

  @override
  String get syncCompletedWithErrors =>
      'Synchronisation terminée avec des erreurs';

  @override
  String get receivingFiles => 'Réception des fichiers...';

  @override
  String syncFromUser(String sender) {
    return 'de $sender';
  }

  @override
  String get aboutServer => 'SERVEUR';

  @override
  String get aboutWhatsNew => 'NOUVEAUTÉS';

  @override
  String get aboutConnected => 'Connecté';

  @override
  String get aboutConnecting => 'Connexion en cours...';

  @override
  String get aboutLoadingLocation => 'Chargement...';

  @override
  String get aboutNoReleaseNotes => 'Aucune note de version disponible.';

  @override
  String get aboutCheckForUpdates => 'Vérifier les mises à jour';

  @override
  String get aboutChecking => 'Vérification...';

  @override
  String get aboutUpToDate => 'Vous êtes à jour !';

  @override
  String aboutUpdateAvailable(String v) {
    return 'Mise à jour disponible : $v';
  }

  @override
  String get downloadUpdateTitle => 'Télécharger la mise à jour';

  @override
  String get downloadUpdateVersion => 'Version';

  @override
  String get downloadUpdateWhatsNew => 'NOUVEAUTÉS';

  @override
  String get downloadUpdateReady => 'Prêt à télécharger';

  @override
  String get downloadUpdateDownloading => 'Téléchargement...';

  @override
  String get downloadUpdateComplete => 'Téléchargement terminé !';

  @override
  String get downloadUpdateNoPlatform =>
      'Aucun téléchargement disponible pour cette plateforme';

  @override
  String get downloadUpdateInstall => 'Télécharger et installer';

  @override
  String get downloadUpdateOpen => 'Ouvrir';

  @override
  String get downloadUpdateRetry => 'Réessayer';

  @override
  String get downloadUpdateCancel => 'Annuler le téléchargement';

  @override
  String get editChat => 'Modifier la discussion';

  @override
  String get chatNameLabel => 'Nom de la discussion';

  @override
  String get editFolder => 'Modifier le dossier';

  @override
  String get folderNameLabel => 'Nom du dossier';

  @override
  String get createChat => 'Nouvelle discussion';

  @override
  String get profileMessage => 'Message';

  @override
  String get tapAvatarHint =>
      'Appuyez sur l\'avatar pour le changer • Appui long pour le retirer';

  @override
  String get tapAvatarLongRemove =>
      'Appuyez pour changer • Appui long pour retirer';

  @override
  String get e2eeWarnTitle => 'Non chiffré de bout en bout';

  @override
  String get e2eeWarnUnderstand => 'J\'ai compris';

  @override
  String get e2eeWarnDoNotShare =>
      'Ne partagez pas de mots de passe, de fichiers privés ou d\'informations sensibles ici.';

  @override
  String get e2eeWarnGroupBody =>
      'Les messages de ce groupe ne sont pas protégés par le chiffrement de bout en bout — le serveur peut les lire.';

  @override
  String get e2eeWarnGroupMedia =>
      'Les médias joints sont envoyés vers un hébergeur public (catbox.moe) et accessibles à quiconque possède le lien.';

  @override
  String get e2eeWarnExtBody =>
      'Les messages de ce groupe ne sont pas protégés par le chiffrement de bout en bout — le serveur du propriétaire du groupe peut les lire.';

  @override
  String get e2eeWarnExtMedia =>
      'Les médias joints sont envoyés et stockés sur le propre serveur du propriétaire, pas sur ONYX.';

  @override
  String get e2eeWarnExtOnyxUnrelated =>
      'ONYX n\'a aucun lien avec ce groupe et ne peut ni modérer ni protéger son contenu.';

  @override
  String get securityLevelTitle => 'Niveau de confiance de l\'appareil';

  @override
  String get securityLevelEasy => 'Simple';

  @override
  String get securityLevelEasyDesc =>
      'Un nouvel appareil est approuvé immédiatement après la connexion. Friction minimale, mais le mot de passe est votre seule ligne de défense.';

  @override
  String get securityLevelBalanced => 'Équilibré';

  @override
  String get securityLevelBalancedDesc =>
      'Tout appareil déjà approuvé peut approuver un nouvel appareil. Recommandé pour la plupart des utilisateurs.';

  @override
  String get securityLevelStrict => 'Strict';

  @override
  String get securityLevelStrictDesc =>
      'Un nouvel appareil nécessite l\'approbation de deux appareils de confiance distincts.';

  @override
  String get securityLevelLowerRequiresTrusted =>
      'Abaisser le niveau de sécurité nécessite un appareil de confiance.';

  @override
  String get securityLevelUpdated => 'Niveau de sécurité mis à jour';

  @override
  String get sessionTtlTitle => 'Durée de session';

  @override
  String get sessionTtlSubtitle =>
      'Délai avant que cet appareil ne redemande votre mot de passe';

  @override
  String get sessionTtlRecommended => 'recommandé';

  @override
  String sessionTtlDays(int days) {
    return '$days jours';
  }

  @override
  String get sessionTtlNever => 'Jamais';

  @override
  String get sessionTtlUpdated => 'Durée de session mise à jour';

  @override
  String get approvalsProgress => 'Approuvé';

  @override
  String get pendingDeviceTitleSingle => 'Nouvel appareil';

  @override
  String pendingDeviceTitleMulti(int count) {
    return 'Nouveaux appareils ($count)';
  }

  @override
  String get pendingDeviceApprove => 'Approuver';

  @override
  String get pendingDeviceDeny => 'Refuser';

  @override
  String get recoveryTitle => 'Récupération de compte';

  @override
  String get recoveryBannerText =>
      'Cet appareil n\'est pas encore approuvé. Si aucun appareil de confiance n\'est joignable, vous pouvez récupérer l\'accès avec votre mot de passe et votre phrase de récupération.';

  @override
  String get recoveryBannerButton => 'Récupérer l\'accès';

  @override
  String get recoveryIntro =>
      'Entrez votre mot de passe et la phrase de récupération de 12 mots qui vous a été montrée lors de l\'inscription. La demande ne prendra pas effet immédiatement — vos appareils de confiance disposent d\'un délai pour l\'annuler si ce n\'est pas vous.';

  @override
  String get recoveryPasswordLabel => 'Mot de passe';

  @override
  String get recoveryPassphraseLabel => 'Phrase de récupération (12 mots)';

  @override
  String get recoverySubmit => 'Envoyer la demande';

  @override
  String get recoveryInvalid =>
      'Mot de passe ou phrase de récupération invalide';

  @override
  String get recoveryAlreadyPending => 'Une demande est déjà en attente';

  @override
  String get recoveryPendingTitle => 'Demande envoyée';

  @override
  String recoveryPendingBody(String when) {
    return 'L\'accès sera restauré $when sauf si un appareil de confiance annule la demande.';
  }

  @override
  String get recoveryCancelled => 'Demande de récupération annulée';

  @override
  String get recoveryExecuted =>
      'Accès restauré. Veuillez vous reconnecter pour appliquer le changement.';

  @override
  String get recoveryCancelRequiresTrusted =>
      'Seul un appareil de confiance peut annuler cette demande. Approuvez d\'abord cet appareil dans Appareils actifs.';

  @override
  String get recoveryAlertRequestedTitle =>
      'Quelqu\'un a demandé la récupération du compte';

  @override
  String recoveryAlertRequestedBody(String deviceName, String when) {
    return 'L\'appareil \"$deviceName\" a demandé la récupération du compte. Si ce n\'est pas vous, annulez immédiatement. Sinon, cela prendra effet $when.';
  }

  @override
  String get recoveryAlertCancelButton => 'Annuler';

  @override
  String get recoveryAlertIgnoreButton => 'C\'est moi, ignorer';

  @override
  String get recoveryAlertFailedTitle => 'Tentative de récupération échouée';

  @override
  String get recoveryAlertFailedBody =>
      'Quelqu\'un a tenté de récupérer l\'accès à votre compte mais a saisi un mot de passe ou une phrase de récupération incorrects.';

  @override
  String get recoveryAlertExecutedTitle => 'Récupération terminée';

  @override
  String get recoveryAlertExecutedBody =>
      'La demande de récupération a pris effet — le compte a un nouvel appareil principal. Si ce n\'est pas vous, révoquez immédiatement la session inconnue dans Appareils actifs.';

  @override
  String get wardLinkSyncSettingsTitle => 'Paramètres de synchronisation';

  @override
  String get wardLinkSyncSettingsSubtitle =>
      'Limite de taille de fichier et notifications de la bulle';

  @override
  String get wardLinkPairedDevicesSubtitle =>
      'Ajouter et gérer les appareils associés';

  @override
  String get notifGeneralTitle => 'Général';

  @override
  String get notifGeneralSubtitle =>
      'Activer les notifications et la visibilité du contenu';

  @override
  String get notifSoundSubtitle => 'Son de notification et fichier audio';

  @override
  String get notifAdvancedTitle => 'Avancé';

  @override
  String get notifAdvancedSubtitle =>
      'Comportement au démarrage et position de la fenêtre contextuelle';

  @override
  String get securityPrivacyTitle => 'Confidentialité';

  @override
  String get securityPrivacySubtitle =>
      'Paramètres de visibilité et de recherche';

  @override
  String get cacheStorageTitle => 'Stockage';

  @override
  String get cacheStorageSubtitle =>
      'Cache multimédia et nettoyage des fichiers inutilisés';

  @override
  String get connectionServerTitle => 'Connexion au serveur';

  @override
  String get connectionServerSubtitle =>
      'Se connecter ou se déconnecter du serveur WebSocket';

  @override
  String get interactPerformanceTitle => 'Performance';

  @override
  String get interactPerformanceSubtitle =>
      'Tampon de défilement et fenêtre de préchargement des images';

  @override
  String get interactFilesTitle => 'Fichiers et stockage';

  @override
  String get interactFilesSubtitle =>
      'Dossier de téléchargement et gestion des données de l\'application';

  @override
  String get appearanceChatDisplayTitle => 'Affichage des discussions';

  @override
  String get appearanceChatDisplaySubtitle =>
      'Alignement, avatars et animations';

  @override
  String get appearanceLayoutTitle => 'Disposition';

  @override
  String get appearanceLayoutSubtitle =>
      'Navigation, graphe et balayage des onglets';

  @override
  String get appearanceLiquidGlassTitle => 'Effets de verre liquide';

  @override
  String get trashChatsTitle => 'Discussions supprimées';

  @override
  String get trashChatsSubtitle =>
      'Restaurer ou supprimer définitivement des discussions';

  @override
  String get trashMessagesTitle => 'Messages supprimés';

  @override
  String get trashMessagesSubtitle =>
      'Restaurer ou supprimer définitivement des messages';

  @override
  String get download => 'Télécharger';

  @override
  String get retry => 'Réessayer';

  @override
  String get refresh => 'Actualiser';

  @override
  String get revoke => 'Révoquer';

  @override
  String get setup => 'Configurer';

  @override
  String get current => 'Actuel';

  @override
  String get select => 'Sélectionner';

  @override
  String get token => 'Jeton';

  @override
  String get always => 'Toujours';

  @override
  String favRemoveFromFolderNamed(String folderName) {
    return 'Retirer de \"$folderName\"';
  }

  @override
  String get favMoveToFolder => 'Déplacer vers un dossier';

  @override
  String get favRemoveFromFolder => 'Retirer du dossier';

  @override
  String get favUnlock => 'Déverrouiller';

  @override
  String get favLock => 'Verrouiller';

  @override
  String get favUnlockFolder => 'Déverrouiller le dossier';

  @override
  String get favLockFolder => 'Verrouiller le dossier';

  @override
  String favChatsCount(int n) {
    return '$n discussions';
  }

  @override
  String get favNewFolder => 'Nouveau dossier';

  @override
  String get favChatsMovedToTopLevel =>
      'Les discussions seront déplacées au niveau supérieur';

  @override
  String get favDeleteChatQuestion => 'Supprimer la discussion ?';

  @override
  String get favRemoveAvatarQuestion => 'Retirer l\'avatar ?';

  @override
  String get favSelectedRemovedFromFavorites =>
      'Les messages sélectionnés seront retirés des favoris.';

  @override
  String get favDeleteMessageQuestion => 'Supprimer le message ?';

  @override
  String get favMessageRemovedFromFavorites =>
      'Ce message sera retiré des favoris.';

  @override
  String get favDeleteAvatarQuestion => 'Supprimer l\'avatar ?';

  @override
  String get favRemoveAvatarConfirm => 'Cela retirera cet avatar favori.';

  @override
  String get sendAlbum => 'Envoyer l\'album';

  @override
  String get sendAlbums => 'Envoyer les albums';

  @override
  String get sendAllMedia => 'Tout envoyer';

  @override
  String get setAsWallpaper => 'Définir comme fond d\'écran';

  @override
  String get sendVoice => 'Envoyer un message vocal';

  @override
  String get cropAndUpload => 'Recadrer et envoyer';

  @override
  String get deleteMessagesQuestion => 'Supprimer les messages ?';

  @override
  String get connectionDiagnostics => 'Diagnostics de connexion';

  @override
  String get voiceChannels => 'Canaux vocaux';

  @override
  String get forwardMessage => 'Transférer le message';

  @override
  String get noChats => 'Aucune discussion';

  @override
  String get noGroups => 'Aucun groupe';

  @override
  String get noFavorites => 'Aucun favori';

  @override
  String get wifiOnlyOption => 'Wi-Fi uniquement';

  @override
  String get emptyTrash => 'Vider la corbeille';

  @override
  String get performanceReport => 'Rapport de performance';

  @override
  String get revokeSessionQuestion => 'Révoquer la session ?';

  @override
  String get revokeSessionConfirm =>
      'Cet appareil sera immédiatement déconnecté.';

  @override
  String get failedToRevokeSession => 'Échec de la révocation de la session';

  @override
  String get failedToApproveDevice => 'Échec de l\'approbation de l\'appareil';

  @override
  String get noActiveSessionsFound => 'Aucune session active trouvée';

  @override
  String get quotaExceeded => 'Quota dépassé';

  @override
  String get openSettingsAction => 'Ouvrir les paramètres';

  @override
  String get trashIsEmpty => 'La corbeille est vide';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get deviceAuthTabQr => 'QR';

  @override
  String get meshTitle => 'Réseau maillé';

  @override
  String get meshMenuModeWifi => 'Wi-Fi';

  @override
  String get meshMenuModeBluetooth => 'Bluetooth';

  @override
  String mediaCachesCleared(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: ' Caches média effacés ($n)',
      one: ' Cache média effacé ($n)',
    );
    return '$_temp0';
  }

  @override
  String leaveGroupTitle(String isChannel) {
    String _temp0 = intl.Intl.selectLogic(
      isChannel,
      {
        'true': 'le canal',
        'other': 'le groupe',
      },
    );
    return 'Quitter $_temp0 ?';
  }

  @override
  String cacheFilesDeleted(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers supprimés',
      one: '$n fichier supprimé',
    );
    return '$_temp0';
  }

  @override
  String orphanedCleanupDeleted(int files, String freedMb) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files fichiers inutilisés supprimés',
      one: '$files fichier inutilisé supprimé',
    );
    return '$_temp0 ($freedMb Mo libérés)';
  }

  @override
  String deletedLogsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers journaux supprimés.',
      one: '$n fichier journal supprimé.',
    );
    return '$_temp0';
  }

  @override
  String notifEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'Vous serez alerté pour les nouveaux messages',
        'other': 'Toutes les notifications sont désactivées',
      },
    );
    return '$_temp0';
  }

  @override
  String notifHideContentSubtitle(String hidden) {
    String _temp0 = intl.Intl.selectLogic(
      hidden,
      {
        'true': 'Notifications sans texte du message',
        'other': 'Afficher le texte du message dans les notifications',
      },
    );
    return '$_temp0';
  }

  @override
  String notifSoundEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'Son activé',
        'other': 'Son désactivé',
      },
    );
    return '$_temp0';
  }

  @override
  String sessionExpiresInDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'La session expire dans $n jours',
      one: 'La session expire dans $n jour',
    );
    return '$_temp0';
  }

  @override
  String sessionExpiresInHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'La session expire dans $n heures',
      one: 'La session expire dans $n heure',
    );
    return '$_temp0';
  }

  @override
  String sessionActiveForDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Session valide pendant encore $n jours',
      one: 'Session valide pendant encore $n jour',
    );
    return '$_temp0';
  }

  @override
  String meshRadarFound(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n appareils à portée',
      one: '$n appareil à portée',
    );
    return '$_temp0';
  }

  @override
  String trashSummary(int chats, int messages) {
    String _temp0 = intl.Intl.pluralLogic(
      chats,
      locale: localeName,
      other: '$chats discussions',
      one: '$chats discussion',
    );
    String _temp1 = intl.Intl.pluralLogic(
      messages,
      locale: localeName,
      other: '$messages messages',
      one: '$messages message',
    );
    return '$_temp0, $_temp1';
  }
}
