

import 'dart:async';
import 'dart:core';

import 'package:flutter/cupertino.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:mediasoup_client/events.dart';
import 'package:mediasoup_client/handler.dart';
import 'package:mediasoup_client/mediasoup_client.dart';
import 'package:mediasoup_client/producer.dart';
import 'package:mediasoup_client/ortc.dart' as ortc;
import 'package:mediasoup_client/rtp_parameters.dart';
import 'package:mediasoup_client/sctp_parameters.dart';

class IceParameters {
	/*
	 * ICE username fragment.
	 * */
	final String usernameFragment;

	/*
	 * ICE password.
	 */
	final String password;

	/*
	 * ICE Lite.
	 */
	final bool iceLite;

  IceParameters({this.usernameFragment, this.password, this.iceLite});

  static IceParameters fromDynamic(data) {
    return IceParameters(
      iceLite: data['iceLite'],
      password: data['password'],
      usernameFragment: data['usernameFragment'],
    );
  }
}

enum Protocol {
  udp, tcp
}

enum IceCandidateType {
  host, srflx, prflx, relay
}

enum TcpType {
  active, passive, so
}

class IceCandidate {
	/*
	 * Unique identifier that allows ICE to correlate candidates that appear on
	 * multiple transports.
	 */
	final String foundation;

	/*
	 * The assigned priority of the candidate.
	 */
	final int priority;

	/*
	 * The IP address of the candidate.
	 */
	final String ip;

	/*
	 * The protocol of the candidate.
	 */
	final Protocol protocol;

	/*
	 * The port for the candidate.
	 */
	final int port;

	/*
	 * The type of candidate..
	 */
	final IceCandidateType type;

	/*
	 * The type of TCP candidate.
	 */
	final TcpType tcpType;

  IceCandidate({this.foundation, this.priority, this.ip, this.protocol, this.port, this.type, this.tcpType});

  static IceCandidate fromDynamic(data) {
    return IceCandidate(
      foundation: data['foundation'], 
      priority: data['priority'], 
      ip: data['ip'], 
      protocol: Protocol.values.firstWhere((e) => e.toString() == 'Protocol.${data['protocol']}'),
      port: data['port'], 
      type: IceCandidateType.values.firstWhere((e) => e.toString() == 'IceCandidateType.${data['type']}'),
      tcpType: data['tcpType'] != null ? TcpType.values.firstWhere((e) => e.toString() == 'TcpType.${data['tcpType']}') : null,
    );
  }
}

enum DtlsRole{
  auto, client, server
}

enum ConnectionState{
  new_, connecting, connected, failed, closed
}

class DtlsParameters {
	/*
	 * DTLS role. Default 'auto'.
	 */
	DtlsRole role;

	/*
	 * DTLS fingerprints.
	 */
	final List<DtlsFingerprint> fingerprints;

  DtlsParameters({this.role, this.fingerprints});
  
  static DtlsParameters fromDynamic(data) {
    return DtlsParameters(
      fingerprints: data['fingerprints'].map<DtlsFingerprint>((dtlsFingerprint) => DtlsFingerprint.fromDynamic(dtlsFingerprint)).toList(),
      role: DtlsRole.values.firstWhere((e) => e.toString() == 'DtlsRole.${data['role']}'),
    );
  }
}

/*
 * The hash function algorithm (as defined in the "Hash function Textual Names"
 * registry initially specified in RFC 4572 Section 8) and its corresponding
 * certificate fingerprint value (in lowercase hex string as expressed utilizing
 * the syntax of "fingerprint" in RFC 4572 Section 5).
 */
class DtlsFingerprint {
	final String algorithm;
	final String value;

  DtlsFingerprint({this.algorithm, this.value});
  
  static DtlsFingerprint fromDynamic(data) {
    return DtlsFingerprint(
      algorithm: data['algorithm'],
      value: data['value'],
    );
  }
}

