import 'package:flutter/material.dart';

import '../../api/proprietario_api.dart';
import '../../api/veiculo_api.dart';
import '../../models/Proprietario.dart';
import '../../models/Veiculo.dart';
import 'veiculo_form_screen.dart';

class VeiculosListScreen extends StatefulWidget {
  final int? proprietarioId;

  const VeiculosListScreen({super.key, this.proprietarioId});

  @override
  State<VeiculosListScreen> createState() => _VeiculosListScreenState();
}

class _VeiculosListScreenState extends State<VeiculosListScreen> {
  int? proprietarioSelecionadoId;

  Future<List<Proprietario>>? proprietariosFuture;
  Future<List<Veiculo>>? veiculosFuture;

  @override
  void initState() {
    super.initState();

    proprietarioSelecionadoId = widget.proprietarioId;

    if (proprietarioSelecionadoId == null) {
      proprietariosFuture = ProprietarioApi.listarTodos();
    } else {
      carregarVeiculos();
    }
  }

  void carregarVeiculos() {
    final id = proprietarioSelecionadoId;
    if (id == null) return;

    veiculosFuture = VeiculoApi.listarPorProprietario(id);
    setState(() {});
  }

  Future<void> abrirForm({Veiculo? veiculo}) async {
    final id = proprietarioSelecionadoId;
    if (id == null) return;

    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VeiculoFormScreen(
          veiculo: veiculo,
          proprietarioIdFixo: id,
        ),
      ),
    );

    if (alterou == true) carregarVeiculos();
  }

  Future<void> deletar(Veiculo v) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Excluir veículo"),
        content: Text("Deseja excluir o veículo ${v.placa}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await VeiculoApi.deletar(v.id);
      carregarVeiculos();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veículo excluído ✅")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao excluir: $e")),
      );
    }
  }

  Widget _buildEscolherProprietario() {
    return FutureBuilder<List<Proprietario>>(
      future: proprietariosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Center(
            child: Text("Erro ao carregar proprietários: ${snapshot.error}"),
          );
        }

        final lista = snapshot.data ?? [];

        if (lista.isEmpty) {
          return const Center(
            child: Text("Nenhum proprietário encontrado."),
          );
        }

        int? selecionado;

        return Column(
          children: [
            DropdownButtonFormField<int>(
              value: selecionado,
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
              onChanged: (value) => selecionado = value,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (selecionado == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Selecione um proprietário")),
                    );
                    return;
                  }

                  setState(() {
                    proprietarioSelecionadoId = selecionado;
                  });

                  carregarVeiculos();
                },
                child: const Text("Ver veículos"),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListaVeiculos() {
    return FutureBuilder<List<Veiculo>>(
      future: veiculosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return Center(child: Text("Erro: ${snapshot.error}"));
        }

        final lista = snapshot.data ?? [];

        if (lista.isEmpty) {
          return const Center(
            child: Text("Nenhum veículo cadastrado para esse proprietário."),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: lista.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final v = lista[i];

            return Card(
              child: ListTile(
                title: Text(v.placa),
                subtitle: Text("Renavam: ${v.renavam}"),
                trailing: SizedBox(
                  width: 110,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: "Editar",
                        icon: const Icon(Icons.edit),
                        onPressed: () => abrirForm(veiculo: v),
                      ),
                      IconButton(
                        tooltip: "Excluir",
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => deletar(v),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final escolhendoProprietario = proprietarioSelecionadoId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(escolhendoProprietario ? "Escolher Proprietário" : "Veículos"),
        centerTitle: true,
        actions: [
          if (!escolhendoProprietario)
            IconButton(
              tooltip: "Trocar proprietário",
              icon: const Icon(Icons.swap_horiz),
              onPressed: () {
                setState(() {
                  proprietarioSelecionadoId = null;
                  proprietariosFuture = ProprietarioApi.listarTodos();
                  veiculosFuture = null;
                });
              },
            ),
        ],
      ),
      floatingActionButton: escolhendoProprietario
          ? null
          : FloatingActionButton(
        onPressed: () => abrirForm(),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: escolhendoProprietario
            ? _buildEscolherProprietario()
            : _buildListaVeiculos(),
      ),
    );
  }
}
