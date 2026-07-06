import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

class OpenRouterService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  static const String _defaultModel = 'openrouter/free';

  const OpenRouterService();

  Future<String> sendChatMessage({
    required String apiKey,
    required List<ChatMessage> messages,
    String model = _defaultModel,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://batterie.app',
        'X-Title': 'Batterie Energy Health',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw OpenRouterException.fromResponse(response);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['choices'] as List)[0]['message']['content'] as String;
  }

  Future<EnergyAnalysis> analyzeEnergyLevels({
    required String apiKey,
    required String userInput,
  }) async {
    const systemPrompt =
        '''You are an energy health analyzer. Based on how the user describes their physical and mental state, assess their energy levels.

Respond with ONLY a valid JSON object — no markdown, no code fences, no extra text:
{
  "physicalPercent": 0.75,
  "brainPercent": 0.60,
  "status": "One or two sentences summarising current state.",
  "potential": "One or two sentences on what they can realistically handle today.",
  "recommendations": ["Short action 1", "Short action 2", "Short action 3"]
}

Rules:
- physicalPercent and brainPercent must be between 0.0 and 1.0
- Be empathetic, realistic, and concise
- recommendations must have exactly 3 items''';

    final response = await sendChatMessage(
      apiKey: apiKey,
      messages: [
        const ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: userInput),
      ],
    );

    try {
      final data = jsonDecode(response) as Map<String, dynamic>;
      return EnergyAnalysis.fromJson(data);
    } catch (_) {
      // If the model wrapped JSON in markdown, strip it
      final cleaned = response
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      return EnergyAnalysis.fromJson(data);
    }
  }
}

class OpenRouterException implements Exception {
  const OpenRouterException(this.message);

  final String message;

  factory OpenRouterException.fromResponse(http.Response response) {
    final errorMessage = _extractErrorMessage(response.body);

    if (response.statusCode == 402) {
      return const OpenRouterException(
        'OpenRouter says this API key has insufficient credits. Use a free '
        'model, add credits to the OpenRouter account, or check that this API '
        'key has a non-zero credit limit.',
      );
    }

    return OpenRouterException(
      errorMessage ?? 'OpenRouter request failed: HTTP ${response.statusCode}',
    );
  }

  static String? _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;

      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }

      final message = decoded['message'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {
      return body.trim().isEmpty ? null : body.trim();
    }

    return null;
  }

  @override
  String toString() => message;
}

class EnergyAnalysis {
  const EnergyAnalysis({
    required this.physicalPercent,
    required this.brainPercent,
    required this.status,
    required this.potential,
    required this.recommendations,
  });

  final double physicalPercent;
  final double brainPercent;
  final String status;
  final String potential;
  final List<String> recommendations;

  factory EnergyAnalysis.fromJson(Map<String, dynamic> json) {
    return EnergyAnalysis(
      physicalPercent:
          (json['physicalPercent'] as num).toDouble().clamp(0.0, 1.0),
      brainPercent: (json['brainPercent'] as num).toDouble().clamp(0.0, 1.0),
      status: json['status'] as String,
      potential: json['potential'] as String,
      recommendations: List<String>.from(json['recommendations'] as List),
    );
  }
}
