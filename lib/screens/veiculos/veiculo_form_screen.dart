import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_exception.dart';
import '../../api/proprietario_api.dart';
import '../../api/veiculo_api.dart';
import '../../models/Proprietario.dart';
import '../../models/Veiculo.dart';

class VeiculoFormScreen extends StatefulWidget {
  final Veiculo? veiculo;
  final int? proprietarioIdFixo;

  const VeiculoFormScreen({
    super.key,
    this.veiculo,
    this.proprietarioIdFixo,
  });

  @override
  State<VeiculoFormScreen> createState() => _VeiculoFormScreenState();
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _VeiculoFormScreenState extends State<VeiculoFormScreen> {
  final formKey = GlobalKey<FormState>();

  final placaController = TextEditingController();
  final renavamController = TextEditingController();

  bool carregando = false;

  int? proprietarioSelecionadoId;
  late Future<List<Proprietario>> proprietariosFuture;

  String? renavamErroServidor;

  bool get editando => widget.veiculo != null;

  String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  bool placaValida(String placa) {
    final p = placa.toUpperCase();

    final antigo = RegExp(r'^[A-Z]{3}[0-9]{4}$'); // ABC1234
    final mercosul = RegExp(r'^[A-Z]{3}[0-9]{1}[A-Z]{1}[0-9]{2}$'); // ABC1D23

    return antigo.hasMatch(p) || mercosul.hasMatch(p);
  }

  @override
  void initState() {
    super.initState();

    if (!editando && widget.proprietarioIdFixo == null) {
      proprietariosFuture = ProprietarioApi.listarTodos();
    }

    if (editando) {
      placaController.text = widget.veiculo!.placa;
      renavamController.text = onlyDigits("${widget.veiculo!.renavam}");
    }
  }

  Future<void> salvar() async {
    FocusScope.of(context).unfocus();

    // ✅ remove SnackBars antigas que possam estar aparecendo
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (renavamErroServidor != null) {
      setState(() => renavamErroServidor = null);
    }

    if (!formKey.currentState!.validate()) return;

    final placa = placaController.text.trim().toUpperCase();
    final renavam = onlyDigits(renavamController.text.trim());

    final donoId = widget.proprietarioIdFixo ?? proprietarioSelecionadoId;

    if (!editando && donoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione um proprietário")),
      );
      return;
    }

    setState(() => carregando = true);

    try {
      if (editando) {
        await VeiculoApi.atualizar(
          id: widget.veiculo!.id,
          placa: placa,
          renavam: renavam,
        );
      } else {
        await VeiculoApi.criar(
          proprietarioId: donoId!,
          placa: placa,
          renavam: renavam,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      // ✅ sempre garante que não vai empilhar snackbars
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // ✅ se for ApiException, usa só a mensagem
      if (e is ApiException) {
        final mensagem = e.message;
        final lower = mensagem.toLowerCase();

        // ✅ captura qualquer variação possível do seu backend
        final renavamDuplicado = lower.contains("renavam") &&
            (lower.contains("já cadastrado") ||
                lower.contains("ja cadastrado") ||
                lower.contains("já existe") ||
                lower.contains("ja existe") ||
                lower.contains("cadastrado") ||
                lower.contains("exist") ||
                lower.contains("duplicate") ||
                lower.contains("taken"));

        // ✅ RENAVAM duplicado: mostra SOMENTE no campo (sem SnackBar)
        if (renavamDuplicado) {
          setState(() => renavamErroServidor = "RENAVAM já cadastrado.");
          formKey.currentState!.validate();
          return;
        }

        // ✅ outros erros: SnackBar normal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagem)),
        );
        return;
      }

      // ✅ erros não tratados
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar: $e")),
      );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  void dispose() {
    placaController.dispose();
    renavamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mostrarDropdown = !editando && widget.proprietarioIdFixo == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? "Editar Veículo" : "Novo Veículo"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              if (mostrarDropdown) ...[
                FutureBuilder<List<Proprietario>>(
                  future: proprietariosFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          "Erro ao carregar proprietários: ${snapshot.error}",
                        ),
                      );
                    }

                    final lista = snapshot.data ?? [];

                    if (lista.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text("Nenhum proprietário encontrado."),
                      );
                    }

                    return DropdownButtonFormField<int>(
                      value: proprietarioSelecionadoId,
                      decoration: const InputDecoration(
                        labelText: "Proprietário",
                        border: OutlineInputBorder(),
                      ),
                      items: lista
                          .map(
                            (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text("${p.nome} (${p.cpfCnpj})"),
                        ),
                      )
                          .toList(),
                      onChanged: (value) {
                        setState(() => proprietarioSelecionadoId = value);
                      },
                      validator: (v) =>
                      v == null ? "Selecione um proprietário" : null,
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: placaController,
                decoration: const InputDecoration(
                  labelText: "Placa",
                  border: OutlineInputBorder(),
                  hintText: "ABC1234 ou ABC1D23",
                ),
                inputFormatters: [
                  UpperCaseTextFormatter(),
                  LengthLimitingTextInputFormatter(7),
                ],
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  final valor = (v ?? "").trim().toUpperCase();

                  if (valor.isEmpty) return "Informe a placa";
                  if (valor.length != 7) return "A placa deve ter 7 caracteres";
                  if (!placaValida(valor)) return "Placa inválida";

                  return null;
                },
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: renavamController,
                decoration: const InputDecoration(
                  labelText: "RENAVAM",
                  border: OutlineInputBorder(),
                  hintText: "11 dígitos",
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                onChanged: (_) {
                  if (renavamErroServidor != null) {
                    setState(() => renavamErroServidor = null);
                  }
                },
                validator: (v) {
                  final valor = onlyDigits((v ?? "").trim());

                  if (valor.isEmpty) return "Informe o renavam";
                  if (valor.length != 11) return "RENAVAM deve ter 11 dígitos";
                  if (renavamErroServidor != null) return renavamErroServidor;

                  return null;
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: carregando ? null : salvar,
                  child: carregando
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(editando ? "Salvar alterações" : "Salvar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