class RTCIceServer {
    // fincal RTCOAuthCredential credential;
    // final RTCIceCredentialType credentialType;
    final List<String> urls;
    final String username;

  RTCIceServer({this.urls, this.username});

  static RTCIceServer fromDynamic(dynamic data) {
    return RTCIceServer(
      urls: data['urls'],
      username: data['username'],
    );
  }
}
enum RTCIceTransportPolicy {
  relay, all
}

class TransportOptions {
	final String id;
	final IceParameters iceParameters;
	final List<IceCandidate> iceCandidates;
	final DtlsParameters dtlsParameters;
	final List<SctpParameters> sctpParameters;
	final List<RTCIceServer> iceServers;
	final RTCIceTransportPolicy iceTransportPolicy;
	final dynamic additionalSettings;
	final dynamic proprietaryConstraints;
	final dynamic appData;

  TransportOptions({this.id, this.iceParameters, this.iceCandidates, this.dtlsParameters, this.sctpParameters, this.iceServers, this.iceTransportPolicy, this.additionalSettings, this.proprietaryConstraints, this.appData});

  static TransportOptions fromDynamic(dynamic data) {
    return TransportOptions(
      id: data['id'],
      iceParameters: IceParameters.fromDynamic(data['iceParameters']),
      iceCandidates: data['iceCandidates'].map<IceCandidate>((iceCandidate) => IceCandidate.fromDynamic(iceCandidate)).toList(),
      dtlsParameters: DtlsParameters.fromDynamic(data['dtlsParameters']),
      sctpParameters: data['sctpParameters'] == null ? [] : data['sctpParameters'].map<SctpParameters>((sctpParameters) => SctpParameters.fromDynamic(sctpParameters)).toList(),
      iceServers: data['iceServers'] == null ? [] : data['iceServers'].map<RTCIceServer>((iceServer) => RTCIceServer.fromDynamic(iceServer)).toList(),
      iceTransportPolicy: data['iceTransportPolicy'] == null ? RTCIceTransportPolicy.all : RTCIceTransportPolicy.values.firstWhere((e) => e.toString() == 'RTCIceTransportPolicy.${data['iceTransportPolicy']}'),
      additionalSettings: data['additionalSettings'],
      proprietaryConstraints: data['proprietaryConstraints'],
      appData: data['appData'],
    );
  }
}

enum TransportDirection {
  send, recv
}


/* Provides the ability to control and obtain details about how a particular MediaStreamTrack is encoded and sent to a remote peer. */
class RTCRtpSender {
    // final RTCDTMFSender dtmf;
    // final RTCDtlsTransport rtcpTransport;
    // final MediaStreamTrack track;
    // final RTCDtlsTransport transport;
    // getParameters(): RTCRtpSendParameters;
    // getStats(): Promise<RTCStatsReport>;
    // replaceTrack(withTrack: MediaStreamTrack | null): Promise<void>;
    // setParameters(parameters: RTCRtpSendParameters): Promise<void>;
    // setStreams(...streams: MediaStream[]): void;
}

class CanProduceByKind
{
	bool audio;
	bool video;

  bool operator [] (String kind) {
    return (kind == 'audio' && audio) || (kind == 'video' && video);
  }
}

class Transport extends EventEmitter {
  Handler _handler;
	final String id;

	// Closed flag.
	bool closed = false;

	// Direction.
	final TransportDirection direction;

	final IceParameters iceParameters;
	final List<IceCandidate> iceCandidates;
	final DtlsParameters dtlsParameters;
	final List<SctpParameters> sctpParameters;
	final List<RTCIceServer> iceServers;
	final RTCIceTransportPolicy iceTransportPolicy;
	final dynamic additionalSettings;
	final dynamic proprietaryConstraints;

	// Extended RTP capabilities.
	final RtpCapabilities extendedRtpCapabilities;

	// Whether we can produce audio/video based on computed extended RTP
	// capabilities.
	final CanProduceByKind canProduceByKind;

