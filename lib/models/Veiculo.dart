class Veiculo {
  final int id;
  final String placa;
  final String renavam;

  Veiculo({
    required this.id,
    required this.placa,
    required this.renavam,
  });

  factory Veiculo.fromJson(Map<String, dynamic> json) {
    final rawId = json["id"];

    return Veiculo(
      id: rawId is int ? rawId : int.parse(rawId.toString()),
      placa: json["placa"].toString(),
      renavam: json["renavam"].toString(),
    );
  }
}
