import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/Proprietario.dart';
import 'api_exception.dart';

class ProprietarioApi {
  // ✅ Celular físico: IP da sua máquina
  // ✅ Emulador Android: http://10.0.2.2:8080
  static const String baseUrl = "http://192.168.1.209:8080";

  static Future<List<Proprietario>> listarTodos() async {
    final url = Uri.parse("$baseUrl/proprietarios");

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      final List lista = decoded is List
          ? decoded
          : (decoded["data"] ??
          decoded["content"] ??
          decoded["proprietarios"] ??
          []);

      return lista.map((e) => Proprietario.fromJson(e)).toList();
    }

    throw _handleError(res);
  }

  static Future<Proprietario?> buscarPorCpfCnpj(String cpfCnpj) async {
    final url = Uri.parse("$baseUrl/proprietarios/cpf/$cpfCnpj");

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return Proprietario.fromJson(decoded);
    }

    if (res.statusCode == 404) return null;

    throw _handleError(res);
  }

  static Future<void> criar({
    required String cpfCnpj,
    required String nome,
    required String endereco,
  }) async {
    final url = Uri.parse("$baseUrl/proprietarios/cadastrar");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "cpfCnpj": cpfCnpj,
        "nome": nome,
        "endereco": endereco,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) return;

    throw _handleError(res);
  }

  static Future<void> atualizar({
    required int id,
    required String cpfCnpj,
    required String nome,
    required String endereco,
  }) async {
    final url = Uri.parse("$baseUrl/proprietarios/atualizar/$id");

    final res = await http.put(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "cpfCnpj": cpfCnpj,
        "nome": nome,
        "endereco": endereco,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 204) return;

    throw _handleError(res);
  }

  static Future<void> deletar(int id) async {
    final url = Uri.parse("$baseUrl/proprietarios/deletar/$id");

    final res = await http.delete(url);

    if (res.statusCode == 200 || res.statusCode == 204) return;

    throw _handleError(res);
  }

  // ============================
  // ERROS (inclui CPF/CNPJ duplicado)
  // ============================

  static ApiException _handleError(http.Response res) {
    final status = res.statusCode;
    final msg = _parseMessage(res.body);

    if (status == 409) {
      return ApiException("CPF/CNPJ já cadastrado.", status);
    }

    if (status == 422 || status == 400) {
      final lower = msg.toLowerCase();
      if (lower.contains("já cadastrado") ||
          lower.contains("ja cadastrado") ||
          lower.contains("já existe") ||
          lower.contains("ja existe") ||
          lower.contains("exist") ||
          lower.contains("duplicate") ||
          lower.contains("taken")) {
        return ApiException("CPF/CNPJ já cadastrado.", status);
      }

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