	// SCTP max message size if enabled, null otherwise.
	int _maxSctpMessageSize;

	// Transport connection state.
	ConnectionState _connectionState = ConnectionState.new_;

	// App custom data.
	final dynamic appData;

	// Map of Producers indexed by id.
	Map<String, Producer> _producers = Map<String, Producer>();

	// // Map of Consumers indexed by id.
	// Map<String, Consumer> consumers = Map<String, Consumer>();

	// // Map of DataProducers indexed by id.
	// Map<String, DataProducer> dataProducers = Map<String, DataProducer>();

	// // Map of DataConsumers indexed by id.
	// Map<String, DataConsumer> dataConsumers: Map<String, DataConsumer>();

	// Whether the Consumer for RTP probation has been created.
	bool probatorConsumerCreated = false;

	// StreamController instance to make async tasks happen sequentially.
	StreamController<Function> _awaitQueue = StreamController<Function>();

	/*
	 * @emits connect - (transportLocalParameters: any, callback: Function, errback: Function)
	 * @emits connectionstatechange - (connectionState: ConnectionState)
	 * @emits produce - (producerLocalParameters: any, callback: Function, errback: Function)
	 * @emits producedata - (dataProducerLocalParameters: any, callback: Function, errback: Function)
	 */
	Transport({
    this.direction,
    this.id,
    this.iceParameters,
    this.iceCandidates,
    this.dtlsParameters,
    this.sctpParameters,
    this.iceServers,
    this.iceTransportPolicy,
    this.additionalSettings,
    this.proprietaryConstraints,
    this.appData,
    this.extendedRtpCapabilities,
    this.canProduceByKind
  }) {
    if(direction == TransportDirection.send) {
      
      var sendingRtpParametersByKind = RtpParametersByKind(
        audio: ortc.getSendingRtpParameters(MediaKind.audio, extendedRtpCapabilities),
        video: ortc.getSendingRtpParameters(MediaKind.video, extendedRtpCapabilities)
      );

      var sendingRemoteRtpParametersByKind = RtpParametersByKind(
        audio: ortc.getSendingRemoteRtpParameters(MediaKind.audio, extendedRtpCapabilities),
        video: ortc.getSendingRemoteRtpParameters(MediaKind.video, extendedRtpCapabilities)
      );
      
      _handler = SendHandler(
        iceServers: iceServers, 
        iceTransportPolicy: iceTransportPolicy, 
        iceParameters: iceParameters, 
        iceCandidates: iceCandidates, 
        dtlsParameters: dtlsParameters, 
        sctpParameters: sctpParameters,
        sendingRtpParametersByKind: sendingRtpParametersByKind,
        sendingRemoteRtpParametersByKind: sendingRemoteRtpParametersByKind
      );
    }
    else {
      // TODO
    }
		_maxSctpMessageSize = sctpParameters != null && sctpParameters.isNotEmpty ? sctpParameters.first.maxMessageSize : null;

    _awaitQueue.stream.forEach((Function action) => action());
		// // Clone and sanitize additionalSettings.
		// additionalSettings = utils.clone(additionalSettings);

		// delete additionalSettings.iceServers;
		// delete additionalSettings.iceTransportPolicy;
		// delete additionalSettings.bundlePolicy;
		// delete additionalSettings.rtcpMuxPolicy;
		// delete additionalSettings.sdpSemantics;

		this._handleHandler();
	}

	// /*
	//  * Close the Transport.
	//  */
	// close(): void
	// {
	// 	if (this._closed)
	// 		return;

	// 	logger.debug('close()');

	// 	this._closed = true;

	// 	// Close the AwaitQueue.
	// 	this._awaitQueue.close();

	// 	// Close the handler.
	// 	this._handler.close();

	// 	// Close all Producers.
	// 	for (const producer of this._producers.values())
	// 	{
	// 		producer.transportClosed();
	// 	}
	// 	this._producers.clear();

