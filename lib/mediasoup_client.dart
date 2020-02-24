import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:mediasoup_client/handler.dart';
import 'package:mediasoup_client/rtp_parameters.dart';
import 'package:mediasoup_client/sctp_parameters.dart';
import 'package:mediasoup_client/sdp.dart';
import 'package:mediasoup_client/ortc.dart' as ortc;
import 'package:mediasoup_client/transport.dart';


class InvalidStateError implements Exception {
  String message;

  InvalidStateError(this.message);

  String toString() => 'InvalidStateError: $message';
}

Future<dynamic> _getNativeRtpCapabilities() async {
  
    Map<String, dynamic> configuration = {
      "iceServers"         : [],
      "iceTransportPolicy" : 'all',
      "bundlePolicy"       : 'max-bundle',
      "rtcpMuxPolicy"      : 'require',
      "sdpSemantics"       : 'unified-plan'
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": false,
        "OfferToReceiveVideo": false,
      },
      "optional": [],
    };

    final Map<String, dynamic> constraints = {
      "mandatory": {},
      "optional": [
        {"DtlsSrtpKeyAgreement": true},
      ],
    };

    RTCPeerConnection pc;
		try
		{
      pc = await createPeerConnection(configuration, constraints);
      RTCSessionDescription offer = await pc.createOffer(offerSdpConstraints);

			try { pc.close(); }
			catch (error) {}

			var sdpObject = SdpTransform.parse(offer.sdp);
			return SdpTransform.extractRtpCapabilities(sdpObject);
		}
		catch (error)
		{
			try { pc.close(); }
			catch (error2) {}

			throw error;
		}
}

class Device {
  bool loaded = false;
  dynamic _extendedRtpCapabilities;
  CanProduceByKind _canProduceByKind = CanProduceByKind();
  RtpCapabilities _recvRtpCapabilities;
  SctpCapabilities _sctpCapabilities;

  Future<void> load(RtpCapabilities routerRtpCapabilities) async {
		if (loaded) {
			throw InvalidStateError('already loaded');
    }

		var nativeRtpCapabilities = await Handler.getNativeRtpCapabilities();

		// Get extended RTP capabilities.
		RtpCapabilities _extendedRtpCapabilities = ortc.getExtendedRtpCapabilities(
			nativeRtpCapabilities, routerRtpCapabilities);

		// Check whether we can produce audio/video.
		_canProduceByKind.audio =
			ortc.canSend(MediaKind.audio, _extendedRtpCapabilities);
		_canProduceByKind.video =
			ortc.canSend(MediaKind.video, _extendedRtpCapabilities);

		// Generate our receiving RTP capabilities for receiving media.
		_recvRtpCapabilities = ortc.getRecvRtpCapabilities(_extendedRtpCapabilities);

		_sctpCapabilities = Handler.getNativeSctpCapabilities();

		loaded = true;
  }
  
  /*
   * Creates a Transport for sending media.
   *
   * @throws {InvalidStateError} if not loaded.
   * @throws {TypeError} if wrong arguments.
   */
  Transport createSendTransport(TransportOptions options) {
		if (!loaded)
			throw new InvalidStateError('not loaded');
		else if (options.id == null)
			throw new TypeError();
		else if (options.iceParameters == null)
			throw new TypeError();
		else if (options.iceCandidates == null)
			throw new TypeError();
		else if (options.dtlsParameters == null)
			throw new TypeError();

		// Create a new Transport.
		return Transport(
      direction: TransportDirection.send,
      id: options.id,
      iceParameters: options.iceParameters,
      iceCandidates: options.iceCandidates,
      dtlsParameters: options.dtlsParameters,
      sctpParameters: options.sctpParameters,
      iceServers: options.iceServers,
      iceTransportPolicy: options.iceTransportPolicy,
      additionalSettings: options.additionalSettings,
      proprietaryConstraints: options.proprietaryConstraints,
      appData: options.appData,
      extendedRtpCapabilities : this._extendedRtpCapabilities,
      canProduceByKind        : this._canProduceByKind
		);
  }
}

class MediasoupClient {
  static const MethodChannel _channel =
      const MethodChannel('mediasoup_client');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
