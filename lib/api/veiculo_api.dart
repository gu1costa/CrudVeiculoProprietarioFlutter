import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/Veiculo.dart';
import 'api_exception.dart';

class VeiculoApi {
  static const String baseUrl = "http://192.168.1.209:8080";

  static Future<List<Veiculo>> listarTodos() async {
    final url = Uri.parse("$baseUrl/veiculos");

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      final List lista = decoded is List
          ? decoded
          : (decoded["data"] ?? decoded["content"] ?? decoded["veiculos"] ?? []);

      return lista.map((e) => Veiculo.fromJson(e)).toList();
    }

    throw _handleError(res);
  }

  static Future<Veiculo?> buscarPorId(int id) async {
    final url = Uri.parse("$baseUrl/veiculos/$id");

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return Veiculo.fromJson(decoded);
    }

    if (res.statusCode == 404) return null;

    throw _handleError(res);
  }

  // ✅ Como você usa veículos por proprietário na tela expandida,
  // é MUITO provável que exista esse GET também:
  // GET /veiculos/proprietario/{id}
  static Future<List<Veiculo>> listarPorProprietario(int proprietarioId) async {
    final url = Uri.parse("$baseUrl/veiculos/proprietario/$proprietarioId");

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      final List lista = decoded is List
          ? decoded
          : (decoded["data"] ?? decoded["content"] ?? decoded["veiculos"] ?? []);

      return lista.map((e) => Veiculo.fromJson(e)).toList();
  }

    throw _handleError(res);
  }

  static Future<void> criar({
    required int proprietarioId,
    required String placa,
    required String renavam,
  }) async {
    // ✅ SUA ROTA REAL
    final url = Uri.parse("$baseUrl/veiculos/proprietario/$proprietarioId");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "placa": placa,
        "renavam": renavam,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) return;

    throw _handleError(res);
  }

  static Future<void> atualizar({
    required int id,
    required String placa,
    required String renavam,
  }) async {
    final url = Uri.parse("$baseUrl/veiculos/atualizar/$id");

    final res = await http.put(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "placa": placa,
        "renavam": renavam,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 204) return;

    throw _handleError(res);
  }

  static Future<void> deletar(int id) async {
    final url = Uri.parse("$baseUrl/veiculos/deletar/$id");

    final res = await http.delete(url);

    if (res.statusCode == 200 || res.statusCode == 204) return;

    throw _handleError(res);
  }

  // ============================
  // ERROS
  // ============================

  static ApiException _handleError(http.Response res) {
    final status = res.statusCode;
    final msg = _parseMessage(res.body);

    if (status == 409) {
      return ApiException("Veículo já cadastrado.", status);
    }

    if (status == 422 || status == 400) {
      return ApiException(msg.isEmpty ? "Dados inválidos." : msg, status);
    }

    return ApiException(
      msg.isEmpty ? "Erro ao processar requisição (HTTP $status)." : msg,
      status,
    );
  }

  static String _parseMessage(String body) {
    if (body.trim().isEmpty) return "";

    try {
      final decoded = jsonDecode(body);

      if (decoded is Map) {
        if (decoded["message"] != null) return decoded["message"].toString();
        if (decoded["error"] != null) return decoded["error"].toString();

        final msgs = <String>[];
        decoded.forEach((k, v) {
          if (v is List) {
            for (final item in v) {
              msgs.add("$k: $item");
            }
          } else {
            msgs.add("$k: $v");
          }
        });
        return msgs.join("\n");
      }

      if (decoded is List) return decoded.join("\n");
    } catch (_) {}

    return body;
  }
}
