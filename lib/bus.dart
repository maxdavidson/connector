library connector.bus;

import 'dart:async';
import 'dart:convert';


/**
 * An interface to a bus with input and output
 */
abstract class Bus<T> {
  Stream<T> get input;
  StreamSink<T> get output;

  // Should be a generic function transform<S>, but Dart does not support that
  Bus<dynamic> transform(Codec<dynamic, T> codec) => new _TransformedBus<dynamic, T>(codec, this);
}

/**
 * Delegates an input and output
 */
class BusAdapter<T> extends Bus<T> {
  final Stream<T> _input;
  final StreamSink<T> output;
  bool debug = false;

  BusAdapter(this._input, this.output);

  Stream<T> get input => _input.map((data) { if (debug) print('Received: $data'); return data; });
}

/**
 * Converts a Bus<T> to a Bus<S> using a Codec<S,T>.
 * This is because the output is encoded from T to S 
 * while the input is decoded from S to T.
 */
class _TransformedBus<S,T> extends Bus<S> {
  final Bus<T> delegate;
  final Codec<S,T> codec;
  final controller = new StreamController<S>(sync: true);

  _TransformedBus(this.codec, this.delegate) {
    controller.stream.map(codec.encode).pipe(delegate.output);
  }

  Stream<S> get input => delegate.input.map(codec.decode);
  StreamSink<S> get output => controller;
}
