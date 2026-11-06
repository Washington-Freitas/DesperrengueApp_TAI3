import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/scheduling_models.dart';
import '../../../core/services/scheduling_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/geo.dart';

/// Camada de blocos 100 % gratuita: OpenStreetMap no claro e CARTO "Dark Matter" no escuro.
/// (Ambos exigem a atribuição exibida em [MapAttribution].)
Widget buildTileLayer(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return TileLayer(
    urlTemplate: dark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: dark ? const ['a', 'b', 'c', 'd'] : const [],
    userAgentPackageName: 'br.com.desperrengue.app',
    maxNativeZoom: 19,
  );
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: context.tk.card.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
        child: Text(
          dark ? '© OpenStreetMap · © CARTO' : '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 10, color: context.tk.textMuted),
        ),
      ),
    );
  }
}

Future<void> _openExternal(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showSnack(context, 'Não foi possível abrir o aplicativo de navegação.', error: true);
  } catch (_) {
    if (context.mounted) showSnack(context, 'Não foi possível abrir o aplicativo de navegação.', error: true);
  }
}

/// Mapa da rota: pino do profissional (GPS ao vivo), pino do cliente, polilinha real nas ruas,
/// distância/ETA (OSRM) e atalhos para Google Maps / Waze.
class MapaRotaServicoModal extends StatefulWidget {
  const MapaRotaServicoModal({
    super.key,
    required this.destination,
    required this.addressLabel,
    required this.position,
    this.routing,
  });

  final JobDestination destination;
  final String addressLabel;

  /// Posição do profissional, atualizada pela tela de origem (stream único do GPS).
  final ValueListenable<GeoFix?> position;

  /// Injetável para testes (padrão: OSRM público).
  final RoutingService? routing;

  static Future<void> show(
    BuildContext context, {
    required JobDestination destination,
    required String addressLabel,
    required ValueListenable<GeoFix?> position,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: MapaRotaServicoModal(destination: destination, addressLabel: addressLabel, position: position),
        ),
      );

  @override
  State<MapaRotaServicoModal> createState() => _MapaRotaServicoModalState();
}

class _MapaRotaServicoModalState extends State<MapaRotaServicoModal> {
  late final RoutingService _routing = widget.routing ?? RoutingService();
  final _map = MapController();
  RouteInfo? _route;
  GeoFix? _routedFrom;
  DateTime? _lastRouteAt;
  bool _fetching = false;

  LatLng get _dest => LatLng(widget.destination.lat, widget.destination.lng);

  @override
  void initState() {
    super.initState();
    widget.position.addListener(_onPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPosition());
  }

  @override
  void dispose() {
    widget.position.removeListener(_onPosition);
    super.dispose();
  }

  Future<void> _onPosition() async {
    final p = widget.position.value;
    if (p == null || _fetching || !mounted) return;
    // Só recalcula a rota se andou > 80 m ou passaram 20 s (respeita o servidor público do OSRM).
    final moved = _routedFrom == null ? double.infinity : haversineMeters(p.lat, p.lng, _routedFrom!.lat, _routedFrom!.lng);
    final stale = _lastRouteAt == null || DateTime.now().difference(_lastRouteAt!) > const Duration(seconds: 20);
    if (_route != null && moved < 80 && !stale) return;
    _fetching = true;
    final r = await _routing.route(fromLat: p.lat, fromLng: p.lng, toLat: _dest.latitude, toLng: _dest.longitude);
    _fetching = false;
    if (!mounted) return;
    setState(() {
      _route = r ?? _route;
      _routedFrom = p;
      _lastRouteAt = DateTime.now();
    });
    _fit();
  }

