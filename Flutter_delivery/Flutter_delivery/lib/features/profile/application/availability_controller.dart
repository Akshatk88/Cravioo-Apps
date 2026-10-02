import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/error/result.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/rider_online_service.dart';
import '../../../core/services/socket_service.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../../orders/application/orders_state.dart';
import '../data/profile_repository.dart';

class AvailabilityController extends Notifier<bool> {
  late final ProfileRepository _repository;
  StreamSubscription<Position>? _positionSub;
  Timer? _keepAliveTimer;
  DateTime _lastPing = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool build() {
    _repository = ref.read(profileRepositoryProvider);
    final authState = ref.read(authControllerProvider);
    final startedOnline = authState is AuthAuthenticated && authState.user.isOnline;

    ref.onDispose(() {
      _positionSub?.cancel();
      _keepAliveTimer?.cancel();
      // Covers logout, which tears this controller down without going through
      // goOffline — otherwise the service and its notification outlive the
      // session, claiming a signed-out rider is online.
      unawaited(RiderOnlineService.stop());
    });

    if (startedOnline) {
      Future.microtask(() async {
        await _repository.updateAvailability(true);
        _startTracking();
        ref.read(ordersControllerProvider.notifier).startPolling();
      });
    }
    return startedOnline;
  }

  Future<Result<void, AppError>> toggle() async {
    if (state) {
      return goOffline();
    }
    return goOnline();
  }

  Future<Result<void, AppError>> goOnline() async {
    final locationService = ref.read(locationServiceProvider);
    final hasPermission = await locationService.ensurePermissions();
    if (!hasPermission) {
      return Result.failure(
        NetworkError('Location permission is required to go online'),
      );
    }

    // Send explicit status toggle WITHOUT location coords first,
    // so backend accepts status transition from 'offline' to 'online'.
    final result = await _repository.updateAvailability(true);
    return result.when(
      success: (_) async {
        state = true;
        try {
          final pos = await Geolocator.getCurrentPosition();
          locationService.lastPosition = pos;
          await _repository.updateAvailability(
            true,
            lat: pos.latitude,
            lng: pos.longitude,
          );
        } catch (_) {
          // location ping will pick up next fix
        }
        ref.read(ordersControllerProvider.notifier).startPolling();
        _startTracking();
        return const Result.success(null);
      },
      failure: (error) => Result.failure(error),
    );
  }

  Future<Result<void, AppError>> goOffline() async {
    final result = await _repository.updateAvailability(false);
    _stopTracking();
    ref.read(ordersControllerProvider.notifier).stopPolling();
    state = false;
    return result.when(
      success: (_) => const Result.success(null),
      failure: (error) => Result.failure(error),
    );
  }

  void _startTracking() {
    // Ask Android to stop freezing us first. Everything below — the position
    // stream and the keep-alive ping — silently stops running once the process
    // is backgrounded without this, which is what let riders go stale and drop
    // out of dispatch while believing they were online.
    unawaited(RiderOnlineService.start());

    final locationService = ref.read(locationServiceProvider);
    locationService.startTracking();
    _positionSub?.cancel();
    _positionSub = locationService.positionStream.listen(_onPosition);

    // The position stream only emits on movement (distanceFilter), so a
    // stationary rider would otherwise never refresh lastLocationAt and
    // silently drop out of dispatch once the backend's GPS staleness
    // window elapses. Ping on a timer too, independent of movement.
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 3), (_) => _pingLocation());
    // Ping immediately as well. build() starts tracking for a rider who was
    // already online without ever taking a fix (unlike goOnline, which calls
    // getCurrentPosition), so without this their first ping is 3 minutes away
    // at best — and never, if they don't move.
    unawaited(_pingLocation());
  }

  /// Refreshes lastLocationAt server-side so dispatch keeps considering this rider.
  ///
  /// Resolving a position here rather than bailing on null is the whole point:
  /// LocationService.lastPosition stays null until the movement-gated stream first
  /// emits, which never happens for a rider who resumed the app already-online and
  /// hasn't moved 15m. Those riders were being dropped from every order offer, so
  /// they never even received the new-order push.
  Future<void> _pingLocation() async {
    final service = ref.read(locationServiceProvider);
    var pos = service.lastPosition ?? await Geolocator.getLastKnownPosition();
    if (pos == null) {
      try {
        pos = await Geolocator.getCurrentPosition();
      } catch (_) {
        return; // No fix available at all — nothing useful to report.
      }
    }
    service.lastPosition = pos;
    _lastPing = DateTime.now();
    await _repository.updateAvailability(true, lat: pos.latitude, lng: pos.longitude);
  }

  void _stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    ref.read(locationServiceProvider).stopTracking();

    // The notification must go the moment the rider goes offline. A lingering
    // "You're online" is both a lie and a battery drain, and it is the single
    // fastest way to get uninstalled.
    unawaited(RiderOnlineService.stop());
  }

  void _onPosition(Position position) {
    final now = DateTime.now();
    if (now.difference(_lastPing) < const Duration(seconds: 4)) return;
    _lastPing = now;

    _repository.updateAvailability(
      true,
      lat: position.latitude,
      lng: position.longitude,
    );

    final ordersState = ref.read(ordersControllerProvider);
    if (ordersState is OrdersLoaded && ordersState.currentOrder != null) {
      ref.read(socketServiceProvider).sendLocationUpdate(
        orderId: ordersState.currentOrder!.id,
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
      );
    }
  }
}

final availabilityControllerProvider =
    NotifierProvider<AvailabilityController, bool>(AvailabilityController.new);
