import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'discovery_service.dart';
import 'file_transfer.dart';
import 'android_server.dart';

void main() {
  runApp(const QuickDropApp());
}

class QuickDropApp extends StatelessWidget {
  const QuickDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. MATERIAL 3 THEME SETUP
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QuickDrop',
      themeMode: ThemeMode.system, // Auto Light/Dark
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4), // Modern Purple Seed
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFDF8FF),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF), // Dark mode variant
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF141218),
      ),
      home: const QuickDropHome(),
    );
  }
}

class QuickDropHome extends StatefulWidget {
  const QuickDropHome({super.key});

  @override
  State<QuickDropHome> createState() => _QuickDropHomeState();
}

class _QuickDropHomeState extends State<QuickDropHome>
    with SingleTickerProviderStateMixin {
  final DiscoveryService _discovery = DiscoveryService();
  final AndroidServer _server = AndroidServer();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Radar Animation Setup
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _discovery.addListener(() => setState(() {}));
    _discovery.startScanning();

    _server.startServer();
    _server.onStatusChange = (status) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    };
  }

  @override
  void dispose() {
    _discovery.stopScanning();
    _server.stopServer();
    _pulseController.dispose();
    super.dispose();
  }

  String? _getValidIp(Service service) {
    if (service.host != null && service.host!.contains('.'))
      return service.host;
    if (service.addresses != null) {
      for (var addr in service.addresses!) {
        if (addr.type == InternetAddressType.IPv4) return addr.address;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final deviceCount = _discovery.foundServices.length;

    return Scaffold(
      // 2. MODERN SCROLLABLE LAYOUT
      body: CustomScrollView(
        slivers: [
          // A. Large Collapsing Header
          SliverAppBar.large(
            floating: true,
            pinned: true,
            title: const Text("QuickDrop"),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  _discovery.stopScanning();
                  _discovery.startScanning();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // B. Status Status (Radar)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primaryContainer.withOpacity(
                            0.3 +
                                (_pulseController.value * 0.2), // Pulse opacity
                          ),
                        ),
                        child: Icon(
                          Icons.radar_rounded,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    deviceCount == 0
                        ? "Scanning for nearby devices..."
                        : "Found $deviceCount device(s)",
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // C. The Device List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: deviceCount == 0
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: SizedBox.shrink(), // Keeps it clean
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final service = _discovery.foundServices[index];
                      final ip = _getValidIp(service);
                      return _buildDeviceCard(service, ip, colorScheme);
                    }, childCount: deviceCount),
                  ),
          ),
        ],
      ),
    );
  }

  // 3. PREMIUM DEVICE CARD COMPONENT
  Widget _buildDeviceCard(Service service, String? ip, ColorScheme colors) {
    final bool isReady = ip != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surfaceContainer, // M3 Surface Tone
        borderRadius: BorderRadius.circular(24), // Super round corners
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: isReady ? () => _sendFile(ip, service.port!) : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.laptop_mac_rounded,
                    color: colors.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name?.replaceAll("QuickDrop ", "") ??
                            "Unknown Device",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isReady ? "Tap to send file" : "Connecting...",
                        style: TextStyle(
                          fontSize: 14,
                          color: isReady ? colors.green : colors.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: isReady ? colors.primary : colors.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendFile(String ip, int port) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      if (!mounted) return;

      try {
        await FileTransfer.sendFile(ip, port, file);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Sent successfully!")));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Failed: $e")));
      }
    }
  }
}

// Extension to simulate custom colors without full theme extension for brevity
extension CustomColors on ColorScheme {
  Color get green => brightness == Brightness.light
      ? const Color(0xFF2E7D32)
      : const Color(0xFF81C784);
}
