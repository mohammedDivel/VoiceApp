import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  String? _resultFilePath;

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _selectedFilePath = path;
        _resultFilePath = null;
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
        _resultFilePath = null;
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

        final dir = await getTemporaryDirectory();
        final savedPath =
            '${dir.path}/voicenote_${DateTime.now().millisecondsSinceEpoch}.ogg';
        File resultFile = File(savedPath);
        await resultFile.writeAsBytes(responseData);

        setState(() {
          _resultFilePath = savedPath;
        });
      } else {
        _showError("فشل التحويل (خطأ من الخادم: ${response.statusCode})");
      }
    } catch (e) {
      _showError("حدث خطأ في الاتصال بالخادم");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _playResult() async {
    if (_resultFilePath != null) {
      await _audioPlayer.play(DeviceFileSource(_resultFilePath!));
    }
  }

  Future<void> _shareResult() async {
    if (_resultFilePath != null) {
      await Share.shareXFiles(
        [XFile(_resultFilePath!)],
        text: 'Voice Note',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Note AI'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 90,
                icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic),
                color: _isRecording ? Colors.red : Colors.deepPurple,
                onPressed: _toggleRecording,
              ),
              Text(
                _isRecording ? "جاري التسجيل..." : "اضغط للتسجيل",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text("أو اختر ملف صوتي"),
                onPressed: _pickAudioFile,
              ),
              if (_selectedFilePath != null) ...[
                const SizedBox(height: 12),
                const Icon(Icons.check_circle, color: Colors.green),
                const Text("تم اختيار ملف"),
              ],
              const SizedBox(height: 32),
              if (_selectedFilePath != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("تحويل إلى Voice Note"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _convertVoice,
                ),
              if (_resultFilePath != null) ...[
                const SizedBox(height: 32),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.graphic_eq, size: 40, color: Colors.deepPurple),
                        const SizedBox(height: 8),
                        const Text(
                          "الـ Voice Note جاهز!",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text("تشغيل"),
                              onPressed: _playResult,
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.share),
                              label: const Text("مشاركة"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _shareResult,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
