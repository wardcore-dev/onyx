// Small runtime key->text lookup helpers that don't fit the ARB placeholder
// model (they translate arbitrary English string keys computed elsewhere in
// the app, e.g. enum-like values, not fixed UI copy). Kept as a plain
// extension on the generated AppLocalizations class so call sites are
// unaffected by the ARB/gen-l10n migration.
import 'app_localizations.dart';

extension AppLocalizationsExtra on AppLocalizations {
  bool get _ru => localeName == 'ru';

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
}
