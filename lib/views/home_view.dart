import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/account_controller.dart';
import '../controllers/chat_controller.dart';
import 'chat_view.dart';

// ─── Telegram brand colours ────────────────────────────────────────────────
const _bg    = Color(0xFF17212B);
const _surf  = Color(0xFF1C2733);
const _blue  = Color(0xFF2AABEE);
const _dim   = Color(0xFF8A9DB0);
const _sep   = Color(0xFF1C2733);
// ──────────────────────────────────────────────────────────────────────────

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);
  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatController>(context, listen: false).loadChats();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccountController, ChatController>(
      builder: (context, accCtrl, chatCtrl, _) {
        final current = accCtrl.currentAccount;
        final chats   = chatCtrl.chats;

        return Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(context, accCtrl, current),
          drawer: _buildDrawer(context, accCtrl),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            backgroundColor: _blue,
            elevation: 4,
            child: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
          ),
          body: Column(
            children: [
              // ── Search bar ─────────────────────────────────────────────
              _buildSearchBar(),
              // ── Chat list ──────────────────────────────────────────────
              Expanded(
                child: chatCtrl.isLoadingChats
                    ? const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2))
                    : current == null
                        ? _buildEmpty(context)
                        : chats.isEmpty
                            ? _buildEmptyChats()
                            : _buildChatList(context, chats),
              ),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext ctx, AccountController acc, dynamic current) {
    return AppBar(
      backgroundColor: _surf,
      elevation: 0,
      titleSpacing: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: current != null
              ? _avatar(current.firstName, radius: 18)
              : const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: _searching
          ? TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: _blue,
              decoration: const InputDecoration(
                hintText: 'Search chats...',
                hintStyle: TextStyle(color: _dim),
                border: InputBorder.none,
              ),
            )
          : Text(
              'Telegram',
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(_searching ? Icons.close : Icons.search, color: Colors.white),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) _searchCtrl.clear();
          }),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF232E3C),
          onSelected: (v) {
            if (v == 'new_account') Navigator.pushNamed(ctx, '/login');
            if (v == 'sessions') Navigator.pushNamed(ctx, '/sessions');
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'new_account',
              child: _menuItem(Icons.person_add_outlined, 'Add Account'),
            ),
            PopupMenuItem(
              value: 'sessions',
              child: _menuItem(Icons.devices_outlined, 'Active Sessions'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: _dim, size: 20),
      const SizedBox(width: 14),
      Text(text, style: GoogleFonts.roboto(color: Colors.white, fontSize: 14)),
    ],
  );

  Widget _buildSearchBar() {
    return Container(
      height: 1,
      color: const Color(0xFF0F1923),
    );
  }

  Widget _buildChatList(BuildContext ctx, List<Map<String, dynamic>> chats) {
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat   = chats[index];
        final chatId = (chat['id'] ?? 0) as int;
        final title  = (chat['title'] as String?) ?? 'Unknown';
        final lastMsg = chat['last_message'];
        String subtitle = '';
        if (lastMsg != null) {
          final content = lastMsg['content'];
          if (content?['@type'] == 'messageText') {
            subtitle = content['text']['text'] ?? '';
          } else if (content != null) {
            subtitle = '📎 Attachment';
          }
        }
        final unread = (chat['unread_count'] as int?) ?? 0;
        final muted  = ((chat['notification_settings']?['mute_for'] ?? 0) as int) > 0;
        final isPinned = (chat['is_pinned'] as bool?) ?? false;

        return _ChatTile(
          title: title,
          subtitle: subtitle,
          unreadCount: unread,
          isMuted: muted,
          isPinned: isPinned,
          time: _formatTime(lastMsg?['date']),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatView(chatId: chatId, chatTitle: title),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext ctx) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _surf,
              border: Border.all(color: _blue.withOpacity(0.3), width: 2),
            ),
            child: const Icon(Icons.person_outline, color: _dim, size: 36),
          ),
          const SizedBox(height: 20),
          Text('No Account', style: GoogleFonts.roboto(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Add an account to get started', style: GoogleFonts.roboto(color: _dim, fontSize: 14)),
          const SizedBox(height: 28),
          TextButton(
            onPressed: () => Navigator.pushNamed(ctx, '/login'),
            style: TextButton.styleFrom(foregroundColor: _blue),
            child: const Text('Add Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChats() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, color: _dim, size: 64),
          const SizedBox(height: 16),
          Text('No chats yet', style: GoogleFonts.roboto(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Start a conversation', style: GoogleFonts.roboto(color: _dim, fontSize: 14)),
        ],
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext ctx, AccountController ctrl) {
    final current = ctrl.currentAccount;
    return Drawer(
      backgroundColor: _surf,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: _bg,
            padding: EdgeInsets.only(
              top: MediaQuery.of(ctx).padding.top + 16,
              left: 20, right: 20, bottom: 16,
            ),
            child: current != null ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(current.firstName, radius: 30),
                const SizedBox(height: 14),
                Text(
                  current.firstName,
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  current.phoneNumber,
                  style: GoogleFonts.roboto(color: _dim, fontSize: 14),
                ),
                const SizedBox(height: 12),
                // Account switcher mini-list
                if (ctrl.accounts.length > 1)
                  ...ctrl.accounts.where((a) => a.phoneNumber != current.phoneNumber).map((acc) =>
                    InkWell(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await ctrl.switchAccount(acc);
                        if (ctx.mounted) {
                          Provider.of<ChatController>(ctx, listen: false).loadChats();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            _avatar(acc.firstName, radius: 16, fontSize: 13),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(acc.firstName, style: GoogleFonts.roboto(color: Colors.white, fontSize: 14)),
                                  Text(acc.phoneNumber, style: GoogleFonts.roboto(color: _dim, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ),
              ],
            ) : Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text('No Account', style: GoogleFonts.roboto(color: _dim, fontSize: 16)),
            ),
          ),
          // ── Menu items ──────────────────────────────────────────────────
          _drawerItem(Icons.person_add_outlined, 'Add Account', () {
            Navigator.pop(ctx);
            Navigator.pushNamed(ctx, '/login');
          }),
          _drawerItem(Icons.devices_outlined, 'Active Sessions', () {
            Navigator.pop(ctx);
            Navigator.pushNamed(ctx, '/sessions');
          }),
          _drawerItem(Icons.star_outline_rounded, 'Saved Messages', () {
            Navigator.pop(ctx);
          }),
          const Divider(color: Color(0xFF0F1923), height: 1),
          _drawerItem(
            Icons.diamond_outlined,
            'Telegram Premium',
            () {
              Navigator.pop(ctx);
              _showPremiumSheet(ctx, ctrl);
            },
            iconColor: const Color(0xFFB069FF),
          ),
          const Divider(color: Color(0xFF0F1923), height: 1),
          _drawerItem(Icons.settings_outlined, 'Settings', () {
            Navigator.pop(ctx);
          }),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, {Color? iconColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? _dim, size: 22),
      title: Text(label, style: GoogleFonts.roboto(color: Colors.white, fontSize: 15)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      horizontalTitleGap: 12,
    );
  }

  // ── Premium bottom sheet ──────────────────────────────────────────────────
  void _showPremiumSheet(BuildContext ctx, AccountController ctrl) {
    ctrl.syncPremiumStatus();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Consumer<AccountController>(
        builder: (_, c, __) {
          final acc = c.currentAccount;
          final isPrem = acc?.isPremium ?? false;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: _dim.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                )),
                const SizedBox(height: 20),
                Row(children: [
                  const Icon(Icons.diamond_rounded, color: Color(0xFFB069FF), size: 26),
                  const SizedBox(width: 12),
                  Text('Telegram Premium', style: GoogleFonts.roboto(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                  )),
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isPrem
                        ? const Color(0xFF1E1B2E)
                        : const Color(0xFF1C1F26),
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
                      Text(
                        isPrem ? 'Premium Active' : 'No Premium',
                        style: GoogleFonts.roboto(
                          color: isPrem ? const Color(0xFFB069FF) : Colors.redAccent,
                          fontWeight: FontWeight.w700, fontSize: 15,
                        ),
                      ),
                      Text(
                        acc?.firstName ?? '',
                        style: GoogleFonts.roboto(color: _dim, fontSize: 12),
                      ),
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
                    label: Text('Open @PremiumBot', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _avatar(String name, {double radius = 22, double? fontSize}) {
    final colors = [
      const Color(0xFF2A9FE0), const Color(0xFF47A76A), const Color(0xFFE07B39),
      const Color(0xFF9B59B6), const Color(0xFFE74C3C), const Color(0xFF1ABC9C),
    ];
    final color = colors[name.codeUnitAt(0) % colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? radius * 0.75,
        ),
      ),
    );
  }

  String _formatTime(dynamic unixTs) {
    if (unixTs == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch((unixTs as int) * 1000);
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}

// ── Chat tile widget ─────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final String time;
  final VoidCallback onTap;

  const _ChatTile({
    required this.title,
    required this.subtitle,
    required this.unreadCount,
    required this.isMuted,
    required this.isPinned,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColors = [
      const Color(0xFF2A9FE0), const Color(0xFF47A76A), const Color(0xFFE07B39),
      const Color(0xFF9B59B6), const Color(0xFFE74C3C), const Color(0xFF1ABC9C),
    ];
    final avatarColor = avatarColors[title.isNotEmpty ? title.codeUnitAt(0) % avatarColors.length : 0];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _bg,
          border: const Border(bottom: BorderSide(color: _sep, width: 0.5)),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: avatarColor,
                  child: Text(
                    title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                if (isPinned)
                  Positioned(
                    right: -2, bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: _bg),
                      child: const Icon(Icons.push_pin_rounded, color: _dim, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: GoogleFonts.roboto(
                          color: unreadCount > 0 && !isMuted ? _blue : _dim,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(color: _dim, fontSize: 14),
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMuted ? const Color(0xFF3D4F5C) : _blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
