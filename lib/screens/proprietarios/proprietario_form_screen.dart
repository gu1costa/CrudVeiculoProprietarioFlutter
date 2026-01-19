import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_exception.dart';
import '../../api/proprietario_api.dart';
import '../../models/Proprietario.dart';

class ProprietarioFormScreen extends StatefulWidget {
  final Proprietario? proprietario;

  const ProprietarioFormScreen({super.key, this.proprietario});

  @override
  State<ProprietarioFormScreen> createState() => _ProprietarioFormScreenState();
}

class _ProprietarioFormScreenState extends State<ProprietarioFormScreen> {
  final formKey = GlobalKey<FormState>();

  final cpfController = TextEditingController();
  final nomeController = TextEditingController();
  final enderecoController = TextEditingController();

  bool carregando = false;

  String? cpfErroServidor;

  bool get editando => widget.proprietario != null;

  String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();

    if (editando) {
      cpfController.text = onlyDigits(widget.proprietario!.cpfCnpj);
      nomeController.text = widget.proprietario!.nome;
      enderecoController.text = widget.proprietario!.endereco;
    }
  }

  String? validarCpfCnpj(String? v) {
    final valor = onlyDigits((v ?? "").trim());

    if (valor.isEmpty) return "Informe o CPF/CNPJ";
    if (valor.length != 11 && valor.length != 14) {
      return "CPF deve ter 11 dígitos ou CNPJ 14 dígitos";
    }

    if (cpfErroServidor != null) return cpfErroServidor;

    return null;
  }

  Future<void> salvar() async {
    FocusScope.of(context).unfocus();

    cpfErroServidor = null;

    if (!formKey.currentState!.validate()) return;

    setState(() => carregando = true);

    try {
      final cpf = onlyDigits(cpfController.text.trim());
      final nome = nomeController.text.trim();
      final endereco = enderecoController.text.trim();

      if (editando) {
        await ProprietarioApi.atualizar(
          id: widget.proprietario!.id,
          cpfCnpj: cpf,
          nome: nome,
          endereco: endereco,
        );
      } else {
        await ProprietarioApi.criar(
          cpfCnpj: cpf,
          nome: nome,
          endereco: endereco,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      String mensagem = "Erro ao salvar.";

      if (e is ApiException) {
        mensagem = e.message;

        if (mensagem.toLowerCase().contains("já cadastrado")) {
          setState(() {
            cpfErroServidor = "CPF/CNPJ já cadastrado.";
          });

          formKey.currentState!.validate();
        }
      } else {
        mensagem = "Erro ao salvar: $e";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem)),
      );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  void dispose() {
    cpfController.dispose();
    nomeController.dispose();
    enderecoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? "Editar Proprietário" : "Novo Proprietário"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: cpfController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(14),
                ],
                decoration: const InputDecoration(
                  labelText: "CPF/CNPJ",
                  hintText: "Somente números (11 ou 14 dígitos)",
                ),
                onChanged: (_) {
                  if (cpfErroServidor != null) {
                    setState(() => cpfErroServidor = null);
                  }
                },
                validator: validarCpfCnpj,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: "Nome"),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Informe o nome" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: enderecoController,
                decoration: const InputDecoration(labelText: "Endereço"),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Informe o endereço"
                    : null,
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
