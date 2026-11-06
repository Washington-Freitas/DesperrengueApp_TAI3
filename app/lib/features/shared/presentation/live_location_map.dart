import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/geocode_models.dart';
import '../../../core/models/scheduling_models.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/utils/geo.dart';
import 'service_map_widgets.dart' show MapAttribution, buildTileLayer;

/// Fonte da posição do usuário em tempo real (produção: `geolocator`).
typedef UserPositionStream = Stream<GeoFix> Function();

/// Resolve um endereço em coordenadas (produção: Nominatim/OSM).
typedef AddressResolver = Future<GeocodeHit?> Function(String addressLine, String? summary);

/// Stream de GPS real. Lança [LocationUnavailable] se o serviço/permissão não estiverem
/// disponíveis. Funciona no Web/PWA (API de geolocalização do navegador) e nativo.
Stream<GeoFix> geolocatorPositionStream() async* {
  if (!await Geolocator.isLocationServiceEnabled()) throw const LocationUnavailable('Ative o GPS/localização do aparelho.');
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw const LocationUnavailable('Permissão de localização negada. Mostrando só o endereço.');
  }
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3),
  ).map((p) => GeoFix(p.latitude, p.longitude, accuracyM: p.accuracy));
}

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Mapa interativo (OpenStreetMap + GPS em tempo real) do endereço do serviço, aberto a
/// partir da seção "Localização" da Revisão e do detalhe do pedido.
///
/// Mostra o marcador exato do endereço (coordenadas já conhecidas ou geocodificadas) e a
/// posição VIVA do usuário, com círculo de precisão e distância em linha reta.
class LiveLocationMapSheet extends StatefulWidget {
  const LiveLocationMapSheet({
    super.key,
    required this.addressLine,
    this.summary,
    this.latitude,
    this.longitude,
    this.positionStream,
    this.resolver,
    this.tileLayer,
  });

  final String addressLine;
  final String? summary;

  /// Coordenadas já conhecidas do endereço (evita geocodificar de novo).
  final double? latitude;
  final double? longitude;

  /// Injetáveis (testes).
  final UserPositionStream? positionStream;
  final AddressResolver? resolver;
  final Widget? tileLayer;

  static Future<void> show(
    BuildContext context, {
    required String addressLine,
    String? summary,
    double? latitude,
    double? longitude,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: LiveLocationMapSheet(addressLine: addressLine, summary: summary, latitude: latitude, longitude: longitude),
        ),
      );

  @override
  State<LiveLocationMapSheet> createState() => _LiveLocationMapSheetState();
}

class _LiveLocationMapSheetState extends State<LiveLocationMapSheet> {
  final _map = MapController();
  StreamSubscription<GeoFix>? _sub;
  LatLng? _dest;
  DestinationPrecision _precision = DestinationPrecision.house;
  GeoFix? _me;
  String? _gpsNote;
  bool _resolving = false;
  bool _destFailed = false;
  bool _fitted = false;

  static const _fallback = LatLng(-21.7900318, -46.5647928);

  @override
  void initState() {
    super.initState();
    if (widget.latitude != null && widget.longitude != null) {
      _dest = LatLng(widget.latitude!, widget.longitude!);
    } else {
      _resolveDestination();
    }
    _startGps();
  }

