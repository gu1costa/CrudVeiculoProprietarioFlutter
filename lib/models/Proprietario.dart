class Proprietario {
  final int id;
  final String cpfCnpj;
  final String nome;
  final String endereco;

  Proprietario({
    required this.id,
    required this.cpfCnpj,
    required this.nome,
    required this.endereco,
  });

  factory Proprietario.fromJson(Map<String, dynamic> json) {
    final rawId = json["id"];

    return Proprietario(
      id: rawId is int ? rawId : int.parse(rawId.toString()),
      cpfCnpj: json["cpfCnpj"].toString(),
      nome: json["nome"].toString(),
      endereco: json["endereco"].toString(),
    );
  }
}
