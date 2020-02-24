/*
 * The RTP capabilities define what mediasoup or an endpoint can receive at
 * media level.
 */

class RtpCapabilities {
	/*
	 * Supported media and RTX codecs.
	 */
	final List<RtpCodecCapability> codecs;

	/*
	 * Supported RTP header extensions.
	 */
	final List<RtpHeaderExtension> headerExtensions;

	/*
	 * Supported FEC mechanisms.
	 */
	List<String> fecMechanisms;

  RtpCapabilities({this.codecs, this.headerExtensions, this.fecMechanisms});

  static RtpCapabilities fromDynamic(dynamic capabilities) {
    List<RtpCodecCapability> codecs;
    List<RtpHeaderExtension> headerExtensions;
    List<String> fecMechanisms;

    if(capabilities['codecs'] != null) {
      codecs = capabilities['codecs'].map<RtpCodecCapability>((codec) => RtpCodecCapability.fromDynamic(codec)).toList();
    }
    
    if(capabilities['headerExtensions'] != null) {
      headerExtensions = capabilities['headerExtensions'].map<RtpHeaderExtension>((headerExtension) => RtpHeaderExtension.fromDynamic(headerExtension)).toList();
    }
    
    if(capabilities['fecMechanisms'] != null) {
      fecMechanisms = capabilities['fecMechanisms'].map<String>((fecMechanism) => fecMechanism.toString()).toList();
    }

    return RtpCapabilities(
      codecs: codecs,
      headerExtensions: headerExtensions,
      fecMechanisms: fecMechanisms,
    );
  }
}

enum MediaKind {
  audio,
  video
}

/*
 * Provides information on the capabilities of a codec within the RTP
 * capabilities. The list of media codecs supported by mediasoup and their
 * settings is defined in the supportedRtpCapabilities.ts file.
 *
 * Exactly one RtpCodecCapability will be present for each supported combination
 * of parameters that requires a distinct value of preferredPayloadType. For
 * example:
 *
 * - Multiple H264 codecs, each with their own distinct 'packetization-mode' and
 *   'profile-level-id' values.
 * - Multiple VP9 codecs, each with their own distinct 'profile-id' value.
 *
 * RtpCodecCapability entries in the mediaCodecs array of RouterOptions do not
 * require preferredPayloadType field (if unset, mediasoup will choose a random
 * one). If given, make sure it's in the 96-127 range.
 */
class RtpCodecCapability {
	/*
	 * Media kind.
	 */
	final MediaKind kind;

	/*
	 * The codec MIME media type/subtype (e.g. 'audio/opus', 'video/VP8').
	 */
	final String mimeType;

	/*
	 * The preferred RTP payload type.
	 */
	final int preferredPayloadType;

	/*
	 * Codec clock rate expressed in Hertz.
	 */
	final int clockRate;

	/*
	 * The number of channels supported (e.g. two for stereo). Just for audio.
	 * Default 1.
	 */
	int channels;

	/*
	 * Codec specific parameters. Some parameters (such as 'packetization-mode'
	 * and 'profile-level-id' in H264 or 'profile-id' in VP9) are critical for
	 * codec matching.
	 */
	dynamic parameters = {};

	/*
	 * Transport layer and codec-specific feedback messages for this codec.
	 */
	final List<RtcpFeedback> rtcpFeedback;

  RtpCodecCapability({this.kind, this.mimeType, this.preferredPayloadType, this.clockRate, this.channels, this.parameters, this.rtcpFeedback});

  static RtpCodecCapability fromDynamic(dynamic codecCapability) {
    return RtpCodecCapability(
      kind: codecCapability['kind'].toLowerCase() == 'audio' ? MediaKind.audio : (codecCapability['kind'].toLowerCase() == 'video' ? MediaKind.video : null),
      mimeType: codecCapability['kind'],
      preferredPayloadType: codecCapability['preferredPayloadType'],
      clockRate: codecCapability['clockRate'],
      channels: codecCapability['channels'],
      parameters: codecCapability['parameters'],
      rtcpFeedback: codecCapability['rtcpFeedback'] == null ? null : codecCapability['rtcpFeedback'].map<RtcpFeedback>((fb) => RtcpFeedback.fromDynamic(fb)).toList(),
    );
  }
}