	// 	// Close all Consumers.
	// 	for (const consumer of this._consumers.values())
	// 	{
	// 		consumer.transportClosed();
	// 	}
	// 	this._consumers.clear();

	// 	// Close all DataProducers.
	// 	for (const dataProducer of this._dataProducers.values())
	// 	{
	// 		dataProducer.transportClosed();
	// 	}
	// 	this._dataProducers.clear();

	// 	// Close all DataConsumers.
	// 	for (const dataConsumer of this._dataConsumers.values())
	// 	{
	// 		dataConsumer.transportClosed();
	// 	}
	// 	this._dataConsumers.clear();
	// }

	// /**
	//  * Get associated Transport (RTCPeerConnection) stats.
	//  *
	//  * @returns {RTCStatsReport}
	//  */
	// async getStats(): Promise<any>
	// {
	// 	if (this._closed)
	// 		throw new InvalidStateError('closed');

	// 	return this._handler.getTransportStats();
	// }

	// /**
	//  * Restart ICE connection.
	//  */
	// async restartIce(
	// 	{ iceParameters }:
	// 	{ iceParameters: IceParameters }
	// ): Promise<void>
	// {
	// 	logger.debug('restartIce()');

	// 	if (this._closed)
	// 		throw new InvalidStateError('closed');
	// 	else if (!iceParameters)
	// 		throw new TypeError('missing iceParameters');

	// 	// Enqueue command.
	// 	return this._awaitQueue.push(
	// 		async () => this._handler.restartIce({ iceParameters }));
	// }

	// /**
	//  * Update ICE servers.
	//  */
	// async updateIceServers(
	// 	{ iceServers }:
	// 	{ iceServers?: RTCIceServer[] } = {}
	// ): Promise<void>
	// {
	// 	logger.debug('updateIceServers()');

	// 	if (this._closed)
	// 		throw new InvalidStateError('closed');
	// 	else if (!Array.isArray(iceServers))
	// 		throw new TypeError('missing iceServers');

	// 	// Enqueue command.
	// 	return this._awaitQueue.push(
	// 		async () => this._handler.updateIceServers({ iceServers }));
	// }

	/*
	 * Create a Producer.
	 */
	Future<Producer> produce({@required MediaStreamTrack track, @required MediaStream stream}) {
		if (this.direction != TransportDirection.send)
			throw new UnsupportedError('not a sending Transport');
		else if (!this.canProduceByKind[track.kind.toLowerCase()])
			throw new UnsupportedError('cannot produce ${track.kind}');
		else if (!hasListener('connect') && _connectionState == ConnectionState.new_)
			throw new TypeError();
		else if (!hasListener('produce'))
			throw new TypeError();

		// Enqueue command.
    Completer<Producer> completer = Completer<Producer>();
		_awaitQueue.add(() async {
      // var normalizedEncodings;

      // if (encodings && !Array.isArray(encodings))
      // {
      // 	throw TypeError('encodings must be an array');
      // }
      // else if (encodings && encodings.length === 0)
      // {
      // 	normalizedEncodings = undefined;
      // }
      // else if (encodings)
      // {
      // 	normalizedEncodings = encodings
      // 		.map((encoding: any) =>
      // 		{
      // 			const normalizedEncoding: any = { active: true };

      // 			if (encoding.active === false)
      // 				normalizedEncoding.active = false;
      // 			if (typeof encoding.maxBitrate === 'number')
      // 				normalizedEncoding.maxBitrate = encoding.maxBitrate;
      // 			if (typeof encoding.maxFramerate === 'number')
      // 				normalizedEncoding.maxFramerate = encoding.maxFramerate;
      // 			if (typeof encoding.scaleResolutionDownBy === 'number')
      // 				normalizedEncoding.scaleResolutionDownBy = encoding.scaleResolutionDownBy;
      // 			if (typeof encoding.dtx === 'boolean')
      // 				normalizedEncoding.dtx = encoding.dtx;
      // 			if (typeof encoding.scalabilityMode === 'string')
      // 				normalizedEncoding.scalabilityMode = encoding.scalabilityMode;
      // 			if (typeof encoding.priority === 'string')
      // 				normalizedEncoding.priority = encoding.priority;
      // 			if (typeof encoding.networkPriority === 'string')
      // 				normalizedEncoding.networkPriority = encoding.networkPriority;

      // 			return normalizedEncoding;
      // 		});
      // }

      // var [localId, rtpSender, rtpParameters] = (_handler as SendHandler).send(
      var rtpParameters = await (_handler as SendHandler).send(
        track: track,
        stream: stream,
        // encodings : normalizedEncodings,
        // codecOptions
      );

      try
      {
        Future<String> futureId = emit('produce', track.kind, rtpParameters, appData);
        var id  = await futureId;

        var producer = Producer(
          id: id, 
          // localId: localId, 
          // rtpSender: rtpSender, 
          track: track,
          rtpParameters: rtpParameters, 
          appData: appData
        );

        _producers[producer.id] = producer;
        _handleProducer(producer);

        completer.complete(producer);
      }
      catch (error)
      {
        (_handler as SendHandler).stopSending(localId: localId).catchError(() => {});

        completer.completeError(error);
      }
    });

    return completer.future;
	}