  Future<void> _resolveDestination() async {
    setState(() => _resolving = true);
    try {
      final resolver = widget.resolver ?? ((line, summary) => GeocodingService().geocode(line, summary: summary));
      final hit = await resolver(widget.addressLine, widget.summary);
      if (!mounted) return;
      setState(() {
        if (hit == null) {
          _destFailed = true;
        } else {
          _dest = LatLng(hit.lat, hit.lng);
          _precision = hit.precision;
        }
      });
      _fit();
    } catch (_) {
      if (mounted) setState(() => _destFailed = true);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _startGps() {
    try {
      _sub = (widget.positionStream ?? geolocatorPositionStream)().listen(
        (fix) {
          if (!mounted) return;
          setState(() {
            _me = fix;
            _gpsNote = null;
          });
          if (!_fitted) _fit();
        },
        onError: (Object e) {
          if (mounted) setState(() => _gpsNote = e is LocationUnavailable ? e.message : 'Não foi possível acompanhar o seu GPS.');
        },
      );
    } catch (e) {
      _gpsNote = 'Não foi possível acompanhar o seu GPS.';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _fit() {
    final pts = <LatLng>[?_dest, if (_me != null) LatLng(_me!.lat, _me!.lng)];
    if (pts.isEmpty) return;
    try {
      if (pts.length == 1) {
        _map.move(pts.first, 17);
      } else {
        _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(64), maxZoom: 17));
      }
      _fitted = true;
    } catch (_) {
      // O controlador ainda não está pronto; o próximo evento tenta de novo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dest = _dest;
    final me = _me;
    final meters = (dest != null && me != null) ? haversineMeters(me.lat, me.lng, dest.latitude, dest.longitude) : null;
    final approx = _precision != DestinationPrecision.house && _precision != DestinationPrecision.exact;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(
            children: [
              Icon(Icons.place_rounded, color: tk.clientAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.addressLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(tooltip: 'Fechar', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        for (final note in [
          if (_destFailed) 'Não encontramos este endereço no mapa. Confira rua e número.',
          if (!_destFailed && approx) 'Localização aproximada: o pino pode estar a algumas dezenas de metros da casa.',
          ?_gpsNote,
        ])
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: tk.warningSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: tk.warningInk),
                const SizedBox(width: 8),
                Expanded(child: Text(note, style: TextStyle(fontSize: 12.5, color: tk.warningInk))),
              ],
            ),
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  key: const ValueKey('live-map'),
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: dest ?? (me != null ? LatLng(me.lat, me.lng) : _fallback),
                    initialZoom: dest != null ? 17 : 13,
                    minZoom: 3,
                    maxZoom: 19,
                    onMapReady: _fit,
                  ),
                  children: [
                    widget.tileLayer ?? buildTileLayer(context),
                    if (me != null && me.accuracyM != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: LatLng(me.lat, me.lng),
                          radius: me.accuracyM!,
                          useRadiusInMeter: true,
                          color: tk.info.withValues(alpha: 0.14),
                          borderColor: tk.info.withValues(alpha: 0.6),
                          borderStrokeWidth: 1,
                        ),
                      ]),
                    MarkerLayer(markers: [
                      if (dest != null)
                        Marker(
                          point: dest,
                          width: 48,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: Icon(Icons.location_on_rounded, size: 44, color: tk.danger),
                        ),
                      if (me != null)
                        Marker(
                          point: LatLng(me.lat, me.lng),
                          width: 26,
                          height: 26,
                          child: Container(
                            decoration: BoxDecoration(
                              color: tk.info,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: tk.shadow, blurRadius: 6)],
                            ),
                          ),
                        ),
                    ]),
                    const MapAttribution(),
                  ],
                ),
                if (_resolving) const Positioned(top: 12, left: 12, child: _Pill(label: 'Localizando endereço…', loading: true)),
                Positioned(
                  right: 10,
                  top: 10,
                  child: FloatingActionButton.small(
                    heroTag: 'live_fit',
                    onPressed: _fit,
                    tooltip: 'Enquadrar endereço e minha posição',
                    child: const Icon(Icons.center_focus_strong_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.my_location_rounded, color: me == null ? tk.textMuted : tk.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      me == null
                          ? 'Aguardando o seu GPS…'
                          : (meters == null
                              ? 'Sua posição em tempo real'
                              : '${formatMeters(meters)} do endereço'
                                  '${me.accuracyM != null ? ' · precisão ±${me.accuracyM!.round()} m' : ''}'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (me != null) Icon(Icons.fiber_manual_record_rounded, size: 12, color: tk.success),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                dest == null
                    ? 'Marcador do endereço indisponível no momento.'
                    : '${dest.latitude.toStringAsFixed(5)}, ${dest.longitude.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 12, color: tk.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.loading = false});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: context.tk.card, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: context.tk.shadow, blurRadius: 6)]),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            if (loading) const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      );
}
