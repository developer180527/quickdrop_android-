import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'package:flutter/services.dart';
import 'package:nsd/nsd.dart';
import 'package:permission_handler/permission_handler.dart';

class AndroidServer {
  Registration? _registration;
  ServerSocket? _serverSocket;
  Function(String)? onStatusChange;

  Future<void> startServer() async {
    if (!await _checkPermissions()) {
      onStatusChange?.call("❌ Storage/Network Permission Denied");
      return;
    }

    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      int realPort = _serverSocket!.port;

      debugPrint("Android Server bound to port: $realPort");
      onStatusChange?.call("Ready. Waiting for Mac...");

      _registration = await register(
        Service(
          name: 'QuickDrop Android',
          type: '_quickdrop._tcp',
          port: realPort,
        ),
      );

      _serverSocket!.listen(handleConnection);
    } catch (e) {
      debugPrint("Server Start Error: $e");
      onStatusChange?.call("Server Error: $e");
      stopServer();
    }
  }

  Future<bool> _checkPermissions() async {
    var status = await Permission.storage.request();
    await Permission.notification.request();
    return !status.isPermanentlyDenied;
  }

  void handleConnection(Socket socket) async {
    onStatusChange?.call("⚡️ Mac Connecting...");

    // 🚀 SPEED TWEAK: Disable Nagle's algorithm
    socket.setOption(SocketOption.tcpNoDelay, true);

    List<int> headerBuffer = [];
    int? headerSize;
    int? fileSize;
    String? fileName;
    IOSink? fileSink;
    int bytesReceived = 0;

    // 🏎️ PERFORMANCE TUNING
    int bytesUnflushed = 0;
    // LowerCamelCase for linter compliance
    // 32MB Buffer before flushing to disk
    const int flushThreshold = 32 * 1024 * 1024;

    try {
      // Natural Backpressure Loop
      await for (var data in socket) {
        // 1. Header Logic
        if (fileSink == null) {
          headerBuffer.addAll(data);

          if (headerSize == null && headerBuffer.length >= 4) {
            ByteData byteData = ByteData.sublistView(
              Uint8List.fromList(headerBuffer.sublist(0, 4)),
            );
            headerSize = byteData.getUint32(0, Endian.little);
            headerBuffer.removeRange(0, 4);
          }

          if (headerSize != null &&
              fileName == null &&
              headerBuffer.length >= headerSize!) {
            String jsonString = utf8.decode(
              headerBuffer.sublist(0, headerSize!),
            );
            List<int> leftoverBytes = headerBuffer.sublist(headerSize!);
            headerBuffer.clear();

            var metadata = jsonDecode(jsonString);
            fileName = metadata['filename'];
            fileSize = metadata['size'];

            debugPrint("🔍 Incoming: $fileName ($fileSize bytes)");
            onStatusChange?.call("Receiving $fileName...");

            String path = '/storage/emulated/0/Download/$fileName';
            // FIXED: Removed bufferSize parameter
            fileSink = File(path).openWrite(mode: FileMode.write);

            if (leftoverBytes.isNotEmpty) {
              fileSink.add(leftoverBytes);
              bytesReceived += leftoverBytes.length;
              bytesUnflushed += leftoverBytes.length;
            }
          }
        }
        // 2. High Speed Body Logic
        else {
          fileSink.add(data);
          bytesReceived += data.length;
          bytesUnflushed += data.length;

          // Only stop the network to flush when we hit 32MB
          if (bytesUnflushed >= flushThreshold) {
            await fileSink.flush();
            bytesUnflushed = 0;
          }
        }

        // 3. Completion Logic
        if (fileSize != null && bytesReceived >= fileSize!) {
          debugPrint("✅ 100% Received. Final Flush...");
          await fileSink!.flush();
          await fileSink!.close();
          fileSink = null;

          socket.add(utf8.encode("ACK"));
          await socket.flush();

          if (fileName != null) {
            _scanFile('/storage/emulated/0/Download/$fileName');
          }
          onStatusChange?.call("✅ Saved $fileName");

          // Wait for ACK to leave the radio
          await Future.delayed(const Duration(milliseconds: 200));
          break;
        }
      }
    } catch (e) {
      debugPrint("Processing Error: $e");
    } finally {
      debugPrint("🔌 Closing Socket.");
      await fileSink?.close();
      socket.destroy();
    }
  }

  Future<void> _scanFile(String path) async {
    try {
      const platform = MethodChannel('com.example.quickdrop/share');
      await platform.invokeMethod('scanFile', {'path': path});
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
  }

  Future<void> stopServer() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
    await _serverSocket?.close();
    _serverSocket = null;
  }
}