	// /**
	//  * Create a Consumer to consume a remote Producer.
	//  */
	// async consume(
	// 	{
	// 		id,
	// 		producerId,
	// 		kind,
	// 		rtpParameters,
	// 		appData = {}
	// 	}: ConsumerOptions = {}
	// ): Promise<Consumer>
	// {
	// 	logger.debug('consume()');

	// 	if (this._closed)
	// 		throw new InvalidStateError('closed');
	// 	else if (this._direction !== 'recv')
	// 		throw new UnsupportedError('not a receiving Transport');
	// 	else if (typeof id !== 'string')
	// 		throw new TypeError('missing id');
	// 	else if (typeof producerId !== 'string')
	// 		throw new TypeError('missing producerId');
	// 	else if (kind !== 'audio' && kind !== 'video')
	// 		throw new TypeError(`invalid kind '${kind}'`);
	// 	else if (typeof rtpParameters !== 'object')
	// 		throw new TypeError('missing rtpParameters');
	// 	else if (this.listenerCount('connect') === 0 && this._connectionState === 'new')
	// 		throw new TypeError('no "connect" listener set into this transport');
	// 	else if (appData && typeof appData !== 'object')
	// 		throw new TypeError('if given, appData must be an object');

	// 	// Enqueue command.
	// 	return this._awaitQueue.push(
	// 		async () =>
	// 		{
	// 			// Ensure the device can consume it.
	// 			const canConsume = ortc.canReceive(
	// 				rtpParameters, this._extendedRtpCapabilities);

	// 			if (!canConsume)
	// 				throw new UnsupportedError('cannot consume this Producer');

	// 			const { localId, rtpReceiver, track } =
	// 				await this._handler.receive({ id, kind, rtpParameters });

	// 			const consumer = new Consumer(
	// 				{ id, localId, producerId, rtpReceiver, track, rtpParameters, appData });

	// 			this._consumers.set(consumer.id, consumer);
	// 			this._handleConsumer(consumer);

	// 			// If this is the first video Consumer and the Consumer for RTP probation
	// 			// has not yet been created, create it now.
	// 			if (!this._probatorConsumerCreated && kind === 'video')
	// 			{
	// 				try
	// 				{
	// 					const probatorRtpParameters =
	// 						ortc.generateProbatorRtpParameters(consumer.rtpParameters);

	// 					await this._handler.receive(
	// 						{
	// 							id            : 'probator',
	// 							kind          : 'video',
	// 							rtpParameters : probatorRtpParameters
	// 						});

