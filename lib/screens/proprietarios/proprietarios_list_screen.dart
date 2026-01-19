import 'package:flutter/material.dart';

import '../../api/proprietario_api.dart';
import '../../api/veiculo_api.dart';
import '../../models/Proprietario.dart';
import '../../models/Veiculo.dart';

import '../veiculos/veiculo_form_screen.dart';
import 'proprietario_form_screen.dart';

class ProprietariosListScreen extends StatefulWidget {
  const ProprietariosListScreen({super.key});

  @override
  State<ProprietariosListScreen> createState() =>
      _ProprietariosListScreenState();
}

class _ProprietariosListScreenState extends State<ProprietariosListScreen> {
  late Future<List<Proprietario>> proprietariosFuture;

  final Map<int, Future<List<Veiculo>>> _veiculosFuturePorProp = {};

  @override
  void initState() {
    super.initState();
    carregar();
  }

  void carregar() {
    proprietariosFuture = ProprietarioApi.listarTodos();
    _veiculosFuturePorProp.clear();
    setState(() {});
  }

  Future<List<Veiculo>> _getVeiculosFuture(int proprietarioId) {
    return _veiculosFuturePorProp.putIfAbsent(
      proprietarioId,
          () => VeiculoApi.listarPorProprietario(proprietarioId),
    );
  }

  void _refreshVeiculos(int proprietarioId) {
    setState(() {
      _veiculosFuturePorProp[proprietarioId] =
          VeiculoApi.listarPorProprietario(proprietarioId);
    });
  }

  // =========================
  // CRUD PROPRIETÁRIO
  // =========================

  Future<void> criarProprietario() async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProprietarioFormScreen(),
      ),
    );

    if (alterou == true) carregar();
  }

  Future<void> editarProprietario(Proprietario p) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProprietarioFormScreen(proprietario: p),
      ),
    );

    if (alterou == true) carregar();
  }

  Future<void> deletarProprietario(Proprietario p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Excluir proprietário"),
        content: Text("Deseja excluir o proprietário ${p.nome}?"),
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
      await ProprietarioApi.deletar(p.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Proprietário excluído ✅")),
      );

      carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao excluir: $e")),
      );
    }
  }

  // =========================
  // CRUD VEÍCULO
  // =========================

  Future<void> criarVeiculo(Proprietario p) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VeiculoFormScreen(
          proprietarioIdFixo: p.id,
        ),
      ),
    );

    if (alterou == true) {
      _refreshVeiculos(p.id);
    }
  }

  Future<void> editarVeiculo(Proprietario p, Veiculo v) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VeiculoFormScreen(
          veiculo: v,
          proprietarioIdFixo: p.id,
        ),
      ),
    );

    if (alterou == true) {
      _refreshVeiculos(p.id);
    }
  }

  Future<void> deletarVeiculo(Proprietario p, Veiculo v) async {
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veículo excluído ✅")),
      );

      _refreshVeiculos(p.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao excluir: $e")),
      );
    }
  }

  Widget buildVeiculos(Proprietario p) {
    return FutureBuilder<List<Veiculo>>(
      future: _getVeiculosFuture(p.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text("Erro ao carregar veículos: ${snapshot.error}"),
          );
        }

        final veiculos = snapshot.data ?? [];

        if (veiculos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text("Nenhum veículo cadastrado."),
          );
        }

        return Column(
          children: veiculos.map((v) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Card(
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
                          onPressed: () => editarVeiculo(p, v),
                        ),
                        IconButton(
                          tooltip: "Excluir",
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => deletarVeiculo(p, v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Proprietários"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Atualizar",
            icon: const Icon(Icons.refresh),
            onPressed: carregar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: criarProprietario,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Proprietario>>(
        future: proprietariosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }

          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }

          final lista = snapshot.data ?? [];

          if (lista.isEmpty) {
            return const Center(child: Text("Nenhum proprietário cadastrado."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = lista[index];

              return Card(
                child: ExpansionTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(p.nome),
                  subtitle: Text("${p.cpfCnpj} • ${p.endereco}"),
                  trailing: SizedBox(
                    width: 110,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: "Editar proprietário",
                          icon: const Icon(Icons.edit),
                          onPressed: () => editarProprietario(p),
                        ),
                        IconButton(
                          tooltip: "Excluir proprietário",
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => deletarProprietario(p),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => criarVeiculo(p),
                          icon: const Icon(Icons.add),
                          label: const Text("Adicionar veículo"),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    buildVeiculos(p),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
