import 'dart:async';

import 'package:unittest/unittest.dart';
import 'package:quiver/iterables.dart';

import 'package:connector/connector.dart';
import 'package:connector/bus.dart';


main() {

  Connector server, client;

  testRunner() {

    test('Function returning simple value', () {
      server.on('hello', () => 'world');

      expect(client.call('hello'), completion(equals('world')));
    });

    test('Functions returning simple values, multiple calls', () {
      server
        ..on('foo', (n) => n)
        ..on('bar', (a, b) => a + b);

      range(10)
        ..forEach((n) => expect(client.call('foo', args: [n]), completion(equals(n))))
        ..forEach((n) => expect(client.call('bar', args: [n, n]), completion(equals(n*2))));
    });

    test('Function returning simple value, positional arguments', () {
      server.on('add', (a, b) => a + b);

      expect(client.call('add', args: [5, 9]), completion(equals(14)));
    });

    test('Function returning simple value, optional named arguments', () {
      server.on('say', ({what: 'Max'}) => what);

      expect(client.call('say'), completion(equals('Max')));
      expect(client.call('say', kwargs: {'what': 'hello'}), completion(equals('hello')));
    });

    test('Function throws', () {
      server
        ..on('foo', (n) => n)
        ..on('bar', (String text) => text.startsWith('hello'));

      expect(client.call('foo'), throws); //TODO: throwsArgumentError
      expect(client.call('bar', args: [5]), throws);
    });

    test('Function returning iterable', () {
      final nums = range(5);
      server.on('foo', () => new Future.value(nums));
      expect(client.call('foo'), completion(equals(nums)));
    });

    test('Function returning map', () {
      server.on('foo', () => new Future.value({ 'hello': 'world' }));

      expect(client.call('foo'), completion(equals({ 'hello': 'world' })));
    });

    test('Function returning future', () {
      server.on('foo', () => new Future.value('bar'));

      expect(client.call('foo'), completion(equals('bar')));
    });

    test('Function returning delayed future', () {
      server.on('foo', () => new Future.delayed(const Duration(milliseconds: 50), () => 'bar'));

      expect(client.call('foo'), completion(equals('bar')));
    });

    test('Function returning nested futures', () {
      server.on('foo', () => new Future(() => new Future(() => new Future(() => new Future.value('bar')))));

      expect(client.call('foo'), completion(equals('bar')));
    });

    test('Function returning stream, single item', () {
      server.on('foo', () => new Future.value('bar').asStream());

      final stream = client.subscribe('foo');

      expect(stream.toList(), completion(equals(['bar'])));
    });

    test('Function returning stream, multiple items', () {
      final nums = range(15);
      server.on('foo', () => new Stream.fromIterable(nums));

      final stream = client.subscribe('foo');

      expect(stream.toList(), completion(equals(nums)));
    });

    test('Function returning nested stream', () {
      final nums = range(15);
      server.on('foo', () => new Future.value(nums).asStream().map((nums) => new Stream.fromIterable(nums)));

      final stream = client.subscribe('foo');

      expect(stream.toList(), completion(equals(nums)));
    });

    test('Pausing, resuming and canceling stream', () {
      server.on('foo', () => new Stream.periodic(const Duration(milliseconds: 100), (n) => n));

      Future delay(f()) => new Future.delayed(const Duration(milliseconds: 500), f);

      final stream = client.subscribe('foo');
      final reachedMiddle = new Completer();
      final clientSubscription = stream.listen((n) { if (n == 10) reachedMiddle.complete(); });

      return reachedMiddle.future.then((_) {
        clientSubscription.pause();
        return delay(() {
          expect(clientSubscription.isPaused, isTrue);
          expect(server.subscriptions, hasLength(1));
          final serverSubscription = server.subscriptions.first;
          expect(serverSubscription.isPaused, isTrue);
          clientSubscription.resume();
          return delay(() {
            expect(clientSubscription.isPaused, isFalse);
            expect(server.subscriptions, hasLength(1));
            expect(serverSubscription.isPaused, isFalse);
            clientSubscription.cancel();
            return delay(() {
              expect(server.subscriptions, isEmpty);
            });
          });
        });
      });
    });
  }

  group('Messages sent as raw message objects', () {
    setUp(() {
      // Create two controllers
      final serverController = new StreamController<Message>();
      final clientController = new StreamController<Message>();

      // Create two buses that have their inputs and outputs connected
      final serverBus = new BusAdapter<Message>(clientController.stream, serverController.sink);
      final clientBus = new BusAdapter<Message>(serverController.stream, clientController.sink);

      // Create the connectors from the buses
      server = new Connector.fromRawBus(serverBus);
      client = new Connector.fromRawBus(clientBus);
    });

    testRunner();

    tearDown(() {
      server.close();
      client.close();
    });
  });

  group('Messages encoded as JSON strings', () {
    setUp(() {
      // Create two controllers
      final serverController = new StreamController<String>();
      final clientController = new StreamController<String>();

      // Create two buses that have their inputs and outputs connected
      final serverBus = new BusAdapter<String>(clientController.stream, serverController.sink);
      final clientBus = new BusAdapter<String>(serverController.stream, clientController.sink);

      // Create the connectors from the buses
      server = new Connector.fromStringBus(serverBus);
      client = new Connector.fromStringBus(clientBus);
    });

    testRunner();

    tearDown(() {
      server.close();
      client.close();
    });
  });

  group('Messages encoded as binary BSON', () {
    setUp(() {
      // Create two controllers
      final serverController = new StreamController<List<int>>();
      final clientController = new StreamController<List<int>>();

      // Create two buses that have their inputs and outputs connected
      final serverBus = new BusAdapter<List<int>>(clientController.stream, serverController.sink);
      final clientBus = new BusAdapter<List<int>>(serverController.stream, clientController.sink);

      // Create the connectors from the buses
      server = new Connector.fromBinaryBus(serverBus);
      client = new Connector.fromBinaryBus(clientBus);
    });

    testRunner();

    tearDown(() {
      server.close();
      client.close();
    });
  });

}
