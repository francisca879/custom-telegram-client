import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/account_controller.dart';
import '../controllers/chat_controller.dart';
import '../services/tdlib_service.dart';
import 'chat_view.dart';

// ─── Telegram brand colours ────────────────────────────────────────────────
const _bg   = Color(0xFF17212B);
const _surf = Color(0xFF1C2733);
const _blue = Color(0xFF2AABEE);
const _dim  = Color(0xFF8A9DB0);
const _sep  = Color(0xFF0F1923);
// ──────────────────────────────────────────────────────────────────────────

// ── Avatar colour helper (shared) ────────────────────────────────────────────
Color avatarColor(String name) {
  const colors = [
    Color(0xFF2A9FE0), Color(0xFF47A76A), Color(0xFFE07B39),
    Color(0xFF9B59B6), Color(0xFFE74C3C), Color(0xFF1ABC9C),
  ];
  return name.isNotEmpty ? colors[name.codeUnitAt(0) % colors.length] : colors[0];
}

Widget buildAvatar(String name, {double radius = 24}) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: avatarColor(name),
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.75,
      ),
    ),
  );
}

// ── HomeView ─────────────────────────────────────────────────────────────────
class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);
  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatController>(context, listen: false).loadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccountController, ChatController>(
      builder: (ctx, accCtrl, chatCtrl, _) {
        final current = accCtrl.currentAccount;
        return Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(ctx, accCtrl, current),
          drawer: _buildDrawer(ctx, accCtrl),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openSearch(ctx),
            backgroundColor: _blue,
            elevation: 3,
            child: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
          ),
          body: chatCtrl.isLoadingChats
              ? const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2))
              : current == null
                  ? _buildNoAccount(ctx)
                  : chatCtrl.chats.isEmpty
                      ? _buildEmptyChats()
                      : _buildChatList(ctx, chatCtrl.chats),
        );
      },
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext ctx, AccountController acc, dynamic current) {
    return AppBar(
      backgroundColor: _surf,
      elevation: 0,
      titleSpacing: 0,
      leading: Builder(
        builder: (ctx2) => IconButton(
          icon: current != null
              ? buildAvatar(current.firstName, radius: 18)
              : const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(ctx2).openDrawer(),
        ),
      ),
      title: Text(
        'Telegram',
        style: GoogleFonts.roboto(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => _openSearch(ctx),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF232E3C),
          onSelected: (v) {
            if (v == 'new') Navigator.pushNamed(ctx, '/login');
            if (v == 'sessions') Navigator.pushNamed(ctx, '/sessions');
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'new', child: _menuRow(Icons.person_add_outlined, 'Add Account')),
            PopupMenuItem(value: 'sessions', child: _menuRow(Icons.devices_outlined, 'Active Sessions')),
          ],
        ),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(children: [
    Icon(icon, color: _dim, size: 20),
    const SizedBox(width: 14),
    Text(label, style: GoogleFonts.roboto(color: Colors.white, fontSize: 14)),
  ]);

  // ── Search ────────────────────────────────────────────────────────────────
  void _openSearch(BuildContext ctx) {
    final svc = Provider.of<AccountController>(ctx, listen: false).tdService;
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => _SearchPage(tdService: svc),
    ));
  }

  // ── Chat list ─────────────────────────────────────────────────────────────
  Widget _buildChatList(BuildContext ctx, List<Map<String, dynamic>> chats) {
    return RefreshIndicator(
      color: _blue,
      backgroundColor: _surf,
      onRefresh: () =>
          Provider.of<ChatController>(ctx, listen: false).loadChats(),
      child: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, i) {
          final chat = chats[i];
          final chatId = (chat['id'] as int?) ?? 0;
          final title  = (chat['title'] as String?) ?? 'Chat';
          final lastMsg = chat['last_message'];
          String subtitle = '';
          if (lastMsg != null) {
            final c = lastMsg['content'];
            if (c?['@type'] == 'messageText') {
              subtitle = c['text']['text'] ?? '';
            } else if (c != null) {
              subtitle = '📎 ${(c['@type'] as String).replaceAll('message', '')}';
            }
          }
          final unread  = (chat['unread_count'] as int?) ?? 0;
          final muted   = ((chat['notification_settings']?['mute_for'] ?? 0) as int) > 0;
          final pinned  = (chat['is_pinned'] as bool?) ?? false;
          final ts      = lastMsg?['date'];
          final time    = ts != null ? _fmtTime(ts as int) : '';
          return _ChatTile(
            title: title,
            subtitle: subtitle,
            unreadCount: unread,
            isMuted: muted,
            isPinned: pinned,
            time: time,
            onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => ChatView(chatId: chatId, chatTitle: title),
            )),
          );
        },
      ),
    );
  }

  Widget _buildNoAccount(BuildContext ctx) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      buildAvatar('?', radius: 36),
      const SizedBox(height: 20),
      Text('No Account', style: GoogleFonts.roboto(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Add an account to start', style: GoogleFonts.roboto(color: _dim, fontSize: 14)),
      const SizedBox(height: 28),
      TextButton(
        onPressed: () => Navigator.pushNamed(ctx, '/login'),
        child: const Text('Add Account', style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  Widget _buildEmptyChats() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.chat_bubble_outline, color: _dim, size: 60),
      const SizedBox(height: 16),
      Text('No chats yet', style: GoogleFonts.roboto(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Search or tap edit to start a conversation', style: GoogleFonts.roboto(color: _dim, fontSize: 14)),
    ]),
  );

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext ctx, AccountController ctrl) {
    final current = ctrl.currentAccount;
    return Drawer(
      backgroundColor: _surf,
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          color: _bg,
          padding: EdgeInsets.only(
            top: MediaQuery.of(ctx).padding.top + 16,
            left: 20, right: 20, bottom: 16,
          ),
          child: current == null
              ? Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text('No Account', style: GoogleFonts.roboto(color: _dim)),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  buildAvatar(current.firstName, radius: 30),
                  const SizedBox(height: 14),
                  Text(current.firstName,
                      style: GoogleFonts.roboto(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(current.phoneNumber,
                      style: GoogleFonts.roboto(color: _dim, fontSize: 14)),
                  const SizedBox(height: 12),
                  // Other accounts mini-list
                  ...ctrl.accounts
                      .where((a) => a.phoneNumber != current.phoneNumber)
                      .map((acc) => InkWell(
                            onTap: () async {
                              Navigator.pop(ctx);
                              await ctrl.switchAccount(acc);
                              if (ctx.mounted) {
                                Provider.of<ChatController>(ctx, listen: false).loadChats();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(children: [
                                buildAvatar(acc.firstName, radius: 16),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(acc.firstName,
                                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 14)),
                                    Text(acc.phoneNumber,
                                        style: GoogleFonts.roboto(color: _dim, fontSize: 12)),
                                  ],
                                )),
                              ]),
                            ),
                          )),
                ]),
        ),
        _drawerItem(Icons.person_add_outlined, 'Add Account', () {
          Navigator.pop(ctx);
          Navigator.pushNamed(ctx, '/login');
        }),
        _drawerItem(Icons.devices_outlined, 'Active Sessions', () {
          Navigator.pop(ctx);
          Navigator.pushNamed(ctx, '/sessions');
        }),
        _drawerItem(Icons.bookmark_border_rounded, 'Saved Messages', () {
          Navigator.pop(ctx);
        }),
        const Divider(color: _sep, height: 1),
        _drawerItem(Icons.diamond_outlined, 'Telegram Premium', () {
          Navigator.pop(ctx);
          _showPremiumSheet(ctx, ctrl);
        }, iconColor: const Color(0xFFB069FF)),
        const Divider(color: _sep, height: 1),
        _drawerItem(Icons.settings_outlined, 'Settings', () {
          Navigator.pop(ctx);
        }),
      ]),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {Color? iconColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? _dim, size: 22),
      title: Text(label, style: GoogleFonts.roboto(color: Colors.white, fontSize: 15)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      horizontalTitleGap: 12,
    );
  }

  // ── Premium bottom sheet ───────────────────────────────────────────────────
  void _showPremiumSheet(BuildContext ctx, AccountController ctrl) {
    ctrl.syncPremiumStatus();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Consumer<AccountController>(
        builder: (_, c, __) {
          final acc    = c.currentAccount;
          final isPrem = acc?.isPremium ?? false;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _dim.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.diamond_rounded, color: Color(0xFFB069FF), size: 26),
                const SizedBox(width: 12),
                Text('Telegram Premium',
                    style: GoogleFonts.roboto(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPrem ? const Color(0xFF1E1B2E) : const Color(0xFF1C1F26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPrem
                        ? const Color(0xFF7B3FE4).withOpacity(0.4)
                        : Colors.redAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(children: [
                  Icon(
                    isPrem ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isPrem ? const Color(0xFFB069FF) : Colors.redAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isPrem ? 'Premium Active' : 'No Premium',
                        style: GoogleFonts.roboto(
                          color: isPrem ? const Color(0xFFB069FF) : Colors.redAccent,
                          fontWeight: FontWeight.w700, fontSize: 15,
                        )),
                    Text(acc?.firstName ?? '',
                        style: GoogleFonts.roboto(color: _dim, fontSize: 12)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    try {
                      final chat = await ctrl.tdService.searchPublicChat('PremiumBot');
                      final chatId = (chat['id'] as int?) ?? 0;
                      if (chatId != 0 && ctx.mounted) {
                        Navigator.push(ctx, MaterialPageRoute(
                          builder: (_) => ChatView(chatId: chatId, chatTitle: 'Premium Bot 💎'),
                        ));
                      }
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B3FE4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text('Open @PremiumBot',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmtTime(int unixTs) {
    final dt  = DateTime.fromMillisecondsSinceEpoch(unixTs * 1000);
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (now.difference(dt).inDays < 7) return days[dt.weekday - 1];
    return '${dt.day}/${dt.month}';
  }
}

// ── Chat tile ─────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final String time;
  final VoidCallback onTap;

  const _ChatTile({
    required this.title, required this.subtitle, required this.unreadCount,
    required this.isMuted, required this.isPinned, required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _sep, width: 0.5)),
        ),
        child: Row(children: [
          // Avatar
          Stack(clipBehavior: Clip.none, children: [
            buildAvatar(title, radius: 28),
            if (isPinned)
              Positioned(
                right: -2, bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _bg),
                  child: const Icon(Icons.push_pin_rounded, color: _dim, size: 11),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          // Text content
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: GoogleFonts.roboto(
                    color: unreadCount > 0 && !isMuted ? _blue : _dim,
                    fontSize: 12,
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(color: _dim, fontSize: 14),
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isMuted ? const Color(0xFF3D4F5C) : _blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (isPinned)
                  const Icon(Icons.push_pin_rounded, color: _dim, size: 14),
              ]),
            ],
          )),
        ]),
      ),
    );
  }
}

// ── Search Page (Telegram-style) ──────────────────────────────────────────────
class _SearchPage extends StatefulWidget {
  final TdLibService tdService;
  const _SearchPage({required this.tdService});
  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final q = _ctrl.text.trim();
    if (q.isEmpty) { setState(() { _results = []; _loading = false; }); return; }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q));
  }

  Future<void> _search(String q) async {
    final results = <Map<String, dynamic>>[];

    // 1. Search contacts by name
    try {
      final r = await widget.tdService.searchContacts(q, limit: 10);
      final ids = (r['user_ids'] as List?) ?? [];
      for (final uid in ids) {
        try {
          final user = await widget.tdService.send('getUser', {'user_id': uid});
          results.add({'_src': 'contact', ...user});
        } catch (_) {}
      }
    } catch (_) {}

    // 2. Try public username search
    final uname = q.startsWith('@') ? q.substring(1) : q;
    if (uname.length >= 3) {
      try {
        final chat = await widget.tdService.searchPublicChat(uname);
        if (chat['id'] != null) {
          // Avoid duplicate if already in contacts
          final exists = results.any((r) {
            final cid = (chat['id'] as int?) ?? 0;
            return r['id'] == cid;
          });
          if (!exists) results.insert(0, {'_src': 'public', ...chat});
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() { _results = results; _loading = false; });
  }

  String _getName(Map<String, dynamic> item) {
    final src = item['_src'];
    if (src == 'contact') {
      return '${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'.trim();
    }
    return (item['title'] as String?) ?? '';
  }

  String _getSubtitle(Map<String, dynamic> item) {
    final src = item['_src'];
    if (src == 'contact') {
      final u = item['username'] ??
          ((item['usernames']?['active_usernames'] as List?)?.isNotEmpty == true
              ? (item['usernames']?['active_usernames'] as List).first
              : null);
      return u != null ? '@$u' : '';
    }
    // public chat
    final mc = item['member_count'];
    return mc != null ? '$mc members' : 'Public channel/group';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surf,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          style: GoogleFonts.roboto(color: Colors.white, fontSize: 17),
          cursorColor: _blue,
          decoration: InputDecoration(
            hintText: 'Search chats or @username',
            hintStyle: GoogleFonts.roboto(color: _dim, fontSize: 17),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: _dim),
              onPressed: () { _ctrl.clear(); setState(() => _results = []); },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2))
          : _results.isEmpty && _ctrl.text.trim().isNotEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.search_off_rounded, color: _dim, size: 52),
                  const SizedBox(height: 14),
                  Text('No results found', style: GoogleFonts.roboto(color: _dim, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Try searching by @username', style: GoogleFonts.roboto(color: _dim.withOpacity(0.6), fontSize: 13)),
                ]))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final item = _results[i];
                    final name = _getName(item);
                    final sub  = _getSubtitle(item);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: buildAvatar(name, radius: 26),
                      title: Text(name,
                          style: GoogleFonts.roboto(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      subtitle: sub.isNotEmpty
                          ? Text(sub, style: GoogleFonts.roboto(color: _dim, fontSize: 13))
                          : null,
                      onTap: () async {
                        int chatId = (item['id'] as int?) ?? 0;
                        // For a user result, open/create private chat
                        if (item['_src'] == 'contact' && chatId != 0) {
                          try {
                            final chat = await widget.tdService.send(
                                'createPrivateChat', {'user_id': chatId, 'force': false});
                            chatId = (chat['id'] as int?) ?? 0;
                          } catch (_) {}
                        }
                        if (chatId != 0 && context.mounted) {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChatView(chatId: chatId, chatTitle: name),
                          ));
                        }
                      },
                    );
                  },
                ),
    );
  }
}
