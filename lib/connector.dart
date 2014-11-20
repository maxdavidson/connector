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


/// A [Connector] defines a messaging protocol that works with [Stream] objects.
/// It uses a [Bus] object, i.e. a two-way stream, to communicate with another
/// instance.
abstract class Connector {

  /// Create a raw [Connector] from an input [Stream] and an output [StreamSink].
  factory Connector.fromRawIO(Stream<Message> input, StreamSink<Message> output)
    => new _Connector(new BusAdapter<Message>(input, output));

  /// Create a raw [Connector] from a raw [Bus].
  factory Connector.fromRawBus(Bus<Message> bus)
    => new _Connector(bus);

  /// Create a [Connector] that converts messages to stringified JSON.
  factory Connector.fromStringBus(Bus<String> bus)
    => new _Connector(bus.transform(MESSAGE.fuse(JSON)));

  /// Create a [Connector] that converts messages to binary BSON.
  factory Connector.fromBinaryBus(Bus<List<int>> bus)
    => new _Connector(bus.transform(MESSAGE.fuse(BSON)));

  /// Subscribe to the result of a method attached on a different connector.
  Stream subscribe(String uri, {List args, Map kwargs});

  /// Call a method attached to a different connector.
  Future call(String uri, {List args, Map kwargs});

  /// Attach an event handler to a pattern.
  on(Pattern pattern, Function fn);

  /// Cancel all active local subscriptions.
  close();

  /// A future that completes when the connection closes.
  Future get onClose;
  
  Iterable<StreamSubscription> get subscriptions;
}
