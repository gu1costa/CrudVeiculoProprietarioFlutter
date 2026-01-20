import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/proprietario_api.dart';
import '../../api/veiculo_api.dart';
import '../../models/Proprietario.dart';
import '../../models/Veiculo.dart';
import 'veiculo_form_screen.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class VeiculosListScreen extends StatefulWidget {
  const VeiculosListScreen({super.key});

  @override
  State<VeiculosListScreen> createState() => _VeiculosListScreenState();
}

class _VeiculosListScreenState extends State<VeiculosListScreen> {
  final _placaFormKey = GlobalKey<FormState>();
  final _cpfFormKey = GlobalKey<FormState>();

  final _placaController = TextEditingController();
  final _cpfController = TextEditingController();

  bool carregandoPlaca = false;
  bool carregandoCpf = false;

  List<Veiculo> resultadoPlaca = [];
  List<Veiculo> resultadoCpf = [];

  Proprietario? proprietarioEncontrado;

  // cache de proprietários
  List<Proprietario> _listaProprietariosCache = [];

  // ✅ dono por placa (resolve o "não identificado")
  final Map<String, Proprietario> _donoPorPlaca = {};

  String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  bool placaValida(String placa) {
    final p = placa.toUpperCase();
    final antigo = RegExp(r'^[A-Z]{3}[0-9]{4}$'); // ABC1234
    final mercosul = RegExp(r'^[A-Z]{3}[0-9]{1}[A-Z]{1}[0-9]{2}$'); // ABC1D23
    return antigo.hasMatch(p) || mercosul.hasMatch(p);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _carregarProprietariosCache() async {
    if (_listaProprietariosCache.isNotEmpty) return;
    _listaProprietariosCache = await ProprietarioApi.listarTodos();
  }

  // ✅ Resolve dono do veículo pelo endpoint /veiculos/proprietario/{id}
  Future<Proprietario?> _resolverDonoPorPlaca(String placa) async {
    final key = placa.trim().toUpperCase();

    if (_donoPorPlaca.containsKey(key)) {
      return _donoPorPlaca[key];
    }

    await _carregarProprietariosCache();

    for (final p in _listaProprietariosCache) {
      try {
        final veiculos = await VeiculoApi.listarPorProprietario(p.id);

        final encontrou = veiculos.any(
              (v) => v.placa.trim().toUpperCase() == key,
        );

        if (encontrou) {
          _donoPorPlaca[key] = p;
          return p;
        }
      } catch (_) {
        // se um proprietário der erro, ignora e segue
      }
    }

    return null;
  }

  // ======================================
  // PESQUISA 1: POR PLACA (com proprietário)
  // ======================================
  Future<void> pesquisarPorPlaca() async {
    FocusScope.of(context).unfocus();
    if (!_placaFormKey.currentState!.validate()) return;

    final placa = _placaController.text.trim().toUpperCase();

    setState(() {
      carregandoPlaca = true;
      resultadoPlaca = [];
      proprietarioEncontrado = null;
      resultadoCpf = [];
    });

    try {
      final lista = await VeiculoApi.listarTodos();

      final filtrados = lista
          .where((v) => v.placa.trim().toUpperCase() == placa)
          .toList();

      setState(() => resultadoPlaca = filtrados);

      if (filtrados.isEmpty) {
        _showSnack("Nenhum veículo encontrado para a placa $placa.");
        return;
      }

      // ✅ garante que o dono vai aparecer
      for (final v in filtrados) {
        await _resolverDonoPorPlaca(v.placa);
      }

      setState(() {});
    } catch (e) {
      _showSnack("Erro ao buscar por placa: $e");
    } finally {
      if (mounted) setState(() => carregandoPlaca = false);
    }
  }

  // ======================================
  // PESQUISA 2: POR CPF/CNPJ (só veículos)
  // ======================================
  Future<void> pesquisarPorCpfCnpj() async {
    FocusScope.of(context).unfocus();
    if (!_cpfFormKey.currentState!.validate()) return;

    final cpfCnpj = onlyDigits(_cpfController.text.trim());

    setState(() {
      carregandoCpf = true;
      resultadoCpf = [];
      proprietarioEncontrado = null;
      resultadoPlaca = [];
    });

    try {
      final p = await ProprietarioApi.buscarPorCpfCnpj(cpfCnpj);

      if (p == null) {
        _showSnack("Nenhum proprietário encontrado para $cpfCnpj.");
        return;
      }

      proprietarioEncontrado = p;

      final veiculos = await VeiculoApi.listarPorProprietario(p.id);

      setState(() => resultadoCpf = veiculos);

      if (veiculos.isEmpty) {
        _showSnack("Esse proprietário não possui veículos cadastrados.");
      }
    } catch (e) {
      _showSnack("Erro ao buscar por CPF/CNPJ: $e");
    } finally {
      if (mounted) setState(() => carregandoCpf = false);
    }
  }

  Future<void> editarVeiculo(Veiculo v, {int? proprietarioIdFixo}) async {
    final alterou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VeiculoFormScreen(
          veiculo: v,
          proprietarioIdFixo: proprietarioIdFixo,
        ),
      ),
    );

