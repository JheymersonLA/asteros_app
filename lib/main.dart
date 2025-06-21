import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
// import 'horoscope_result_screen.dart'; // Supondo que você tenha este arquivo
import 'package:http/http.dart' as http;
import 'dart:ui'; // Para ImageFilter
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Pacote para usar SVG
import 'dart:math'; // Usado para valores aleatórios

// --- DEFINIÇÃO DE CORES DO TEMA (ATUALIZADO) ---
const Color kBackgroundColor = Color(0xFF1B1C1B);
const Color kPrimaryTextColor = Color(0xFFD7D0C4);
// Cor secundária derivada da primária para manter a harmonia
const Color kSecondaryTextColor = Color(0xFF9E9A90);
const Color kButtonColor = Color(0xFFD7D0C4);
const Color kButtonTextColor = Color(0xFF1B1C1B);
// Cor para superfícies levemente elevadas, como o popup do Autocomplete
const Color kSlightlyElevatedColor = Color(0xFF2C2D2C);
const Color kDisabledButtonOutlineColor = Color.fromARGB(255, 146, 145, 144);

// --- CLASSE PARA OS ELEMENTOS ANIMADOS ---
class AnimatedParticle {
  final String svgAsset;
  late Offset position;
  late double size;
  late Offset velocity;
  final Random random;
  final Size screenSize;

  AnimatedParticle({required this.svgAsset, required this.random, required this.screenSize}) {
    _reset(isInitial: true);
  }

  // Reseta a partícula para uma nova posição e velocidade aleatória
  void _reset({bool isInitial = false}) {
    size = random.nextDouble() * 15 + 8; // Tamanho entre 8 e 23
    velocity = Offset(
      (random.nextDouble() * 0.2) - 0.1, // Velocidade X entre -0.1 e 0.1
      (random.nextDouble() * 0.2) - 0.1, // Velocidade Y entre -0.1 e 0.1
    );

    // Se for a primeira vez, espalha na tela. Senão, começa fora da tela.
    if (isInitial) {
      position = Offset(random.nextDouble() * screenSize.width, random.nextDouble() * screenSize.height);
    } else {
      // Começa de uma borda aleatória
      if (random.nextBool()) {
        position = Offset(random.nextBool() ? -size : screenSize.width + size, random.nextDouble() * screenSize.height);
      } else {
        position = Offset(random.nextDouble() * screenSize.width, random.nextBool() ? -size : screenSize.height + size);
      }
    }
  }

  // Atualiza a posição da partícula
  void update() {
    position = position + velocity;

    // Se sair da tela, reseta
    if (position.dx < -size || position.dx > screenSize.width + size || position.dy < -size || position.dy > screenSize.height + size) {
      _reset();
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AsterosApp());
}

class AsterosApp extends StatelessWidget {
  const AsterosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asteros',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBackgroundColor,
        fontFamily: 'Gilroy',
        primaryColor: kPrimaryTextColor,
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryTextColor,
          secondary: kSecondaryTextColor,
          surface: kBackgroundColor,
          background: kBackgroundColor,
          onPrimary: kButtonTextColor, // Cor do texto sobre a cor primária
          onSecondary: kButtonTextColor,
          onSurface: kPrimaryTextColor, // Cor do texto sobre superfícies
          onBackground: kPrimaryTextColor,
        ),
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

class _BirthInfoScreenState extends State<BirthInfoScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _birthTimeController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _zodiacSign;

  bool _formIsValid = false;
  List<String> _allCities = [];
  bool _isFetchingCities = true;

  // --- CONTROLE DE ANIMAÇÃO E PARTÍCULAS ---
  late AnimationController _animationController;
  final List<AnimatedParticle> _particles = [];
  final Random _random = Random();
  final List<String> _svgAssets = ['assets/svgs/star_1.svg', 'assets/svgs/star_2.svg', 'assets/svgs/moon.svg', 'assets/svgs/dot_fill.svg', 'assets/svgs/dot_line.svg'];

  // Mapa de ícones que usa caminhos para os arquivos SVG.
  final Map<String, String> _zodiacIcons = {
    'Peixes': 'assets/svgs/Peixes.svg',
    'Áries': 'assets/svgs/Áries.svg',
    'Touro': 'assets/svgs/Touro.svg',
    'Gêmeos': 'assets/svgs/Gêmeos.svg',
    'Câncer': 'assets/svgs/Câncer.svg',
    'Leão': 'assets/svgs/Leão.svg',
    'Virgem': 'assets/svgs/Virgem.svg',
    'Libra': 'assets/svgs/Libra.svg',
    'Escorpião': 'assets/svgs/Escorpião.svg',
    'Sagitário': 'assets/svgs/Sargitário.svg', // Conforme nome no arquivo da imagem
    'Capricórnio': 'assets/svgs/Carpicórnio.svg', // Conforme nome no arquivo da imagem
    'Aquário': 'assets/svgs/Aquário.svg',
  };

