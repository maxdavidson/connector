library connector.websocket;

import 'dart:html';
import 'dart:async';
import 'dart:typed_data';

import 'bus.dart';
import 'codec.dart';

/**
 * Adapts the browser-based WebSocket object the Bus interface.
 * Attempts to reconnect if connection fails.
 */
class WebSocketBus<T> extends Bus<T> {

  // Input events come from different places and need to be joined into one stream
  final inputController = new StreamController<T>(sync: true);

  // Output events need to be buffered before the WebSocket connection is opened
  final outputController = new StreamController<T>(sync: true);

  WebSocket ws;

  var _isOpen = new Completer();
  Future get isOpen => _isOpen.future;

  Stream<T> get input => inputController.stream;
  StreamSink<T> get output => outputController.sink;

  factory WebSocketBus({String host, String pathname: '', bool useSSL: false}) {
    if (host == null) host = window.location.host;
    var ws = new WebSocket('${useSSL ? 'wss' : 'ws'}://$host/$pathname');
    return new WebSocketBus.fromConnection(ws);
  }

  WebSocketBus.fromConnection(this.ws) {

    _attachListeners();

    outputController.stream
      .asyncMap((data) => isOpen.then((_) => data)) // delay until opened
      .listen((T data) {
        print('Sent: $data');
        if (ws.readyState == WebSocket.OPEN) ws.send(data);
        else inputController.addError('WebSocket failed with code ${ws.readyState}');
      }, onDone: ws.close);
  }

  _attachListeners() {
    ws..onMessage
        .map((MessageEvent event) => event.data)
        .map((data) { print('Received: $data'); return data; })
        .listen(inputController.add)
      ..onError.listen(inputController.addError)
      ..onClose.listen((CloseEvent e) => new Future.delayed(const Duration(seconds: 1), () => _reconnect()))
      ..onOpen.listen((Event e) => _isOpen.complete());
  }

  _reconnect() {
    ws = new WebSocket(ws.url);
    _isOpen = new Completer();
    _attachListeners();
  }

}

/**
 * A binary WebSocket class that converts streams
 * of ByteBuffers to streams of List<int>
 */
class BinaryWebSocketBus extends Bus<List<int>> {
  static final binaryCodec = new CodecAdapter<List<int>, ByteBuffer>(
          (List<int> list) => new Uint8List.fromList(list).buffer,
          (ByteBuffer buffer) => new Uint8List.view(buffer));
  
  final Bus<List<int>> delegate;

  factory BinaryWebSocketBus({String host, String pathname: '', bool useSSL: false}) {
    if (host == null) host = window.location.host;
    var ws = new WebSocket('${useSSL ? 'wss' : 'ws'}://$host/$pathname');
    return new BinaryWebSocketBus.fromConnection(ws);
  }

  BinaryWebSocketBus.fromConnection(WebSocket ws) :
    delegate = new WebSocketBus.fromConnection(ws..binaryType='arraybuffer').transform(binaryCodec);
  
  Stream<List<int>> get input => delegate.input;
  StreamSink<List<int>> get output => delegate.output;
}