    if (alterou == true) {
      _donoPorPlaca.clear();
      _listaProprietariosCache = [];

      if (proprietarioEncontrado != null) {
        await pesquisarPorCpfCnpj();
      } else if (_placaController.text.trim().isNotEmpty) {
        await pesquisarPorPlaca();
      }
    }
  }

  Future<void> deletarVeiculo(Veiculo v) async {
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

      _showSnack("Veículo excluído ✅");

      _donoPorPlaca.remove(v.placa.trim().toUpperCase());

      if (proprietarioEncontrado != null) {
        await pesquisarPorCpfCnpj();
      } else if (_placaController.text.trim().isNotEmpty) {
        await pesquisarPorPlaca();
      }
    } catch (e) {
      _showSnack("Erro ao excluir: $e");
    }
  }

  Widget _listaVeiculos(
      List<Veiculo> veiculos, {
        bool mostrarProprietario = false,
        int? proprietarioIdFixo,
      }) {
    if (veiculos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text("Nenhum resultado."),
      );
    }

    return Column(
      children: veiculos.map((v) {
        Proprietario? dono;

        if (mostrarProprietario) {
          dono = _donoPorPlaca[v.placa.trim().toUpperCase()];
        }

        return Card(
          child: ListTile(
            title: Text(v.placa),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("RENAVAM: ${v.renavam}"),
                if (mostrarProprietario) ...[
                  const SizedBox(height: 4),
                  if (dono != null)
                    Text("Proprietário: ${dono.nome} • ${dono.cpfCnpj}")
                  else
                    const Text("Proprietário: não identificado"),
                ],
              ],
            ),
            trailing: SizedBox(
              width: 110,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: "Editar",
                    icon: const Icon(Icons.edit),
                    onPressed: () => editarVeiculo(
                      v,
                      proprietarioIdFixo: proprietarioIdFixo,
                    ),
                  ),
                  IconButton(
                    tooltip: "Excluir",
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => deletarVeiculo(v),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _placaController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Pesquisar Veículos"),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Placa"),
              Tab(text: "CPF/CNPJ"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final alterou = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => const VeiculoFormScreen(),
              ),
            );

            if (alterou == true) {
              _donoPorPlaca.clear();
              _listaProprietariosCache = [];

              if (proprietarioEncontrado != null) {
                await pesquisarPorCpfCnpj();
              } else if (_placaController.text.trim().isNotEmpty) {
                await pesquisarPorPlaca();
              }
            }
          },
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [
            // TAB 1: PLACA (retorna veículo + dono)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Form(
                    key: _placaFormKey,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _placaController,
                            decoration: const InputDecoration(
                              labelText: "Placa",
                              hintText: "ABC1234 ou ABC1D23",
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9]'),
                              ),
                              UpperCaseTextFormatter(),
                              LengthLimitingTextInputFormatter(7),
                            ],
                            textCapitalization: TextCapitalization.characters,
                            validator: (v) {
                              final valor = (v ?? "").trim().toUpperCase();
                              if (valor.isEmpty) return "Informe a placa";
                              if (valor.length != 7) {
                                return "A placa deve ter 7 caracteres";
                              }
                              if (!placaValida(valor)) return "Placa inválida";
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: carregandoPlaca ? null : pesquisarPorPlaca,
                          icon: const Icon(Icons.search),
                          label: const Text("Buscar"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (carregandoPlaca) const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _listaVeiculos(
                        resultadoPlaca,
                        mostrarProprietario: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TAB 2: CPF/CNPJ (retorna só veículo)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Form(
                    key: _cpfFormKey,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cpfController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "CPF/CNPJ do proprietário",
                              hintText: "Somente números (11 ou 14 dígitos)",
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(14),
                            ],
                            validator: (v) {
                              final valor = onlyDigits((v ?? "").trim());
                              if (valor.isEmpty) return "Informe o CPF/CNPJ";
                              if (valor.length != 11 && valor.length != 14) {
                                return "CPF deve ter 11 dígitos ou CNPJ 14 dígitos";
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: carregandoCpf ? null : pesquisarPorCpfCnpj,
                          icon: const Icon(Icons.search),
                          label: const Text("Buscar"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (carregandoCpf) const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _listaVeiculos(
                        resultadoCpf,
                        mostrarProprietario: false,
                        proprietarioIdFixo: proprietarioEncontrado?.id,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
