import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:web_socket_channel/io.dart';
// import 'package:crypto/crypto.dart';

import 'package:flutter_webrtc/webrtc.dart';
import 'package:mediasoup_client/mediasoup_client.dart' as mediasoup;
import 'package:mediasoup_client/rtp_parameters.dart' as mediasoupRtp;
import 'package:mediasoup_client/transport.dart' as mediasoupTransport;
import 'package:mediasoup_client/producer.dart' as mediasoupProducer;

class Peer {
  final String sessionId;
  final mediasoup.Device device;

  Peer(this.sessionId, this.device);

  List<mediasoupProducer.Producer> producers;
  MediaStream localStream;
  mediasoupTransport.Transport sendTransport;

  // bool hasVideo () {
  //   return this.producers.find((producer => producer.kind === 'video'));
  // }

  // bool hasAudio () {
  //   return this.producers.find((producer => producer.kind === 'audio'));
  // }
}

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {  
  WebSocket _socket;
  IOWebSocketChannel _channel;
  Peer _peer;
  final _localRenderer = new RTCVideoRenderer();


  @override
  void initState() {
    super.initState();
    _init();
  }
  
  static Future awaitWithTimeout(Future future, int timeoutMs, {Function onTimeout, Function onSuccessAfterTimeout, Function onErrorAfterTimeout}) {
    Completer completer = new Completer();

    Timer timer = new Timer(new Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) {
        if (onTimeout != null) {
          onTimeout();
        }
        completer.completeError(new Exception('Future timeout before complete'));
      }
    });
    future.then((t) {
      if (completer.isCompleted) {
        if (onSuccessAfterTimeout != null) {
          onSuccessAfterTimeout(t);
        }
      } else {
        timer.cancel();
        completer.complete(t);
      }
    }).catchError((err) {
      if (completer.isCompleted) {
        if (onErrorAfterTimeout != null) {
          onErrorAfterTimeout(err);
        }
      } else {
        timer.cancel();
        completer.completeError(err);
      }
    });

    return completer.future;
  }

  static Future<WebSocket> connectToWebSocket(
      String url, {
      Iterable<String> protocols,
      Map<String, dynamic> headers,
      HttpClient httpClient,
      bool useStandardWebSocket = true
    }) async {
    Uri uri = Uri.parse(url);

    if (useStandardWebSocket && uri.scheme != "wss") {
      return await awaitWithTimeout(WebSocket.connect(
        url,
        protocols: protocols,
        headers: headers
      ), 60000, onSuccessAfterTimeout: (WebSocket socket){
        socket.close();
      });
    }

    if (uri.scheme != "ws" && uri.scheme != "wss") {
      throw new WebSocketException("Unsupported URL scheme '${uri.scheme}'");
    }

    Random random = new Random();
    // Generate 16 random bytes.
    Uint8List nonceData = new Uint8List(16);
    for (int i = 0; i < 16; i++) {
      nonceData[i] = random.nextInt(256);
    }
    String nonce = base64Encode(nonceData);

    int port = uri.port;
    if (port == 0) {
      port = uri.scheme == "wss" ? 443 : 80;
    }

    uri = new Uri(
      scheme: uri.scheme == "wss" ? "https" : "http",
      userInfo: uri.userInfo,
      host: uri.host,
      port: port,
      path: uri.path,
      query: uri.query
    );

    HttpClient _client = httpClient == null ? (
      new HttpClient()
        ..badCertificateCallback = (a, b, c) => true
    ) : httpClient;

    return _client.openUrl("GET", uri).then((HttpClientRequest request) async {
      if (headers != null) {
        headers.forEach((field, value) => request.headers.add(field, value));
      }
      // Setup the initial handshake.
      request.headers
        ..set(HttpHeaders.CONNECTION, "Upgrade")
        ..set(HttpHeaders.UPGRADE, "websocket")
        ..set("Sec-WebSocket-Key", nonce)
        ..set("Cache-Control", "no-cache")
        ..set("Sec-WebSocket-Version", "13");
      if (protocols != null) {
        request.headers.add("Sec-WebSocket-Protocol", protocols.toList());
      }
      return request.close();
    }).then((response) {
      return response;
    }).then((HttpClientResponse response) {
      void error(String message) {
        // Flush data.
        response.detachSocket().then((Socket socket) {
          socket.destroy();
        });
        throw new WebSocketException(message);
      }
      if (response.statusCode != HttpStatus.SWITCHING_PROTOCOLS ||
        response.headers[HttpHeaders.CONNECTION] == null ||
        !response.headers[HttpHeaders.CONNECTION].any(
              (value) => value.toLowerCase() == "upgrade") ||
        response.headers.value(HttpHeaders.UPGRADE).toLowerCase() != "websocket") {
        error("Connection to '$uri' was not upgraded to websocket");
      }
      String accept = response.headers.value("Sec-WebSocket-Accept");
      if (accept == null) {
        error("Response did not contain a 'Sec-WebSocket-Accept' header");
      }
      // List<int> expectedAccept = sha1.convert("$nonce$_webSocketGUID".codeUnits).bytes;
      // List<int> receivedAccept = base64Decode(accept);
      // if (expectedAccept.length != receivedAccept.length) {
      //   error("Response header 'Sec-WebSocket-Accept' is the wrong length");
      // }
      // for (int i = 0; i < expectedAccept.length; i++) {
      //   if (expectedAccept[i] != receivedAccept[i]) {
      //     error("Bad response 'Sec-WebSocket-Accept' header");
      //   }
      // }
      var protocol = response.headers.value('Sec-WebSocket-Protocol');
      return response.detachSocket().then((socket) {
        // socket.setOption(SocketOption.TCP_NODELAY, _tcpNoDelay);
        return new WebSocket.fromUpgradedSocket(
          socket,
          protocol: protocol,
          serverSide: false
        );
      });
    }).timeout(new Duration(minutes: 1), onTimeout:(){
      _client.close(force: true);
      throw new WebSocketException('timeout');
    });
  }

  Future<void> _init() async {

    // for valida certificate:
    // channel = IOWebSocketChannel.connect('wss://192.168.1.27:3000');

    // for invalid certificate
    HttpClient httpClient = new HttpClient();
    httpClient.connectionTimeout = Duration(seconds: 60);
    httpClient.badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
    _socket = await connectToWebSocket('wss://10.60.27.68:3000', httpClient: httpClient);
    _channel = IOWebSocketChannel(_socket);
    print(_channel.protocol);
    
    // _channel.sink.add('data');
    _channel.stream.listen((message) {
      print(message);
      _handleMessage(jsonDecode(message));
    });
  }

  Future<void> _handleRouterRtpCapabilitiesRequest(dynamic data) async {
    String sessionId = data['sessionId'];
    var routerRtpCapabilities = mediasoupRtp.RtpCapabilities.fromDynamic(data['routerRtpCapabilities']);

    try {
      var device = mediasoup.Device();
      // Load the mediasoup device with the router rtp capabilities gotten from the server
      await device.load(routerRtpCapabilities);

      _peer = Peer(sessionId, device);
      _createTransport();
    } catch (error) {
      print('handleRouterRtpCapabilities() failed to init device: $error');
      _socket.close();
    }
  }

  void _createTransport() {
    if (_peer == null || !_peer.device.loaded) {
      throw('Peer or device is not initialized');
    }

    // First we must create the mediasoup transport on the server side
    _channel.sink.add(jsonEncode({
      'action': 'create-transport',
      'sessionId': _peer.sessionId
    }));
  }
  
  void _handleTransportConnectEvent(dtlsParameters, callback, errback) {
    try {
      // const action = (jsonMessage) => {
      //   callback();
      //   queue.remove('connect-transport');
      // };

      // queue.push('connect-transport', action);

      _channel.sink.add(jsonEncode({
        'action': 'connect-transport',
        'sessionId': _peer.sessionId,
        'transportId': _peer.sendTransport.id, 
        'dtlsParameters': dtlsParameters
      }));
    } catch (error) {
      print('handleTransportConnectEvent() failed: $error');
      errback(error);
    }
  }

  void _handleTransportProduceEvent(kind, rtpParameters, callback, errback) {
    try {
      // const action = jsonMessage => {
      //   console.log('handleTransportProduceEvent callback [data:%o]', jsonMessage);
      //   callback({ id: jsonMessage.id });
      //   queue.remove('produce');
      // };

      // queue.push('produce', action);

      _channel.sink.add(jsonEncode({
        'action': 'produce',
        'sessionId': _peer.sessionId,
        'transportId': _peer.sendTransport.id,
        'kind': kind,
        'rtpParameters': rtpParameters
      }));
    } catch (error) {
      print('handleTransportProduceEvent() failed: $error');
      errback(error);
    }
  }

  void _handleSendTransportListeners() {
    _peer.sendTransport.on('connect', _handleTransportConnectEvent);
    _peer.sendTransport.on('produce', _handleTransportProduceEvent);
    _peer.sendTransport.on('connectionstatechange', (connectionState) => print('send transport connection state change: $connectionState'));
  }

  Future<void> _getMediaStream() async {
    
    final Map<String, dynamic> mediaConstraints = {
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth":
              '1280', // Provide your own width, height and frame rate here
          "minHeight": '720',
          "minFrameRate": '30',
        },
        "facingMode": "user",
        "optional": [],
      }
    };

    MediaStream stream = await navigator.getUserMedia(mediaConstraints);
    _peer.localStream = stream;
    _localRenderer.srcObject = stream;
    _localRenderer.mirror = true;
    
    // If there is a video track start sending it to the server
    var videoTracks = stream.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      var videoProducer = await _peer.sendTransport.produce(track: videoTracks.first, stream: stream);
      _peer.producers.add(videoProducer);
    }

    // if there is a audio track start sending it to the server
    var audioTracks = stream.getAudioTracks();
    if (audioTracks != null && audioTracks.isNotEmpty) {
      var audioProducer = await _peer.sendTransport.produce(track: audioTracks.first, stream: stream);
      _peer.producers.add(audioProducer);
    }

    if (mounted) {
      // setState(() {
      //   _inCalling = true;
      // });
    }
  }

  Future<void> _handleCreateTransportRequest(dynamic data) async {
    try {
      // Create the local mediasoup send transport
      _peer.sendTransport = _peer.device.createSendTransport(mediasoupTransport.TransportOptions.fromDynamic(data));

      // Set the transport listeners and get the users media stream
      _handleSendTransportListeners();
      _getMediaStream();
    } catch (error) {
      print('handleCreateTransportRequest() failed to create transport: $error');
      _socket.close();
    }
  }

  void _handleMessage(dynamic data) {
    String action = data['action'];
    switch(action) {
    case 'router-rtp-capabilities':
      _handleRouterRtpCapabilitiesRequest(data);
      break;
    case 'create-transport':
      _handleCreateTransportRequest(data);
      break;
    case 'connect-transport':
      // TODO
      // _handleConnectTransportRequest(data);
      break;
    case 'produce':
      // TODO
      // _handleProduceRequest(data);
      break;
    default: 
      print('Unknown action $action');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Running'),
        ),
      ),
    );
  }
}
