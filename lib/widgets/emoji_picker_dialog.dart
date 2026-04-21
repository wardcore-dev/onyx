// lib/widgets/emoji_picker_dialog.dart
import 'package:flutter/material.dart';
import '../managers/settings_manager.dart';

// ─── Emoji data ───────────────────────────────────────────────────────────────

class _EmojiCategory {
  final String label;
  final IconData icon;
  final List<String> emojis;
  const _EmojiCategory(this.label, this.icon, this.emojis);
}

const List<String> _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

final List<_EmojiCategory> _categories = [
  _EmojiCategory('Smileys', Icons.sentiment_satisfied_alt, [
    '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃','😉','😊','😇',
    '🥰','😍','🤩','😘','😗','😚','😙','🥲','😋','😛','😜','🤪','😝',
    '🤑','🤗','🤭','🤫','🤔','🤐','🤨','😐','😑','😶','😏','😒','🙄',
    '😬','🤥','😌','😔','😪','🤤','😴','😷','🤒','🤕','🤢','🤮','🤧',
    '🥵','🥶','🥴','😵','🤯','🤠','🥳','🥸','😎','🤓','🧐','😕','😟',
    '🙁','☹️','😮','😯','😲','😳','🥺','😦','😧','😨','😰','😥','😢',
    '😭','😱','😖','😣','😞','😓','😩','😫','🥱','😤','😡','😠','🤬',
    '😈','👿','💀','☠️','💩','🤡','👹','👺','👻','👽','👾','🤖',
    '😺','😸','😹','😻','😼','😽','🙀','😿','😾',
  ]),
  _EmojiCategory('People', Icons.people_alt_outlined, [
    '👋','🤚','🖐️','✋','🖖','👌','🤌','🤏','✌️','🤞','🤟','🤘','🤙',
    '👈','👉','👆','👇','☝️','👍','👎','✊','👊','🤛','🤜','👏','🙌',
    '👐','🤲','🤝','🙏','✍️','💅','🤳','💪','🦾','🦵','🦶','👂','🦻',
    '👃','🧠','🫀','🫁','🦷','🦴','👁️','👀','👅','💋','🫦','👤','👥',
    '🧑','👶','🧒','👦','👧','🧔','👱','👩','🧓','👴','👵','🙍','🙎',
    '🙅','🙆','💁','🙋','🧏','🙇','🤦','🤷','💆','💇','🚶','🧍','🧎',
    '🏃','💃','🕺','🕴️','👫','👬','👭','👨‍👩‍👦','👨‍👩‍👧','👪',
  ]),
  _EmojiCategory('Animals', Icons.pets, [
    '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷',
    '🐸','🐙','🐧','🐦','🦅','🦆','🦢','🦉','🦩','🦚','🦜','🐺','🐗',
    '🐴','🦄','🐝','🪱','🐛','🦋','🐌','🐞','🐜','🪲','🦟','🦗','🕷️',
    '🦂','🐢','🐍','🦎','🦖','🦕','🐊','🦏','🦛','🦍','🦧','🦣','🐘',
    '🐪','🐫','🦒','🦘','🦬','🐃','🐂','🐄','🦌','🐎','🐖','🐏','🐑',
    '🦙','🐐','🐕','🐩','🐈','🐓','🦃','🐇','🦝','🦨','🦡','🦫','🦦',
    '🦥','🐁','🐀','🦔','🌸','🌺','🌻','🌹','🌷','🌼','🍀','🌿','🌱',
    '🌾','🍁','🍂','🍃','🍄','🌵','🎄','🌲','🌳','🌴','🌊','🌀','🌈',
  ]),
  _EmojiCategory('Food', Icons.restaurant, [
    '🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🍒','🍑','🥭','🍍','🥥',
    '🥝','🍅','🫒','🥑','🍆','🥔','🥕','🌽','🌶️','🫑','🥦','🥬','🥒',
    '🧄','🧅','🌰','🍞','🥐','🥖','🫓','🥨','🧀','🥚','🍳','🧈','🥞',
    '🧇','🥓','🥩','🍗','🍖','🌭','🍔','🍟','🍕','🫔','🌮','🌯','🥙',
    '🧆','🍜','🍝','🍛','🍲','🫕','🍣','🍱','🥟','🦪','🍤','🍙','🍚',
    '🍘','🍥','🥮','🍡','🧁','🍰','🎂','🍮','🍭','🍬','🍫','🍿','🍩',
    '🍪','🍦','🍧','🍨','🥧','☕','🍵','🫖','🧃','🥤','🧋','🍺','🍻',
    '🥂','🍷','🥃','🍸','🍹','🧉','🍾','🧊',
  ]),
  _EmojiCategory('Travel', Icons.flight, [
    '🚀','🛸','🚁','🛶','⛵','🚤','🛥️','🚢','✈️','🛩️','🚂','🚃','🚄',
    '🚅','🚆','🚇','🚊','🚝','🚞','🚋','🚌','🚍','🚎','🚐','🚑','🚒',
    '🚓','🚔','🚕','🚖','🚗','🚘','🚙','🛻','🚚','🚛','🚜','🏎️','🏍️',
    '🛵','🚲','🛴','🛹','🛼','🏔️','⛰️','🌋','🗻','🏕️','🏖️','🏜️',
    '🏝️','🏞️','🏟️','🏛️','🏗️','🏘️','🏚️','🏠','🏡','🏢','🏣','🏤',
    '🏥','🏦','🏨','🏩','🏪','🏫','🏬','🏭','🏯','🏰','💒','🗼','🗽',
    '⛪','🕌','🛕','⛩️','🕍','⛲','⛺','🌁','🌃','🏙️','🌄','🌅',
    '🌆','🌇','🌉','🎠','🎡','🎢','🎪','🗺️','🧭','🌍','🌎','🌏',
  ]),
  _EmojiCategory('Activities', Icons.sports_soccer, [
    '⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🥏','🎱','🪀','🏓','🏸',
    '🏒','🏑','🥍','🏏','🪃','🥅','⛳','🪁','🎣','🤿','🎽','🎿','🛷',
    '🥌','🎯','🎮','🕹️','🎲','♟️','🎭','🎨','🎬','🎤','🎧','🎼','🎹',
    '🥁','🪘','🎷','🎺','🎸','🎻','🪕','🎙️','🎵','🎶','🎤','🎧',
    '🏅','🥇','🥈','🥉','🏆','🥊','🥋','🛡️','🤺','⛷️','🏂','🪂',
    '🏋️','🤼','🤸','🤺','🏊','🤽','🚣','🧗','🚵','🚴','🤸','🤾',
    '🏌️','🏇','🧘','🛀','🛌',
  ]),
  _EmojiCategory('Objects', Icons.lightbulb_outline, [
    '📱','💻','🖥️','🖨️','⌨️','🖱️','🖲️','💿','📺','📷','📸','📹',
    '🎥','📽️','🎞️','📞','☎️','📟','📠','📡','🔋','🪫','🔌','💡',
    '🔦','🕯️','🪔','📔','📕','📖','📗','📘','📙','📚','📓','📃','📄',
    '📑','🗒️','🗓️','📊','📈','📉','🗃️','🗳️','🗂️','🗄️','🗑️',
    '📥','📤','📦','📫','📪','📬','📭','📮','🗳️','✏️','✒️','🖋️','🖊️',
    '📝','🔍','🔎','🔏','🔐','🔒','🔓','🔑','🗝️','🔨','🪓','⛏️',
    '⚒️','🛠️','🗡️','⚔️','🔫','🪃','🏹','🛡️','🪚','🔧','🪛','🔩',
    '⚙️','🗜️','⚖️','🪝','🔗','⛓️','🪤','🧲','🪜','🧰','🪤','🎈',
    '🎉','🎊','🎀','🎁','🎗️','🎟️','🎫','🎖️','🏷️','📫','💌','📧',
    '🗺️','🧭','🕰️','⏰','⏱️','⏲️','🕛','💰','💴','💵','💶','💷',
    '💸','💳','🪙','💎','🔮','🧿','🪬','🧸','🪆','🖼️','🧩','🪅',
  ]),
  _EmojiCategory('Symbols', Icons.favorite_border, [
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❤️‍🔥','❤️‍🩹',
    '💕','💞','💓','💗','💖','💘','💝','💟','☮️','✝️','☪️','🕉️',
    '☸️','✡️','🔯','☯️','☦️','🛐','⛎','♈','♉','♊','♋','♌','♍',
    '♎','♏','♐','♑','♒','♓','🔴','🟠','🟡','🟢','🔵','🟣','⚫','⚪',
    '🟥','🟧','🟨','🟩','🟦','🟪','🟫','⬛','⬜','◼️','◻️','◾','◽',
    '▪️','▫️','✅','❌','❎','⭕','🛑','⛔','📛','🚫','💯','♾️',
    '🔞','📵','🚷','🚯','🚱','🚳','❗','❕','❓','❔','‼️','⁉️',
    '⚠️','🔱','♻️','🆔','🆕','🆓','🆒','🆗','🆙','🆚','🆖','🆘',
    '🆎','🆑','🅰️','🅱️','🅾️','🅿️','🔔','🔕','📳','📴','📵',
    '✔️','☑️','🔘','🔲','🔳','🔉','🔊','🔇','🔈','🔅','🔆',
    '⏩','⏪','⏫','⏬','⏭️','⏮️','⏸️','⏹️','⏺️','⏏️','▶️','◀️',
    '🔼','🔽','📶','📳','🔃','🔄','🔙','🔚','🔛','🔜','🔝',
    '🌐','💠','Ⓜ️','🌀','💤','🏧','🚾','♿','🈳','🈹','🛗',
    '💱','💲','🔣','🔤','🔡','🔠','#️⃣','*️⃣','0️⃣','1️⃣','2️⃣',
    '3️⃣','4️⃣','5️⃣','6️⃣','7️⃣','8️⃣','9️⃣','🔟',
    '🌟','⭐','🌠','✨','💫','💥','🔥','🌊','🌀','🎆','🎇','✈️',
    '🗓️','📅','📆','📇','📋','📌','📍','🗺️','🧭',
  ]),
  _EmojiCategory('Flags', Icons.flag_outlined, [
    '🏳️','🏴','🚩','🏁','🏳️‍🌈','🏳️‍⚧️','🏴‍☠️',
    '🇦🇫','🇦🇱','🇩🇿','🇦🇩','🇦🇴','🇦🇷','🇦🇲','🇦🇺','🇦🇹',
    '🇦🇿','🇧🇸','🇧🇭','🇧🇩','🇧🇧','🇧🇾','🇧🇪','🇧🇿','🇧🇯',
    '🇧🇹','🇧🇴','🇧🇦','🇧🇼','🇧🇷','🇧🇳','🇧🇬','🇧🇫','🇧🇮',
    '🇨🇻','🇰🇭','🇨🇲','🇨🇦','🇨🇫','🇹🇩','🇨🇱','🇨🇳','🇨🇴',
    '🇨🇬','🇨🇷','🇭🇷','🇨🇺','🇨🇾','🇨🇿','🇩🇰','🇩🇯','🇩🇴',
    '🇪🇨','🇪🇬','🇸🇻','🇬🇶','🇪🇷','🇪🇪','🇸🇿','🇪🇹','🇫🇯',
    '🇫🇮','🇫🇷','🇬🇦','🇬🇲','🇬🇪','🇩🇪','🇬🇭','🇬🇷','🇬🇹',
    '🇬🇳','🇬🇼','🇬🇾','🇭🇹','🇭🇳','🇭🇺','🇮🇸','🇮🇳','🇮🇩',
    '🇮🇷','🇮🇶','🇮🇪','🇮🇱','🇮🇹','🇯🇲','🇯🇵','🇯🇴','🇰🇿',
    '🇰🇪','🇰🇵','🇰🇷','🇽🇰','🇰🇼','🇰🇬','🇱🇦','🇱🇻','🇱🇧',
    '🇱🇸','🇱🇷','🇱🇾','🇱🇮','🇱🇹','🇱🇺','🇲🇬','🇲🇼','🇲🇾',
    '🇲🇻','🇲🇱','🇲🇹','🇲🇷','🇲🇺','🇲🇽','🇲🇩','🇲🇨','🇲🇳',
    '🇲🇪','🇲🇦','🇲🇿','🇲🇲','🇳🇦','🇳🇵','🇳🇱','🇳🇿','🇳🇮',
    '🇳🇪','🇳🇬','🇳🇴','🇴🇲','🇵🇰','🇵🇼','🇵🇦','🇵🇬','🇵🇾',
    '🇵🇪','🇵🇭','🇵🇱','🇵🇹','🇶🇦','🇷🇴','🇷🇺','🇷🇼','🇼🇸',
    '🇸🇦','🇸🇳','🇷🇸','🇸🇱','🇸🇬','🇸🇰','🇸🇮','🇸🇧','🇸🇴',
    '🇿🇦','🇸🇸','🇪🇸','🇱🇰','🇸🇩','🇸🇷','🇸🇪','🇨🇭','🇸🇾',
    '🇹🇼','🇹🇯','🇹🇿','🇹🇭','🇹🇱','🇹🇬','🇹🇴','🇹🇹','🇹🇳',
    '🇹🇷','🇹🇲','🇺🇬','🇺🇦','🇦🇪','🇬🇧','🇺🇸','🇺🇾','🇺🇿',
    '🇻🇳','🇾🇪','🇿🇲','🇿🇼',
  ]),
];

