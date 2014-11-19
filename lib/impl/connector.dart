part of connector;

/**
 * Recursively converts anything into an asynchronously flattened stream
 */
Stream _convertToStream(input) => ((input is Stream)
  ? (input as Stream).asyncExpand(_convertToStream)
  : (input is Future)
    ? _convertToStream((input as Future).asStream())
    : new Future.value(input).asStream())
      .map((item) => (item is Iterable) ? item.toList() : item);

StreamTransformer _attachCallbacks({void onListen(), void onPause(), void onResume(), onCancel()}) =>
  new StreamTransformer((Stream input, bool cancelOnError) {
    final controller = new StreamController(
        onListen: onListen, onPause: onPause, onResume: onResume, onCancel: onCancel, sync: true);
    input.listen(controller.add, onError: controller.addError, onDone: controller.close);
    return controller.stream.listen(null, cancelOnError: cancelOnError);
  });

isType(MessageType type) => (Message msg) => msg.type == type;

class _Connector implements Connector {

  final Bus<Message> bus;
  final StreamRouter<Message> router;

  final handlers = new Multimap<RegExp, Function>();
  final _subscriptions = new Map<String, StreamSubscription>();

  // A set of uuids that were ended by a ENDED message, to prevent responding with CANCEL
  final _endedExternally = new Set<String>();

  _Connector(Bus<Message> bus) : this.bus = bus, router = new StreamRouter<Message>(bus.input) {

    extractSubscription(Message msg) {
      final sub = _subscriptions[msg.uuid];
      return (sub == null) ? [] : [sub];
    }

    // Respond to events
    router
      ..defaultStream.listen((message) => print('Unknown message type: ${message.type.value}'))

      ..route(isType(MessageType.PAUSE)).expand(extractSubscription).listen((sub) => sub.pause())
      ..route(isType(MessageType.RESUME)).expand(extractSubscription).listen((sub) => sub.resume())
      ..route(isType(MessageType.CANCEL)).listen((Message msg) {
        var sub = _subscriptions[msg.uuid];
        if (sub != null) {
          sub.cancel();
          _subscriptions.remove(msg.uuid);
        }
      })

      ..route(isType(MessageType.REQUEST)).listen((Message msg) {
        try {
          // Transform the keys of the kwarg map into symbols
          final kwargs = (msg.kwargs == null) ? null
            : new Map<Symbol, dynamic>.fromIterables(msg.kwargs.keys.map((key) => new Symbol(key)), msg.kwargs.values);

          // Run all matching functions and create a message stream of all results
          final stream = new Stream.fromIterable(
            handlers.keys
              .where((pattern) => pattern.hasMatch(msg.uri))
              .expand((pattern) => handlers[pattern]))
            .map((handler) => Function.apply(handler, msg.args, kwargs))
            .asyncExpand(_convertToStream)
            .map((value) => new Message.response(msg.uuid, data: value));

          // Store the local subscription
          _subscriptions[msg.uuid] = stream.listen(bus.output.add,
            onError: (e, trace) => bus.output.add(new Message.error(msg.uuid, error: e, trace: trace)),
            onDone: () {
              bus.output.add(new Message.ended(msg.uuid));
              _subscriptions.remove(msg.uuid);
            });
        } catch(e, trace) {
          bus.output.add(new Message.error(msg.uuid, error: e, trace: trace));
        }
      });

  }

  /**
   * Subscribe to a method defined on a different connector
   */
  Stream subscribe(String uri, {List args, Map kwargs}) {

    // Create the request message. UUID is generate automatically
    final request = new Message.request(uri, args: args, kwargs: kwargs);

    // Listen to messages with the generated UUID and transform the result
    return router
      .route((msg) => msg.uuid == request.uuid)

      // Pass through response messages or trigger errors or close stream
      .transform(new StreamTransformer.fromHandlers(
          handleData: (Message msg, EventSink<Message> sink) {
            if (msg.type == MessageType.RESPONSE) {
              sink.add(msg.args.first);
            } else if (msg.type == MessageType.ERROR) {
              sink.addError(msg.args.first);
            } else if (msg.type == MessageType.ENDED) {
              _endedExternally.add(msg.uuid);
              sink.close();
            } else {
              sink.addError(new ArgumentError('Incorrect message type'));
            }
          }))
      //
      .transform(_attachCallbacks(
        onListen: () => bus.output.add(request),
        onPause:  () => bus.output.add(new Message.pause(request.uuid)),
        onResume: () => bus.output.add(new Message.resume(request.uuid)),
        onCancel: () {
          // Send a CANCEL message only if canceled locally
          if (!_endedExternally.remove(request.uuid))
            bus.output.add(new Message.cancel(request.uuid));
        }));
  }

  Future call(String uri, {List args, Map kwargs}) => subscribe(uri, args: args, kwargs: kwargs).single;

  /**
   * Attach an event handler to a pattern
   */
  void on(Pattern pattern, Function fn) =>
    handlers.add((pattern is String) ? new RegExp(pattern) : pattern, fn);

  /**
   * Cancel all active local subscriptions
   */
  void close() {
    _subscriptions
      ..values.forEach((val) => val.cancel())
      ..keys.forEach(_subscriptions.remove);
    _onClose.complete();
  }

  final _onClose = new Completer();
  Future get onClose => _onClose.future;

  Iterable<StreamSubscription> get subscriptions => this._subscriptions.values;

}
