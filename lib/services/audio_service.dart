import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playMessageAudio(String messageId) async {
    final url = 'http://192.168.1.134:5075/api/messages/$messageId/audio';

    try {
      await _player.play(UrlSource(url));
    } catch (e) {
      print('Erro ao reproduzir áudio: $e');
    }
  }
}