// ─── Picker widget ─────────────────────────────────────────────────────────────

class EmojiPickerDialog extends StatefulWidget {
  final void Function(String emoji) onEmojiSelected;

  const EmojiPickerDialog({super.key, required this.onEmojiSelected});

  /// Show as a bottom sheet. Returns the selected emoji or null.
  static Future<String?> show(
    BuildContext context, {
    required void Function(String emoji) onSelected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmojiPickerDialog(onEmojiSelected: onSelected),
    );
  }

  @override
  State<EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<EmojiPickerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _searchResults {
    if (_query.isEmpty) return [];
    return _categories
        .expand((c) => c.emojis)
        .where((e) => e.toLowerCase().contains(_query))
        .toList();
  }

  void _pick(String emoji) {
    widget.onEmojiSelected(emoji);
    Navigator.of(context).pop(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final sheetHeight = mq.size.height * 0.55;

    return ValueListenableBuilder<double>(
      valueListenable: SettingsManager.elementBrightness,
      builder: (_, br, __) => ValueListenableBuilder<double>(
        valueListenable: SettingsManager.elementOpacity,
        builder: (_, op, __) {
          final bg = SettingsManager.getElementColor(
            colorScheme.surfaceContainerHighest, br,
          ).withValues(alpha: op.clamp(0.85, 1.0));
          final sBg = SettingsManager.getElementColor(
            colorScheme.surface, br,
          ).withValues(alpha: op.clamp(0.85, 1.0));

          return Container(
            height: sheetHeight + mq.viewInsets.bottom,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _quickReactions
                        .map((e) => _EmojiButton(emoji: e, size: 32, onTap: () => _pick(e)))
                        .toList(),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search emoji…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: sBg,
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (_query.isEmpty)
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    padding: EdgeInsets.zero,
                    tabAlignment: TabAlignment.start,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: _categories
                        .map((c) => Tab(
                              child: Tooltip(
                                message: c.label,
                                child: Icon(c.icon, size: 20),
                              ),
                            ))
                        .toList(),
                  ),
                Expanded(
                  child: _query.isNotEmpty
                      ? _buildGrid(_searchResults, 'No results')
                      : TabBarView(
                          controller: _tabController,
                          children: _categories
                              .map((c) => _buildGrid(c.emojis, 'No emoji'))
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<String> emojis, String emptyLabel) {
    if (emojis.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: emojis.length,
      itemBuilder: (_, i) => _EmojiButton(
        emoji: emojis[i],
        size: 26,
        onTap: () => _pick(emojis[i]),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  final String emoji;
  final double size;
  final VoidCallback onTap;

  const _EmojiButton({
    required this.emoji,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size)),
      ),
    );
  }
}
