import 'dart:async';

import 'package:rxdart/rxdart.dart';

extension ValueExtensions<T> on Stream<T> {
  ValueStream<T> asValueStream() {
    StreamSubscription<T>? subscription;

    final stream = doOnDone(() {
      // When source stream done, cancel [ConnectableStream] subscription
      subscription?.cancel();
    }).publishValue();

    // Intructs the [ConnectableStream to begin emiting items]
    subscription = stream.connect();

    return stream;
  }
}
