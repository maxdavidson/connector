import 'dart:io';
import 'package:http_server/http_server.dart';
import 'dart:async';
import 'dart:convert';

import 'package:quiver/async.dart';
import 'package:connector/connector.dart';
import 'package:connector/bus.dart';

const PORT = 1234;
const HOME = '../web/';

const useBson = false;

main() {

  HttpServer.bind('127.0.0.1', PORT)
    .then((HttpServer server) {
      print('Listening for connections on $PORT');

      onPath(String path) => (HttpRequest request) => request.uri.path == path;
      final webSocketTransformer = new WebSocketTransformer();
      final index = new File(HOME + 'index.html');

      new StreamRouter(server)
        ..defaultStream.listen((HttpRequest request) {

          final ct = <String, ContentType> {
            'htm': ContentType.HTML,
            'dart': new ContentType('application', 'dart'),
            'js': new ContentType('application', 'javascript')
          };

          var match = ct[ct.keys.firstWhere(request.uri.pathSegments.last.endsWith, orElse: () => null)];
          if (match != null)
            request.response.headers.contentType = match;

          final file = new File(HOME + request.uri.pathSegments.join('/'));
          file.exists().then((exists) { if (exists) file.openRead().pipe(request.response); });
        })
        ..route(onPath('/'))
          .listen((HttpRequest request) {
            request.response.headers.contentType = ContentType.HTML;
            index.openRead().pipe(request.response);
          })
        ..route(onPath('/ws')).transform(webSocketTransformer)
          .listen((WebSocket ws) {
            print('WebSocket connected with ready state: ${ws.readyState}');

            ws.pingInterval = const Duration(seconds: 5);

            var adapter = new BusAdapter(ws, ws);

            Connector connector = useBson
              ? new Connector.fromBinaryBus(adapter)
              : new Connector.fromStringBus(adapter);

            connector.on('periodic', () => new Stream.periodic(const Duration(milliseconds: 10), (n) => n));

            ws.done.then((_) {
              print('WebSocket closed with close code: ${ws.closeCode}');
            });
         });
    })
    .catchError((error) => print("Error starting HTTP server: $error"));
}
