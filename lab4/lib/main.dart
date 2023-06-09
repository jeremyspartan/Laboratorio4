import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uni_links/uni_links.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

bool _initialUriIsHandled = false;

void main() => runApp(const MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  Uri? _latestUri;
  Object? _err;
  Position? _currentPosition;

  void _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  StreamSubscription? _sub;

  final _scaffoldKey = GlobalKey<FormState>();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      const baseUrl = 'https://host/lib/main';
      final name = _nameController.text;
      final email = _emailController.text;
      final phone = _phoneController.text;
      final address = _addressController.text;

      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'name': name,
          'email': email,
          'phone': phone,
          'address': address,
        },
      );
      if (kDebugMode) {
        print(uri);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
    _handleInitialUri();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleIncomingLinks() {
    if (!kIsWeb) {
      _sub = uriLinkStream.listen((Uri? uri) {
        if (!mounted) return;
        if (kDebugMode) {
          print('got uri: $uri');
        }
        setState(() {
          _latestUri = uri;
          _err = null;
        });
      }, onError: (Object err) {
        if (!mounted) return;
        if (kDebugMode) {
          print('got err: $err');
        }
        setState(() {
          _latestUri = null;
          if (err is FormatException) {
            _err = err;
          } else {
            _err = null;
          }
        });
      });
    }
  }

  Future<void> _handleInitialUri() async {
    if (!_initialUriIsHandled) {
      _initialUriIsHandled = true;
      try {
        final uri = await getInitialUri();
        if (uri == null) {
          if (kDebugMode) {
            print('no initial uri');
          }
        } else {
          if (kDebugMode) {
            print('got initial uri: $uri');
          }
        }
        if (!mounted) return;
      } on PlatformException {
        if (kDebugMode) {
          print('falied to get initial uri');
        }
      } on FormatException catch (err) {
        if (!mounted) return;
        if (kDebugMode) {
          print('malformed initial uri');
        }
        setState(() => _err = err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queryParams = _latestUri?.queryParametersAll.entries.toList();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('uni_links example app'),
      ),
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8.0),
        children: [
          if (_err != null)
            ListTile(
              title: const Text('Error', style: TextStyle(color: Colors.red)),
              subtitle: Text('$_err'),
            ),
          if (!kIsWeb) ...[
            if (_latestUri != null)
              ExpansionTile(
                initiallyExpanded: true,
                title: const Text('Bienvenido'),
                children: queryParams == null
                    ? const [ListTile(dense: true, title: Text('null'))]
                    : [
                        for (final item in queryParams)
                          ListTile(
                            title: Text(item.key),
                            trailing: Text(item.value.join(', ')),
                          ),
                        const SizedBox(height: 16.0),
                        const Text(
                          'Mapa con ubicación actual',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16.0),
                        SizedBox(
                            height: 300, // Altura del mapa
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _currentPosition != null
                                    ? LatLng(_currentPosition!.latitude,
                                        _currentPosition!.longitude)
                                    : const LatLng(37.422,
                                        -122.084), // Ubicación inicial (latitud, longitud)
                                zoom: 14, // Nivel de zoom inicial
                              ),
                              myLocationEnabled:
                                  true, // Habilitar el botón "Mi ubicación"
                              myLocationButtonEnabled:
                                  true, // Mostrar el botón "Mi ubicación"
                              onMapCreated: (GoogleMapController controller) {},
                              markers: _currentPosition != null
                                  ? {
                                      Marker(
                                        markerId:
                                            const MarkerId('currentLocation'),
                                        position: LatLng(
                                            _currentPosition!.latitude,
                                            _currentPosition!.longitude),
                                      ),
                                    }
                                  : {},
                            )),
                      ],
              ),
          ],
          const SizedBox(height: 16.0),
          if (_latestUri == null) // Agregado para espaciado
            const Text(
              'Formulario', // Título del formulario
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          if (_latestUri == null) const SizedBox(height: 16.0),
          if (_latestUri == null)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  textWidget("nombre", _nameController),
                  textWidget("correo", _emailController),
                  textWidget("numero", _phoneController),
                  textWidget("direccion", _addressController),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Enviar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextFormField textWidget(String label, TextEditingController controller) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor, ingresa tu $label';
        }
        return null;
      },
      controller: controller,
    );
  }
}
