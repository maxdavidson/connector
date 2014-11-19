library connector;

import 'dart:async';
import 'dart:convert';

import 'package:quiver/async.dart';
import 'package:quiver/collection.dart';
import 'package:uuid/uuid.dart';

import 'bus.dart';
import 'bson.dart';
import 'codec.dart';

part 'impl/connector.dart';
part 'impl/message.dart';

/**
 * A connector defines a messaging protocol that works with Stream objects.
 * It uses a Bus object, e.g. a two-way stream, to communicate with another 
 * connector.
 */
abstract class Connector {

  factory Connector.fromRawIO(Stream<Message> input, StreamSink<Message> output)
    => new _Connector(new BusAdapter<Message>(input, output));

  factory Connector.fromRawBus(Bus<Message> bus)
    => new _Connector(bus);

  factory Connector.fromStringBus(Bus<String> bus)
    => new _Connector(bus.transform(MESSAGE.fuse(JSON)));

  factory Connector.fromBinaryBus(Bus<List<int>> bus)
    => new _Connector(bus.transform(MESSAGE.fuse(BSON)));

  /**
   * Subscribe to the result of a method attached on a different connector
   */
  Stream subscribe(String uri, {List args, Map kwargs});

  /**
   * Call a method attached to a different connector
   */
  Future call(String uri, {List args, Map kwargs});

  /**
   * Attach an event handler to a pattern
   */
  on(Pattern pattern, Function fn);

  /**
   * Cancel all active local subscriptions
   */
  close();

  /**
   * A futures that completes when the connection closes
   */
  Future get onClose;
  
  Iterable<StreamSubscription> get subscriptions;
}