class RtpExtendedCodecCapability extends RtpCodecCapability {
	final int localPayloadType;
	final int remotePayloadType;
	final dynamic localParameters;
	final dynamic remoteParameters;
  int localRtxPayloadType;
  int remoteRtxPayloadType;

  RtpExtendedCodecCapability({this.localPayloadType, this.remotePayloadType, this.localParameters, this.remoteParameters, MediaKind kind, String mimeType, int preferredPayloadType, int clockRate, int channels, dynamic parameters, List<RtcpFeedback> rtcpFeedback}) : super(
    kind: kind, 
    mimeType: mimeType, 
    preferredPayloadType: preferredPayloadType, 
    clockRate: clockRate, 
    channels: channels, 
    parameters: parameters, 
    rtcpFeedback: rtcpFeedback
  );
}

/*
 * Provides information on RTCP feedback messages for a specific codec. Those
 * messages can be transport layer feedback messages or codec-specific feedback
 * messages. The list of RTCP feedbacks supported by mediasoup is defined in the
 * supportedRtpCapabilities.ts file.
 */
class RtcpFeedback {
	/*
	 * RTCP feedback type.
	 */
	final String type;

	/*
	 * RTCP feedback parameter.
	 */
	final String parameter;

  RtcpFeedback({this.type, this.parameter});
  
  static RtcpFeedback fromDynamic(dynamic fb) {
    return RtcpFeedback(
      type: fb['type'],
      parameter: fb['parameter'],
    );
  }
}

/*
 * Direction of RTP header extension.
 */
enum RtpHeaderExtensionDirection{
  sendrecv,
  sendonly,
  recvonly,
  inactive
}

/*
 * Provides information relating to supported header extensions. The list of
 * RTP header extensions supported by mediasoup is defined in the
 * supportedRtpCapabilities.ts file.
 *
 * mediasoup does not currently support encrypted RTP header extensions. The
 * direction field is just present in mediasoup RTP capabilities (retrieved via
 * router.rtpCapabilities or mediasoup.getSupportedRtpCapabilities()). It's
 * ignored if present in endpoints' RTP capabilities.
 */
class RtpHeaderExtension {
	/*
	 * Media kind. If unset, it's valid for all kinds.
	 * Default any media kind.
	 */
	final MediaKind kind;

	/*
	 * The URI of the RTP header extension, as defined in RFC 5285.
	 */
	final String uri;

	/*
	 * The preferred numeric identifier that goes in the RTP packet. Must be
	 * unique.
	 */
	final int preferredId;
	final int sendId;
	final int recvId;

	/*
	 * If true, it is preferred that the value in the header be encrypted as per
	 * RFC 6904. Default false.
	 */
	final bool preferredEncrypt;

	/*
	 * If 'sendrecv', mediasoup supports sending and receiving this RTP extension.
	 * 'sendonly' means that mediasoup can send (but not receive) it. 'recvonly'
	 * means that mediasoup can receive (but not send) it.
	 */
	final RtpHeaderExtensionDirection direction;

  RtpHeaderExtension({this.kind, this.uri, this.preferredId, this.sendId, this.recvId, this.preferredEncrypt, this.direction});
  
  static RtpHeaderExtensionDirection _directionFromString(String direction) {
    switch(direction) {
      case 'sendrecv':
        return RtpHeaderExtensionDirection.sendrecv;

      case 'sendonly':
        return RtpHeaderExtensionDirection.sendonly;

      case 'recvonly':
        return RtpHeaderExtensionDirection.recvonly;

      case 'inactive':
        return RtpHeaderExtensionDirection.inactive;
    }
    return null;
  }

