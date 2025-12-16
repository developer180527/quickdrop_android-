import 'package:flutter/services.dart'; // Import this for MethodChannel
import 'package:nsd/nsd.dart';
import 'package:flutter/foundation.dart';

class DiscoveryService extends ChangeNotifier {
  List<Service> foundServices = [];
  Discovery? discovery;

  // 1. Define the channel to talk to Kotlin
  static const platform = MethodChannel('com.example.quickdrop/share');

  Future<void> startScanning() async {
    try {
      // Start finding the Mac
      discovery = await startDiscovery(
        '_quickdrop._tcp',
        ipLookupType: IpLookupType.v4,
      );
      debugPrint("Discovery started...");

      discovery!.addListener(() {
        // 🔍 FILTER LOGIC: Remove the "QuickDrop Android" service (ourselves)
        // We use .contains() to catch cases like "QuickDrop Android (2)"
        final allServices = discovery!.services;

        foundServices = allServices.where((service) {
          // If the service name contains "Android", skip it!
          return service.name != null &&
              !service.name!.contains("QuickDrop Android");
        }).toList();

        // 2. CHECK: If we found a Mac, add it to the Native Share Sheet!
        for (var service in foundServices) {
          // Basic check to ensure we have a valid IP
          if (service.host != null) {
            _addToShareSheet(service.name ?? "MacBook", service.host!);
          }
        }

        notifyListeners();
      });
    } catch (e) {
      debugPrint("Discovery failed: $e");
    }
  }

  // 3. The Function that calls Kotlin
  Future<void> _addToShareSheet(String name, String ip) async {
    try {
      await platform.invokeMethod('addShareTarget', {
        "name": name, // This will appear in the share sheet
        "id": ip, // We use the IP as the ID for now
      });
      // debugPrint("Added $name to Android Share Sheet!");
      // Commented out to reduce console spam
    } catch (e) {
      debugPrint("Failed to add share target: $e");
    }
  }

  void stopScanning() {
    if (discovery != null) {
      stopDiscovery(discovery!);
    }
  }
}
