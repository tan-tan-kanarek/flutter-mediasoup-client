import 'dart:async';

import 'package:flutter_webrtc/webrtc.dart';
import 'package:mediasoup_client/events.dart';
import 'package:mediasoup_client/rtp_parameters.dart';
import 'package:mediasoup_client/sctp_parameters.dart';
import 'package:mediasoup_client/sdp.dart';
import 'package:mediasoup_client/transport.dart';


class ScalabilityMode {
  static final scalabilityModeRegex = new RegExp('^[LS]([1-9]\\d{0,1})T([1-9]\\d{0,1})');

	final int spatialLayers;
	final int temporalLayers;

  ScalabilityMode({this.spatialLayers, this.temporalLayers});
}

ScalabilityMode parseScalabilityMode(String scalabilityMode) {
	Iterable<RegExpMatch> matches = ScalabilityMode.scalabilityModeRegex.allMatches(scalabilityMode);

	if (matches.isNotEmpty) {
    var match = matches.first;
		return ScalabilityMode(
			spatialLayers  : int.parse(match[1]),
			temporalLayers : int.parse(match[2])
		);
	}
	else {
		return ScalabilityMode(
			spatialLayers  : 1,
			temporalLayers : 1
		);
	}
}


class Handler extends EventEmitter {
  RTCPeerConnection _pc;
  RemoteSdp _remoteSdp;
  bool _transportReady = false;

  Handler({List<RTCIceServer> iceServers, RTCIceTransportPolicy iceTransportPolicy, IceParameters iceParameters, List<IceCandidate> iceCandidates, DtlsParameters dtlsParameters, List<SctpParameters> sctpParameters}) { 
		_remoteSdp = RemoteSdp(
      iceParameters: iceParameters,
      iceCandidates: iceCandidates,
      dtlsParameters: dtlsParameters,
      sctpParameters: sctpParameters
    );
      
    _init(iceServers, iceTransportPolicy);
  }

  Future<void> _init(iceServers, iceTransportPolicy) async {    
      Map<String, dynamic> configuration = {
        "iceServers"         : iceServers,
        "iceTransportPolicy" : iceTransportPolicy.toString().split('.')[1],
        "bundlePolicy"       : 'max-bundle',
        "rtcpMuxPolicy"      : 'require',
        "sdpSemantics"       : 'unified-plan'
      };

      final Map<String, dynamic> constraints = {
        "mandatory": {},
        "optional": [
          {"DtlsSrtpKeyAgreement": true},
        ],
      };

      try {
        _pc = await createPeerConnection(configuration, constraints);
        _pc.onIceConnectionState = (RTCIceConnectionState state) {
          switch (state) {
            case RTCIceConnectionState.RTCIceConnectionStateChecking:
              emit('@connectionstatechange', 'connecting');
              break;
            case RTCIceConnectionState.RTCIceConnectionStateConnected:
            case RTCIceConnectionState.RTCIceConnectionStateCompleted:
              emit('@connectionstatechange', 'connected');
              break;
            case RTCIceConnectionState.RTCIceConnectionStateFailed:
              emit('@connectionstatechange', 'failed');
              break;
            case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
              emit('@connectionstatechange', 'disconnected');
              break;
            case RTCIceConnectionState.RTCIceConnectionStateClosed:
              emit('@connectionstatechange', 'closed');
              break;
            default:
              break;
          }
        };
      }
      catch (error)
      {
        try { _pc.close(); }
        catch (error2) {}

        throw error;
      }
  }
  
	Future<void> _setupTransport({ DtlsRole localDtlsRole, dynamic localSdpObject }) async {
		if (localSdpObject == null) {
      RTCSessionDescription localDescription = await _pc.getLocalDescription();
			localSdpObject = SdpTransform.parse(localDescription.sdp);
    }

		// Get our local DTLS parameters.
		DtlsParameters dtlsParameters = SdpTransform.extractDtlsParameters(localSdpObject);

		// Set our DTLS role.
		dtlsParameters.role = localDtlsRole;

		// Update the remote DTLS role in the SDP.
		_remoteSdp.updateDtlsRole(localDtlsRole == DtlsRole.client ? DtlsRole.server : DtlsRole.client);

		// Need to tell the remote transport about our parameters.
		emit('@connect', dtlsParameters);

		_transportReady = true;
	}

  static NumSctpStreams _sctpNumStreams = NumSctpStreams(os: 1024, mis: 1024);

