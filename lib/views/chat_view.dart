import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/chat_controller.dart';

// ─── Telegram brand colours ────────────────────────────────────────────────
const _bg         = Color(0xFF0E1621);   // chat background (dark navy)
const _surf       = Color(0xFF1C2733);
const _blue       = Color(0xFF2AABEE);
const _bubbleOut  = Color(0xFF2B52A3);   // outgoing bubble
const _bubbleIn   = Color(0xFF182533);   // incoming bubble
const _inputBg    = Color(0xFF1C2733);
const _dim        = Color(0xFF8A9DB0);
// ──────────────────────────────────────────────────────────────────────────

class ChatView extends StatefulWidget {
  final int chatId;
  final String chatTitle;

  const ChatView({Key? key, required this.chatId, required this.chatTitle}) : super(key: key);

  @override
  _ChatViewState createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _hasText     = false;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatController>(context, listen: false).loadMessages(widget.chatId);
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    Provider.of<ChatController>(context, listen: false).sendMessage(widget.chatId, text);
    _msgCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  // ── Avatar colour helper ──────────────────────────────────────────────────
  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF2A9FE0), const Color(0xFF47A76A), const Color(0xFFE07B39),
      const Color(0xFF9B59B6), const Color(0xFFE74C3C), const Color(0xFF1ABC9C),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final ac = _avatarColor(widget.chatTitle);
    return AppBar(
      backgroundColor: _surf,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ac,
            child: Text(
              widget.chatTitle.isNotEmpty ? widget.chatTitle.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.chatTitle,
                  style: GoogleFonts.roboto(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'tap for more info',
                  style: GoogleFonts.roboto(color: _dim, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.white), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call_outlined, color: Colors.white), onPressed: () {}),
        IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
      ],
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatController>(
      builder: (context, ctrl, _) {
        final messages = ctrl.getMessagesForChat(widget.chatId);

        if (ctrl.isLoadingMessages) {
          return const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2));
        }

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: _dim, size: 48),
                const SizedBox(height: 12),
                Text('No messages yet', style: GoogleFonts.roboto(color: _dim, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Send the first message!', style: GoogleFonts.roboto(color: _dim.withOpacity(0.6), fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (ctx, i) => _buildBubble(messages[i]),
        );
      },
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isOut  = (msg['is_outgoing'] as bool?) ?? false;
    final content = msg['content'];
    String text = '';
    if (content?['@type'] == 'messageText') {
      text = content['text']['text'] ?? '';
    } else {
      text = '📎 ${content?['@type']?.replaceAll('message', '') ?? 'Media'}';
    }

    final ts   = (msg['date'] as int?) ?? 0;
    final dt   = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isOut ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOut)
            const SizedBox(width: 6),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: isOut ? _bubbleOut : _bubbleIn,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isOut ? 18 : 4),
                  bottomRight: Radius.circular(isOut ? 4 : 18),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    text,
                    style: GoogleFonts.roboto(
                      color: Colors.white, fontSize: 15, height: 1.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: GoogleFonts.roboto(
                          color: Colors.white.withOpacity(0.55), fontSize: 11,
                        ),
                      ),
                      if (isOut) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF54B3E8)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isOut)
            const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: _surf,
        border: Border(top: BorderSide(color: Color(0xFF0F1923), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach button
            _iconBtn(Icons.attach_file_rounded, onTap: () {}),
            const SizedBox(width: 4),
            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: _inputBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        maxLines: null,
                        style: GoogleFonts.roboto(color: Colors.white, fontSize: 15),
                        cursorColor: _blue,
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: GoogleFonts.roboto(color: _dim, fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    // Emoji
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, color: _dim),
                      onPressed: () {},
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(10),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Send / mic button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: _hasText
                  ? GestureDetector(
                      key: const ValueKey('send'),
                      onTap: _sendMessage,
                      child: Container(
                        width: 48, height: 48,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: _blue),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey('mic'),
                      onTap: () {},
                      child: Container(
                        width: 48, height: 48,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: _blue),
                        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: _dim, size: 22),
      ),
    );
  }
}
