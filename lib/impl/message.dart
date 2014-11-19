part of connector;

class MessageType {
  final value;

  static const REQUEST = const MessageType('REQUEST');
  static const RESPONSE = const MessageType('RESPONSE');
  static const ERROR = const MessageType('ERROR');
  static const PAUSE = const MessageType('PAUSE');
  static const RESUME = const MessageType('RESUME');
  static const CANCEL = const MessageType('CANCEL');
  static const ENDED = const MessageType('ENDED');

  const MessageType(this.value);

  bool operator==(MessageType other) => value == other.value;
}

class Message {
  final MessageType type;
  final String uuid;
  String uri;
  List args;
  Map kwargs;

  static final _cryptoBase = new Uuid();

  Message(this.type, this.uuid, {this.uri, this.args, this.kwargs});

  Message.request(this.uri, {this.args, this.kwargs}) : type = MessageType.REQUEST, uuid = _cryptoBase.v4();
  Message.response(this.uuid, {dynamic data, this.uri}) : type = MessageType.RESPONSE, args = [data];
  Message.error(this.uuid, {Error error, StackTrace trace}) : type = MessageType.ERROR, args = [error.toString(), trace.toString()];
  Message.pause(this.uuid) : type = MessageType.PAUSE;
  Message.resume(this.uuid) : type = MessageType.RESUME;
  Message.cancel(this.uuid) : type = MessageType.CANCEL;
  Message.ended(this.uuid) : type = MessageType.ENDED;

  Message.decode(Map data) : type = new MessageType(data['type']), uuid = data['uuid'], uri = data['uri'], args = data['args'], kwargs = data['kwargs'];

  Map _removeNullValues(Map map) =>
    new Map.fromIterable(map.keys.where((key) => map[key] != null), value: (key) => map[key]);

  Map encode() => _removeNullValues({
      'type': type.value,
      'uuid': uuid,
      'uri': uri,
      'args': args,
      'kwargs': kwargs
  });

}

final MESSAGE = new CodecAdapter<Message, Object>(
  (Message message) => message.encode(),
  (Object data) => new Message.decode(data));
