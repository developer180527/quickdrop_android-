import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

class FileTransfer {
  /// Connects to the Mac and sends a file
  static Future<void> sendFile(String ip, int port, File file) async {
    Socket? socket;

    try {
      print("Connecting to $ip:$port...");
      socket = await Socket.connect(ip, port);
      print("Connected!");

      // 1. Prepare Metadata
      String filename = file.uri.pathSegments.last;
      int fileSize = await file.length();

      Map<String, dynamic> metadata = {"filename": filename, "size": fileSize};

      String jsonHeader = jsonEncode(metadata);
      List<int> headerBytes = utf8.encode(jsonHeader);
      int headerLength = headerBytes.length;

      // 2. Prepare the 4-byte Length Prefix (Little Endian for Mac Apple Silicon)
      ByteData lengthData = ByteData(4);
      lengthData.setUint32(0, headerLength, Endian.little);

      // 3. SEND: Header Length (4 bytes)
      socket.add(lengthData.buffer.asUint8List());

      // 4. SEND: JSON Header
      socket.add(headerBytes);

      // 5. SEND: The File Body (Streamed to avoid memory crash on big files)
      print("Sending file body...");
      await socket.addStream(file.openRead());

      print("File Sent Successfully!");
      await socket.flush();
    } catch (e) {
      print("Error sending file: $e");
    } finally {
      socket?.destroy();
    }
  }
}
