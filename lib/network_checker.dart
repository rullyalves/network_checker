import 'dart:async';
import 'dart:io';
import 'dart:developer';
import 'dart:math' hide log;
import 'package:rxdart/rxdart.dart';
import 'stream_extensions.dart';

class NetworkChecker {
  NetworkChecker() {
    onNetworkStatusChanged = _statusStreamController.stream.asValueStream();
  }

  List<String> _hostList = defaultHostList;

  Duration _fetchTimeout = defaultFetchTimeout;

  Duration _pollingInterval = defaultPollingInterval;

  Duration _debounceInterval = defaultDebounceInterval;

  static const defaultFetchTimeout = Duration(seconds: 5);
  static const defaultPollingInterval = Duration(milliseconds: 500);
  static const defaultDebounceInterval = Duration(milliseconds: 3500);
  static const defaultHostList = [
    'google.com',
    'cloudflare.com',
    'facebook.com',
    'youtube.com',
    'twitter.com',
    'microsoft.com',
    'stackoverflow.com',
  ];

  StreamSubscription<bool>? _statusStreamSubscription;

  final _statusStreamController = StreamController<bool>.broadcast();
  late ValueStream<bool> onNetworkStatusChanged;

  final _hostAddressListMapping = <String, List<InternetAddress>>{};

  final _random = Random();

  Stream<bool> _checkNextHost() async* {
    final index = _random.nextInt(_hostList.length);
    final result = await _istHostReachable(_hostList[index]) ?? false;

    yield result;
  }

  Future<bool> _istHostAddressReachable(InternetAddress address) async {
    Socket? socket;
    try {
      socket = await Socket.connect(address, 80, timeout: _fetchTimeout);
      return true;
    } catch (e) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Future<List<InternetAddress>> _resolveInternetAddress(String hostLink) async {
    final cachedAddressList = _hostAddressListMapping[hostLink];
    if (cachedAddressList != null) {
      return cachedAddressList;
    }

    try {
      final addressList = await InternetAddress.lookup(hostLink);
      if (addressList.isNotEmpty) {
        _hostAddressListMapping[hostLink] = addressList;
        return addressList;
      }
    } catch (_) {}

    return [];
  }

  Future<bool?> _istHostReachable(String hostLink) async {
    final addressList = await _resolveInternetAddress(hostLink);

    return () async {
      for (final address in addressList) {
        if (await _istHostAddressReachable(address)) {
          return true;
        }

        return false;
      }
    }()
        .timeout(_fetchTimeout, onTimeout: () => false);
  }

  void start() {
    if (_statusStreamSubscription == null) {
      final statusStream = Stream.periodic(_pollingInterval, (_) => _checkNextHost())
          .startWith(_checkNextHost())
          .switchMap((value) => value)
          .distinct()
          .switchMap((value) => value ? Stream.value(value) : Stream.value(value).delay(_debounceInterval));
      _statusStreamSubscription = statusStream.listen((event) {
        _statusStreamController.add(event);
        log('network status: $event');
      });
    }
  }

  void stop() {
    _statusStreamSubscription?.cancel();
    _statusStreamSubscription = null;
  }

  void configure({
    Duration? fetchTimeout,
    Duration? pollingInterval,
    Duration? debounceInterval,
    List<String>? hostList,
  }) {
    stop();

    _hostList = hostList ?? _hostList;
    _fetchTimeout = fetchTimeout ?? _fetchTimeout;
    _pollingInterval = pollingInterval ?? _pollingInterval;
    _debounceInterval = debounceInterval ?? _debounceInterval;

    start();
  }
}
