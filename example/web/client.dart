import 'dart:async';

import 'package:connector/connector.dart';
import 'package:connector/websocket.dart';

const PORT = 1234;

const useBson = false;

main() {

  final client = useBson
    ? new Connector.fromBinaryBus(new BinaryWebSocketBus(pathname: 'ws'))
    : new Connector.fromStringBus(new WebSocketBus<String>(pathname: 'ws'));

  final n = 10;
  final stopwatch = new Stopwatch()..start();

  var stream = client.subscribe('periodic').take(n);

  StreamSubscription sub;
  sub = stream.listen((n) {
    print(n);
    if (n == 5)
      sub.pause(new Future.delayed(const Duration(seconds: 1)));
  })..asFuture()

    .then((_) {
      stopwatch.stop();
      print(stopwatch.elapsedMilliseconds/n);
    });

}
