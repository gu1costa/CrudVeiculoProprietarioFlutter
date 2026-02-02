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
  State<ProprietariosListScreen> createState() => _ProprietariosListScreenState();
}

class _ProprietariosListScreenState extends State<ProprietariosListScreen> {
  static const primary = Color(0xFF0D47A1);
  static const softBg = Color(0xFFEAF2FF);
  static const danger = Color(0xFFE53935);

  late Future<List<Proprietario>> proprietariosFuture;
  final Map<int, Future<List<Veiculo>>> _veiculosFuturePorProp = {};
  final TextEditingController _searchController = TextEditingController();
  List<Proprietario> _todosProprietarios = [];
  List<Proprietario> _proprietariosFiltrados = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void carregar() {
    proprietariosFuture = ProprietarioApi.listarTodos();
    _veiculosFuturePorProp.clear();
    setState(() {});
  }

  void _filtrarProprietarios(String query) {
    setState(() {
      _buscando = query.isNotEmpty;
      if (query.isEmpty) {
        _proprietariosFiltrados = [];
      } else {
        _proprietariosFiltrados = _todosProprietarios
            .where((p) => p.nome.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
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

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> criarProprietario() async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProprietarioFormScreen()),
    );

    if (alterou == true) carregar();
  }

  Future<void> editarProprietario(Proprietario p) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProprietarioFormScreen(proprietario: p)),
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
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ProprietarioApi.deletar(p.id);
      if (!mounted) return;
      _snack("Proprietário excluído ✅");
      carregar();
    } catch (e) {
      if (!mounted) return;
      _snack("Erro ao excluir: $e");
    }
  }

  Future<void> criarVeiculo(Proprietario p) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VeiculoFormScreen(proprietarioIdFixo: p.id),
      ),
    );

    if (alterou == true) _refreshVeiculos(p.id);
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

    if (alterou == true) _refreshVeiculos(p.id);
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
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await VeiculoApi.deletar(v.id);
      if (!mounted) return;
      _snack("Veículo excluído ✅");
      _refreshVeiculos(p.id);
    } catch (e) {
      if (!mounted) return;
      _snack("Erro ao excluir: $e");
    }
  }

  Widget buildVeiculos(Proprietario p) {
    return FutureBuilder<List<Veiculo>>(
      future: _getVeiculosFuture(p.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 10),
            child: LinearProgressIndicator(minHeight: 3),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              "Erro ao carregar veículos: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
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
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD7E6FF)),
                color: Colors.white,
              ),
              child: ListTile(
                leading: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: softBg,
                  ),
                  child: const Icon(Icons.directions_car, color: primary),
                ),
                title: Text(
                  v.placa,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                subtitle: Text("RENAVAM: ${v.renavam}"),
                trailing: SizedBox(
                  width: 110,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: "Editar",
                        icon: const Icon(Icons.edit, color: primary),
                        onPressed: () => editarVeiculo(p, v),
                      ),
                      IconButton(
                        tooltip: "Excluir",
                        icon: const Icon(Icons.delete_outline, color: danger),
                        onPressed: () => deletarVeiculo(p, v),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _headerCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color(0xFF1565C0)],
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.16),
            ),
            child: const Icon(Icons.badge, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Proprietários",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Gerencie proprietários e veículos",
                  style: TextStyle(color: Color(0xFFDCEBFF)),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: criarProprietario,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add),
            label: const Text("Novo"),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _filtrarProprietarios,
        decoration: InputDecoration(
          hintText: "Buscar proprietário...",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filtrarProprietarios('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text("DETRAN"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Atualizar",
            icon: const Icon(Icons.refresh),
            onPressed: carregar,
          ),
        ],
      ),
      body: Column(
        children: [
          _headerCard(),
          _searchBar(),
          Expanded(
            child: FutureBuilder<List<Proprietario>>(
              future: proprietariosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator(minHeight: 3);
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Erro: ${snapshot.error}"));
                }

                final lista = snapshot.data ?? [];
                _todosProprietarios = lista;
                final listaExibir = _buscando ? _proprietariosFiltrados : lista;

                if (listaExibir.isEmpty) {
                  return Center(
                    child: Text(
                      _buscando 
                          ? "Nenhum proprietário encontrado para '${_searchController.text}'."
                          : "Nenhum proprietário cadastrado."
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                  itemCount: listaExibir.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = listaExibir[index];

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                            color: Colors.black.withOpacity(0.06),
                          )
                        ],
                        border: Border.all(color: const Color(0xFFD7E6FF)),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        leading: Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: softBg,
                          ),
                          child: const Icon(Icons.person, color: primary),
                        ),
                        title: Text(
                          p.nome,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text("${p.cpfCnpj} • ${p.endereco}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: "Editar proprietário",
                              icon: const Icon(Icons.edit, color: primary),
                              onPressed: () => editarProprietario(p),
                            ),
                            IconButton(
                              tooltip: "Excluir proprietário",
                              icon: const Icon(Icons.delete_outline, color: danger),
                              onPressed: () => deletarProprietario(p),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => criarVeiculo(p),
                                style: FilledButton.styleFrom(
                                  backgroundColor: primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text("Adicionar veículo"),
                              ),
                            ),
                          ),
                          buildVeiculos(p),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
