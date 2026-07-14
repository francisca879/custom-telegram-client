import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/account_controller.dart';
import '../controllers/chat_controller.dart';
import 'chat_view.dart';

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
      builder: (context, accController, chatController, child) {
        final current = accController.currentAccount;
        return Scaffold(
          backgroundColor: const Color(0xFF000000),
          appBar: AppBar(
            backgroundColor: const Color(0xFF161618),
            title: Text(
              current != null ? current.firstName : "Telegram X",
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => chatController.loadChats(),
              )
            ],
          ),
          drawer: _buildAccountDrawer(context, accController),
          body: chatController.isLoadingChats
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2FA4E7)),
                )
              : current == null
                  ? _buildNoAccountsBody(context)
                  : _buildChatListBody(context, chatController),
        );
      },
    );
  }

  Widget _buildNoAccountsBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle_outlined, color: Colors.grey, size: 80),
            const SizedBox(height: 20),
            Text(
              "No accounts logged in",
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Add up to 50 accounts to manage and switch between them seamlessly.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 15),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Add Account"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2FA4E7),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatListBody(BuildContext context, ChatController controller) {
    final chats = controller.chats;
    
    if (chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey[600], size: 60),
              const SizedBox(height: 16),
              Text(
                "Your chat list is empty",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Chats will appear here once your account synchronizes or you start a new conversation.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (context, index) => const Divider(color: Color(0xFF1C1C1E), height: 1),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final int chatId = chat['id'] ?? 0;
        final String title = chat['title'] ?? 'Telegram Chat';
        
        final lastMessage = chat['last_message'];
        String subtitle = "No messages";
        if (lastMessage != null) {
          final content = lastMessage['content'];
          if (content != null && content['@type'] == 'messageText') {
            subtitle = content['text']['text'] ?? "";
          } else {
            subtitle = "[Attachment / Media]";
          }
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF2FA4E7).withOpacity(0.15),
            radius: 26,
            child: Text(
              title.isNotEmpty ? title.substring(0, 1).toUpperCase() : "?",
              style: const TextStyle(color: Color(0xFF2FA4E7), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatView(
                  chatId: chatId,
                  chatTitle: title,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccountDrawer(BuildContext context, AccountController controller) {
    final current = controller.currentAccount;
    return Drawer(
      child: Container(
        color: const Color(0xFF161618),
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0F0F10)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: const Color(0xFF2FA4E7),
                child: Text(
                  current != null ? current.firstName.substring(0, 1) : "T",
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              accountName: Text(
                current != null ? current.firstName : "Telegram X User",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              accountEmail: Text(
                current != null ? current.phoneNumber : "No active session",
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Switch Profiles (${controller.accounts.length}/50)",
                    style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF2FA4E7), size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/login');
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: controller.accounts.length,
                itemBuilder: (context, index) {
                  final acc = controller.accounts[index];
                  final isCurrent = acc.phoneNumber == current?.phoneNumber;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent ? const Color(0xFF2FA4E7) : Colors.grey[800],
                      child: Text(acc.firstName.substring(0, 1), style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(
                      acc.firstName,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(acc.phoneNumber, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle, color: Color(0xFF2FA4E7))
                        : IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => controller.deleteAccount(acc.phoneNumber),
                          ),
                    onTap: () async {
                      Navigator.pop(context);
                      await controller.switchAccount(acc);
                      Provider.of<ChatController>(context, listen: false).loadChats();
                    },
                  );
                },
              ),
            ),
            const Divider(color: Color(0xFF2C2C2E), height: 1),
            ListTile(
              leading: const Icon(Icons.devices_rounded, color: Colors.white),
              title: Text(
                "Login Activity",
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text("Manage active device sessions", style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/sessions');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