  static Future<RtpCapabilities> getNativeRtpCapabilities() async {
    
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
      try {
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
  
	static SctpCapabilities getNativeSctpCapabilities() {
		return SctpCapabilities(
			numStreams : _sctpNumStreams
		);
	}
}

class SendHandler extends Handler {
  RtpParametersByKind sendingRtpParametersByKind;
  RtpParametersByKind sendingRemoteRtpParametersByKind;
  
  SendHandler({
    List<RTCIceServer> iceServers, 
    RTCIceTransportPolicy iceTransportPolicy, 
    IceParameters iceParameters, 
    List<IceCandidate> iceCandidates, 
    DtlsParameters dtlsParameters, 
    List<SctpParameters> sctpParameters,    
    this.sendingRtpParametersByKind,
    this.sendingRemoteRtpParametersByKind
  }) : super(
    iceServers: iceServers, 
    iceTransportPolicy: iceTransportPolicy, 
    iceParameters: iceParameters, 
    iceCandidates: iceCandidates, 
    dtlsParameters: dtlsParameters, 
    sctpParameters: sctpParameters,
  );

	Future<RtpParameters> send({
      MediaStreamTrack track, 
      MediaStream stream,
      encodings, 
      codecOptions 
    }) async {
		// if (encodings && encodings.length > 1)
		// {
		// 	encodings.forEach((encoding: any, idx: number) =>
		// 	{
		// 		encoding.rid = `r${idx}`;
		// 	});
		// }

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": false,
        "OfferToReceiveVideo": false,
      },
      "optional": [],
    };
    
		var mediaSectionIdx = _remoteSdp.getNextMediaSectionIdx();
		_pc.addStream(stream);
		var offer = await _pc.createOffer(offerSdpConstraints);
		var localSdpObject = SdpTransform.parse(offer.sdp);
		var offerMediaObject;
		var sendingRtpParameters = sendingRtpParametersByKind[track.kind];

		if (!_transportReady) {
			_setupTransport(localDtlsRole: DtlsRole.server, localSdpObject: localSdpObject);
    }

		// Special case for VP9 with SVC.
		var hackVp9Svc = false;

		// var layers = parseScalabilityMode((encodings || [ {} ])[0].scalabilityMode);

		// if (
		// 	encodings &&
		// 	encodings.length === 1 &&
		// 	layers.spatialLayers > 1 &&
		// 	sendingRtpParameters.codecs[0].mimeType.toLowerCase() === 'video/vp9'
		// ) {
		// 	hackVp9Svc = true;
		// 	localSdpObject = sdpTransform.parse(offer.sdp);
		// 	offerMediaObject = localSdpObject.media[mediaSectionIdx.idx];

		// 	sdpUnifiedPlanUtils.addLegacySimulcast(
		// 		{
		// 			offerMediaObject,
		// 			numStreams : layers.spatialLayers
		// 		});

		// 	offer = { type: 'offer', sdp: sdpTransform.write(localSdpObject) };
		// }

		await _pc.setLocalDescription(offer);

		// We can now get the transceiver.mid.
		// var localId = transceiver.mid;

		// Set MID.
		sendingRtpParameters.mid = stream.id;

    var localDescription = await _pc.getLocalDescription();
		localSdpObject = SdpTransform.parse(localDescription.sdp);
		offerMediaObject = localSdpObject['media'][mediaSectionIdx.idx];

		// Set RTCP CNAME.
		sendingRtpParameters.rtcp.cname = SdpTransform.getCname(offerMediaObject);

		// Set RTP encodings by parsing the SDP offer if no encodings are given.
		// if (!encodings) {
			sendingRtpParameters.setRtpEncodings(offerMediaObject);
		// }
		// Set RTP encodings by parsing the SDP offer and complete them with given
		// one if just a single encoding has been given.
		// else if (encodings.length == 1) {
		// 	var newEncodings = sdpUnifiedPlanUtils.getRtpEncodings({ offerMediaObject });

			// Object.assign(newEncodings[0], encodings[0]);

			// Hack for VP9 SVC.
		// 	if (hackVp9Svc) {
		// 		newEncodings = [ newEncodings[0] ];
    //   }

		// 	sendingRtpParameters.encodings = newEncodings;
		// }
		// Otherwise if more than 1 encoding are given use them verbatim.
		// else {
		// 	sendingRtpParameters.encodings = encodings;
		// }

		// If VP8 or H264 and there is effective simulcast, add scalabilityMode to
		// each encoding.
		if (
			sendingRtpParameters.encodings.length > 1 &&
			(
				sendingRtpParameters.codecs[0].mimeType.toLowerCase() == 'video/vp8' ||
				sendingRtpParameters.codecs[0].mimeType.toLowerCase() == 'video/h264'
			)
		) {
			for (RtpEncodingParameters encoding in sendingRtpParameters.encodings)
			{
				encoding.scalabilityMode = 'S1T3';
			}
		}

		_remoteSdp.send(
				offerMediaObject    : offerMediaObject,
				reuseMid            : mediaSectionIdx.reuseMid,
				offerRtpParameters  : sendingRtpParameters,
				answerRtpParameters : sendingRemoteRtpParametersByKind[track.kind],
				codecOptions        : codecOptions,
				extmapAllowMixed    : true,
			);

		var answer = RTCSessionDescription(_remoteSdp.getSdp(), 'answer');

		await _pc.setRemoteDescription(answer);

		// Store in the map.
		// _mapMidTransceiver[localId] = transceiver;

		// return [localId, transceiver.sender, sendingRtpParameters];
		return sendingRtpParameters;
	}
  
	Future<void> stopSending({ String localId }) async {
		var transceiver = _mapMidTransceiver[localId];

		if (!transceiver) {
			throw 'associated RTCRtpTransceiver not found';
    }

		transceiver.sender.replaceTrack(null);
		_pc.removeStream(transceiver.sender);
		// _remoteSdp.closeMediaSection(transceiver.mid);

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": false,
        "OfferToReceiveVideo": false,
      },
      "optional": [],
    };
		var offer = await _pc.createOffer(offerSdpConstraints);
		await _pc.setLocalDescription(offer);

		var answer = RTCSessionDescription(_remoteSdp.getSdp(), 'answer');
		await this._pc.setRemoteDescription(answer);
	}

}