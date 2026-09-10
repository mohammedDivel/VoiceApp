import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(const VoiceNoteApp());
}

class VoiceNoteApp extends StatelessWidget {
  const VoiceNoteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Note AI',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const VoiceScreen(),
    );
  }
}

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({Key? key}) : super(key: key);

  @override
  _VoiceScreenState createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  String? _selectedFilePath;
  bool _isLoading = false;

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _selectedFilePath = path;
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: filePath);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _convertVoice() async {
    if (_selectedFilePath == null) return;
    setState(() => _isLoading = true);

    try {
      var uri = Uri.parse('https://voice-r761.onrender.com/convert-voice/');
      var request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('audio_file', _selectedFilePath!));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();

        File convertedFile = File('$_selectedFilePath-voicenote.ogg');
        await convertedFile.writeAsBytes(responseData);

        await _audioPlayer.play(DeviceFileSource(convertedFile.path));
      } else {
        print("خطأ من الخادم: ${response.statusCode}");
      }
    } catch (e) {
      print("حدث خطأ في الاتصال: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Note AI')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 80,
              icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic),
              color: _isRecording ? Colors.red : Colors.deepPurple,
              onPressed: _toggleRecording,
            ),
            const Text("اضغط للتسجيل"),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder),
              label: const Text("أو اختر ملف صوتي (MP3)"),
              onPressed: _pickAudioFile,
            ),
            const SizedBox(height: 10),
            if (_selectedFilePath != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("تم اختيار ملف", style: TextStyle(color: Colors.grey[700])),
              ),
            const SizedBox(height: 30),
            if (_selectedFilePath != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                onPressed: _isLoading ? null : _convertVoice,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("تحويل وإنشاء Voice Note", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}
