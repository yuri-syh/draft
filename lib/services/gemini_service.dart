import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'package:image_picker/image_picker.dart';

class GeminiService {
  static const String apiKey = '';
  static const String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  static List<Map<String, dynamic>> _formatMessages(List<ChatMessage> messages) {
    return messages.map((msg) {
      return {
        'role': msg.role == 'user' ? 'user' : 'model',
        'parts': <Map<String, dynamic>>[
          {'text': msg.text}
        ],
      };
    }).toList();
  }


  static Future<String> sendMultiTurnMessage(
      List<ChatMessage> conversationHistory,
      String personaPrompt,
      String firstInteraction, {
        XFile? imageFile,
      }) async {
    try {
      // BAGONG INSTRUCTION: Language Auto-Detection & Mirroring
      const String autoDetectInstruction = """
STRICT RULE: Automatically detect the language used by the user. 
- If the user speaks in Tagalog/Filipino, respond in Tagalog/Filipino.
- If the user speaks in English, respond in English.
- If the user uses Taglish, respond in Taglish.
Always match the tone and language of the user's latest message.
""";

      final fullInstruction = """
$autoDetectInstruction

$personaPrompt

PERMANENT MEMORY (First Interaction): "$firstInteraction"

STRICT RULE: If the user asks what their first question was, or if they ask if you remember them after they deleted the history, you MUST use the "PERMANENT MEMORY" above to answer them accurately.
""";

      List<Map<String, dynamic>> contents = _formatMessages(conversationHistory);

      if (imageFile != null) {
        Uint8List imageBytes;

        // SAFETY CHECK for Flutter Web (blob dies after refresh)
        if (kIsWeb) {
          try {
            imageBytes = await imageFile.readAsBytes();
          } catch (e) {
            return '⚠️ The selected image is no longer available. Please re-upload the image.';
          }
        } else {
          imageBytes = await imageFile.readAsBytes();
        }

        final String base64Image = base64Encode(imageBytes);

        if (contents.isNotEmpty && contents.last['role'] == 'user') {
          (contents.last['parts'] as List).add({
            'inline_data': {
              'mime_type': imageFile.mimeType ?? 'image/jpeg',
              'data': base64Image,
            }
          });
        }
      }


      final response = await http.post(
        Uri.parse('$apiUrl?key=$apiKey'),
        headers: {'Content-type': 'application/json'},
        body: jsonEncode({
          'contents': contents,
          'system_instruction': {
            'parts': [{'text': fullInstruction}]
          },
          'generationConfig': {
            'temperature': 0.8,
            'topK': 1,
            'topP': 1,
            'maxOutputTokens': 300,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return 'Error: ${response.statusCode}';
      }
    } catch (e) {
      return e.toString().contains('Image')
          ? e.toString()
          : 'Network error. Please try again.';
    }

  }
}