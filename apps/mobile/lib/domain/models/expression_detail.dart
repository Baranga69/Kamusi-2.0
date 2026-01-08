class ExpressionDetail {
  ExpressionDetail({
    required this.id,
    required this.text,
    required this.meanings,
    required this.examples,
  });

  final String id;
  final String text;
  final List<Meaning> meanings;
  final List<Example> examples;
}

class Meaning {
  Meaning({required this.language, required this.text});

  final String language;
  final String text;
}

class Example {
  Example({required this.text});

  final String text;
}