  void _fit() {
    final p = widget.position.value;
    final pts = <LatLng>[
      _dest,
      if (p != null) LatLng(p.lat, p.lng),
      ...?_route?.points.map((e) => LatLng(e.lat, e.lng)),
    ];
    if (pts.length < 2) return;
    try {
      _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(56), maxZoom: 17));
    } catch (_) {
      // O controlador ainda não está pronto; o próximo evento de posição tenta de novo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dest = widget.destination;
    final p = widget.position.value;
    final straight = p == null ? null : haversineMeters(p.lat, p.lng, dest.lat, dest.lng);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(
            children: [
              Icon(Icons.place_rounded, color: tk.providerAccent),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.addressLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
            ],
          ),
        ),
        if (!dest.usableForCheckIn || dest.needsClientPin)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: tk.warningSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: tk.warningInk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dest.usableForCheckIn
                        ? 'Localização aproximada: o pino pode estar a algumas dezenas de metros da casa.'
                        : 'Localização aproximada (só a região). Peça ao cliente para confirmar o local no mapa.',
                    style: TextStyle(fontSize: 12.5, color: tk.warningInk),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ValueListenableBuilder<GeoFix?>(
              valueListenable: widget.position,
              builder: (context, pos, _) => Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(initialCenter: _dest, initialZoom: 16, minZoom: 3, maxZoom: 19),
                    children: [
                      buildTileLayer(context),
                      if (_route != null)
                        PolylineLayer(polylines: [
                          Polyline(
                            points: [for (final e in _route!.points) LatLng(e.lat, e.lng)],
                            strokeWidth: 5,
                            color: tk.providerAccent,
                            borderStrokeWidth: 1.5,
                            borderColor: Colors.white,
                          ),
                        ]),
                      CircleLayer(circles: [
                        if (dest.usableForCheckIn)
                          CircleMarker(
                            point: _dest,
                            radius: dest.radiusM,
                            useRadiusInMeter: true,
                            color: tk.success.withValues(alpha: 0.15),
                            borderColor: tk.success,
                            borderStrokeWidth: 1.5,
                          ),
                      ]),
                      MarkerLayer(markers: [
                        Marker(point: _dest, width: 44, height: 44, alignment: Alignment.topCenter, child: Icon(Icons.home_rounded, size: 40, color: tk.danger)),
                        if (pos != null)
                          Marker(
                            point: LatLng(pos.lat, pos.lng),
                            width: 28,
                            height: 28,
                            child: Container(
                              decoration: BoxDecoration(
                                color: tk.providerAccent,
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
                  Positioned(
                    right: 10,
                    top: 10,
                    child: FloatingActionButton.small(
                      heroTag: 'fit_route',
                      onPressed: _fit,
                      tooltip: 'Enquadrar rota',
                      child: const Icon(Icons.center_focus_strong_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.route_rounded, color: tk.providerAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _route != null
                          ? '${formatMeters(_route!.distanceM)} · chegada em ${formatEta(_route!.eta)}'
                          : straight != null
                              ? '${formatMeters(straight)} em linha reta'
                              : 'Aguardando o seu GPS…',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openExternal(
                        context,
                        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${dest.lat},${dest.lng}&travelmode=driving'),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('Google Maps'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openExternal(context, Uri.parse('https://waze.com/ul?ll=${dest.lat},${dest.lng}&navigate=yes')),
                      icon: const Icon(Icons.alt_route_rounded, size: 18),
                      label: const Text('Waze'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Abrir navegação externa', style: TextStyle(fontSize: 11.5, color: tk.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// O CLIENTE confirma o local exato do serviço no mapa (toque ou GPS). O servidor passa a
/// validar a presença do profissional contra este ponto (raio de 100 m).
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key, required this.initial, required this.onConfirm});

  final JobDestination? initial;
  final Future<void> Function(double lat, double lng) onConfirm;

  static Future<bool?> show(
    BuildContext context, {
    required JobDestination? initial,
    required Future<void> Function(double lat, double lng) onConfirm,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: LocationPickerSheet(initial: initial, onConfirm: onConfirm)),
      );

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _map = MapController();
  LatLng? _pin;
  bool _busy = false;
  bool _locating = false;

  // Centro do Brasil como último recurso; normalmente há um destino aproximado ou o GPS.
  static const _fallback = LatLng(-21.7900318, -46.5647928);

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) _pin = LatLng(i.lat, i.lng);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) showSnack(context, 'Permissão de localização negada.', error: true);
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      final ll = LatLng(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() => _pin = ll);
      _map.move(ll, 18);
    } catch (_) {
      if (mounted) showSnack(context, 'Não foi possível obter a localização.', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    final pin = _pin;
    if (pin == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.onConfirm(pin.latitude, pin.longitude);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showSnack(context, friendlyError(e), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Confirme o local do serviço', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                'Toque no mapa sobre a sua casa. O profissional só consegue iniciar o serviço quando estiver a menos de 100 m deste ponto.',
                style: TextStyle(color: tk.textMuted, fontSize: 13, height: 1.3),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _pin ?? _fallback,
                    initialZoom: _pin == null ? 13 : 17,
                    minZoom: 3,
                    maxZoom: 19,
                    onTap: (_, ll) => setState(() => _pin = ll),
                  ),
                  children: [
                    buildTileLayer(context),
                    MarkerLayer(markers: [
                      if (_pin != null)
                        Marker(point: _pin!, width: 44, height: 44, alignment: Alignment.topCenter, child: Icon(Icons.location_on_rounded, size: 42, color: tk.danger)),
                    ]),
                    const MapAttribution(),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: FloatingActionButton.small(
                    heroTag: 'my_location',
                    onPressed: _locating ? null : _useMyLocation,
                    tooltip: 'Usar minha localização',
                    child: _locating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
          child: PrimaryButton(
            label: 'Confirmar este local',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: _pin == null ? null : _confirm,
          ),
        ),
      ],
    );
  }
}
