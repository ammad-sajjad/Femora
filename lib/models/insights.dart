// Response pieces shared by the risk models (PCOS, breast).

class RiskFactor {
  final String key;
  final String label;

  const RiskFactor({required this.key, required this.label});

  factory RiskFactor.fromJson(Map<String, dynamic> json) =>
      RiskFactor(key: json['key'] as String, label: json['label'] as String);
}

class Guidance {
  final String key; // icon hint
  final String title;
  final String description;

  const Guidance({required this.key, required this.title, required this.description});

  factory Guidance.fromJson(Map<String, dynamic> json) => Guidance(
        key: json['key'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
      );
}

enum RiskLevel { low, medium, high }