	// 					logger.debug('consume() | Consumer for RTP probation created');

	// 					this._probatorConsumerCreated = true;
	// 				}
	// 				catch (error)
	// 				{
	// 					logger.warn(
	// 						'consume() | failed to create Consumer for RTP probation:%o',
	// 						error);
	// 				}
	// 			}

	// 			return consumer;
	// 		});
	// }

	// /**
	//  * Create a DataProducer
	//  */
	// async produceData(
	// 	{
	// 		ordered = true,
	// 		maxPacketLifeTime,
	// 		maxRetransmits,
	// 		priority = 'low',
	// 		label = '',
	// 		protocol = '',
	// 		appData = {}
	// 	}: DataProducerOptions = {}
	// ): Promise<DataProducer>
	// {
	// 	logger.debug('produceData()');

	// 	if (this._direction !== 'send')
	// 		throw new UnsupportedError('not a sending Transport');
	// 	else if (!this._maxSctpMessageSize)
	// 		throw new UnsupportedError('SCTP not enabled by remote Transport');
	// 	else if (![ 'very-low', 'low', 'medium', 'high' ].includes(priority))
	// 		throw new TypeError('wrong priority');
	// 	else if (this.listenerCount('connect') === 0 && this._connectionState === 'new')
	// 		throw new TypeError('no "connect" listener set into this transport');
	// 	else if (this.listenerCount('producedata') === 0)
	// 		throw new TypeError('no "producedata" listener set into this transport');
	// 	else if (appData && typeof appData !== 'object')
	// 		throw new TypeError('if given, appData must be an object');

	// 	if (maxPacketLifeTime || maxRetransmits)
	// 		ordered = false;

	// 	// Enqueue command.
	// 	return this._awaitQueue.push(
	// 		async () =>
	// 		{
	// 			const {
	// 				dataChannel,
	// 				sctpStreamParameters
	// 			} = await this._handler.sendDataChannel(
	// 				{
	// 					ordered,
	// 					maxPacketLifeTime,
	// 					maxRetransmits,
	// 					priority,
	// 					label,
	// 					protocol
	// 				});

	// 			const { id } = await this.safeEmitAsPromise(
	// 				'producedata',
	// 				{
	// 					sctpStreamParameters,
	// 					label,
	// 					protocol,
	// 					appData
	// 				});

	// 			const dataProducer =
	// 				new DataProducer({ id, dataChannel, sctpStreamParameters, appData });

	// 			this._dataProducers.set(dataProducer.id, dataProducer);
	// 			this._handleDataProducer(dataProducer);

	// 			return dataProducer;
	// 		});
	// }

	// /**
	//  * Create a DataConsumer
	//  */
	// async consumeData(
	// 	{
	// 		id,
	// 		dataProducerId,
	// 		sctpStreamParameters,
	// 		label = '',
	// 		protocol = '',
	// 		appData = {}
	// 	}: DataConsumerOptions
	// ): Promise<DataConsumer>
	// {
	// 	logger.debug('consumeData()');

	// 	if (this._closed)
	// 		throw new InvalidStateError('closed');
	// 	else if (this._direction !== 'recv')
	// 		throw new UnsupportedError('not a receiving Transport');
	// 	else if (!this._maxSctpMessageSize)
	// 		throw new UnsupportedError('SCTP not enabled by remote Transport');
	// 	else if (typeof id !== 'string')
	// 		throw new TypeError('missing id');
	// 	else if (typeof dataProducerId !== 'string')
	// 		throw new TypeError('missing dataProducerId');
	// 	else if (typeof sctpStreamParameters !== 'object')
	// 		throw new TypeError('missing sctpStreamParameters');
	// 	else if (this.listenerCount('connect') === 0 && this._connectionState === 'new')
	// 		throw new TypeError('no "connect" listener set into this transport');
	// 	else if (appData && typeof appData !== 'object')
	// 		throw new TypeError('if given, appData must be an object');