  static RtpHeaderExtension fromDynamic(dynamic rtpHeaderExtension) {
    return RtpHeaderExtension(
      kind: rtpHeaderExtension['kind'].toLowerCase() == 'audio' ? MediaKind.audio : (rtpHeaderExtension['kind'].toLowerCase() == 'video' ? MediaKind.video : null),
      uri: rtpHeaderExtension['uri'],
      preferredId: rtpHeaderExtension['preferredId'],
      preferredEncrypt: rtpHeaderExtension['preferredEncrypt'],
      direction: _directionFromString(rtpHeaderExtension['direction']),
    );
  }
}

/*
 * Provides information on codec settings within the RTP parameters. The list
 * of media codecs supported by mediasoup and their settings is defined in the
 * supportedRtpCapabilities.ts file.
 */
class RtpCodecParameters {
	/*
	 * The codec MIME media type/subtype (e.g. 'audio/opus', 'video/VP8').
	 */
	final String mimeType;

	/*
	 * The value that goes in the RTP Payload Type Field. Must be unique.
	 */
	final int payloadType;

	/*
	 * Codec clock rate expressed in Hertz.
	 */
	final int clockRate;

	/*
	 * The number of channels supported (e.g. two for stereo). Just for audio.
	 * Default 1.
	 */
	final int channels;

	/*
	 * Codec-specific parameters available for signaling. Some parameters (such
	 * as 'packetization-mode' and 'profile-level-id' in H264 or 'profile-id' in
	 * VP9) are critical for codec matching.
	 */
	final dynamic parameters;

	/*
	 * Transport layer and codec-specific feedback messages for this codec.
	 */
	List<RtcpFeedback> rtcpFeedback;

  RtpCodecParameters({this.mimeType, this.payloadType, this.clockRate, this.channels, this.parameters, this.rtcpFeedback});
}

/*
 * Defines a RTP header extension within the RTP parameters. The list of RTP
 * header extensions supported by mediasoup is defined in the
 * supportedRtpCapabilities.ts file.
 *
 * mediasoup does not currently support encrypted RTP header extensions and no
 * parameters are currently considered.
 */
class RtpHeaderExtensionParameters
{
	/*
	 * The URI of the RTP header extension, as defined in RFC 5285.
	 */
	final String uri;

	/*
	 * The numeric identifier that goes in the RTP packet. Must be unique.
	 */
	final int id;

	/*
	 * If true, the value in the header is encrypted as per RFC 6904. Default false.
	 */
	final bool encrypt;

	/*
	 * Configuration parameters for the header extension.
	 */
	final dynamic parameters;

  RtpHeaderExtensionParameters({this.uri, this.id, this.encrypt, this.parameters});
}

enum RtpPriority {
  very_low, low, medium, high
}

/*
 * Provides information relating to an encoding, which represents a media RTP
 * stream and its associated RTX stream (if any).
 */
class RtpEncodingParameters {
	/*
	 * The media SSRC.
	 */
	final int ssrc;

	/*
	 * The RID RTP extension value. Must be unique.
	 */
	final String rid;

	/*
	 * Codec payload type this encoding affects. If unset, first media codec is
	 * chosen.
	 */
	final int codecPayloadType;

	/*
	 * RTX stream information. It must contain a numeric ssrc field indicating
	 * the RTX SSRC.
	 */
	final dynamic rtx;

	/*
	 * It indicates whether discontinuous RTP transmission will be used. Useful
	 * for audio (if the codec supports it) and for video screen sharing (when
	 * static content is being transmitted, this option disables the RTP
	 * inactivity checks in mediasoup). Default false.
	 */
	final bool dtx;

	/*
	 * Number of spatial and temporal layers in the RTP stream (e.g. 'L1T3').
	 * See webrtc-svc.
	 */
	String scalabilityMode;

	final RtpPriority priority;

