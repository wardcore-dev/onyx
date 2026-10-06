// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navChats => 'Chats';

  @override
  String get navGroups => 'Grupos';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navAccounts => 'Cuentas';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get close => 'Cerrar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get delete => 'Eliminar';

  @override
  String get clear => 'Borrar';

  @override
  String get loading => 'Cargando...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Listo';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado';

  @override
  String get test => 'Probar';

  @override
  String get connect => 'Conectar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get enabled => 'Activado';

  @override
  String get disabled => 'Desactivado';

  @override
  String get on => 'Sí';

  @override
  String get off => 'No';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get supportOnyx => 'Apoyar a ONYX';

  @override
  String get securityTitle => 'Seguridad y privacidad';

  @override
  String get securitySubtitle =>
      'Toca para ver consejos y detalles del cifrado';

  @override
  String get tipOfTheDay => 'Consejo del día';

  @override
  String get statusSettings => 'Ajustes de estado';

  @override
  String get showDisplayNameInGroups => 'Mostrar mi nombre en los grupos';

  @override
  String get showDisplayNameSubtitle =>
      'Si está desactivado, tus mensajes aparecerán como \"Anónimo\"';

  @override
  String get pinLock => 'Bloqueo con PIN';

  @override
  String get enablePinLock => 'Activar bloqueo con PIN';

  @override
  String get enablePinSubtitle =>
      'Requerir un PIN de 4 dígitos para desbloquear la app al iniciarla';

  @override
  String get pinLockEnabled => ' Bloqueo con PIN activado';

  @override
  String get pinLockDisabled => 'Bloqueo con PIN desactivado';

  @override
  String get useBiometrics => 'Usar biometría';

  @override
  String get useBiometricsSubtitle =>
      'Desbloquear con huella digital o reconocimiento facial';

  @override
  String get biometricsUnavailable =>
      'La biometría no está disponible en este dispositivo';

  @override
  String get lockOnResume => 'Bloquear al pasar a segundo plano';

  @override
  String get lockOnResumeSubtitle =>
      'Pedir el PIN cada vez que la app vuelve a primer plano';

  @override
  String get pinScreenSetTitle => 'Establecer PIN';

  @override
  String get pinScreenConfirmTitle => 'Confirmar PIN';

  @override
  String get pinScreenEnterTitle => 'Introducir PIN';

  @override
  String get pinScreenChooseSubtitle => 'Elige un PIN de 4 dígitos';

  @override
  String get pinScreenChooseChatSubtitle =>
      'Elige un PIN de 4 dígitos para este chat';

  @override
  String get pinScreenReenterSubtitle =>
      'Vuelve a introducir tu PIN para confirmarlo';

  @override
  String get pinScreenUnlockSubtitle =>
      'Introduce tu PIN de 4 dígitos para desbloquear';

  @override
  String get pinScreenGenericSubtitle => 'Introduce tu PIN de 4 dígitos';

  @override
  String get pinScreenDisableHeader =>
      'Introduce el PIN actual para desactivarlo';

  @override
  String get pinScreenMismatchError =>
      'Los PIN no coinciden. Inténtalo de nuevo.';

  @override
  String get pinScreenIncorrectError => 'PIN incorrecto';

  @override
  String get searchChatsHint => 'Buscar chats y mensajes…';

  @override
  String get searchGroupsHint => 'Buscar grupos y mensajes…';

  @override
  String get searchFavoritesHint => 'Buscar en favoritos…';

  @override
  String get searchSettingsHint => 'Buscar en ajustes…';

  @override
  String get keyMgmtTitle => 'Gestión de claves';

  @override
  String get keyMgmtSubtitle => 'Rotar o restablecer tu identidad de cifrado';

  @override
  String get keyMgmtDescription =>
      'Rota tu clave de identidad E2EE si sospechas que fue comprometida. Tus contactos recibirán la nueva clave automáticamente.';

  @override
  String get rotateE2eeKey => 'Rotar clave E2EE';

  @override
  String get rotateE2eeKeyPrimaryOnly =>
      'Rotar clave E2EE (solo dispositivo principal)';

  @override
  String get rotateKeyDialogTitle => '¿Rotar la clave de cifrado?';

  @override
  String get rotateKeyDialogContent =>
      'Se generará un nuevo par de claves X25519 y se subirá al servidor.nnTu sesión e historial de mensajes NO se ven afectados. Los contactos usarán automáticamente la nueva clave en su próximo mensaje.';

  @override
  String get rotateKeyBtn => 'Rotar';

  @override
  String get rotatingKey => ' Rotando clave…';

  @override
  String get keyRotated => ' Clave E2EE rotada y subida';

  @override
  String get keyRotationFailed => ' Error al rotar la clave';

  @override
  String get activeDevices => 'Dispositivos activos';

  @override
  String get activeDevicesSubtitle =>
      'Dispositivos, contraseña y clave de cifrado';

  @override
  String get activeDevicesPrimaryOnly =>
      'Dispositivos activos (solo dispositivo principal)';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get changePasswordPrimaryOnly =>
      'Cambiar contraseña (solo dispositivo principal)';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get notificationsSubtitle => 'Gestionar alertas y opciones de entrega';

  @override
  String get notificationsEnabled => 'Activar notificaciones';

  @override
  String get notificationsEnabledSubtitle =>
      'Mostrar notificaciones del sistema para mensajes nuevos';

  @override
  String get notificationPosition => 'Posición de la notificación';

  @override
  String get notifPosTopLeft => 'Arriba a la izquierda';

  @override
  String get notifPosTopRight => 'Arriba a la derecha';

  @override
  String get notifPosBottomLeft => 'Abajo a la izquierda';

  @override
  String get notifPosBottomRight => 'Abajo a la derecha';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get appearanceSubtitle => 'Elegir tema y modo oscuro';

  @override
  String get selectTheme => 'Seleccionar tema';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get fontAndTextSize => 'Fuente y tamaño de texto';

  @override
  String get fontFamily => 'Familia de fuente';

  @override
  String get messageSize => 'Tamaño de los mensajes';

  @override
  String get fontPreviewMessage => 'Ejemplo';

  @override
  String get ownMessagesRight => 'Mis mensajes: derecha';

  @override
  String get ownMessagesLeft => 'Mis mensajes: izquierda';

  @override
  String get alignAllRight => 'Alinear todos los mensajes a la derecha';

  @override
  String get alignAllRightSubtitle =>
      'Todos los mensajes se alinean a la derecha, como en un espejo';

  @override
  String get showAvatarInChats => 'Mostrar avatar en la lista de chats';

  @override
  String get showAccountIndicator => 'Mostrar cuenta actual';

  @override
  String get showAccountIndicatorSubtitle =>
      'Mostrar nombre y usuario en la esquina de la app';

  @override
  String get showAvatarSubtitle =>
      'Mostrar el avatar del contacto en la lista de chats';

  @override
  String get chatBackground => 'Fondo del chat';

  @override
  String get chatBgSubtitle => 'Establecer una imagen como fondo del chat';

  @override
  String get chooseImage => 'Elegir imagen';

  @override
  String get clearBackground => 'Quitar fondo';

  @override
  String get applyGlobally => 'Aplicar globalmente';

  @override
  String get applyGloballySubtitle => 'Usar este fondo en todos los chats';

  @override
  String get blurBackground => 'Difuminar fondo';

  @override
  String get elementOpacity => 'Opacidad de los elementos';

  @override
  String get elementBrightness => 'Brillo de los elementos';

  @override
  String get uiLayout => 'Diseño de la interfaz';

  @override
  String get navBarPosition => 'Posición de la barra de navegación';

  @override
  String get navLeft => 'Izquierda';

  @override
  String get navBottom => 'Abajo';

  @override
  String get inputBarMaxWidth => 'Ancho de la barra de entrada';

  @override
  String get minimizeBottomNav => 'Minimizar barra de navegación inferior';

  @override
  String get minimizeBottomNavSubtitle =>
      'Ocultar etiquetas en la barra de navegación inferior';

  @override
  String get swipeTabs => 'Deslizar entre pestañas';

  @override
  String get swipeTabsSubtitle =>
      'Cambiar de pestaña con un gesto de deslizamiento horizontal';

  @override
  String get smoothScroll => 'Desplazamiento suave';

  @override
  String get performanceOptimizations => 'Optimizaciones de rendimiento';

  @override
  String get macOsWindowStyle => 'Estilo de ventana';

  @override
  String get macOsWindowStyleSubtitle => 'Estilo de los controles de ventana';

  @override
  String get macOsNativeTitleBar => 'macOS nativo (semáforo)';

  @override
  String get macOsCustomTitleBar => 'Estilo Windows (lado derecho)';

  @override
  String get updateAvailableLabel => 'Actualización disponible';

  @override
  String get updateDownload => 'Descargar';

  @override
  String get cacheTitle => 'Caché';

  @override
  String get cacheSubtitle => 'Gestionar la caché de medios local';

  @override
  String get mediaCacheSize => 'Caché de mensajes multimedia: ';

  @override
  String get clearLocalCache => 'Borrar caché local';

  @override
  String get clearLocalCacheTitle => 'Borrar caché local';

  @override
  String get clearLocalCacheContent =>
      '¿Seguro que quieres eliminar todos los medios en caché (voz, imágenes, videos)?nEsto NO afecta a lo subido al servidor ni al historial de chats.';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String get serverMediaCache => 'Caché de medios del servidor';

  @override
  String get serverMediaCacheSubtitle =>
      'Almacenado en el servidor: imágenes, voz, video.';

  @override
  String get clearServerCache => 'Borrar caché del servidor';

  @override
  String get dangerZone => 'Zona de peligro';

  @override
  String get dangerZoneSubtitle => 'Borrar los datos locales.';

  @override
  String get factoryReset => 'Restablecer de fábrica';

  @override
  String get factoryResetHint =>
      'Selecciona qué restablecer. Debes elegir al menos una opción.';

  @override
  String get resetDeleteAccount => 'Eliminar cuenta del servidor';

  @override
  String resetDeleteAccountSubtitle(String username) {
    return 'Elimina permanentemente a @$username: todos los mensajes, medios y claves del servidor.';
  }

  @override
  String get resetNoAccount => 'No hay ninguna cuenta iniciada sesión.';

  @override
  String get resetDeleteLocal => 'Eliminar datos locales de la app';

  @override
  String get resetDeleteLocalSubtitle =>
      'Borra todos los chats, claves, ajustes, caché y medios locales.';

  @override
  String get reset => 'Restablecer';

  @override
  String get resetFailed => 'Error al restablecer';

  @override
  String get resetConfirmStep1Title => '¿Está seguro de que desea hacer esto?';

  @override
  String get resetConfirmStep1Message =>
      'Esto eliminará permanentemente los datos seleccionados. Esta acción no se puede deshacer.';

  @override
  String get resetConfirmStep2Title => '¿Está seguro?';

  @override
  String get resetConfirmStep2Message =>
      'Esta es su última oportunidad para cancelar. Confirmar iniciará el restablecimiento de inmediato.';

  @override
  String get connectionTitle => 'Conexión';

  @override
  String get connectionSubtitle => 'Estado y controles del WebSocket';

  @override
  String get appDataTitle => 'Carpeta de datos de ONYX';

  @override
  String get appDataSubtitle =>
      'Mover la carpeta de datos de la app a otra unidad';

  @override
  String get appDataCurrentPath => 'Carpeta actual';

  @override
  String get appDataDefault => 'Predeterminada (carpeta del sistema)';

  @override
  String get appDataMove => 'Mover…';

  @override
  String get appDataReset => 'Restablecer';

  @override
  String get appDataMigrating => 'Moviendo datos…';

  @override
  String get appDataMigrateError => 'Error al mover';

  @override
  String get appDataRestartRequired =>
      'Carpeta cambiada. Reinicia ONYX para que el cambio surta efecto.';

  @override
  String get appDataRestart => 'Reiniciar ONYX';

  @override
  String get appDataOpenFolder => 'Abrir carpeta';

  @override
  String get appDataDeleteOldFolder => 'Eliminar carpeta anterior';

  @override
  String get appDataDeleteOldFolderSubtitle =>
      'Elimina la carpeta de datos original del sistema tras la migración';

  @override
  String get appDataDeleteOldFolderConfirm =>
      '¿Eliminar la carpeta de datos original de ONYX?nnEsto no se puede deshacer. Asegúrate de que los datos se migraron correctamente.';

  @override
  String get appDataDeleteOldFolderSuccess => 'Carpeta anterior eliminada';

  @override
  String get appDataDeleteOldFolderError => 'Error al eliminar: ';

  @override
  String get interactTitle => 'Interacción';

  @override
  String get interactSubtitle => 'Confirmaciones al subir archivos';

  @override
  String get confirmFileUpload => 'Confirmar subida de archivo';

  @override
  String get confirmFileUploadSubtitle =>
      'Mostrar un diálogo de confirmación antes de enviar archivos';

  @override
  String get confirmVoiceMessage => 'Confirmar mensaje de voz';

  @override
  String get confirmVoiceSubtitle =>
      'Mostrar un diálogo de confirmación antes de enviar audios';

  @override
  String get downloadFolder => 'Carpeta de descargas';

  @override
  String get downloadFolderSubtitle =>
      'Dónde guardar los archivos recibidos (por defecto: Descargas/ONYX)';

  @override
  String get downloadFolderDefault => 'Predeterminada (Descargas/ONYX)';

  @override
  String get downloadFolderChange => 'Elegir carpeta';

  @override
  String get downloadFolderReset => 'Restablecer';

  @override
  String get contactTitle => 'Contacto';

  @override
  String get contactSubtitle => 'Sitio web, repositorio y comentarios';

  @override
  String get contactWebsite => 'Sitio web oficial';

  @override
  String get contactRepository => 'Código fuente (cliente)';

  @override
  String get contactRepositoryServer => 'Código fuente (servidor autoalojado)';

  @override
  String get contactEmail => 'Contáctanos';

  @override
  String get debugTitle => 'Depuración/Registros';

  @override
  String get debugSubtitle => 'Rendimiento y registros en tiempo real';

  @override
  String get debugMode => 'Modo de depuración';

  @override
  String get debugModeSubtitle =>
      'Activar monitoreo de rendimiento y registros';

  @override
  String get enableFileLogging => 'Activar registro en archivo';

  @override
  String get enableFileLoggingSubtitle =>
      'Guardar los registros de la app en el disco (desactívalo por privacidad)';

  @override
  String get deleteAllLogs => 'Eliminar todos los registros';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSubtitle => 'Idioma de la interfaz de la app';

  @override
  String get languageChanged => 'Idioma cambiado';

  @override
  String get noChatsYet => 'Aún no hay chats';

  @override
  String get deleteChatTitle => '¿Eliminar chat?';

  @override
  String get removeFromContacts => 'Quitar de contactos';

  @override
  String get blockUserLabel => 'Bloquear usuario';

  @override
  String get unblockUserLabel => 'Desbloquear';

  @override
  String get muteUserLabel => 'Silenciar notificaciones';

  @override
  String get unmuteUserLabel => 'Activar notificaciones';

  @override
  String get blockedByUserMessage =>
      'Este usuario ha restringido los mensajes entrantes de tu parte.';

  @override
  String unblockUserConfirmContent(String name) {
    return '¿Desbloquear a $name?';
  }

  @override
  String blockUserConfirmContent(String name) {
    return '¿Bloquear a $name? No podrá enviarte mensajes.';
  }

  @override
  String deleteChatContent(String name) {
    return '¿Seguro que quieres eliminar el chat con \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get displayName => 'Nombre visible';

  @override
  String get addAccount => 'Añadir cuenta';

  @override
  String get identityNewIdentityButton => 'Nueva identidad';

  @override
  String get identityInfoTooltip => '¿Cómo funciona esto?';

  @override
  String get identityInfoTitle => 'Una nueva forma de comunicarse';

  @override
  String get identityInfoBody =>
      'ONYX está pasando a un modelo totalmente descentralizado. En lugar de una cuenta en un servidor central, tu identidad ahora es una clave criptográfica generada localmente en tu dispositivo: una dirección Tor que solo tú controlas.\n\nNo hay contraseña ni servidor que sepa quién eres. Una frase semilla de 12 palabras es la única forma de restaurar esta identidad en un nuevo dispositivo.\n\nLos mensajes a contactos que ya tienen tu nueva dirección se entregan directamente por Tor, sin pasar por ningún servidor central. Los contactos que sigan en el sistema antiguo deberán compartir contigo su nueva dirección una vez, igual que compartirías un número de teléfono.';

  @override
  String get identityTitleChoose => 'Crear una identidad';

  @override
  String get identityChooseSubtitle =>
      'La clave y la dirección se generan localmente en este dispositivo.';

  @override
  String get identityCreateNewButton => 'Nueva identidad';

  @override
  String get identityRestoreLinkButton => 'Ya tengo una frase semilla';

  @override
  String get identityTitleMnemonic => 'Tu frase semilla';

  @override
  String get identityMnemonicIntro =>
      'Anota estas 12 palabras y guárdalas en un lugar seguro.';

  @override
  String get identityMnemonicRestoreNote =>
      'Esta es la única forma de restaurar tu identidad en un nuevo dispositivo.';

  @override
  String get identityCopyButton => 'Copiar';

  @override
  String get identityCopiedSnack => 'Copiado';

  @override
  String get identitySavedConfirm => 'Guardé la frase en un lugar seguro';

  @override
  String get identityContinueButton => 'Continuar';

  @override
  String get identityTitleRestore => 'Restaurar identidad';

  @override
  String get identityRestoreHint =>
      'Introduce tu frase semilla (12 palabras separadas por espacios).';

  @override
  String get identityRestoreButton => 'Restaurar';

  @override
  String get identityBackButton => 'Atrás';

  @override
  String get identityTitleDone => 'Identidad lista';

  @override
  String get identityAccountIdLabel => 'ID de cuenta';

  @override
  String get identityAccountIdExplain =>
      'Un identificador estable derivado de tu clave: es lo que vincula tus dispositivos y mensajes en lugar de un nombre de usuario.';

  @override
  String get identityFingerprintLabel => 'Huella';

  @override
  String get identityFingerprintExplain =>
      'Un código corto que tus contactos pueden usar para verificar que realmente eres tú.';

  @override
  String get identityDoneButton => 'Listo';

  @override
  String get tapToCopyAddress => 'Toca para copiar la dirección';

  @override
  String get identityErrorCreatePrefix => 'No se pudo crear la identidad';

  @override
  String get identityErrorRestorePrefix => 'No se pudo restaurar la identidad';

  @override
  String get identityTitleSetup => 'Configura tu perfil';

  @override
  String get identityDisplayNameLabel => 'Nombre visible';

  @override
  String get identityDisplayNameHint => 'Así te verán tus contactos';

  @override
  String get identityCreateAccountButton => 'Crear cuenta';

  @override
  String get welcomeTitle => 'Bienvenido';

  @override
  String get welcomeTagline =>
      'Mensajería segura con cifrado de extremo a extremo';

  @override
  String get otherAccounts => 'Otras identidades';

  @override
  String get tapToSwitch => 'Toca para cambiar';

  @override
  String get deleteFromRecentTitle => '¿Eliminar cuenta de recientes?';

  @override
  String get authUsernameLabel => 'Usuario (3-16 caracteres)';

  @override
  String get authPasswordLabel => 'Contraseña (mín. 16 caracteres)';

  @override
  String get loginBtn => 'Iniciar sesión';

  @override
  String get registerBtn => 'Registrarse';

  @override
  String get deviceAuthTitle => 'Vincular dispositivo';

  @override
  String get deviceAuthTabScan => 'Escanear';

  @override
  String get deviceAuthTapToScan => 'Toca para escanear el código QR';

  @override
  String get deviceAuthLanNote =>
      'Ambos dispositivos deben estar en la misma red local';

  @override
  String get loginWithQr => 'Iniciar sesión con QR';

  @override
  String get qrAuthWaitingTitle => 'Esperando al teléfono';

  @override
  String get qrAuthWaitingSubtitle =>
      'Escanea este código en un dispositivo autorizado para transferir la sesión aquí';

  @override
  String get qrAuthSuccess => 'Dispositivo autorizado';

  @override
  String get qrAuthFailed => 'Error en la autenticación por QR';

  @override
  String get qrAuthCancelled => 'Autenticación por QR cancelada';

  @override
  String get authorizeDevice => 'Autorizar dispositivo';

  @override
  String get authorizeDeviceSubtitle =>
      'Permitir que otro dispositivo inicie sesión escaneando un código QR';

  @override
  String get authorizeDeviceScanHint =>
      'Apunta la cámara al código QR mostrado en el otro dispositivo';

  @override
  String get authorizeDeviceSuccess => 'Dispositivo autorizado correctamente';

  @override
  String get authorizeDeviceFailed => 'Error al autorizar el dispositivo';

  @override
  String get authorizeDeviceSending => 'Enviando credenciales…';

  @override
  String get qrAuthEncryptedNote =>
      'La transferencia está cifrada (X25519 + AES-256-GCM)';

  @override
  String get scanFromPc => 'Recibir desde el PC';

  @override
  String get scanFromPcHint =>
      'Apunta la cámara al código QR mostrado en otro dispositivo para iniciar sesión aquí';

  @override
  String get grantDeviceTitle => 'Autorizar teléfono';

  @override
  String get grantDeviceSubtitle =>
      'Escanea este código en otro dispositivo para iniciar sesión allí con esta cuenta';

  @override
  String get grantDeviceSuccess => 'Teléfono autorizado correctamente';

  @override
  String get grantDeviceFailed => 'Error al autorizar el teléfono';

  @override
  String get enterUsernameMsg => 'Introduce tu nombre de usuario';

  @override
  String get loginSuccess => 'Sesión iniciada correctamente';

  @override
  String get loginFailed => 'Error al iniciar sesión';

  @override
  String get registeringMsg => 'Registrando...';

  @override
  String get registrationFailed => ' Error en el registro';

  @override
  String get usernameInvalidMsg =>
      'Usuario: 3-16 caracteres, solo letras, dígitos, _ . -';

  @override
  String get passwordTooShortMsg => 'Contraseña demasiado corta (mín. 16)';

  @override
  String get generatePasswordTooltip => 'Generar contraseña segura';

  @override
  String get savePasswordWarning =>
      'Asegúrate de guardar tu contraseña en un lugar seguro: anótala. La recuperación sin contraseña es imposible.';

  @override
  String get passphraseWriteDown =>
      'Esta frase de recuperación no volverá a mostrarse. Anota estas 12 palabras a mano y guárdalas en un lugar seguro; las necesitarás para recuperar tu cuenta si olvidas tu contraseña.';

  @override
  String get passphraseWriteOnPaper =>
      'Escribe tu frase de recuperación en papel ahora mismo: ¡no habrá una segunda oportunidad!';

  @override
  String get copyToClipboard => 'Copiar al portapapeles';

  @override
  String get copiedToClipboard => '¡Copiado!';

  @override
  String passphraseCountdown(int s) {
    return 'Por favor, lee con atención; disponible en $s s...';
  }

  @override
  String get iSavedIt => 'Ya la guardé';

  @override
  String deleteFromRecentContent(String acc) {
    return '¿Quitar \"$acc\" de la lista reciente?';
  }

  @override
  String get createGroupChannel => 'Crear grupo/canal';

  @override
  String get channelAdminOnly => 'Canal (solo publican los administradores)';

  @override
  String get viewByToken => 'Ver por token';

  @override
  String get viewByIp => 'Ver por IP (servidor externo)';

  @override
  String get createGroupOrChannel => 'Crear grupo o canal';

  @override
  String get removeExternalServerTitle => '¿Eliminar servidor externo?';

  @override
  String removeExternalServerContent(String name) {
    return '¿Eliminar \"$name\" y todos sus grupos de tu lista? Puedes volver a unirte más tarde introduciendo de nuevo la dirección del servidor.';
  }

  @override
  String get noGroupsYet => 'Aún no hay grupos';

  @override
  String get groupNameLabel => 'Nombre del grupo:';

  @override
  String get groupNameHint => 'Introduce un nombre';

  @override
  String get pasteToken => 'Pegar token:';

  @override
  String get create => 'Crear';

  @override
  String get view => 'Ver';

  @override
  String get leave => 'Salir';

  @override
  String get remove => 'Quitar';

  @override
  String get leaveGroupAction => 'Salir';

  @override
  String leaveGroupContent(String name) {
    return '¿Seguro que quieres salir de \"$name\"? Dejarás de recibir sus mensajes.';
  }

  @override
  String get chooseCrypto => 'Elige una criptomoneda para donar';

  @override
  String get addressCopied => 'dirección copiada';

  @override
  String get hideFromSearch => 'Ocultarme de las búsquedas';

  @override
  String get hideFromSearchSubtitle =>
      'Otros no podrán encontrarte buscando tu nombre de usuario';

  @override
  String get hideFromSearchSavedOk => ' Ajustes de privacidad guardados';

  @override
  String get hideFromSearchSavedFail =>
      ' Guardado localmente, no se pudo sincronizar';

  @override
  String get statusVisibility => 'Visibilidad';

  @override
  String get statusShowStatus => 'Mostrar estado';

  @override
  String get statusHideStatus => 'Ocultar estado';

  @override
  String get statusCustomText => 'Texto de estado personalizado';

  @override
  String get statusWhenOnline => 'Cuando está en línea';

  @override
  String get statusWhenOffline => 'Cuando está desconectado';

  @override
  String get statusSavedOk => ' Ajustes de estado guardados y sincronizados';

  @override
  String get statusSavedFail =>
      ' Guardado localmente, no se pudo sincronizar con el servidor';

  @override
  String get clearServerCacheTitle => '¿Borrar medios del servidor?';

  @override
  String get clearServerCacheContent =>
      'Esto eliminará TODOS tus medios subidos al servidor, incluyendo:n\'\n        \'• Mensajes de vozn\'\n        \'• Imágenesn\'\n        \'• Videosn\'\n        \'• Archivosn\'\n        \'• Avatarnn\'\n        \'La caché local se conservará. Esta acción no se puede deshacer.';

  @override
  String get serverMediaCleared => ' Todos los medios del servidor eliminados';

  @override
  String get notLoggedIn => 'Sesión no iniciada';

  @override
  String get serverMediaManagerTitle => 'Medios del servidor';

  @override
  String get cacheTabImages => 'Imágenes';

  @override
  String get cacheTabVoice => 'Voz';

  @override
  String get cacheTabAudio => 'Audio';

  @override
  String get cacheTabVideo => 'Video';

  @override
  String get cacheTabFiles => 'Archivos';

  @override
  String get cacheTabDocuments => 'Documentos';

  @override
  String get cacheTabArchives => 'Comprimidos';

  @override
  String get cacheTabData => 'Datos';

  @override
  String get cacheTabAvatars => 'Avatares';

  @override
  String get cacheNoFiles => 'No hay archivos en esta categoría';

  @override
  String get cacheClearTabTitle => '¿Borrar categoría?';

  @override
  String cacheClearTabContent(String typeName) {
    return '¿Eliminar todos los archivos en \"$typeName\"? Esto no se puede deshacer.';
  }

  @override
  String get cacheFileDeleteFailed => 'Error al eliminar el archivo';

  @override
  String get cacheClearAll => 'Borrar todo';

  @override
  String get cacheClearTab => 'Borrar pestaña';

  @override
  String get cleanUnusedFiles => 'Limpiar archivos sin usar';

  @override
  String get cleaningUnusedFiles => 'Limpiando...';

  @override
  String get orphanedCleanupAppNotReady => 'La app no está lista';

  @override
  String get orphanedCleanupNoFiles => 'No se encontraron archivos sin usar';

  @override
  String get manageCacheTitle => 'Gestionar caché';

  @override
  String get manageCacheButton => 'Gestionar caché de medios';

  @override
  String get localCacheTab => 'Local';

  @override
  String get serverCacheTab => 'Servidor';

  @override
  String get cacheSelectAll => 'Seleccionar todo';

  @override
  String get cacheDeselectAll => 'Deseleccionar todo';

  @override
  String get cacheSelected => 'seleccionados';

  @override
  String get clearLocalCacheDialogTitle => 'Borrar caché local';

  @override
  String get clearLocalCacheDialogContent =>
      '¿Eliminar todos los medios en caché (voz, imágenes, vídeos)?\nEl historial de chats no se ve afectado.';

  @override
  String get deleteAllLogsTitle => '¿Eliminar todos los registros?';

  @override
  String get deleteAllLogsContent =>
      'Esto eliminará permanentemente todos los archivos de registro de la app en el disco.\nEsta acción no se puede deshacer.';

  @override
  String get noLogsFound => 'No se encontraron archivos de registro.';

  @override
  String get changePasswordInfo =>
      'Introduce tu frase de recuperación y tu contraseña actual para establecer una nueva.';

  @override
  String get changePasswordPassphraseLabel =>
      'Frase de recuperación (12 palabras)';

  @override
  String get changePasswordCurrentLabel => 'Contraseña actual';

  @override
  String get changePasswordNewLabel => 'Nueva contraseña (mín. 16 caracteres)';

  @override
  String get changePasswordChange => 'Cambiar';

  @override
  String get changePasswordFieldsRequired =>
      'Todos los campos son obligatorios';

  @override
  String get changePasswordTooShort =>
      'La nueva contraseña debe tener al menos 16 caracteres';

  @override
  String get changePasswordChanging => 'Cambiando contraseña...';

  @override
  String get changePasswordSuccess => ' Contraseña cambiada correctamente';

  @override
  String get clearBgTitle => '¿Quitar fondo?';

  @override
  String get clearBgContent =>
      'Quitar el fondo de chat personalizado y restaurar el predeterminado.';

  @override
  String get chatBgSet => ' Fondo de chat establecido';

  @override
  String get chatBgCleared => 'Fondo eliminado';

  @override
  String get sendAsCodeTitle => '¿Enviar como código?';

  @override
  String get sendAsCodeContent =>
      'Este mensaje parece código. ¿Enviarlo como un bloque de código con formato?';

  @override
  String get sendAsCode => 'Enviar como código';

  @override
  String get sendAsPlainText => 'Enviar como texto';

  @override
  String get allMessagesLeft => 'Todos los mensajes: izquierda';

  @override
  String get allMessagesRight2 => 'Todos los mensajes: derecha';

  @override
  String get allMessagesMixed => 'Todos los mensajes: mixto';

  @override
  String get applyBackgroundToApp => 'Aplicar el fondo a toda la app';

  @override
  String get uiElementsOpacityLabel => 'Opacidad de elementos de la interfaz';

  @override
  String get uiElementsBrightnessLabel => 'Brillo de elementos de la interfaz';

  @override
  String get navPanelPosition => 'Posición del panel de navegación';

  @override
  String get navPosBottom => 'Abajo (bajo la lista de chats)';

  @override
  String get navPosLeft => 'Izquierda (barra lateral)';

  @override
  String get tabSwiping => 'Deslizamiento de pestañas';

  @override
  String get tabSwipingSubtitle =>
      'Deslizar entre pestañas con efecto de rebote';

  @override
  String get showAvatarsInChats => 'Mostrar avatares en los chats';

  @override
  String get smoothScrollDown => 'Desplazamiento suave hacia abajo';

  @override
  String get messageAnimations => 'Animaciones de mensajes';

  @override
  String get chatListMoveAnimations =>
      'Animaciones de movimiento en la lista de chats';

  @override
  String get scrollDownButtonPosition =>
      'Posición del botón de desplazamiento hacia abajo';

  @override
  String get scrollDownButtonPositionLeft => 'Izquierda';

  @override
  String get scrollDownButtonPositionCenter => 'Centro';

  @override
  String get scrollDownButtonPositionRight => 'Derecha';

  @override
  String get scrollDownButtonSize =>
      'Tamaño del botón de desplazamiento hacia abajo';

  @override
  String get loadOlderMessagesOnScroll =>
      'Cargar mensajes antiguos al desplazarse';

  @override
  String get showSnackbars => 'Mostrar avisos emergentes';

  @override
  String get autoLoadVideos => 'Cargar videos automáticamente';

  @override
  String get autoLoadVideosSubtitle =>
      'Si está desactivado, los videos solo se cargan al tocarlos; el desplazamiento es más fluido';

  @override
  String get tapToLoadVideo => 'Toca para cargar el video';

  @override
  String get chooseBackground => 'Elegir';

  @override
  String get presetsBackground => 'Predefinidos';

  @override
  String get clearBackground2 => 'Quitar';

  @override
  String get liquidGlassSubtitle =>
      'Configura los efectos de cristal y su calidad por elemento';

  @override
  String get liquidGlassNavBarLabel => 'Barra de navegación';

  @override
  String get liquidGlassNavBarDesc =>
      'Efecto de cristal en la barra de navegación inferior';

  @override
  String get liquidGlassInputLabel => 'Barra de entrada';

  @override
  String get liquidGlassInputDesc =>
      'Efecto de cristal en la barra de redacción de mensajes';

  @override
  String get liquidGlassSearchLabel => 'Búsqueda';

  @override
  String get liquidGlassSearchDesc =>
      'Panel de cristal estilo Spotlight para la búsqueda de usuarios';

  @override
  String get liquidGlassAppBarLabel => 'Botones de la barra superior';

  @override
  String get liquidGlassAppBarDesc =>
      'Efecto de cristal en los botones de icono de la barra superior del chat';

  @override
  String get sendFavoritesScanHint =>
      'Apunta la cámara al código QR mostrado en el dispositivo receptor';

  @override
  String get mediaPickerGallery => 'Galería';

  @override
  String get mediaPickerCamera => 'Cámara';

  @override
  String get mediaPickerFile => 'Archivo';

  @override
  String mediaPickerSend(int n) {
    return 'Enviar $n';
  }

  @override
  String get mediaPickerChooseWallpaper => 'Elegir fondo de pantalla';

  @override
  String get mediaPickerFiles => 'Archivos';

  @override
  String get mediaPickerDeniedTitle => 'Acceso a la galería denegado';

  @override
  String get mediaPickerDeniedBody =>
      'Permite el acceso en los ajustes o elige un archivo directamente.';

  @override
  String get mediaPickerPickFile => 'Elegir archivo';

  @override
  String get mediaPickerOpenSettings => 'Abrir ajustes';

  @override
  String get notifWarning =>
      'Las notificaciones solo llegan mientras la app está en ejecución. Para no perderte ningún mensaje, minimiza ONYX a la bandeja del sistema en lugar de cerrarlo.';

  @override
  String get backgroundServiceTitle => 'Servicio en segundo plano';

  @override
  String get backgroundServiceSubtitle =>
      'Mantener ONYX conectado al minimizarlo';

  @override
  String get backgroundServiceEnableLabel =>
      'Seguir ejecutándose en segundo plano';

  @override
  String get backgroundServiceEnableSubtitle =>
      'Muestra una notificación persistente para que el sistema no impida que ONYX reciba mensajes mientras está minimizado';

  @override
  String get backgroundServiceTextLabel => 'Texto de la notificación';

  @override
  String get backgroundServiceDefaultText => 'Esperando mensajes';

  @override
  String get notifPopupPosition => 'Posición del aviso emergente';

  @override
  String get notifPopupPositionSubtitle =>
      'Elige dónde aparece el aviso emergente de notificación en la pantalla';

  @override
  String get notifEnableLabel => 'Activar notificaciones';

  @override
  String get notifHideContentLabel => 'Ocultar contenido del mensaje';

  @override
  String get notifSoundEnableLabel => 'Sonido de notificación';

  @override
  String get notifSoundChooseLabel => 'Elegir sonido';

  @override
  String get notifSoundCustom => 'Subir sonido personalizado...';

  @override
  String get notifSoundCustomLoaded => 'Sonido personalizado establecido';

  @override
  String get notifSoundCustomError => 'Error al cargar el sonido';

  @override
  String get notifSoundCustomInvalidFormat =>
      'Formatos admitidos: WAV, MP3, M4A, OGG, AAC';

  @override
  String get resetting => 'Restableciendo...';

  @override
  String get launchAtStartupLabel => 'Iniciar al arrancar el sistema';

  @override
  String get launchAtStartupSubtitle =>
      'Iniciar ONYX automáticamente al iniciar sesión';

  @override
  String get launchAtStartupEnabled => 'Inicio automático activado';

  @override
  String get launchAtStartupDisabled => 'Inicio automático desactivado';

  @override
  String get launchAtStartupFailed =>
      'Error al cambiar el ajuste de inicio automático';

  @override
  String get avatarUpdated => 'Avatar actualizado';

  @override
  String get fileNotFound => 'Archivo no encontrado';

  @override
  String get fileSent => 'Archivo enviado';

  @override
  String get imageSent => 'Imagen enviada';

  @override
  String get videoSent => 'Video enviado';

  @override
  String uploadingFile(String name) {
    return 'Subiendo $name...';
  }

  @override
  String albumSent(int n) {
    return 'Álbum enviado ($n imágenes)';
  }

  @override
  String get fileEmpty => 'El archivo está vacío';

  @override
  String get networkError => 'Error de red';

  @override
  String get avatarRemoved => 'Avatar eliminado';

  @override
  String get uinCopied => 'UIN copiado';

  @override
  String get displayNameLength =>
      'El nombre visible debe tener entre 1 y 16 caracteres';

  @override
  String get displayNameRequired => 'El nombre visible no puede estar vacío';

  @override
  String get displayNameUpdated => 'Nombre actualizado';

  @override
  String get failedSendLan => 'Error al enviar por LAN';

  @override
  String get fileCancelled => 'Archivo cancelado';

  @override
  String get doneRestarting => '¡Listo! Reiniciando...';

  @override
  String get deleteMessageTitle => '¿Eliminar mensaje?';

  @override
  String get deleteMessageContent =>
      'Este mensaje se eliminará para ambas partes.';

  @override
  String get cannotDeleteMsg =>
      'No se puede eliminar: el mensaje aún no se guardó en el servidor';

  @override
  String get deleteForMeTitle => '¿Eliminar para mí?';

  @override
  String get deleteForMeContent =>
      'Esto solo eliminará el mensaje de tu dispositivo. La otra persona seguirá viéndolo.';

  @override
  String deleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $count mensajes?',
      one: '¿Eliminar mensaje?',
    );
    return '$_temp0';
  }

  @override
  String deleteSelectedForBoth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Estos mensajes se eliminarán para ambas partes.',
      one: 'Este mensaje se eliminará para ambas partes.',
    );
    return '$_temp0';
  }

  @override
  String deleteSelectedForMe(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Estos mensajes se eliminarán solo para ti. La otra persona seguirá viéndolos.',
      one:
          'Este mensaje se eliminará solo para ti. La otra persona seguirá viéndolo.',
    );
    return '$_temp0';
  }

  @override
  String deleteSelectedMixed(int mine, int theirs) {
    return 'Tus mensajes ($mine) se eliminarán para ambas partes. Los mensajes de la otra persona ($theirs) se eliminarán solo para ti.';
  }

  @override
  String get deleteFavMessageContent =>
      'Este mensaje se eliminará de favoritos.';

  @override
  String get pinnedMessage => 'Mensaje fijado';

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
  String get msgCopied => 'Copiado';

  @override
  String copiedUsername(String name) {
    return 'Copiado @$name';
  }

  @override
  String get deliveryModeTitle => 'Elige el modo de envío';

  @override
  String get deliveryInternet => 'Internet';

  @override
  String get deliveryInternetSubtitle => 'Enviar por servidor (cifrado)';

  @override
  String get deliveryLanSubtitle => 'Enviar por red local (directo)';

  @override
  String get deliveryUserNotInLan => 'Usuario no encontrado en la red local';

  @override
  String get fastChange => 'Cambio rápido';

  @override
  String get fastChangeSubtitle => 'Alternar modo con una pulsación larga';

  @override
  String get lanModeEnabled => 'Modo LAN activado';

  @override
  String get internetModeEnabled => 'Modo internet activado';

  @override
  String get previewMessageTitle => 'Vista previa del mensaje';

  @override
  String get previewYourMessage => 'Tu mensaje:';

  @override
  String replyingTo(String name) {
    return 'Respondiendo a: $name';
  }

  @override
  String get send => 'Enviar';

  @override
  String get fileSentLan => 'Archivo enviado por LAN';

  @override
  String uploadingImages(int n) {
    return 'Subiendo $n imágenes...';
  }

  @override
  String get albumUploadFailed => 'Error al subir el álbum';

  @override
  String get message => 'Mensaje';

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String get voiceCallsTitle => 'Llamadas de voz';

  @override
  String get voiceCallsContent =>
      'Las llamadas de voz solo funcionan por LAN (red local) por ahora.';

  @override
  String get supportOnyxBtn => 'Apoyar a ONYX';

  @override
  String get call => 'Llamar';

  @override
  String get securityCheckTitle => 'Verificación de seguridad';

  @override
  String securityCheckContent(String name) {
    return 'Compara estos emojis con $name.\nSi coinciden, tu chat es seguro.';
  }

  @override
  String get failedToFetchPubkey => 'Error al obtener la clave pública';

  @override
  String get userHasNoPubkey => 'El usuario no tiene clave pública';

  @override
  String get galleryMenuLabel => 'Galería';

  @override
  String get galleryTitle => 'Galería';

  @override
  String get galleryTabMedia => 'Multimedia';

  @override
  String get galleryTabVoice => 'Voz';

  @override
  String get galleryTabFiles => 'Archivos';

  @override
  String get galleryEmptyMedia => 'Aún no hay fotos ni videos';

  @override
  String get galleryEmptyVoice => 'Aún no hay mensajes de voz';

  @override
  String get galleryEmptyFiles => 'Aún no hay archivos';

  @override
  String get galleryShowInChat => 'Mostrar en el chat';

  @override
  String get failedDelete => 'Error al eliminar';

  @override
  String get failedEdit => 'Error al editar el mensaje';

  @override
  String get failedReaction => 'No se pudo añadir la reacción';

  @override
  String get noInternetCached => 'Sin internet: mostrando mensajes en caché';

  @override
  String get sendFailed => 'Error al enviar';

  @override
  String get mediaUploadNotSupportedWeb =>
      'La subida de medios no es compatible en la web';

  @override
  String get localFileRequired => 'Se requiere un archivo local';

  @override
  String get uploadFailed => 'Error al subir';

  @override
  String get voiceUploadFailed => 'Error al subir el audio';

  @override
  String get voiceCancelled => 'Mensaje de voz cancelado';

  @override
  String get uploadingVoice => 'Subiendo audio...';

  @override
  String uploadingAlbumProgress(int done, int total) {
    return 'Subiendo álbum: $done/$total fotos';
  }

  @override
  String get uploadingImageLabel => 'Subiendo imagen...';

  @override
  String get uploadingVideoLabel => 'Subiendo video...';

  @override
  String get uploadingAudioLabel => 'Subiendo audio...';

  @override
  String get uploadingFileLabel => 'Subiendo archivo...';

  @override
  String get leftGroup => 'Has salido del grupo';

  @override
  String get failedLeaveGroup => 'Error al salir del grupo';

  @override
  String get avatarOnlyOwnerMod =>
      'Solo los propietarios y moderadores pueden cambiar el avatar';

  @override
  String get failedReadFile => 'Error al leer el archivo';

  @override
  String get uploadingAvatar => 'Subiendo avatar...';

  @override
  String get avatarUpdatedGroup => 'Avatar del grupo actualizado';

  @override
  String get avatarDeleted => 'Avatar eliminado';

  @override
  String get failedDeleteAvatar => 'Error al eliminar el avatar';

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get tokenCopied => 'Token copiado';

  @override
  String get groupNameLength =>
      'El nombre del grupo debe tener entre 1 y 50 caracteres';

  @override
  String get groupUpdated => 'Grupo actualizado';

  @override
  String get failedUpdateGroup => 'Error al actualizar el grupo';

  @override
  String get deleteAvatarTitle => '¿Eliminar avatar?';

  @override
  String get deleteAvatarContent =>
      'Esto eliminará el avatar del grupo para todos.';

  @override
  String get deleteGroupMsgContent => 'Este mensaje se eliminará para todos.';

  @override
  String get reply => 'Responder';

  @override
  String get edit => 'Editar';

  @override
  String get editGroupTitle => 'Editar grupo';

  @override
  String get editChannelTitle => 'Editar canal';

  @override
  String get groupInfoTitle => 'Group';

  @override
  String get channelInfoTitle => 'Channel';

  @override
  String get channelNameLabel => 'Nombre del canal';

  @override
  String get channelNameHint => 'Introduce el nombre del canal';

  @override
  String unsupportedFileType(String ext) {
    return 'Tipo de archivo no compatible: $ext';
  }

  @override
  String failedToConnect(String e) {
    return 'Error al conectar: $e';
  }

  @override
  String roleChanged(String role) {
    return 'Tu rol cambió a $role';
  }

  @override
  String get unbannedReconnecting =>
      '¡Se ha levantado tu expulsión! Reconectando...';

  @override
  String get onlyModsCanPost =>
      'Solo el propietario y los moderadores pueden publicar en los canales';

  @override
  String get failedSendMessage => 'Error al enviar el mensaje';

  @override
  String get uploadFailedConnectionAborted =>
      'Error al subir: conexión interrumpida. Prueba con un archivo más pequeño o revisa los ajustes del servidor.';

  @override
  String get failedSendMedia => 'Error al enviar el archivo multimedia';

  @override
  String get joinedGroup => '¡Te has unido al grupo!';

  @override
  String get failedJoinGroup => 'Error al unirse al grupo';

  @override
  String get cancelled => 'Cancelado';

  @override
  String get avatarWillBeDeleted => 'El avatar se eliminará';

  @override
  String get ipCopied => 'IP copiada';

  @override
  String get nameCannotBeEmpty => 'El nombre no puede estar vacío';

  @override
  String get groupRenamed => 'Grupo renombrado correctamente';

  @override
  String errorMsg(String e) {
    return 'Error: $e';
  }

  @override
  String get failedRename => 'Error al renombrar';

  @override
  String get imageTooLarge => 'Imagen demasiado grande (máx. 5 MB)';

  @override
  String get avatarUpdatedSuccessfully => 'Avatar actualizado correctamente';

  @override
  String get failedUploadAvatar => 'Error al subir el avatar';

  @override
  String get deletingAvatar => 'Eliminando avatar...';

  @override
  String get avatarDeletedSuccessfully => 'Avatar eliminado correctamente';

  @override
  String userBanned(String name) {
    return '$name expulsado';
  }

  @override
  String get failedBan => 'Error al expulsar';

  @override
  String roleUpdated(String role) {
    return 'Rol actualizado a $role';
  }

  @override
  String get failedChangeRole => 'Error al cambiar el rol';

  @override
  String userUnbanned(String name) {
    return 'Se levantó la expulsión de $name';
  }

  @override
  String get failedUnban => 'Error al levantar la expulsión';

  @override
  String get youHaveBeenBanned => 'Has sido expulsado';

  @override
  String get renameGroupTitle => 'Renombrar grupo';

  @override
  String get rename => 'Renombrar';

  @override
  String get join => 'Unirse';

  @override
  String get manageMembers => 'Gestionar miembros';

  @override
  String get banMemberTitle => 'Expulsar miembro';

  @override
  String get ban => 'Expulsar';

  @override
  String get selectNewRole => 'Selecciona el nuevo rol:';

  @override
  String get moderator => 'Moderador';

  @override
  String get memberRole => 'Miembro';

  @override
  String get manageMembersTitle => 'Gestionar miembros';

  @override
  String get viewBans => 'Ver expulsados';

  @override
  String get unbanUserTitle => 'Levantar expulsión';

  @override
  String get unban => 'Levantar expulsión';

  @override
  String get bannedUsersTitle => 'Usuarios expulsados';

  @override
  String get bannedFromGroup => 'Has sido expulsado de este grupo.';

  @override
  String bannedReason(String reason) {
    return 'Motivo: $reason';
  }

  @override
  String get noBannedUsers => 'No hay usuarios expulsados';

  @override
  String bannedBy(String name) {
    return 'Expulsado por: $name';
  }

  @override
  String bannedDate(String date) {
    return 'Fecha: $date';
  }

  @override
  String banConfirm(String name) {
    return '¿Expulsar a $name del grupo?';
  }

  @override
  String get banReason => 'Motivo (opcional)';

  @override
  String changeRoleTitle(String name) {
    return 'Cambiar el rol de $name';
  }

  @override
  String currentRoleLabel(String role) {
    return 'Rol actual: $role';
  }

  @override
  String ownerCount(int n) {
    return 'Propietarios: $n/3';
  }

  @override
  String get ownerCurrent => 'Propietario (actual)';

  @override
  String get ownerLimitReached => 'Propietario (límite alcanzado)';

  @override
  String get owner => 'Propietario';

  @override
  String get cannotDemoteLastOwner =>
      'No se puede degradar al último propietario';

  @override
  String get noMembersYet => 'Sin miembros';

  @override
  String get changeRole => 'Cambiar rol';

  @override
  String unbanConfirm(String name) {
    return '¿Levantar la expulsión de $name?';
  }

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get failedCreateGroup => 'Error al crear el grupo';

  @override
  String get invalidInviteLinkFormat =>
      'Formato de enlace de invitación no válido';

  @override
  String get invalidInviteLink => 'Enlace de invitación no válido';

  @override
  String get groupAddedForViewing => '¡Grupo añadido para visualización!';

  @override
  String get failedAddGroup => 'Error al añadir el grupo';

  @override
  String serverRemoved(String name) {
    return 'Servidor \"$name\" eliminado';
  }

  @override
  String get channelAdminOnlySubtitle => 'Canal (solo administradores)';

  @override
  String get groupSubtitle => 'Grupo';

  @override
  String get newGroup => 'Nuevo grupo';

  @override
  String get externalGroup => 'Grupo externo';

  @override
  String get externalChannel => 'Canal externo';

  @override
  String get joinExternalServer => 'Unirse a servidor externo';

  @override
  String get enterServerAddress => 'Introduce la dirección del servidor';

  @override
  String get enterValidIp =>
      'Introduce una dirección IP o nombre de host válido';

  @override
  String couldNotConnect(String host) {
    return 'No se pudo conectar a $host';
  }

  @override
  String get usernameRequiredMsg =>
      'Se requiere un nombre de usuario. Asegúrate de haber creado una cuenta en la app.';

  @override
  String get passwordRequiredForGroups =>
      'Se requiere contraseña para los grupos';

  @override
  String get passwordRequired => 'Se requiere contraseña';

  @override
  String connectionFailed(String e) {
    return 'Error de conexión: $e';
  }

  @override
  String connectedToServer(String type, String name) {
    return 'Conectado a $type \"$name\"';
  }

  @override
  String get externalGroupType => 'grupo externo';

  @override
  String get externalChannelType => 'canal externo';

  @override
  String get identityVisible => 'Tu identidad será visible para el servidor';

  @override
  String get usernameLabel => 'Usuario';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get noPasswordForChannels =>
      'No se requiere contraseña para los canales';

  @override
  String get noRegistrationRequired => 'No se requiere registro.';

  @override
  String get back => 'Atrás';

  @override
  String get connecting => 'Conectando...';

  @override
  String get connectBtn => 'Conectar';

  @override
  String get serverInfoGroups => 'Grupos';

  @override
  String get serverInfoMembers => 'Miembros';

  @override
  String get serverInfoMedia => 'Multimedia';

  @override
  String get serverInfoMaxFile => 'Tamaño máximo de archivo';

  @override
  String get profilePresets => 'Identidad';

  @override
  String get profilePresetsSubtitle =>
      'Identidades guardadas para unirte a servidores externos';

  @override
  String get newPreset => 'Nueva identidad';

  @override
  String get editPreset => 'Editar identidad';

  @override
  String get deletePreset => 'Eliminar identidad';

  @override
  String deletePresetConfirm(String label) {
    return '¿Eliminar la identidad \"$label\"?';
  }

  @override
  String get presetLabel => 'Nombre de la identidad';

  @override
  String get presetLabelHint => 'p. ej. Trabajo, Juegos';

  @override
  String get presetNote => 'Nota';

  @override
  String get presetNoteHint => '¿Para qué es esta identidad? (opcional)';

  @override
  String get presetColor => 'Color de etiqueta';

  @override
  String get presetLabelRequired => 'Introduce un nombre para la identidad';

  @override
  String get noPresetsYet => 'Aún no hay identidades';

  @override
  String get noPresetsYetSubtitle =>
      'Guarda una combinación de usuario y contraseña una vez y reutilízala en cualquier servidor externo';

  @override
  String get myPresets => 'Mis identidades';

  @override
  String get usePreset => 'Usar identidad';

  @override
  String get saveAsPreset => 'Guardar como identidad';

  @override
  String get presetSaved => 'Identidad guardada';

  @override
  String get presetDeleted => 'Identidad eliminada';

  @override
  String get thirdPartyServer => 'SERVIDOR DE TERCEROS';

  @override
  String get thirdPartyWarning =>
      'Este servidor no está operado por ONYX. Conéctate solo si confías en su propietario.';

  @override
  String get serverWillKnow => 'El servidor sabrá:';

  @override
  String get serverWillNotReceive => 'El servidor NO recibirá:';

  @override
  String get knowIpAddress => 'Tu dirección IP';

  @override
  String get knowUsername => 'El nombre de usuario que elijas';

  @override
  String get knowMessages => 'El contenido de tus mensajes en este servidor';

  @override
  String get notReceiveAccount => 'Tu cuenta de ONYX o tu contraseña';

  @override
  String get notReceiveContacts => 'Tus contactos y chats privados';

  @override
  String get notReceiveKeys => 'Tus claves de cifrado';

  @override
  String get yourPassphraseTitle => 'Tu frase de recuperación';

  @override
  String get sessionExpiredBanner =>
      'La sesión ha expirado; inicia sesión de nuevo';

  @override
  String get sessionExpiredTitle => 'Sesión expirada';

  @override
  String get sessionExpiredSubtitle => 'Vuelve a iniciar sesión';

  @override
  String get sessionSignIn => 'Iniciar sesión';

  @override
  String get sessionRenewSoon => 'Pronto se requerirá volver a iniciar sesión';

  @override
  String get sessionStillValid => 'El token de autorización es válido';

  @override
  String get blockedUsersTitle => 'Usuarios bloqueados';

  @override
  String get blockedUsersSubtitle => 'Gestionar usuarios bloqueados';

  @override
  String get blockedUsersEmpty => 'No hay usuarios bloqueados';

  @override
  String get unblockAction => 'Desbloquear';

  @override
  String get writeMessage => 'Escribir';

  @override
  String get fakePinTitle => 'PIN señuelo';

  @override
  String get fakePinSubtitle => 'Abrir una cuenta señuelo bajo coacción';

  @override
  String get fakePinSheetTitle => 'Configurar PIN señuelo';

  @override
  String get fakePinStatusActive => 'Activo';

  @override
  String get fakePinStatusOff => 'Desactivado';

  @override
  String get fakePinDescription =>
      'Cuando se introduce este PIN en la pantalla de bloqueo, la app se abre mostrando tu cuenta señuelo en lugar de la real.';

  @override
  String get setFakePin => 'Establecer PIN señuelo';

  @override
  String get disableFakePin => 'Desactivar PIN señuelo';

  @override
  String get changeFakePin => 'Cambiar PIN señuelo';

  @override
  String get disableFakePinTitle => '¿Desactivar el PIN señuelo?';

  @override
  String get disableFakePinContent =>
      'Se eliminará el PIN señuelo. Se conservarán los ajustes de la cuenta señuelo.';

  @override
  String get fakePinEnabledSnack => 'PIN señuelo activado';

  @override
  String get fakePinDisabledSnack => 'PIN señuelo desactivado';

  @override
  String get fakePinCannotMatchReal =>
      'El PIN señuelo no puede coincidir con tu PIN real';

  @override
  String get decoyAccountSection => 'Cuenta señuelo';

  @override
  String get decoyAccountSubtitle =>
      'Esta cuenta se mostrará al usar el PIN señuelo';

  @override
  String get decoyDisplayNameLabel => 'Nombre visible';

  @override
  String get decoyUsernameLabel => 'Usuario';

  @override
  String get decoyDisplayNameHint => 'Introduce el nombre visible';

  @override
  String get decoyUsernameHint => 'Introduce el nombre de usuario';

  @override
  String get saveDecoyAccount => 'Guardar cuenta señuelo';

  @override
  String get decoyAccountSaved => 'Cuenta señuelo guardada';

  @override
  String get decoyFieldsRequired =>
      'El usuario y el nombre visible no pueden estar vacíos';

  @override
  String get removeAvatar => 'Quitar avatar';

  @override
  String get fakePinSecurityNote =>
      'El PIN señuelo debe ser distinto de tu PIN real. La cuenta señuelo no tiene conexión al servidor; solo muestra el perfil que configuraste aquí.';

  @override
  String get decoyNoChats => 'Aún no hay chats';

  @override
  String get decoyNoGroups => 'Aún no hay grupos';

  @override
  String get decoyNoFavorites => 'Aún no hay favoritos';

  @override
  String get decoyOtherAccounts => 'Otras cuentas';

  @override
  String get decoyNoOtherAccounts => 'No hay otras cuentas';

  @override
  String get lock => 'Bloquear';

  @override
  String get decoyAppearance => 'Apariencia';

  @override
  String get decoyNotifications => 'Notificaciones';

  @override
  String get decoyStorage => 'Almacenamiento';

  @override
  String get decoyAppearanceSubtitle => 'Tema y opciones de visualización';

  @override
  String get decoyNotificationsSubtitle => 'Ajustes de sonido y alertas';

  @override
  String get decoyStorageSubtitle => 'Gestionar archivos en caché';

  @override
  String get decoyContactsSection => 'Chats falsos';

  @override
  String get decoyContactsSubtitle =>
      'Añade contactos con mensajes; aparecen al abrir la cuenta señuelo';

  @override
  String get generateContacts => 'Generar contactos';

  @override
  String get addDecoyContact => 'Añadir contacto';

  @override
  String get decoyNoContacts => 'Aún no hay chats falsos';

  @override
  String get decoyContactUsername => 'Usuario del contacto';

  @override
  String get decoyContactDisplayName => 'Nombre visible del contacto';

  @override
  String contactsGenerated(int n) {
    return 'Se añadieron $n contactos';
  }

  @override
  String get contactAdded => 'Contacto añadido';

  @override
  String get contactRemoved => 'Contacto eliminado';

  @override
  String get decoyContactExists => 'El contacto ya existe';

  @override
  String get decoyContactsCleared => 'Todos los chats fueron borrados';

  @override
  String get clearDecoyChats => 'Borrar todos los chats';

  @override
  String get messagesCount => 'mensajes';

  @override
  String get add => 'Añadir';

  @override
  String get decoyChatsSubtitle => 'Contactos con historial de mensajes';

  @override
  String get decoyGroupsSection => 'Grupos y canales';

  @override
  String get decoyGroupsSubtitle => 'Grupos y canales falsos';

  @override
  String get decoyFavoritesSection => 'Favoritos';

  @override
  String get decoyFavoritesSubtitle => 'Chats favoritos fijados';

  @override
  String get noFakeGroups => 'Aún no hay grupos';

  @override
  String get noFakeFavorites => 'Aún no hay favoritos';

  @override
  String get addFakeGroup => 'Grupo';

  @override
  String get addFakeChannel => 'Canal';

  @override
  String get addFakeFavorite => 'Añadir favorito';

  @override
  String get groupType => 'Grupo';

  @override
  String get channelType => 'Canal';

  @override
  String get favTitleHint => 'Título';

  @override
  String get generateAll => 'Generar todo';

  @override
  String get generateAllConfirm =>
      'Se generará contenido aleatorio, reemplazando los datos existentes.';

  @override
  String get sendFavoritesSendChat => 'Enviar chat';

  @override
  String get sendFavoritesQrTitle => 'Muéstralo al dispositivo receptor';

  @override
  String get sendFavoritesQrInstruction =>
      'Abre Favoritos en el otro dispositivo → Sincronizar → Recibir y escanea este código';

  @override
  String get sendFavoritesWaitingScan =>
      'Esperando a que el otro dispositivo escanee el código QR…';

  @override
  String get sendFavoritesTitle => 'Enviar favoritos';

  @override
  String get sendFavoritesShowQrToReceiver => 'Mostrar QR al receptor';

  @override
  String get sendFavoritesScanReceiver => 'Escanear QR\ndel receptor';

  @override
  String get sendFavoritesSending => 'Enviando favoritos';

  @override
  String get sendFavoritesSelectTitle => 'Selecciona los chats a enviar';

  @override
  String get sendFavoritesHintDesktop =>
      'El receptor debe pulsar \"Recibir\" primero. Luego escanea el código QR mostrado aquí.';

  @override
  String get sendFavoritesHintMobile =>
      'El receptor debe pulsar \"Recibir\" primero y mostrar el código QR.';

  @override
  String allChatsCount(int n) {
    return 'Todos los chats ($n)';
  }

  @override
  String get sendFavoritesNoFavs => 'Aún no hay chats favoritos.';

  @override
  String get sendFavoritesSelectAtLeastOne => 'Selecciona al menos un chat';

  @override
  String get sendFavoritesShowQrBtn => 'Mostrar QR';

  @override
  String get sendFavoritesScanQrBtn => 'Escanear QR';

  @override
  String get receiveFavoritesTitle => 'Recibir favoritos';

  @override
  String get receiveFavoritesScanSender => 'Escanear QR\ndel remitente';

  @override
  String get receiveFavoritesScanOnSender =>
      'Escanea en el dispositivo del remitente';

  @override
  String get receiveFavoritesInstruction =>
      'Abre Favoritos en el remitente, toca Sincronizar → Enviar y luego escanea este código';

  @override
  String get receiveFavoritesE2E =>
      'Cifrado de extremo a extremo · solo red local';

  @override
  String get receiveFavoritesScanHint =>
      'Apunta la cámara al código QR mostrado en el dispositivo del remitente';

  @override
  String get receiveFavoritesScanEncrypted =>
      'La transferencia está cifrada · solo red local';

  @override
  String get receiveFavoritesWaiting =>
      'Esperando a que el remitente escanee el código QR…';

  @override
  String get receiveFavoritesComplete => 'Transferencia completada.';

  @override
  String get receiveFavoritesConnecting => 'Conectando con el remitente…';

  @override
  String get receiveFavoritesConnected => '¡Conectado! Esperando archivos…';

  @override
  String get cancelTransfer => 'Cancelar transferencia';

  @override
  String get wardLinkTitle => 'WardLink';

  @override
  String get wardLinkSubtitle =>
      'Sincronización pasiva entre tus dispositivos en la red local';

  @override
  String get wardLinkEnable => 'Sincronización pasiva';

  @override
  String get wardLinkEnableDesc =>
      'Sincroniza automáticamente con dispositivos de confianza en la misma red. En teléfonos funciona mientras la app está abierta; en el escritorio funciona continuamente.';

  @override
  String get wardLinkPairedDevices => 'Dispositivos de confianza';

  @override
  String get wardLinkNoPairedDevices => 'Aún no hay dispositivos vinculados';

  @override
  String get wardLinkAddDevice => 'Añadir';

  @override
  String get wardLinkRemoveDevice => 'Quitar';

  @override
  String get wardLinkRemoveConfirm =>
      '¿Dejar de sincronizar con este dispositivo?';

  @override
  String get wardLinkFavoritesOnlyNote =>
      'Sincroniza tus favoritos: sus mensajes y multimedia';

  @override
  String get wardLinkMaxFileSize => 'Tamaño máximo de archivo';

  @override
  String get wardLinkPairTitle => 'Vincular dispositivo';

  @override
  String get wardLinkShowCode => 'Mostrar código';

  @override
  String get wardLinkScanCode => 'Escanear código';

  @override
  String get wardLinkShowInstruction =>
      'Abre WardLink en tu otro dispositivo y escanea este código';

  @override
  String get wardLinkScanInstruction =>
      'Apunta la cámara al código WardLink del otro dispositivo';

  @override
  String get wardLinkPairedOk => 'Dispositivo vinculado';

  @override
  String get wardLinkPairFailed => 'Error al vincular';

  @override
  String get wardLinkE2E => 'Cifrado de extremo a extremo · solo LAN';

  @override
  String get wardLinkSyncingNow => 'Sincronizando…';

  @override
  String get wardLinkDone => 'Sincronizado';

  @override
  String get wardLinkCurrentFile => 'Archivo actual';

  @override
  String get wardLinkLog => 'Registro de sincronización';

  @override
  String get wardLinkLogEmpty => 'Aún no hay eventos';

  @override
  String get wardLinkHoldForLog =>
      'Mantén pulsada la burbuja para ver el registro';

  @override
  String get wardLinkUpToDate => 'Actualizado';

  @override
  String syncedFromDevice(String device) {
    return 'Sincronizado desde $device';
  }

  @override
  String get syncedFromUnknownDevice => 'Sincronizado desde otro dispositivo';

  @override
  String wardLinkFilesDone(int n) {
    return 'Archivos transferidos: $n';
  }

  @override
  String get wardLinkNoFilesYet => 'No se han transferido archivos';

  @override
  String wardLinkSyncedAgo(String when) {
    return 'Sincronizado $when';
  }

  @override
  String get wardLinkNeverSynced => 'Aún no sincronizado';

  @override
  String get wardLinkFirewallHintWindows =>
      'Si el teléfono no puede conectar con este PC, permite ONYX en el Firewall de Windows (puerto TCP 47832). ONYX intenta añadir la regla automáticamente; si falla: Firewall de Windows → Avanzado → Reglas de entrada → Nueva regla → Puerto → TCP → 47832.';

  @override
  String get wardLinkFirewallHintMac =>
      'Si el teléfono no puede conectar con este Mac, asegúrate de que el firewall de macOS no bloquea ONYX: Ajustes del sistema → Red → Firewall → Opciones → añadir ONYX.';

  @override
  String get wardLinkFirewallHintLinux =>
      'Si el teléfono no puede conectar, abre el puerto TCP 47832 en tu firewall. Ejemplo: sudo ufw allow 47832/tcp  o  sudo firewall-cmd --add-port=47832/tcp --permanent';

  @override
  String get wardLinkSyncFromBeginning => 'Sincronizar desde el principio';

  @override
  String get wardLinkSyncFromBeginningDesc =>
      'Descarga todo el historial que aún no está en este dispositivo';

  @override
  String get wardLinkSyncPending => 'Sincronización pendiente…';

  @override
  String get wardLinkBubbleVisibility => 'Burbuja de sincronización';

  @override
  String get wardLinkBubbleShowAlways => 'Mostrar siempre';

  @override
  String get wardLinkBubbleShowOnErrors => 'Mostrar solo en caso de error';

  @override
  String get wardLinkBubbleSize => 'Tamaño de la burbuja';

  @override
  String get wardLinkSyncFavoritesToggle => 'Sincronizar favoritos';

  @override
  String get wardLinkSyncFavoritesToggleDesc =>
      'Sincroniza tus favoritos — sus mensajes y multimedia';

  @override
  String get wardLinkSyncPersonalToggle => 'Sincronizar mis mensajes';

  @override
  String get wardLinkSyncIncomingToggle => 'Sync incoming messages';

  @override
  String get pairOverTor => 'Emparejar por Tor';

  @override
  String get addContactQr => 'Añadir contacto · QR';

  @override
  String get contactsTitle => 'Contactos';

  @override
  String get contactsEmpty => 'Aún no hay contactos.';

  @override
  String get myDevicesTitle => 'Mis dispositivos';

  @override
  String get myDevicesThisDevice => 'Este dispositivo';

  @override
  String get myDevicesHint =>
      'Vincula otro dispositivo con «Vincular dispositivo» en su pantalla de inicio de sesión. Cada dispositivo tiene su propia dirección Tor y tus mensajes llegan a todos.';

  @override
  String get myDevicesUnlink => 'Desvincular';

  @override
  String get myDevicesUnlinkConfirm =>
      '¿Desvincular este dispositivo de tu cuenta? Dejará de recibir tus mensajes y tus contactos también lo quitarán.';

  @override
  String contactsRemoveConfirm(String username) {
    return '¿Quitar a $username de tus contactos?';
  }

  @override
  String contactsRemoveDeviceConfirm(String name) {
    return '¿Quitar el emparejamiento con el dispositivo de $name? Su otro dispositivo no se ve afectado.';
  }

  @override
  String get pairScanTitle => 'Escanear su código de emparejamiento';

  @override
  String get pairScanHint =>
      'Apunta la cámara al código QR de emparejamiento de la otra persona';

  @override
  String get pairShowHint =>
      'Pide a la otra persona que escanee este código con su app Onyx';

  @override
  String get pairEncrypted => 'Cifrado de extremo a extremo, directo por Tor';

  @override
  String get pairScanCode => 'Escanear código';

  @override
  String get pairedOverTor => 'Emparejado por Tor';

  @override
  String get pairing => 'Emparejando...';

  @override
  String pairFailedWith(String error) {
    return 'Error al emparejar: $error';
  }

  @override
  String pairStartFailed(String error) {
    return 'No se pudo iniciar Tor: $error';
  }

  @override
  String pairRetry(int attempt, int max) {
    return 'Sigo intentando conectar ($attempt/$max) — su dirección puede estar aún publicándose en Tor...';
  }

  @override
  String get peerShowQr => 'Mostrar QR';

  @override
  String get peerHideQr => 'Ocultar QR';

  @override
  String get peerAddressCopied => 'Dirección copiada';

  @override
  String get wardLinkSyncPersonalToggleDesc =>
      'Sincroniza solo los mensajes que TÚ enviaste en chats personales a tus otros dispositivos';

  @override
  String get meshSubtitle => 'Red mesh sin conexión';

  @override
  String get meshEnable => 'Activar red mesh';

  @override
  String get meshEnableDesc =>
      'Mensajería directa sin internet vía Wi-Fi o Bluetooth.\nSolo funciona en mensajes directos.';

  @override
  String get meshUnavailable =>
      'La red mesh no está disponible en esta plataforma.';

  @override
  String get meshOpenRadar => 'Abrir radar';

  @override
  String meshNearbyCount(int n) {
    return 'Cerca: $n dispositivos';
  }

  @override
  String get meshRadarTitle => 'Radar mesh';

  @override
  String get meshRadarScanning => 'Escaneando…';

  @override
  String get meshRadarSearchHint => 'Buscar por nombre...';

  @override
  String meshRadarSearchEmpty(String q) {
    return 'Sin resultados para \"$q\"';
  }

  @override
  String get meshRadarNoDevices =>
      'No hay dispositivos cerca.\nMesh escanea cada 20 s.';

  @override
  String get meshRadarDisabled =>
      'El modo mesh está desactivado.\nActívalo en Ajustes → Mesh.';

  @override
  String get meshRadarStarting => 'Iniciando escaneo BLE…';

  @override
  String get meshMenuRadar => 'Radar';

  @override
  String get meshMenuDiagnostics => 'Diagnóstico';

  @override
  String get meshMenuModeAuto => 'Automático';

  @override
  String get meshBluetoothOffTitle => 'El Bluetooth está desactivado';

  @override
  String get meshBluetoothOffContent =>
      'El chat mesh se cambió al modo solo Bluetooth, pero el Bluetooth está desactivado. Actívalo en los ajustes del sistema para alcanzar los dispositivos cercanos.';

  @override
  String get meshOpenSystemSettings => 'Abrir ajustes';

  @override
  String get meshModeLabel => 'MODO';

  @override
  String get meshModeActive => 'Modo mesh activo';

  @override
  String get meshChatLabel => 'Chat mesh';

  @override
  String get meshLocationRequired =>
      'Activa los servicios de ubicación para el escaneo BLE (Android ≤11)';

  @override
  String get meshChatEmpty =>
      'Aún no hay mensajes.\nEnvía el primer mensaje mesh.';

  @override
  String get meshChatInputHint => 'Mensaje…';

  @override
  String get meshChatSend => 'Enviar';

  @override
  String get meshChatOutOfRange => 'Fuera de alcance';

  @override
  String get meshStatusSending => 'Enviando…';

  @override
  String get meshStatusSendingWifi => 'Enviando por Wi-Fi…';

  @override
  String get meshStatusSendingBle => 'Enviando por Bluetooth…';

  @override
  String get meshStatusRelayed => 'En tránsito por la red mesh';

  @override
  String get meshStatusDelivered => 'Entregado';

  @override
  String get meshStatusFailed => 'No entregado';

  @override
  String get meshStatusRetry => 'Reintentar';

  @override
  String get meshStatusFailedHint => 'El mensaje no llegó al destinatario';

  @override
  String get meshErrorVideoWifiOnly =>
      'El video solo se puede enviar por Wi-Fi. Conéctate a la misma red Wi-Fi que el destinatario.';

  @override
  String get meshErrorFileTooLargeForBle =>
      'El archivo es demasiado grande para Bluetooth (máx. 10 MB). Conéctate a una red Wi-Fi compartida.';

  @override
  String get meshErrorFileTooLarge =>
      'El archivo es demasiado grande (máx. 200 MB).';

  @override
  String get meshErrorAttachmentsUnsupported =>
      'Los archivos adjuntos solo son compatibles en móvil/escritorio';

  @override
  String get meshErrorPickFileFailed => 'Error al elegir el archivo';

  @override
  String get meshErrorSendFileFailed => 'Error al enviar el archivo';

  @override
  String get meshErrorSendVoiceFailed => 'Error al enviar el mensaje de voz';

  @override
  String meshErrorOutOfRange(String username) {
    return '$username está fuera de alcance';
  }

  @override
  String get backupTitle => 'Copia de seguridad';

  @override
  String get backupSubtitle =>
      'Copia de seguridad y restauración local de tus datos';

  @override
  String get backupExport => 'Guardar todos los datos';

  @override
  String get backupRestore => 'Restaurar desde copia de seguridad';

  @override
  String get backupScope => 'Qué respaldar';

  @override
  String get backupFavorites => 'Chats favoritos';

  @override
  String get backupPersonal => 'Chats personales';

  @override
  String get backupIncludeMedia => 'Incluir multimedia';

  @override
  String get backupMediaImages => 'Imágenes';

  @override
  String get backupMediaVideos => 'Videos';

  @override
  String get backupMediaVoice => 'Voz y audio';

  @override
  String get backupMediaOther => 'Otros archivos';

  @override
  String get backupSchedule => 'Copia de seguridad programada';

  @override
  String get backupFreqOff => 'Desactivada';

  @override
  String get backupFreqDaily => 'Diaria';

  @override
  String get backupFreqWeekly => 'Semanal';

  @override
  String get backupFreqMonthly => 'Mensual';

  @override
  String get backupFolder => 'Carpeta de copia automática';

  @override
  String get backupChangeFolder => 'Cambiar';

  @override
  String get backupLastAuto => 'Última copia automática';

  @override
  String get backupNever => 'nunca';

  @override
  String get backupInProgress => 'Creando copia de seguridad…';

  @override
  String get backupRestoring => 'Restaurando…';

  @override
  String get backupSelectScope => 'Selecciona al menos una categoría';

  @override
  String get backupNoAccount => 'No hay ninguna cuenta activa';

  @override
  String get backupNoPermission =>
      'Acceso al almacenamiento denegado. Concede \"Acceso a todos los archivos\" en los ajustes de la app.';

  @override
  String get backupOpenFolder => 'Abrir carpeta';

  @override
  String get backupFolderUnsupported =>
      'Esta carpeta no es accesible. Elige una carpeta en el almacenamiento interno.';

  @override
  String get backupRestoreConfirmTitle =>
      '¿Restaurar desde copia de seguridad?';

  @override
  String get backupRestoreConfirmBody =>
      'Los datos del archivo se restaurarán sobre tus datos actuales (chats, favoritos, ajustes).';

  @override
  String get backupRestartHint => 'Reinicia la app para ver los cambios';

  @override
  String get recycleBinTitle => 'Papelera';

  @override
  String get recycleBinSubtitle =>
      'Chats eliminados y protección contra eliminaciones accidentales por sincronización';

  @override
  String get recycleBinPendingTitle => 'Solicitudes de eliminación';

  @override
  String recycleBinPendingDesc(String device, int count) {
    return 'El dispositivo \"$device\" quiere eliminar $count chat(s). ¿Aplicar o conservar?';
  }

  @override
  String get recycleBinApply => 'Aplicar eliminación';

  @override
  String get recycleBinKeep => 'Conservar mis chats';

  @override
  String get recycleBinNoPending =>
      'No hay solicitudes de eliminación pendientes';

  @override
  String get recycleBinResetTitle => 'Restablecer registros de eliminación';

  @override
  String get recycleBinResetDesc =>
      'Borra la lista de chats eliminados. La sincronización dejará de volver a eliminarlos en otros dispositivos y podrá restaurarlos.';

  @override
  String get recycleBinResetButton => 'Borrar lista de eliminados';

  @override
  String get recycleBinResetDone => 'Registros de eliminación borrados';

  @override
  String get recycleBinResetConfirm =>
      '¿Borrar todos los registros de eliminación de esta cuenta?';

  @override
  String get accountGraph => 'Gráfico de cuenta';

  @override
  String get accountGraphSubtitleDesktopOn =>
      'Muestra un gráfico de tus chats, grupos y canales cuando no hay ningún chat abierto';

  @override
  String get accountGraphSubtitleMobileOn =>
      'Visualiza tu cuenta en vista planetaria';

  @override
  String get accountGraphSubtitleDesktopOff =>
      'Muestra una sugerencia cuando no hay ningún chat abierto';

  @override
  String get accountGraphSubtitleMobileOff =>
      'El gráfico de cuenta está desactivado';

  @override
  String get orbitSpeed => 'Velocidad orbital';

  @override
  String secOrbit(int s) {
    return '$s s/órbita';
  }

  @override
  String minOrbit(int m) {
    return '$m min/órbita';
  }

  @override
  String get animateGraph => 'Animar';

  @override
  String get animateGraphOn => 'Las órbitas giran en tiempo real';

  @override
  String get animateGraphOff => 'El gráfico está congelado / estático';

  @override
  String get preserveView => 'Conservar vista';

  @override
  String get preserveViewOn =>
      'Mantiene el zoom y la posición al salir de un chat';

  @override
  String get preserveViewOff => 'Vuelve al centro al regresar';

  @override
  String get migrationTitle => 'Migración de almacenamiento';

  @override
  String get migrationBody =>
      'ONYX está pasando a un nuevo motor de almacenamiento de alta velocidad. Los chats y medios cargarán mucho más rápido.';

  @override
  String get migrationAccounts => 'Cuentas';

  @override
  String get migrationDataSize => 'Tamaño de los datos';

  @override
  String get migrationBackupNote =>
      'Se creará una copia de seguridad antes de la migración. La app puede quedar temporalmente sin respuesta durante este proceso.';

  @override
  String get migrationStart => 'Iniciar migración';

  @override
  String get migrationSkip => 'Omitir';

  @override
  String get migrationPhaseBackup => 'Creando copia de seguridad';

  @override
  String get migrationPhaseImport => 'Importando datos';

  @override
  String get migrationPhaseVerify => 'Verificando';

  @override
  String get migrationPhasePreparing => 'Preparando';

  @override
  String get migrationDontClose => 'No cierres la app';

  @override
  String get migrationDoneTitle => '¡Listo!';

  @override
  String get migrationDoneBody =>
      'Almacenamiento actualizado. Se guardó una copia de seguridad en la carpeta Backups.';

  @override
  String get migrationDoneNote =>
      'Una vez que confirmes que todo funciona, puedes eliminarla manualmente.';

  @override
  String get migrationDoneButton => '¡Genial!';

  @override
  String get migrationErrorTitle => 'Error de migración';

  @override
  String get migrationErrorBody =>
      'La app continuará con el sistema anterior. Se reintentará la migración en el próximo inicio.';

  @override
  String get migrationErrorButton => 'Entendido';

  @override
  String get audioTitle => 'Audio';

  @override
  String get audioSubtitle => 'Selección de micrófono y altavoz';

  @override
  String get audioMicInput => 'Micrófono (entrada)';

  @override
  String get audioSpeakerOutput => 'Altavoz (salida)';

  @override
  String get audioSystemDefault => 'Predeterminado del sistema';

  @override
  String get audioChangesNote =>
      'Los cambios surten efecto al unirte al siguiente canal de voz.';

  @override
  String get wardlinkReceive => 'Recibir de dispositivo';

  @override
  String get wardlinkReceiveSubtitle =>
      'Muestra un código QR; el remitente lo escanea';

  @override
  String get wardlinkSend => 'Enviar a dispositivo';

  @override
  String get wardlinkSendSubtitle =>
      'Escanea el código QR mostrado en el receptor';

  @override
  String get react => 'Reaccionar';

  @override
  String get pin => 'Fijar';

  @override
  String get unpin => 'Desfijar';

  @override
  String get copyImage => 'Copiar imagen';

  @override
  String get forward => 'Reenviar';

  @override
  String get showInFileSystem => 'Mostrar en el sistema de archivos';

  @override
  String get saveNotSupportedOnWeb => 'Guardar no es compatible en la web';

  @override
  String get imageNotLoadedYet => 'La imagen aún no se ha cargado';

  @override
  String get voiceNotLoadedYet => 'El audio aún no se ha cargado';

  @override
  String get videoNotLoadedYet => 'El video aún no se ha cargado';

  @override
  String get fileNotLoadedYet => 'El archivo aún no se ha cargado';

  @override
  String get fileNotLoadedOpenFirst =>
      'El archivo no se ha descargado en este dispositivo; tócalo en el chat para descargarlo';

  @override
  String editTimerLabel(int s) {
    return 'Editar  ·  ${s}s';
  }

  @override
  String deleteTimerLabel(int s) {
    return 'Eliminar  ·  ${s}s';
  }

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get newChatSubtitle => 'Crear un nuevo chat favorito';

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get newFolderSubtitle => 'Agrupar chats en una carpeta';

  @override
  String get searchEmoji => 'Buscar emoji…';

  @override
  String get syncCompleted => 'Sincronización completada';

  @override
  String get syncCompletedWithErrors => 'Sincronización completada con errores';

  @override
  String get receivingFiles => 'Recibiendo archivos...';

  @override
  String syncFromUser(String sender) {
    return 'de $sender';
  }

  @override
  String get aboutServer => 'SERVIDOR';

  @override
  String get aboutWhatsNew => 'NOVEDADES';

  @override
  String get aboutConnected => 'Conectado';

  @override
  String get aboutConnecting => 'Conectando...';

  @override
  String get aboutLoadingLocation => 'Cargando...';

  @override
  String get aboutNoReleaseNotes => 'No hay notas de la versión disponibles.';

  @override
  String get aboutCheckForUpdates => 'Buscar actualizaciones';

  @override
  String get aboutChecking => 'Buscando...';

  @override
  String get aboutUpToDate => '¡Estás al día!';

  @override
  String aboutUpdateAvailable(String v) {
    return 'Actualización disponible: $v';
  }

  @override
  String get downloadUpdateTitle => 'Descargar actualización';

  @override
  String get downloadUpdateVersion => 'Versión';

  @override
  String get downloadUpdateWhatsNew => 'NOVEDADES';

  @override
  String get downloadUpdateReady => 'Listo para descargar';

  @override
  String get downloadUpdateDownloading => 'Descargando...';

  @override
  String get downloadUpdateComplete => '¡Descarga completa!';

  @override
  String get downloadUpdateNoPlatform =>
      'No hay descarga disponible para esta plataforma';

  @override
  String get downloadUpdateInstall => 'Descargar e instalar';

  @override
  String get downloadUpdateOpen => 'Abrir';

  @override
  String get downloadUpdateRetry => 'Reintentar';

  @override
  String get downloadUpdateCancel => 'Cancelar descarga';

  @override
  String get editChat => 'Editar chat';

  @override
  String get chatNameLabel => 'Nombre del chat';

  @override
  String get editFolder => 'Editar carpeta';

  @override
  String get folderNameLabel => 'Nombre de la carpeta';

  @override
  String get createChat => 'Nuevo chat';

  @override
  String get profileMessage => 'Mensaje';

  @override
  String get tapAvatarHint =>
      'Toca el avatar para cambiarlo • Mantén pulsado para quitarlo';

  @override
  String get tapAvatarLongRemove =>
      'Toca para cambiar • Mantén pulsado para quitar';

  @override
  String get e2eeWarnTitle => 'Sin cifrado de extremo a extremo';

  @override
  String get e2eeWarnUnderstand => 'Entendido';

  @override
  String get e2eeWarnDoNotShare =>
      'No compartas contraseñas, archivos privados ni información sensible aquí.';

  @override
  String get e2eeWarnGroupBody =>
      'Los mensajes de este grupo no están protegidos por cifrado de extremo a extremo: el servidor puede leerlos.';

  @override
  String get e2eeWarnGroupMedia =>
      'Los archivos multimedia adjuntos se suben a un servicio público (catbox.moe) y son accesibles para cualquiera que tenga el enlace.';

  @override
  String get e2eeWarnExtBody =>
      'Los mensajes de este grupo no están protegidos por cifrado de extremo a extremo: el servidor del propietario del grupo puede leerlos.';

  @override
  String get e2eeWarnExtMedia =>
      'Los archivos multimedia adjuntos se suben y almacenan en el servidor propio del propietario, no en ONYX.';

  @override
  String get e2eeWarnExtOnyxUnrelated =>
      'ONYX no tiene relación con este grupo y no puede moderar ni proteger su contenido.';

  @override
  String get securityLevelTitle => 'Nivel de confianza del dispositivo';

  @override
  String get securityLevelEasy => 'Fácil';

  @override
  String get securityLevelEasyDesc =>
      'Un dispositivo nuevo se considera de confianza inmediatamente tras iniciar sesión. Mínima fricción, pero la contraseña es tu única línea de defensa.';

  @override
  String get securityLevelBalanced => 'Equilibrado';

  @override
  String get securityLevelBalancedDesc =>
      'Cualquier dispositivo ya de confianza puede aprobar uno nuevo. Recomendado para la mayoría de personas.';

  @override
  String get securityLevelStrict => 'Estricto';

  @override
  String get securityLevelStrictDesc =>
      'Un dispositivo nuevo necesita la aprobación de dos dispositivos de confianza distintos.';

  @override
  String get securityLevelLowerRequiresTrusted =>
      'Para bajar el nivel de seguridad se requiere un dispositivo de confianza.';

  @override
  String get securityLevelUpdated => 'Nivel de seguridad actualizado';

  @override
  String get sessionTtlTitle => 'Duración de la sesión';

  @override
  String get sessionTtlSubtitle =>
      'Cuánto tiempo pasa antes de que este dispositivo vuelva a pedir tu contraseña';

  @override
  String get sessionTtlRecommended => 'recomendado';

  @override
  String sessionTtlDays(int days) {
    return '$days días';
  }

  @override
  String get sessionTtlNever => 'Nunca';

  @override
  String get sessionTtlUpdated => 'Duración de la sesión actualizada';

  @override
  String get approvalsProgress => 'Aprobado';

  @override
  String get pendingDeviceTitleSingle => 'Nuevo dispositivo';

  @override
  String pendingDeviceTitleMulti(int count) {
    return 'Nuevos dispositivos ($count)';
  }

  @override
  String get pendingDeviceApprove => 'Aprobar';

  @override
  String get pendingDeviceDeny => 'Denegar';

  @override
  String get recoveryTitle => 'Recuperación de cuenta';

  @override
  String get recoveryBannerText =>
      'Este dispositivo aún no está aprobado. Si no hay ningún dispositivo de confianza disponible, puedes recuperar el acceso con tu contraseña y tu frase de recuperación.';

  @override
  String get recoveryBannerButton => 'Recuperar acceso';

  @override
  String get recoveryIntro =>
      'Introduce tu contraseña y la frase de recuperación de 12 palabras que se te mostró al registrarte. La solicitud no se aplicará de inmediato; tus dispositivos de confianza tendrán un margen para cancelarla si no fuiste tú.';

  @override
  String get recoveryPasswordLabel => 'Contraseña';

  @override
  String get recoveryPassphraseLabel => 'Frase de recuperación (12 palabras)';

  @override
  String get recoverySubmit => 'Enviar solicitud';

  @override
  String get recoveryInvalid => 'Contraseña o frase de recuperación no válida';

  @override
  String get recoveryAlreadyPending => 'Ya hay una solicitud pendiente';

  @override
  String get recoveryPendingTitle => 'Solicitud enviada';

  @override
  String recoveryPendingBody(String when) {
    return 'El acceso se restaurará $when a menos que un dispositivo de confianza cancele la solicitud.';
  }

  @override
  String get recoveryCancelled => 'Solicitud de recuperación cancelada';

  @override
  String get recoveryExecuted =>
      'Acceso restaurado. Vuelve a iniciar sesión para aplicar el cambio.';

  @override
  String get recoveryCancelRequiresTrusted =>
      'Solo un dispositivo de confianza puede cancelar esto. Primero aprueba este dispositivo en Dispositivos activos.';

  @override
  String get recoveryAlertRequestedTitle =>
      'Alguien solicitó la recuperación de la cuenta';

  @override
  String recoveryAlertRequestedBody(String deviceName, String when) {
    return 'El dispositivo \"$deviceName\" solicitó la recuperación de la cuenta. Si no fuiste tú, cancélalo ahora. De lo contrario, entrará en vigor $when.';
  }

  @override
  String get recoveryAlertCancelButton => 'Cancelar';

  @override
  String get recoveryAlertIgnoreButton => 'Soy yo, ignorar';

  @override
  String get recoveryAlertFailedTitle => 'Intento de recuperación fallido';

  @override
  String get recoveryAlertFailedBody =>
      'Alguien intentó recuperar el acceso a tu cuenta pero introdujo una contraseña o frase de recuperación incorrecta.';

  @override
  String get recoveryAlertExecutedTitle => 'Recuperación completada';

  @override
  String get recoveryAlertExecutedBody =>
      'La solicitud de recuperación entró en vigor: la cuenta tiene un nuevo dispositivo principal. Si no fuiste tú, revoca de inmediato la sesión desconocida en Dispositivos activos.';

  @override
  String get wardLinkSyncSettingsTitle => 'Ajustes de sincronización';

  @override
  String get wardLinkSyncSettingsSubtitle =>
      'Límite de tamaño de archivo y notificaciones de burbuja';

  @override
  String get wardLinkPairedDevicesSubtitle =>
      'Añade y gestiona dispositivos vinculados';

  @override
  String get notifGeneralTitle => 'General';

  @override
  String get notifGeneralSubtitle =>
      'Activar notificaciones y visibilidad del contenido';

  @override
  String get notifSoundSubtitle => 'Sonido de notificación y archivo de audio';

  @override
  String get notifAdvancedTitle => 'Avanzado';

  @override
  String get notifAdvancedSubtitle =>
      'Comportamiento al iniciar y posición del aviso emergente';

  @override
  String get securityPrivacyTitle => 'Privacidad';

  @override
  String get securityPrivacySubtitle => 'Ajustes de visibilidad y búsqueda';

  @override
  String get cacheStorageTitle => 'Almacenamiento';

  @override
  String get cacheStorageSubtitle =>
      'Caché de multimedia y limpieza de archivos sin usar';

  @override
  String get connectionServerTitle => 'Conexión al servidor';

  @override
  String get connectionServerSubtitle =>
      'Conectar o desconectar del servidor WebSocket';

  @override
  String get interactPerformanceTitle => 'Rendimiento';

  @override
  String get interactPerformanceSubtitle =>
      'Búfer de desplazamiento y ventana de precarga de imágenes';

  @override
  String get interactFilesTitle => 'Archivos y almacenamiento';

  @override
  String get interactFilesSubtitle =>
      'Carpeta de descargas y gestión de datos de la app';

  @override
  String get appearanceChatDisplayTitle => 'Visualización del chat';

  @override
  String get appearanceChatDisplaySubtitle =>
      'Alineación, avatares y animaciones';

  @override
  String get appearanceLayoutTitle => 'Diseño';

  @override
  String get appearanceLayoutSubtitle =>
      'Navegación, gráfico y deslizamiento de pestañas';

  @override
  String get appearanceLiquidGlassTitle => 'Efectos de cristal líquido';

  @override
  String get trashChatsTitle => 'Chats eliminados';

  @override
  String get trashChatsSubtitle => 'Restaurar o eliminar chats permanentemente';

  @override
  String get trashMessagesTitle => 'Mensajes eliminados';

  @override
  String get trashMessagesSubtitle =>
      'Restaurar o eliminar mensajes permanentemente';

  @override
  String get download => 'Descargar';

  @override
  String get retry => 'Reintentar';

  @override
  String get refresh => 'Actualizar';

  @override
  String get revoke => 'Revocar';

  @override
  String get setup => 'Configurar';

  @override
  String get current => 'Actual';

  @override
  String get select => 'Seleccionar';

  @override
  String get token => 'Token';

  @override
  String get always => 'Siempre';

  @override
  String favRemoveFromFolderNamed(String folderName) {
    return 'Quitar de \"$folderName\"';
  }

  @override
  String get favMoveToFolder => 'Mover a carpeta';

  @override
  String get favRemoveFromFolder => 'Quitar de la carpeta';

  @override
  String get favUnlock => 'Desbloquear';

  @override
  String get favLock => 'Bloquear';

  @override
  String get favUnlockFolder => 'Desbloquear carpeta';

  @override
  String get favLockFolder => 'Bloquear carpeta';

  @override
  String favChatsCount(int n) {
    return '$n chats';
  }

  @override
  String get favNewFolder => 'Nueva carpeta';

  @override
  String get favChatsMovedToTopLevel =>
      'Los chats se moverán al nivel superior';

  @override
  String get favDeleteChatQuestion => '¿Eliminar chat?';

  @override
  String get favRemoveAvatarQuestion => '¿Quitar avatar?';

  @override
  String get favSelectedRemovedFromFavorites =>
      'Los mensajes seleccionados se eliminarán de favoritos.';

  @override
  String get favDeleteMessageQuestion => '¿Eliminar mensaje?';

  @override
  String get favMessageRemovedFromFavorites =>
      'Este mensaje se eliminará de favoritos.';

  @override
  String get favDeleteAvatarQuestion => '¿Eliminar avatar?';

  @override
  String get favRemoveAvatarConfirm => 'Esto eliminará este avatar favorito.';

  @override
  String get sendAlbum => 'Enviar álbum';

  @override
  String get sendAlbums => 'Enviar álbumes';

  @override
  String get sendAllMedia => 'Enviar todo';

  @override
  String get setAsWallpaper => 'Establecer como fondo de pantalla';

  @override
  String get sendVoice => 'Enviar voz';

  @override
  String get cropAndUpload => 'Recortar y subir';

  @override
  String get deleteMessagesQuestion => '¿Eliminar mensajes?';

  @override
  String get connectionDiagnostics => 'Diagnóstico de conexión';

  @override
  String get voiceChannels => 'Canales de voz';

  @override
  String get forwardMessage => 'Reenviar mensaje';

  @override
  String get noChats => 'Sin chats';

  @override
  String get noGroups => 'Sin grupos';

  @override
  String get noFavorites => 'Sin favoritos';

  @override
  String get wifiOnlyOption => 'Solo Wi-Fi';

  @override
  String get emptyTrash => 'Vaciar papelera';

  @override
  String get performanceReport => 'Informe de rendimiento';

  @override
  String get revokeSessionQuestion => '¿Revocar sesión?';

  @override
  String get revokeSessionConfirm =>
      'Este dispositivo cerrará sesión de inmediato.';

  @override
  String get failedToRevokeSession => 'Error al revocar la sesión';

  @override
  String get failedToApproveDevice => 'Error al aprobar el dispositivo';

  @override
  String get noActiveSessionsFound => 'No se encontraron sesiones activas';

  @override
  String get quotaExceeded => 'Cuota excedida';

  @override
  String get openSettingsAction => 'Abrir ajustes';

  @override
  String get trashIsEmpty => 'La papelera está vacía';

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
      other: ' Se borraron $n cachés de medios',
      one: ' Se borró $n caché de medios',
    );
    return '$_temp0';
  }

  @override
  String leaveGroupTitle(String isChannel) {
    String _temp0 = intl.Intl.selectLogic(
      isChannel,
      {
        'true': 'l canal',
        'other': 'l grupo',
      },
    );
    return '¿Salir de$_temp0?';
  }

  @override
  String cacheFilesDeleted(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se eliminaron $n archivos',
      one: 'Se eliminó $n archivo',
    );
    return '$_temp0';
  }

  @override
  String orphanedCleanupDeleted(int files, String freedMb) {
    String _temp0 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: 'Se eliminaron $files archivos sin usar',
      one: 'Se eliminó $files archivo sin usar',
    );
    return '$_temp0 ($freedMb MB liberados)';
  }

  @override
  String deletedLogsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se eliminaron $n archivos de registro.',
      one: 'Se eliminó $n archivo de registro.',
    );
    return '$_temp0';
  }

  @override
  String notifEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'Se te avisará de los mensajes nuevos',
        'other': 'Todas las notificaciones están silenciadas',
      },
    );
    return '$_temp0';
  }

  @override
  String notifHideContentSubtitle(String hidden) {
    String _temp0 = intl.Intl.selectLogic(
      hidden,
      {
        'true': 'Notificaciones sin texto del mensaje',
        'other': 'Mostrar el texto del mensaje en las notificaciones',
      },
    );
    return '$_temp0';
  }

  @override
  String notifSoundEnabledSubtitle(String enabled) {
    String _temp0 = intl.Intl.selectLogic(
      enabled,
      {
        'true': 'Sonido activado',
        'other': 'Sonido desactivado',
      },
    );
    return '$_temp0';
  }

  @override
  String sessionExpiresInDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'La sesión expira en $n días',
      one: 'La sesión expira en $n día',
    );
    return '$_temp0';
  }

  @override
  String sessionExpiresInHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'La sesión expira en $n horas',
      one: 'La sesión expira en $n hora',
    );
    return '$_temp0';
  }

  @override
  String sessionActiveForDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'La sesión es válida por $n días más',
      one: 'La sesión es válida por $n día más',
    );
    return '$_temp0';
  }

  @override
  String meshRadarFound(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n dispositivos al alcance',
      one: '$n dispositivo al alcance',
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
      other: '$messages mensajes',
      one: '$messages mensaje',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get muteAction => 'Silenciar';

  @override
  String get unmuteAction => 'Reactivar';

  @override
  String muteUserTitle(String name) {
    return 'Silenciar a $name';
  }

  @override
  String get durationLabel => 'Duración';

  @override
  String get duration15Min => '15 min';

  @override
  String get duration1Hour => '1 hora';

  @override
  String get duration1Day => '1 día';

  @override
  String get duration1Week => '1 semana';

  @override
  String get muteReasonLabel => 'Motivo (opcional)';

  @override
  String userMuted(String name) {
    return '$name silenciado';
  }

  @override
  String get failedMute => 'Error al silenciar';

  @override
  String failedMuteUser(String name) {
    return 'Error al silenciar a $name';
  }

  @override
  String get mutedUsersTitle => 'Usuarios silenciados';

  @override
  String get noMutedUsers => 'No hay usuarios silenciados';

  @override
  String mutedByLabel(String name) {
    return 'Silenciado por: $name';
  }

  @override
  String mutedUntilLabel(String date) {
    return 'Hasta: $date';
  }

  @override
  String userUnmuted(String name) {
    return '$name ya no está silenciado';
  }

  @override
  String get failedUnmute => 'Error al reactivar';

  @override
  String failedUnmuteUser(String name) {
    return 'Error al reactivar a $name';
  }

  @override
  String get youAreMutedTitle => 'Estás silenciado';

  @override
  String mutedUntilMessage(String date) {
    return 'No puedes enviar mensajes en este chat hasta $date.';
  }

  @override
  String get slowModeLabel => 'Modo lento (segundos, 0 = desactivado)';

  @override
  String get slowModeHelper =>
      'Retraso mínimo entre mensajes para miembros normales. No afecta a los administradores.';

  @override
  String slowModeSetTo(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Modo lento fijado en $seconds segundos',
      one: 'Modo lento fijado en $seconds segundo',
    );
    return '$_temp0';
  }

  @override
  String get slowModeDisabled => 'Modo lento desactivado';

  @override
  String get failedSetSlowMode => 'Error al activar el modo lento';

  @override
  String get failedUpdateSlowMode => 'Error al actualizar el modo lento';

  @override
  String get donateMenuLabel => 'Donar';

  @override
  String get pollsMenuLabel => 'Encuestas';

  @override
  String get supportThisCommunityTitle => 'Apoya a esta comunidad';

  @override
  String get donationDisclaimer =>
      'ONYX no procesa estos pagos ni puede reembolsarlos. Envía cripto solo a direcciones en las que confíes.';

  @override
  String get noDonationsOwnerHint =>
      'Aún no hay direcciones de donación. Toca «Editar» para agregar.';

  @override
  String get noDonationsMemberHint =>
      'Esta comunidad aún no ha configurado donaciones.';

  @override
  String get editDonationsTitle => 'Editar direcciones de donación';

  @override
  String get donationCoinLabel => 'Moneda (p. ej. BTC)';

  @override
  String get donationAddressLabel => 'Dirección';

  @override
  String get addDonationAddress => 'Agregar dirección';

  @override
  String get donationsSaved => 'Direcciones de donación guardadas';

  @override
  String get failedSaveDonations =>
      'Error al guardar las direcciones de donación';

  @override
  String get noPollsOwnerHint =>
      'Aún no hay encuestas. Toca «Nueva encuesta» para crear una.';

  @override
  String get noPollsHint => 'Aún no hay encuestas.';

  @override
  String get newPollAction => 'Nueva encuesta';

  @override
  String get addPollOption => 'Agregar opción';

  @override
  String get pollQuestionLabel => 'Pregunta';

  @override
  String pollOptionLabel(int number) {
    return 'Opción $number';
  }

  @override
  String get multipleChoiceLabel => 'Selección múltiple';

  @override
  String get pollQuestionEmpty => 'La pregunta no puede estar vacía';

  @override
  String get pollNeedsTwoOptions => 'Agrega al menos 2 opciones';

  @override
  String get failedCreatePoll => 'Error al crear la encuesta';

  @override
  String get failedVote => 'Error al enviar el voto';

  @override
  String pollVoteCountAnonymous(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '$count voto',
    );
    return '$_temp0 • anónimo';
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

  @override
  String get onionRetryWaiting => 'Sin conexión · se enviará al conectar';

  @override
  String onionRetryNow(int n) {
    return 'Enviando… (intento n.º $n)';
  }

  @override
  String onionRetryIn(int n, int s) {
    return 'Sin conexión · reintento n.º $n en $s s';
  }

  @override
  String get onionOfflineTitle => 'El contacto no está en línea';

  @override
  String onionOfflineMessage(int seconds) {
    return 'Tu mensaje no se pudo entregar ahora porque tu contacto no está en línea. Se guardó en este dispositivo y se reenviará automáticamente cada $seconds segundos hasta que se conecte. Mantén la app abierta para que continúen los reintentos.\n\nPuedes cambiar el intervalo en Ajustes → Interacción → Mensajes.';
  }

  @override
  String get messagesSectionTitle => 'Mensajes';

  @override
  String get messagesSectionSubtitle =>
      'Reintentos de entrega cuando un contacto está desconectado';

  @override
  String get retryIntervalTitle => 'Intervalo de reintento';

  @override
  String get retryIntervalDesc =>
      'Cuando un contacto no está en línea, los mensajes no entregados se reenvían automáticamente con este intervalo hasta que lleguen.';

  @override
  String intervalSeconds(int n) {
    return '$n segundos';
  }

  @override
  String intervalMinutes(int n) {
    return '$n min';
  }

  @override
  String get statusOnlineLabel => 'en línea';

  @override
  String get statusOfflineLabel => 'desconectado';

  @override
  String get statusConnectingLabel => 'conectando…';

  @override
  String get onionCallTitle => 'Llamada por Tor';

  @override
  String get onionCallHideIp => 'No revelar mi dirección IP';

  @override
  String get onionCallHideIpHint =>
      'La llamada va por Tor: tu dirección IP queda oculta, pero habrá un retraso de alrededor de un segundo. El vídeo no está disponible.';

  @override
  String get onionCallDirectHint =>
      'Menos retraso, pero la otra persona verá tu dirección IP. Solo habrá conexión directa si ella también lo permite; si no, la llamada irá igualmente por Tor.';

  @override
  String get onionCallStart => 'Llamar';

  @override
  String get onionCallPeerOffline =>
      'El contacto no está conectado — ahora no se puede llamar';

  @override
  String get onionCallNoAnswer => 'Sin respuesta';

  @override
  String get onionCallFailed =>
      'No se pudo establecer la conexión de la llamada';

  @override
  String get callIncomingTitle => 'Llamada entrante';

  @override
  String get callAccept => 'Aceptar';

  @override
  String get callDecline => 'Rechazar';

  @override
  String get callLogOutgoing => 'Llamada saliente';

  @override
  String get callLogIncoming => 'Llamada entrante';

  @override
  String get callLogMissed => 'Llamada perdida';

  @override
  String get callLogCancelled => 'Llamada cancelada';

  @override
  String get callLogDeclined => 'Llamada rechazada';

  @override
  String get callLogBusy => 'Línea ocupada';

  @override
  String get callLogNoAnswer => 'Sin respuesta';

  @override
  String get callStatusCalling => 'Llamando';

  @override
  String get callStatusConnecting => 'Conectando';

  @override
  String get callPathRelay => 'A través del servidor';

  @override
  String get callEnd => 'Colgar';

  @override
  String get callMinimize => 'Minimizar';

  @override
  String get callRestore => 'Abrir llamada';

  @override
  String get callFallbackName => 'Llamada';

  @override
  String contactRequestNew(String name) {
    return '$name quiere chatear contigo';
  }

  @override
  String get contactRequestsEntry => 'Solicitudes de contacto';

  @override
  String get contactRequestsTitle => 'Solicitudes';

  @override
  String get contactRequestsEmpty => 'No hay solicitudes';

  @override
  String get contactRequestAccept => 'Aceptar';

  @override
  String get contactRequestDecline => 'Rechazar';

  @override
  String get contactRequestDeclineTitle => '¿Rechazar la solicitud?';

  @override
  String get contactRequestDeclineBody =>
      'Esta persona ya no podrá escribirte ni enviarte nuevas solicitudes. Más adelante podrás añadirla tú.';

  @override
  String get contactRequestNoMessages => 'Sin comentario';

  @override
  String contactRequestNameClash(String username) {
    return 'Ya tienes un contacto @$username con otra clave. Puede ser su nuevo dispositivo, o alguien que se hace pasar por él. Acepta solo si estás seguro.';
  }

  @override
  String get contactRequestInfo =>
      'Hasta que aceptes, no puede ver cuándo estás en línea, ni tu perfil, ni llamarte.';

  @override
  String get contactRequestAddress => 'Dirección onion';

  @override
  String get contactRequestKey => 'Huella de la clave';

  @override
  String contactRequestAccepted(String name) {
    return '$name añadido a contactos';
  }

  @override
  String get contactRequestFileHidden =>
      'Archivo (no se acepta de desconocidos)';

  @override
  String get contactRequestMessages => 'Mensajes';

  @override
  String get forwardDone => 'Mensaje reenviado';

  @override
  String get forwardFileUnavailable =>
      'El archivo no está en este dispositivo, no se puede reenviar';

  @override
  String get contactRequestDeclineChoiceBody =>
      'Rechazar: la solicitud desaparece, pero podrá enviar otra más adelante. Rechazar y bloquear: nunca más podrá escribirte ni enviarte solicitudes.';

  @override
  String get contactRequestDeclineAndBlock => 'Rechazar y bloquear';

  @override
  String get blockedFromRequests => 'solicitud bloqueada';

  @override
  String get contactRequestComposeTitle => 'Solicitud de contacto';

  @override
  String contactRequestComposeBody(String name) {
    return 'Añade un comentario a tu solicitud — $name lo verá en sus solicitudes. Podréis escribiros cuando la acepte.';
  }

  @override
  String get contactRequestComposeHint => 'Comentario…';

  @override
  String get contactRequestSend => 'Enviar solicitud';

  @override
  String get contactRequestSkip => 'Sin comentario';

  @override
  String get contactRequestSent => 'Solicitud enviada';

  @override
  String get contactRequestAttached => 'Comentario de la solicitud';

  @override
  String get contactRequestPendingSnack =>
      'Tu solicitud aún no fue aceptada — podrás escribir después.';

  @override
  String get contactRequestPendingCall =>
      'Podrás llamar cuando acepte tu solicitud';

  @override
  String get contactRequestQueued =>
      'Está desconectado — la solicitud se enviará en cuanto se conecte';

  @override
  String contactRequestDelivered(String name) {
    return 'Tu solicitud a $name fue entregada';
  }

  @override
  String get contactRequestResend => 'Volver a enviar la solicitud';

  @override
  String get contactRequestUpdated => 'Solicitud actualizada';

  @override
  String get contactRecordAcceptedBoth => 'Solicitud de contacto aceptada';

  @override
  String get contactRequestAlreadySent =>
      'Ya enviaste una solicitud — está esperando aprobación';

  @override
  String get contactRequestAlreadySentShort => 'Solicitud ya enviada';

  @override
  String get contactRecordAccepted => 'Aceptaste la solicitud de contacto';

  @override
  String get contactRecordAcceptedByThem =>
      'Tu solicitud de contacto fue aceptada';

  @override
  String get contactRecordPreview => 'Contacto añadido';

  @override
  String contactRequestAcceptedByThem(String name) {
    return '$name aceptó tu solicitud';
  }

  @override
  String get searchOnionHint =>
      'Pega una dirección xxxx.onion para enviar una solicitud';

  @override
  String get searchNeedOnionAddress =>
      'No es una dirección onion — pega una del tipo xxxx.onion';

  @override
  String get searchConnectingTor => 'Conectando por Tor…';

  @override
  String searchStillTrying(int attempt, int max) {
    return 'Seguimos intentando conectar ($attempt/$max)…';
  }

  @override
  String get contactRemovedYou =>
      'Ya no estás en los contactos de esta persona — el mensaje no se puede entregar';

  @override
  String get contactNotInContacts =>
      'Esta persona no está en tus contactos — el mensaje no se envió';

  @override
  String get contactRequestCommentFailed =>
      'Solicitud enviada, pero el comentario no llegó — se desconectó';

  @override
  String get callMute => 'Silenciar';

  @override
  String get callVideo => 'Vídeo';

  @override
  String get callSpeaker => 'Altavoz';

  @override
  String get callPathDirect => 'Conexión directa';

  @override
  String get callPathTor => 'Por Tor';

  @override
  String get callVideoUnavailable =>
      'Conexión demasiado débil — vídeo no disponible';

  @override
  String get callVideoPaused =>
      'Vídeo desactivado porque la conexión se debilitó';

  @override
  String get statusShowMyStatus => 'Mostrar mi estado en línea';

  @override
  String get statusShowMyStatusHint =>
      'Tus contactos ven cuándo estás en línea. Si está desactivado, no ven nada.';

  @override
  String get viewCircuitTitle => 'Ver circuito';

  @override
  String get viewCircuitSubtitle =>
      'Los repetidores Tor por los que se enruta tu tráfico ahora mismo';

  @override
  String get viewCircuitEmpty =>
      'Aún no hay circuitos activos. Inténtalo de nuevo en un momento.';

  @override
  String get circuitThisDevice => 'Este dispositivo';

  @override
  String get circuitRoleGuard => 'guardián';

  @override
  String get circuitRoleIntro => 'punto de introducción';

  @override
  String get circuitRoleRend => 'punto de encuentro';

  @override
  String get circuitUnknownRelay => 'Repetidor desconocido';

  @override
  String get circuitOnionRelay => 'Repetidor del servicio onion';

  @override
  String get circuitModeSimple => 'Simple';

  @override
  String get circuitModeAdvanced => 'Avanzado';

  @override
  String get mediaSendFileTitle => 'Enviar archivo';

  @override
  String get mediaSendFileDetails => 'DETALLES DEL ARCHIVO';

  @override
  String get mediaSendAlbumHeading => 'ÁLBUM';

  @override
  String get mediaSendName => 'Nombre';

  @override
  String get mediaSendSize => 'Tamaño';

  @override
  String get mediaSendType => 'Tipo';

  @override
  String get mediaSendUnknown => 'Desconocido';

  @override
  String get mediaSendImagesLabel => 'Imágenes';

  @override
  String mediaSendImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imágenes',
      one: '1 imagen',
    );
    return '$_temp0';
  }

  @override
  String get mediaSendConfirmAlbum =>
      '¿Seguro que quieres enviar estas imágenes como álbum?';

  @override
  String get mediaSendConfirmFile => '¿Seguro que quieres enviar este archivo?';

  @override
  String get mediaSendVoiceTitle => 'Enviar mensaje de voz';

  @override
  String get mediaSendVoiceHeading => 'MENSAJE DE VOZ';

  @override
  String get mediaSendDuration => 'Duración';

  @override
  String get mediaSendConfirmVoice => '¿Enviar este mensaje de voz?';

  @override
  String get glassSimpleTitle => 'Ajustes del cristal';

  @override
  String get glassSimpleDesc =>
      'Un único conjunto de valores para la barra de navegación, la barra de entrada, la búsqueda y los botones de la barra superior';

  @override
  String get glassResetAll => 'Restablecer todo';

  @override
  String favDeleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $count chats?',
      one: '¿Eliminar 1 chat?',
    );
    return '$_temp0';
  }

  @override
  String get favDeleteSelectedMessage =>
      'Los chats seleccionados y todos sus mensajes se eliminarán de favoritos.';

  @override
  String get glassMasterTitle => 'Efectos Liquid Glass';

  @override
  String get glassMasterDesc =>
      'Activa o desactiva todos los efectos de cristal';

  @override
  String get glassTabGeneral => 'General';

  @override
  String get glassTabAdvanced => 'Avanzado';

  @override
  String get glassBlur => 'Desenfoque';

  @override
  String get glassBlurDesc =>
      'Intensidad del desenfoque esmerilado detrás del cristal';

  @override
  String get glassTint => 'Tinte';

  @override
  String get glassTintDesc =>
      'Opacidad de la tinta adaptativa (oscuro/claro automático)';

  @override
  String get glassSaturation => 'Saturación';

  @override
  String get glassSaturationDesc => 'Viveza del color tomada del fondo';

  @override
  String get glassChromatic => 'Aberración cromática';

  @override
  String get glassChromaticDesc =>
      'Bordes de color en los extremos del cristal (efecto lente)';

  @override
  String get glassRefractive => 'Índice de refracción';

  @override
  String get glassRefractiveDesc =>
      'Cuánto desvía el cristal la luz que hay detrás';

  @override
  String get glassLight => 'Intensidad de la luz';

  @override
  String get glassLightDesc => 'Fuerza del brillo especular sobre el cristal';

  @override
  String get glassThickness => 'Grosor';

  @override
  String get glassThicknessDesc =>
      'Profundidad del cristal: afecta a la refracción y al brillo de los bordes';

  @override
  String get glassJelly => 'Cantidad de estiramiento gelatinoso';

  @override
  String get glassJellyDesc =>
      'Expansión del indicador al arrastrar entre pestañas';

  @override
  String get glassQualityTitle => 'Calidad del cristal';

  @override
  String get glassQualityFast => 'Rápido';

  @override
  String get glassQualityFastDesc => 'Ligero\nMejor rendimiento';

  @override
  String get glassQualityMedium => 'Medio';

  @override
  String get glassQualityMediumDesc => 'Sin shaders\nSolo desenfoque';

  @override
  String get glassQualityHigh => 'Calidad';

  @override
  String get glassQualityHighDesc => 'Shaders completos\nMejor aspecto';
}