	// 	// Enqueue command.
	// 	return this._awaitQueue.push(
	// 		async () =>
	// 		{
	// 			const {
	// 				dataChannel
	// 			} = await this._handler.receiveDataChannel(
	// 				{
	// 					sctpStreamParameters,
	// 					label,
	// 					protocol
	// 				});

	// 			const dataConsumer = new DataConsumer(
	// 				{
	// 					id,
	// 					dataProducerId,
	// 					dataChannel,
	// 					sctpStreamParameters,
	// 					appData
	// 				});

	// 			this._dataConsumers.set(dataConsumer.id, dataConsumer);
	// 			this._handleDataConsumer(dataConsumer);

	// 			return dataConsumer;
	// 		});
	// }

	void _handleHandler() {
		_handler.on('@connect', (DtlsParameters dtlsParameters, Function callback, Function errback) {
			if (closed)
			{
				errback(new InvalidStateError('closed'));
				return;
			}

			emit('connect', dtlsParameters, callback, errback);
		});

		_handler.on('@connectionstatechange', (ConnectionState connectionState) {
			if (connectionState == _connectionState)
				return;

			this._connectionState = connectionState;

			if (!closed)
				emit('connectionstatechange', connectionState);
		});
	}

	void _handleProducer(Producer producer) {
		producer.on('@close', () {
			_producers.remove(producer.id);

			if (closed)
				return;

			_awaitQueue.add(() {
        try {
          // _handler.stopSending({ localId: producer.localId })
        }
        catch(err) {
          print('producer.close() failed: $err');
        }
      });
		});

		producer.on('@replacetrack', (track, Function callback, Function errback) {
			_awaitQueue.add(() {
        try {
          _handler.replaceTrack(track, localId: producer.localId);
          callback();
        }
        catch(err) {
          errback(err);
        }
      });
		});

		producer.on('@setmaxspatiallayer', (spatialLayer, callback, errback) {
			_awaitQueue.add(() {
        try {
					_handler.setMaxSpatialLayer(spatialLayer, localId: producer.localId);
          callback();
        }
        catch(err) {
          errback(err);
        }
      });
		});

		producer.on('@setrtpencodingparameters', (params, Function callback, Function errback) {
			_awaitQueue.add(() {
				try {
          _handler.setRtpEncodingParameters(params, localId: producer.localId);
          callback();
        }
        catch(err) {
          errback(err);
        }
		  });
		});

		producer.on('@getstats', (callback, errback) {
			if (closed) {
				return errback(new InvalidStateError('closed'));
      }

      try {
        _handler.getSenderStats(localId: producer.localId);
        callback();
      }
      catch(err) {
        errback(err);
      }
		});
	}

	// _handleConsumer(consumer: Consumer): void
	// {
	// 	consumer.on('@close', () =>
	// 	{
	// 		this._consumers.delete(consumer.id);

	// 		if (this._closed)
	// 			return;

	// 		this._awaitQueue.push(
	// 			async () => this._handler.stopReceiving({ localId: consumer.localId }))
	// 			.catch(() => {});
	// 	});

	// 	consumer.on('@getstats', (callback, errback) =>
	// 	{
	// 		if (this._closed)
	// 			return errback(new InvalidStateError('closed'));

	// 		this._handler.getReceiverStats({ localId: consumer.localId })
	// 			.then(callback)
	// 			.catch(errback);
	// 	});
	// }

	// _handleDataProducer(dataProducer: DataProducer): void
	// {
	// 	dataProducer.on('@close', () =>
	// 	{
	// 		this._dataProducers.delete(dataProducer.id);
	// 	});
	// }

	// _handleDataConsumer(dataConsumer: DataConsumer): void
	// {
	// 	dataConsumer.on('@close', () =>
	// 	{
	// 		this._dataConsumers.delete(dataConsumer.id);
	// 	});
	// }
}
