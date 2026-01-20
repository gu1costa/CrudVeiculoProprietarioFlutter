import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/proprietario_api.dart';
import '../../api/veiculo_api.dart';
import '../../models/Proprietario.dart';
import '../../models/Veiculo.dart';
import 'veiculo_form_screen.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class VeiculosListScreen extends StatefulWidget {
  const VeiculosListScreen({super.key});

  @override
  State<VeiculosListScreen> createState() => _VeiculosListScreenState();
}

class _VeiculosListScreenState extends State<VeiculosListScreen> {
  static const primary = Color(0xFF0D47A1);
  static const softBg = Color(0xFFEAF2FF);
  static const danger = Color(0xFFE53935);

  final _placaFormKey = GlobalKey<FormState>();
  final _cpfFormKey = GlobalKey<FormState>();

  final _placaController = TextEditingController();
  final _cpfController = TextEditingController();

  bool carregandoPlaca = false;
  bool carregandoCpf = false;

  List<Veiculo> resultadoPlaca = [];
  List<Veiculo> resultadoCpf = [];

  Proprietario? proprietarioEncontrado;

  List<Proprietario> _listaProprietariosCache = [];
  final Map<String, Proprietario> _donoPorPlaca = {};

  String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

  bool placaValida(String placa) {
    final p = placa.toUpperCase();
    final antigo = RegExp(r'^[A-Z]{3}[0-9]{4}$');
    final mercosul = RegExp(r'^[A-Z]{3}[0-9]{1}[A-Z]{1}[0-9]{2}$');
    return antigo.hasMatch(p) || mercosul.hasMatch(p);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _carregarProprietariosCache() async {
    if (_listaProprietariosCache.isNotEmpty) return;
    _listaProprietariosCache = await ProprietarioApi.listarTodos();
  }

  Future<Proprietario?> _resolverDonoPorPlaca(String placa) async {
    final key = placa.trim().toUpperCase();

    if (_donoPorPlaca.containsKey(key)) return _donoPorPlaca[key];

    await _carregarProprietariosCache();

    for (final p in _listaProprietariosCache) {
      try {
        final veiculos = await VeiculoApi.listarPorProprietario(p.id);
        final encontrou = veiculos.any((v) => v.placa.trim().toUpperCase() == key);

        if (encontrou) {
          _donoPorPlaca[key] = p;
          return p;
        }
      } catch (_) {}
    }

    return null;
  }

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
      final filtrados = lista.where((v) => v.placa.trim().toUpperCase() == placa).toList();

      setState(() => resultadoPlaca = filtrados);

      if (filtrados.isEmpty) {
        _snack("Nenhum veículo encontrado para $placa.");
        return;
      }

      for (final v in filtrados) {
        await _resolverDonoPorPlaca(v.placa);
      }

      setState(() {});
    } catch (e) {
      _snack("Erro ao buscar por placa: $e");
    } finally {
      if (mounted) setState(() => carregandoPlaca = false);
    }
  }

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
        _snack("Nenhum proprietário encontrado.");
        return;
      }

      proprietarioEncontrado = p;
      final veiculos = await VeiculoApi.listarPorProprietario(p.id);

      setState(() => resultadoCpf = veiculos);

      if (veiculos.isEmpty) _snack("Esse proprietário não possui veículos.");
    } catch (e) {
      _snack("Erro ao buscar por CPF/CNPJ: $e");
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

      if (proprietarioEncontrado != null) {
        await pesquisarPorCpfCnpj();
      } else if (_placaController.text.trim().isNotEmpty) {
        await pesquisarPorPlaca();
      }
    } catch (e) {
      _snack("Erro ao excluir: $e");
    }
  }

  Widget _resultItem(Veiculo v, {Proprietario? dono, int? proprietarioIdFixo}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7E6FF)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.06),
          )
        ],
      ),
      child: ListTile(
        leading: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: softBg,
          ),
          child: const Icon(Icons.directions_car, color: primary),
        ),
        title: Text(
          v.placa,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("RENAVAM: ${v.renavam}"),
            if (dono != null) ...[
              const SizedBox(height: 4),
              Text("Proprietário: ${dono.nome} • ${dono.cpfCnpj}"),
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
                icon: const Icon(Icons.edit, color: primary),
                onPressed: () => editarVeiculo(v, proprietarioIdFixo: proprietarioIdFixo),
              ),
              IconButton(
                tooltip: "Excluir",
                icon: const Icon(Icons.delete_outline, color: danger),
                onPressed: () => deletarVeiculo(v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchCard({
    required Widget child,
    required String title,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7E6FF)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.06),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: softBg,
                ),
                child: Icon(icon, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
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
        backgroundColor: softBg,
        appBar: AppBar(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          title: const Text("Consulta de Veículos"),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFD6E4FF),
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Placa"),
              Tab(text: "CPF/CNPJ"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          onPressed: () async {
            final alterou = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const VeiculoFormScreen()),
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
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _searchCard(
                    title: "Buscar por placa",
                    icon: Icons.search,
                    child: Form(
                      key: _placaFormKey,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _placaController,
                              decoration: InputDecoration(
                                labelText: "Placa",
                                hintText: "ABC1234 ou ABC1D23",
                                filled: true,
                                fillColor: softBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
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
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: carregandoPlaca ? null : pesquisarPorPlaca,
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.search),
                            label: const Text("Buscar"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (carregandoPlaca) const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: resultadoPlaca.map((v) {
                        final dono = _donoPorPlaca[v.placa.trim().toUpperCase()];
                        return _resultItem(v, dono: dono);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _searchCard(
                    title: "Buscar por CPF/CNPJ do proprietário",
                    icon: Icons.badge,
                    child: Form(
                      key: _cpfFormKey,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cpfController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "CPF/CNPJ",
                                hintText: "Somente números (11 ou 14 dígitos)",
                                filled: true,
                                fillColor: softBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(14),
                              ],
                              validator: (v) {
                                final valor = onlyDigits((v ?? "").trim());
                                if (valor.isEmpty) return "Informe o CPF/CNPJ";
                                if (valor.length != 11 && valor.length != 14) {
                                  return "CPF 11 dígitos ou CNPJ 14 dígitos";
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: carregandoCpf ? null : pesquisarPorCpfCnpj,
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.search),
                            label: const Text("Buscar"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (carregandoCpf) const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: resultadoCpf.map((v) {
                        return _resultItem(
                          v,
                          proprietarioIdFixo: proprietarioEncontrado?.id,
                        );
                      }).toList(),
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
