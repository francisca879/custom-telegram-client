import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/session_controller.dart';

class SessionsView extends StatefulWidget {
  const SessionsView({Key? key}) : super(key: key);

  @override
  _SessionsViewState createState() => _SessionsViewState();
}

class _SessionsViewState extends State<SessionsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SessionController>(context, listen: false).loadSessions();
    });
  }

  String _formatDate(int timestamp) {
    if (timestamp == 0) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161618),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Login Activity",
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: Consumer<SessionController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2FA4E7)));
          }

          final sessions = controller.sessions;
          if (sessions.isEmpty) {
            return RefreshIndicator(
              color: const Color(0xFF2FA4E7),
              onRefresh: () => controller.loadSessions(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  const Center(child: Text("No active sessions found", style: TextStyle(color: Colors.grey))),
                ],
              ),
            );
          }

          final currentSession = sessions.firstWhere((s) => s['is_current'] ?? false, orElse: () => null);
          final otherSessions = sessions.where((s) => !(s['is_current'] ?? false)).toList();

          return RefreshIndicator(
            color: const Color(0xFF2FA4E7),
            onRefresh: () => controller.loadSessions(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                if (currentSession != null) ...[
                  _buildSectionHeader("THIS DEVICE"),
                  _buildSessionCard(currentSession, isCurrent: true),
                  const SizedBox(height: 24),
                ],
                
                if (otherSessions.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader("OTHER SESSIONS"),
                      TextButton(
                        onPressed: () => _confirmTerminateAll(context, controller),
                        child: const Text(
                          "Terminate All Others",
                          style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: otherSessions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = otherSessions[index];
                      return _buildSessionCard(session, isCurrent: false, controller: controller);
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      "No other active sessions detected.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
      ),
    );
  }

  Widget _buildSessionCard(dynamic session, {required bool isCurrent, SessionController? controller}) {
    final String deviceModel = session['device_model'] ?? 'Unknown Device';
    final String systemVersion = session['system_version'] ?? '';
    final String appName = session['application_name'] ?? 'Telegram Client';
    final String appVersion = session['application_version'] ?? '';
    final String ip = session['ip_address'] ?? '0.0.0.0';
    final String country = session['location'] ?? 'Unknown Location';
    final int lastActive = session['last_active_date'] ?? 0;
    final int sessionId = session['id'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "$deviceModel ($systemVersion)",
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2FA4E7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Online",
                    style: TextStyle(color: Color(0xFF2FA4E7), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                  onPressed: () => _confirmTerminateSingle(context, controller!, sessionId, deviceModel),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "$appName $appVersion",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: Colors.grey[500], size: 14),
              const SizedBox(width: 4),
              Text(
                "$country • IP: $ip",
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.grey[500], size: 14),
              const SizedBox(width: 4),
              Text(
                "Last active: ${_formatDate(lastActive)}",
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmTerminateSingle(BuildContext context, SessionController controller, int sessionId, String deviceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        title: const Text("Terminate Session?"),
        content: Text("Are you sure you want to log out from $deviceName?"),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Terminate", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              controller.terminateSession(sessionId);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmTerminateAll(BuildContext context, SessionController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        title: const Text("Terminate All Other Sessions?"),
        content: const Text("Are you sure you want to log out all other devices logged into this account?"),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Terminate All", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              controller.terminateAllOtherSessions();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