	final RtpPriority networkPriority;

  RtpEncodingParameters({this.ssrc, this.rid, this.codecPayloadType, this.rtx, this.dtx, this.scalabilityMode, this.priority, this.networkPriority});
}


class RtpParametersByKind {
  final RtpParameters audio;
  final RtpParameters video;

  RtpParametersByKind({this.audio, this.video});

  RtpParameters operator [] (String kind) {
    if(kind == 'audio') {
      return audio;
    }
    if(kind == 'video') {
      return video;
    }
    return null;
  }
}

class RtpParameters
{
	/*
	 * The MID RTP extension value as defined in the BUNDLE specification.
	 */
	String mid;

	/*
	 * Media and RTX codecs in use.
	 */
	final List<RtpCodecParameters> codecs;

	/*
	 * RTP header extensions in use.
	 */
	final List<RtpHeaderExtensionParameters> headerExtensions;

	/*
	 * Transmitted RTP streams and their settings.
	 */
	final List<RtpEncodingParameters> encodings;

	/*
	 * Parameters used for RTCP.
	 */
	final RtcpParameters rtcp;

  RtpParameters({this.mid, this.codecs, this.headerExtensions, this.encodings, this.rtcp});

  
  /*
   * Set RTP encodings.
   *
   * @param {Object} offerMediaObject - Local SDP media Object generated by sdp-transform.
   */
  void setRtpEncodings(offerMediaObject) {
    var ssrcs = Set();

    if(offerMediaObject['ssrcs'] == null) {
      throw 'no a=ssrc lines found';
    }

    for (var line in offerMediaObject['ssrcs']) {
      ssrcs.add(line['id']);
    }

    var ssrcToRtxSsrc = Map();

    // First assume RTX is used.
    for (var line in offerMediaObject['ssrcGroups']) {
      if (line['semantics'] != 'FID') {
        continue;
      }

      var parts = line.ssrcs.split(RegExp('\s+'));
      var ssrc = int.parse(parts[0]);
      var rtxSsrc = int.parse(parts[1]);

      if (ssrcs.contains(ssrc)) {
        // Remove both the SSRC and RTX SSRC from the set so later we know that they
        // are already handled.
        ssrcs.remove(ssrc);
        ssrcs.remove(rtxSsrc);

        // Add to the map.
        ssrcToRtxSsrc[ssrc] = rtxSsrc;
      }
    }

    // If the set of SSRCs is not empty it means that RTX is not being used, so take
    // media SSRCs from there.
    for (var ssrc in ssrcs) {
      // Add to the map.
      ssrcToRtxSsrc[ssrc] = null;
    }

    const encodings = [];

    for (var ssrc in ssrcToRtxSsrc.keys) {
      var rtxSsrc = ssrcToRtxSsrc[ssrc];
      dynamic encoding = {
        'ssrc': ssrc,
        'rtx': {}
      };

      if (rtxSsrc == null) {
        encoding.remove('rtx');
      }
      else {
        encoding['rtx'] = { 'ssrc': rtxSsrc };
      }

      encodings.add(encoding);
    }
  }

}


/*
 * Provides information on RTCP settings within the RTP parameters.
 *
 * If no cname is given in a producer's RTP parameters, the mediasoup transport
 * will choose a random one that will be used into RTCP SDES messages sent to
 * all its associated consumers.
 *
 * mediasoup assumes reducedSize to always be true.
 */
class RtcpParameters
{
	/*
	 * The Canonical Name (CNAME) used by RTCP (e.g. in SDES messages).
	 */
	String cname;

	/*
	 * Whether reduced size RTCP RFC 5506 is configured (if true) or compound RTCP
	 * as specified in RFC 3550 (if false). Default true.
	 */
	final bool reducedSize;

	/*
	 * Whether RTCP-mux is used. Default true.
	 */
	final bool mux;

  RtcpParameters({this.cname, this.reducedSize, this.mux});
}