  @override
  void initState() {
    super.initState();
    _updateFormValidity();
    _fetchCities();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenSize = MediaQuery.of(context).size;
      setState(() {
        for (int i = 0; i < 15; i++) {
          _particles.add(AnimatedParticle(svgAsset: _svgAssets[i % _svgAssets.length], random: _random, screenSize: screenSize));
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _birthTimeController.dispose();
    _birthPlaceController.dispose();
    super.dispose();
  }

  void _updateFormValidity() {
    setState(() {
      _formIsValid = _nameController.text.isNotEmpty && _birthDateController.text.isNotEmpty && _birthTimeController.text.isNotEmpty && _birthPlaceController.text.isNotEmpty;
    });
  }

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
          _allCities.sort();
          _isFetchingCities = false;
        });
      } else {
        setState(() {
          _isFetchingCities = false;
        });
      }
    } catch (e) {
      setState(() {
        _isFetchingCities = false;
      });
      print("Erro ao buscar cidades: $e");
    }
  }

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
        String? city = place.locality ?? place.subAdministrativeArea;
        String? state = place.administrativeArea;
        if (city != null && state != null) {
          setState(() {
            _birthPlaceController.text = "$city, $state";
            _updateFormValidity();
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: kPrimaryTextColor, onPrimary: kBackgroundColor, onSurface: kPrimaryTextColor, surface: kBackgroundColor),
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kPrimaryTextColor)),
            dialogTheme: DialogThemeData(backgroundColor: kSlightlyElevatedColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = DateFormat('dd | MM | yyyy').format(picked);
        _zodiacSign = _getZodiacSign(picked);
        _updateFormValidity();
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(primary: kPrimaryTextColor, onPrimary: kBackgroundColor, surface: kBackgroundColor, onSurface: kPrimaryTextColor),
            dialogTheme: DialogThemeData(backgroundColor: kSlightlyElevatedColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthTimeController.text = picked.format(context);
        _updateFormValidity();
      });
    }
  }

  Widget _buildTextField({required String label, required TextEditingController controller, Widget? suffixIcon, bool readOnly = false, VoidCallback? onTap, String? Function(String?)? validator, void Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kSecondaryTextColor, fontSize: 16),
        floatingLabelStyle: const TextStyle(color: kSecondaryTextColor),
        suffixIcon: suffixIcon,
        border: const UnderlineInputBorder(borderSide: BorderSide(color: kSecondaryTextColor)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kSecondaryTextColor)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kPrimaryTextColor)),
      ),
      style: const TextStyle(color: kPrimaryTextColor, fontSize: 18),
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- BACKGROUND ANIMADO ---
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              for (var particle in _particles) {
                particle.update();
              }
              return Stack(
                children: _particles.map((p) {
                  return Positioned(
                    left: p.position.dx,
                    top: p.position.dy,
                    child: SvgPicture.asset(p.svgAsset, width: p.size, height: p.size, colorFilter: const ColorFilter.mode(kSecondaryTextColor, BlendMode.srcIn)),
                  );
                }).toList(),
              );
            },
          ),
          // --- EFEITO DE BLUR SOBRE O FUNDO ---
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
            child: Container(
              // Adicionar uma leve sobreposição de cor melhora a legibilidade do texto
              // que ficará por cima, sem esconder completamente o fundo.
              color: Colors.black.withOpacity(0.25),
            ),
          ),
          // ------------------------
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 40.0),
                        child: Center(child: SvgPicture.asset('assets/svgs/Logo.svg', height: 38, colorFilter: const ColorFilter.mode(kPrimaryTextColor, BlendMode.srcIn))),
                      ),
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text(
                          'O que os astros dizem hoje para você?',
                          style: TextStyle(color: kPrimaryTextColor, fontSize: 40, fontWeight: FontWeight.w900, height: 1.2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: kSecondaryTextColor, fontSize: 14, height: 1.4),
                          children: const [
                            TextSpan(text: 'Astrologia + Inteligência Artificial '),
                            WidgetSpan(child: Icon(Icons.auto_awesome, color: kSecondaryTextColor, size: 18)),
                            TextSpan(text: '\nUm horóscopo feito só para você.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      // O suffixIcon agora tem tamanho fixo de 22x22.
                      _buildTextField(
                        label: 'Nome',
                        controller: _nameController,
                        suffixIcon: _zodiacSign != null && _zodiacIcons.containsKey(_zodiacSign)
                            ? Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: SvgPicture.asset(_zodiacIcons[_zodiacSign]!, width: 18, height: 18, colorFilter: const ColorFilter.mode(kSecondaryTextColor, BlendMode.srcIn)),
                              )
                            : null,
                        onChanged: (_) => _updateFormValidity(),
                        validator: (value) => (value == null || value.isEmpty) ? 'Por favor, insira o nome.' : null,
                      ),
                      const SizedBox(height: 24),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField(label: 'Aniversário', controller: _birthDateController, readOnly: true, onTap: () => _selectDate(context), validator: (value) => (value == null || value.isEmpty) ? 'Selecione a data.' : null),
                            ),
                            const SizedBox(width: 8),
                            const VerticalDivider(color: kSecondaryTextColor, thickness: 1, indent: 10, endIndent: 10),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTextField(
                                label: 'Hora de nascimento',
                                controller: _birthTimeController,
                                readOnly: true,
                                onTap: () => _selectTime(context),
                                validator: (value) => (value == null || value.isEmpty) ? 'Selecione a hora.' : null,
                              ),
                            ),
                          ],
                        ),
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
                          FocusScope.of(context).unfocus();
                          _updateFormValidity();
                        },
                        fieldViewBuilder: (context, fieldController, fieldFocusNode, onFieldSubmitted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (fieldController.text != _birthPlaceController.text) {
                              fieldController.text = _birthPlaceController.text;
                            }
                          });
                          return TextFormField(
                            controller: _birthPlaceController,
                            focusNode: fieldFocusNode,
                            onChanged: (text) {
                              _updateFormValidity();
                            },
                            decoration: InputDecoration(
                              labelText: 'Onde você nasceu?',
                              labelStyle: const TextStyle(color: kSecondaryTextColor, fontSize: 16),
                              floatingLabelStyle: const TextStyle(color: kSecondaryTextColor),
                              suffixIcon: IconButton(
                                icon: SvgPicture.asset('assets/svgs/location.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(kSecondaryTextColor, BlendMode.srcIn)),
                                onPressed: _getCurrentLocation,
                              ),
                              border: const UnderlineInputBorder(borderSide: BorderSide(color: kSecondaryTextColor)),
                              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kSecondaryTextColor)),
                              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kPrimaryTextColor)),
                            ),
                            style: const TextStyle(color: kPrimaryTextColor, fontSize: 18),
                            validator: (value) => (value == null || value.isEmpty) ? 'Por favor, insira o local.' : null,
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              color: kSlightlyElevatedColor,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final String option = options.elementAt(index);
                                    return InkWell(
                                      onTap: () => onSelected(option),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(option, style: const TextStyle(color: kPrimaryTextColor)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _formIsValid
                              ? () {
                                  if (_formKey.currentState!.validate()) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            HoroscopeResultScreen(name: _nameController.text, birthDate: _birthDateController.text, birthTime: _birthTimeController.text, birthPlace: _birthPlaceController.text, zodiacSign: _zodiacSign),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          style: ButtonStyle(
                            elevation: MaterialStateProperty.all(0),
                            padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 18)),
                            shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            backgroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                              if (states.contains(MaterialState.disabled)) {
                                return Colors.transparent; // Fundo transparente quando desabilitado
                              }
                              return kButtonColor; // Cor de fundo quando habilitado
                            }),
                            side: MaterialStateProperty.resolveWith<BorderSide>((Set<MaterialState> states) {
                              if (states.contains(MaterialState.disabled)) {
                                return const BorderSide(color: kDisabledButtonOutlineColor, width: 1.0); // Borda quando desabilitado
                              }
                              return BorderSide.none; // Sem borda quando habilitado
                            }),
                            foregroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                              if (states.contains(MaterialState.disabled)) {
                                return kDisabledButtonOutlineColor; // Cor do texto quando desabilitado
                              }
                              return kButtonTextColor; // Cor do texto quando habilitado
                            }),
                          ),
                          child: const Text('Horóscopo de hoje', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Tela de placeholder para o resultado ---
class HoroscopeResultScreen extends StatelessWidget {
  final String name;
  final String birthDate;
  final String birthTime;
  final String birthPlace;
  final String? zodiacSign;

  const HoroscopeResultScreen({super.key, required this.name, required this.birthDate, required this.birthTime, required this.birthPlace, this.zodiacSign});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text('Seu Horóscopo', style: TextStyle(color: kPrimaryTextColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: kPrimaryTextColor),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Resultados para $name...',
            style: TextStyle(color: kPrimaryTextColor, fontSize: 22),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
