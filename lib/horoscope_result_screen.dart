import 'package:flutter/material.dart';
import 'dart:convert'; // Para codificar e decodificar JSON
import 'package:http/http.dart' as http; // Para fazer as requisições HTTP
import 'package:intl/intl.dart'; // Para formatar a data do dia

// --- MODELO DE DADOS PARA O HORÓSCOPO ---
// Classe para armazenar os dados estruturados recebidos da API
class HoroscopeData {
  final String ascendente;
  final String previsaoAmor;
  final String palavraChaveAmor;
  final String previsaoDinheiro;
  final String palavraChaveDinheiro;
  final String previsaoTrabalho;
  final String palavraChaveTrabalho;
  final String previsaoEnergia;
  final String palavraChaveEnergia;

  HoroscopeData({
    required this.ascendente,
    required this.previsaoAmor,
    required this.palavraChaveAmor,
    required this.previsaoDinheiro,
    required this.palavraChaveDinheiro,
    required this.previsaoTrabalho,
    required this.palavraChaveTrabalho,
    required this.previsaoEnergia,
    required this.palavraChaveEnergia,
  });

  // Factory constructor para criar uma instância a partir de um JSON
  factory HoroscopeData.fromJson(Map<String, dynamic> json) {
    return HoroscopeData(
      ascendente: json['ascendente'] ?? 'Não calculado',
      previsaoAmor: json['previsao_amor'] ?? '',
      palavraChaveAmor: json['palavra_chave_amor'] ?? '',
      previsaoDinheiro: json['previsao_dinheiro'] ?? '',
      palavraChaveDinheiro: json['palavra_chave_dinheiro'] ?? '',
      previsaoTrabalho: json['previsao_trabalho'] ?? '',
      palavraChaveTrabalho: json['palavra_chave_trabalho'] ?? '',
      previsaoEnergia: json['previsao_energia'] ?? '',
      palavraChaveEnergia: json['palavra_chave_energia'] ?? '',
    );
  }
}

// --- TELA PARA EXIBIR O RESULTADO ---

class HoroscopeResultScreen extends StatefulWidget {
  final String name;
  final String birthDate;
  final String birthTime;
  final String birthPlace;
  final String? zodiacSign;

  const HoroscopeResultScreen({super.key, required this.name, required this.birthDate, required this.birthTime, required this.birthPlace, this.zodiacSign});

  @override
  State<HoroscopeResultScreen> createState() => _HoroscopeResultScreenState();
}

class _HoroscopeResultScreenState extends State<HoroscopeResultScreen> {
  bool _isLoading = true;
  HoroscopeData? _horoscopeData; // Armazena os dados estruturados
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateHoroscope();
  }

  Future<void> _generateHoroscope() async {
    const apiKey = 'AIzaSyCc3Rwz6RBQ9Ayo5EngCH5JO8fbefJ2tUI';
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$apiKey');

    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Prompt atualizado para solicitar uma resposta JSON estruturada
    final prompt =
        """
      Com base nos dados a seguir:
      - Nome: ${widget.name}
      - Signo Solar: ${widget.zodiacSign}
      - Data de Nascimento: ${widget.birthDate}
      - Hora de Nascimento: ${widget.birthTime}
      - Local de Nascimento: ${widget.birthPlace}

      Calcule o signo ascendente e crie um horóscopo para o dia de hoje ($today).
      Responda EXCLUSIVAMENTE em formato JSON, seguindo este modelo:
      {
        "ascendente": "Seu Ascendente",
        "previsao_amor": "Previsão de no máximo 4 linhas para o amor.",
        "palavra_chave_amor": "Uma palavra",
        "previsao_dinheiro": "Previsão de no máximo 4 linhas para o dinheiro.",
        "palavra_chave_dinheiro": "Uma palavra",
        "previsao_trabalho": "Previsão de no máximo 4 linhas para o trabalho.",
        "palavra_chave_trabalho": "Uma palavra",
        "previsao_energia": "Previsão de no máximo 4 linhas para a energia do dia.",
        "palavra_chave_energia": "Uma palavra"
      }
    """;

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
      // Configuração para garantir que a resposta seja JSON
      "generationConfig": {"responseMimeType": "application/json"},
    });

    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);

      if (response.statusCode == 200) {
        // Decodifica a resposta JSON
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String textResponse = data['candidates'][0]['content']['parts'][0]['text'];
        final Map<String, dynamic> horoscopeJson = jsonDecode(textResponse);

        setState(() {
          // Cria o objeto HoroscopeData a partir do JSON
          _horoscopeData = HoroscopeData.fromJson(horoscopeJson);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Erro ao gerar horóscopo: ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro de conexão ou formato da resposta.\n$e';
        _isLoading = false;
      });
    }
  }

  // Widget para construir cada seção do horóscopo
  Widget _buildSection({required IconData icon, required String title, required String prediction, required String keyword}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(prediction, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8), height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text("Palavra-chave: ", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(keyword, style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 20),
            Text('Gerando seu horóscopo...', textAlign: TextAlign.center),
          ],
        ),
      );
    } else if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 20),
            const Text('Ops! Algo deu errado', style: TextStyle(fontSize: 22, color: Colors.redAccent)),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      );
    } else if (_horoscopeData != null) {
      // Constrói a nova UI com os dados recebidos
      final data = _horoscopeData!;
      final today = DateFormat('dd/MM/yyyy').format(DateTime.now());

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Imagem de fundo do Card
                  Image.network(
                    'https://placehold.co/600x400/000000/FFFFFF?text=Imagem+Cosmica',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: Colors.grey[800],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                  // Gradiente para escurecer a imagem e dar legibilidade
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.black.withOpacity(0.8), Colors.transparent], begin: Alignment.center, end: Alignment.topCenter),
                    ),
                  ),
                  // Textos sobrepostos
                  Positioned(
                    bottom: 20,
                    child: Column(
                      children: [
                        Text(
                          "Signo Solar: ${widget.zodiacSign ?? 'N/A'}",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 5)]),
                        ),
                        Text(
                          "Ascendente: ${data.ascendente}",
                          style: const TextStyle(fontSize: 18, color: Colors.white70, shadows: [Shadow(blurRadius: 5)]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "🔮 Horóscopo - $today",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 16),
            _buildSection(icon: Icons.favorite_border, title: "Amor", prediction: data.previsaoAmor, keyword: data.palavraChaveAmor),
            _buildSection(icon: Icons.attach_money, title: "Dinheiro", prediction: data.previsaoDinheiro, keyword: data.palavraChaveDinheiro),
            _buildSection(icon: Icons.work_outline, title: "Trabalho", prediction: data.previsaoTrabalho, keyword: data.palavraChaveTrabalho),
            _buildSection(icon: Icons.star_border, title: "Energia do Dia", prediction: data.previsaoEnergia, keyword: data.palavraChaveEnergia),
          ],
        ),
      );
    }
    return const Center(child: Text("Nenhum resultado para exibir."));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
      body: _buildBodyContent(),
    );
  }
}
