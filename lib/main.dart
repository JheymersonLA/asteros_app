import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'horoscope_result_screen.dart';
import 'package:http/http.dart' as http; // Para a lista de cidades
import 'dart:convert'; // Para a lista de cidades
import 'package:geolocator/geolocator.dart'; // Para o GPS
import 'package:geocoding/geocoding.dart'; // Para o GPS

void main() {
  runApp(const AsterosApp());
}

class AsterosApp extends StatelessWidget {
  const AsterosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asteros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(primary: Colors.amber),
      ),
      home: const BirthInfoScreen(),
    );
  }
}

class BirthInfoScreen extends StatefulWidget {
  const BirthInfoScreen({super.key});

  @override
  State<BirthInfoScreen> createState() => _BirthInfoScreenState();
}

class _BirthInfoScreenState extends State<BirthInfoScreen> {
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _birthTimeController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _zodiacSign;

  // --- NOVAS VARIÁVEIS DE ESTADO ---
  List<String> _allCities = []; // Armazena a lista de cidades vinda da API
  bool _isFetchingCities = true; // Controla o loading das cidades

  final Map<String, IconData> _zodiacIcons = {
    'Áries': Icons.local_fire_department_outlined,
    'Touro': Icons.eco_outlined,
    'Gêmeos': Icons.people_alt_outlined,
    'Câncer': Icons.nightlight_round,
    'Leão': Icons.wb_sunny_outlined,
    'Virgem': Icons.grass_outlined,
    'Libra': Icons.scale_outlined,
    'Escorpião': Icons.water_drop_outlined,
    'Sagitário': Icons.explore_outlined,
    'Capricórnio': Icons.filter_hdr_outlined,
    'Aquário': Icons.air_outlined,
    'Peixes': Icons.waves_outlined,
  };

  @override
  void initState() {
    super.initState();
    _fetchCities(); // Busca as cidades ao iniciar a tela
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _birthTimeController.dispose();
    _birthPlaceController.dispose();
    super.dispose();
  }

  // --- FUNÇÃO PARA BUSCAR CIDADES NA API DO IBGE ---
  Future<void> _fetchCities() async {
    try {
      final response = await http.get(Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/municipios'));
      if (response.statusCode == 200) {
        List<dynamic> citiesJson = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _allCities = citiesJson.map((city) {
            final cityName = city['nome'] as String;
            final state = city['microrregiao']['mesorregiao']['UF']['sigla'] as String;
            return '$cityName, $state';
          }).toList();
          _allCities.sort(); // Opcional: ordena a lista alfabeticamente
          _isFetchingCities = false;
        });
      }
    } catch (e) {
      // Em caso de erro, continua com uma lista vazia e desativa o loading
      setState(() {
        _isFetchingCities = false;
      });
      print("Erro ao buscar cidades: $e");
    }
  }

  // --- FUNÇÃO PARA PEGAR A LOCALIZAÇÃO ATUAL ---
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serviço de localização desativado.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização negada.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização negada permanentemente.')));
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String? city = place.locality;
        String? state = place.administrativeArea;
        if (city != null && state != null) {
          setState(() {
            _birthPlaceController.text = "$city, $state";
          });
        }
      }
    } catch (e) {
      print("Erro ao obter localização: $e");
    }
  }

  String _getZodiacSign(DateTime date) {
    int day = date.day;
    int month = date.month;
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return 'Áries';
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return 'Touro';
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return 'Gêmeos';
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return 'Câncer';
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'Leão';
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return 'Virgem';
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return 'Libra';
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) return 'Escorpião';
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) return 'Sagitário';
    if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) return 'Capricórnio';
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return 'Aquário';
    if ((month == 2 && day >= 19) || (month == 3 && day <= 20)) return 'Peixes';
    return '';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
    if (picked != null) {
      setState(() {
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        _zodiacSign = _getZodiacSign(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        _birthTimeController.text = picked.format(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Horóscopo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gere seu horóscopo personalizado',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 48),

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome Completo',
                    border: const UnderlineInputBorder(),
                    suffixIcon: _zodiacSign != null && _zodiacIcons.containsKey(_zodiacSign) ? Icon(_zodiacIcons[_zodiacSign], color: Colors.amber) : null,
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Por favor, insira o nome.' : null,
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _birthDateController,
                        decoration: const InputDecoration(labelText: 'Data de Nascimento', border: UnderlineInputBorder()),
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        validator: (value) => (value == null || value.isEmpty) ? 'Selecione a data.' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _birthTimeController,
                        decoration: const InputDecoration(labelText: 'Hora de Nascimento', border: UnderlineInputBorder()),
                        readOnly: true,
                        onTap: () => _selectTime(context),
                        validator: (value) => (value == null || value.isEmpty) ? 'Selecione a hora.' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (_isFetchingCities) return const Iterable<String>.empty();
                    if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                    return _allCities.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (String selection) {
                    _birthPlaceController.text = selection;
                  },
                  fieldViewBuilder: (context, fieldController, fieldFocusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: _birthPlaceController,
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Local de Nascimento',
                        border: const UnderlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isFetchingCities) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            IconButton(icon: const Icon(Icons.my_location), onPressed: _getCurrentLocation),
                          ],
                        ),
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Por favor, insira o local.' : null,
                      onChanged: (text) => fieldController.text = text,
                    );
                  },
                ),
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HoroscopeResultScreen(name: _nameController.text, birthDate: _birthDateController.text, birthTime: _birthTimeController.text, birthPlace: _birthPlaceController.text, zodiacSign: _zodiacSign),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: const Text('Calcular', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
