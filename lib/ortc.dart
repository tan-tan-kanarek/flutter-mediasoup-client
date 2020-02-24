

import 'package:mediasoup_client/rtp_parameters.dart';
import 'package:mediasoup_client/h264.dart' as h264;

/*
 * Generate extended RTP capabilities for sending and receiving.
 */
RtpCapabilities getExtendedRtpCapabilities(RtpCapabilities localCaps, RtpCapabilities remoteCaps) {
	RtpCapabilities extendedRtpCapabilities = RtpCapabilities(
		codecs           : [],
		headerExtensions : [],
    fecMechanisms    : []
	);

	// Match media codecs and keep the order preferred by remoteCaps.
  if(remoteCaps.codecs != null) {
	  remoteCaps.codecs.forEach((remoteCodec) {
      // if (
      //   typeof remoteCodec !== 'object' ||
      //   Array.isArray(remoteCodec) ||
      //   typeof remoteCodec.mimeType !== 'string' ||
      //   !/^(audio|video)\/(.+)/.test(remoteCodec.mimeType)
      // )
      // {
      //   throw new TypeError('invalid remote capabilitiy codec');
      // }

      if (RegExp('.+\/rtx\$', caseSensitive: false).hasMatch(remoteCodec.mimeType)) {
        return;
      }

      if(localCaps.codecs != null) {
        var matchingCodecs = localCaps.codecs.where((localCodec) => _matchCodecs(localCodec, remoteCodec, strict: true, modify: true));
        
        if (matchingCodecs.isNotEmpty)
        {
          var matchingLocalCodec = matchingCodecs.first;
          var extendedCodec = RtpExtendedCodecCapability(
            mimeType             : matchingLocalCodec.mimeType,
            kind                 : matchingLocalCodec.kind,
            clockRate            : matchingLocalCodec.clockRate,
            localPayloadType     : matchingLocalCodec.preferredPayloadType,
            remotePayloadType    : remoteCodec.preferredPayloadType,
            channels             : matchingLocalCodec.channels,
            rtcpFeedback         : _reduceRtcpFeedback(matchingLocalCodec, remoteCodec),
            localParameters      : matchingLocalCodec.parameters != null ? matchingLocalCodec.parameters : {},
            remoteParameters     : remoteCodec.parameters != null ? remoteCodec.parameters : {}
          );

          extendedRtpCapabilities.codecs.add(extendedCodec);
        }
      }
    });
	}

	// Match RTX codecs.
  extendedRtpCapabilities.codecs.forEach((codec) {
    RtpExtendedCodecCapability extendedCodec = codec as RtpExtendedCodecCapability;
    if(localCaps.codecs != null && remoteCaps.codecs != null) {
      var matchingLocalRtxCodecs = localCaps.codecs
        .where((localCodec) => (
          RegExp('.+\/rtx\$', caseSensitive: false).hasMatch(localCodec.mimeType) &&
          localCodec.parameters['apt'] == extendedCodec.localPayloadType
        ));

      var matchingRemoteRtxCodecs = remoteCaps.codecs
        .where((remoteCodec) => (
          RegExp('.+\/rtx\$', caseSensitive: false).hasMatch(remoteCodec.mimeType) &&
          remoteCodec.parameters['apt'] == extendedCodec.remotePayloadType
        ));

      if (matchingLocalRtxCodecs.isNotEmpty && matchingRemoteRtxCodecs.isNotEmpty) {
        extendedCodec.localRtxPayloadType = matchingLocalRtxCodecs.first.preferredPayloadType;
        extendedCodec.remoteRtxPayloadType = matchingRemoteRtxCodecs.first.preferredPayloadType;
      }
    }
  });

	// Match header extensions.
  if(localCaps.headerExtensions != null && remoteCaps.headerExtensions != null) {
	  remoteCaps.headerExtensions.forEach((remoteExt) {
      var matchingLocalExtensions = localCaps.headerExtensions.where((localExt) => _matchHeaderExtensions(localExt, remoteExt));

      if (matchingLocalExtensions.isNotEmpty) {
        var extendedExt = RtpHeaderExtension(
          kind      : remoteExt.kind,
          uri       : remoteExt.uri,
          sendId    : matchingLocalExtensions.first.preferredId,
          recvId    : remoteExt.preferredId,
          direction : remoteExt.direction
        );

        extendedRtpCapabilities.headerExtensions.add(extendedExt);
      }
    });
	}

	return extendedRtpCapabilities;
}


bool _matchCodecs(RtpCodecCapability aCodec, RtpCodecCapability bCodec, { strict = false, modify = false })
{
	var aMimeType = aCodec.mimeType.toLowerCase();
	var bMimeType = bCodec.mimeType.toLowerCase();

	if (aMimeType != bMimeType) {
		return false;
  }

	if (aCodec.clockRate != bCodec.clockRate) {
		return false;
  }

	if (
		RegExp('^audio\/.+\$', caseSensitive: false).hasMatch(aMimeType) &&
		(
			(aCodec.channels != null && aCodec.channels != 1) ||
			(bCodec.channels != null && bCodec.channels != 1)
		) &&
		aCodec.channels != bCodec.channels
	)
	{
		return false;
	}

	// Per codec special checks.
	switch (aMimeType)
	{
		case 'video/h264':
			int aPacketizationMode = (aCodec.parameters != null && aCodec.parameters['packetization-mode']) != null ? aCodec.parameters['packetization-mode'] : 0;
			int bPacketizationMode = (bCodec.parameters != null && bCodec.parameters['packetization-mode']) != null ? bCodec.parameters['packetization-mode'] : 0;

			if (aPacketizationMode != bPacketizationMode) {
				return false;
      }

			// If strict matching check profile-level-id.
			if (strict)
			{
				if (!h264.isSameProfile(aCodec.parameters, bCodec.parameters))
					return false;

				var selectedProfileLevelId;

				try
				{
					selectedProfileLevelId =
						h264.generateProfileLevelIdForAnswer(aCodec.parameters, bCodec.parameters);
				}
				catch (error)
				{
					return false;
				}

				if (modify) {
          if(aCodec.parameters == null) {
					  aCodec.parameters = {};
          }

					if (selectedProfileLevelId) {
						aCodec.parameters['profile-level-id'] = selectedProfileLevelId;
          }
					else {
						aCodec.parameters.remove('profile-level-id');
          }
				}
			}
			break;

		case 'video/vp9':
			// If strict matching check profile-id.
			if (strict)
			{
				int aProfileId = aCodec.parameters ? aCodec.parameters['profile-id'] : 0;
				var bProfileId = bCodec.parameters ? bCodec.parameters['profile-id'] : 0;

				if (aProfileId != bProfileId) {
					return false;
        }
			}

			break;
	}

	return true;
}


/*
 * Generate RTP capabilities for receiving media based on the given extended
 * RTP capabilities.
 */
RtpCapabilities getRecvRtpCapabilities(RtpCapabilities extendedRtpCapabilities) {
	RtpCapabilities rtpCapabilities = RtpCapabilities(
		codecs           : [],
		headerExtensions : [],
		fecMechanisms    : []
	);

  extendedRtpCapabilities.codecs.forEach((RtpCodecCapability codecCapability) {
    RtpExtendedCodecCapability extendedCodec = codecCapability as RtpExtendedCodecCapability;
		var codec = RtpCodecCapability(
			mimeType             : extendedCodec.mimeType,
			kind                 : extendedCodec.kind,
			clockRate            : extendedCodec.clockRate,
			preferredPayloadType : extendedCodec.remotePayloadType,
			channels             : extendedCodec.channels,
			rtcpFeedback         : extendedCodec.rtcpFeedback,
			parameters           : extendedCodec.localParameters
		);

		rtpCapabilities.codecs.add(codec);

		// Add RTX codec.
		if (extendedCodec.remoteRtxPayloadType != null)
		{
			var extendedRtxCodec = RtpCodecCapability(
				mimeType             : '${extendedCodec.kind}/rtx',
				kind                 : extendedCodec.kind,
				clockRate            : extendedCodec.clockRate,
				preferredPayloadType : extendedCodec.remoteRtxPayloadType,
				rtcpFeedback         : [],
				parameters           : {
					'apt' : extendedCodec.remotePayloadType
				}
      );

			rtpCapabilities.codecs.add(extendedRtxCodec);
		}
	});

  extendedRtpCapabilities.headerExtensions.forEach((extendedExtension) {
		// Ignore RTP extensions not valid for receiving.
		if (
			extendedExtension.direction != RtpHeaderExtensionDirection.sendrecv &&
			extendedExtension.direction != RtpHeaderExtensionDirection.recvonly
		)
		{
			return;
		}

		var ext = RtpHeaderExtension(
			kind        : extendedExtension.kind,
			uri         : extendedExtension.uri,
			preferredId : extendedExtension.recvId
		);

		rtpCapabilities.headerExtensions.add(ext);
  });

	rtpCapabilities.fecMechanisms = extendedRtpCapabilities.fecMechanisms;

	return rtpCapabilities;
}

/**
 * Generate RTP parameters of the given kind for sending media.
 * Just the first media codec per kind is considered.
 * NOTE: mid, encodings and rtcp fields are left empty.
 */
RtpParameters getSendingRtpParameters(MediaKind kind, RtpCapabilities extendedRtpCapabilities) {
	RtpParameters rtpParameters = RtpParameters(
		codecs           : [],
		headerExtensions : [],
		encodings        : [],
	);

	for (RtpExtendedCodecCapability extendedCodec in extendedRtpCapabilities.codecs)
	{
		if (extendedCodec.kind != kind) {
			continue;
    }

		RtpCodecParameters codec = RtpCodecParameters(
			mimeType     : extendedCodec.mimeType,
			clockRate    : extendedCodec.clockRate,
			payloadType  : extendedCodec.localPayloadType,
			channels     : extendedCodec.channels,
			rtcpFeedback : extendedCodec.rtcpFeedback,
			parameters   : extendedCodec.localParameters
		);
		rtpParameters.codecs.add(codec);

		// Add RTX codec.
		if (extendedCodec.localRtxPayloadType != null)
		{
			RtpCodecParameters rtxCodec = RtpCodecParameters(
				mimeType     : '${extendedCodec.kind}/rtx',
				clockRate    : extendedCodec.clockRate,
				payloadType  : extendedCodec.localRtxPayloadType,
				rtcpFeedback : [],
				parameters   : {
					'apt' : extendedCodec.localPayloadType
				}
			);

			rtpParameters.codecs.add(rtxCodec);
		}

		// NOTE: We assume a single media codec plus an optional RTX codec.
		break;
	}

	for (RtpHeaderExtension extendedExtension in extendedRtpCapabilities.headerExtensions)
	{
		// Ignore RTP extensions of a different kind and those not valid for sending.
		if (
			(extendedExtension.kind != kind) ||
			(
				extendedExtension.direction != RtpHeaderExtensionDirection.sendrecv &&
				extendedExtension.direction != RtpHeaderExtensionDirection.sendonly
			)
		)
		{
			continue;
		}

		RtpHeaderExtensionParameters ext = RtpHeaderExtensionParameters(
			uri : extendedExtension.uri,
			id  : extendedExtension.sendId
		);

		rtpParameters.headerExtensions.add(ext);
	}

	return rtpParameters;
}

/*
 * Generate RTP parameters of the given kind suitable for the remote SDP answer.
 */
RtpParameters getSendingRemoteRtpParameters(MediaKind kind, RtpCapabilities extendedRtpCapabilities) {
	RtpParameters rtpParameters = RtpParameters(
		codecs           : [],
		headerExtensions : [],
		encodings        : [],
	);

	for (RtpExtendedCodecCapability extendedCodec in extendedRtpCapabilities.codecs)
	{
		if (extendedCodec.kind != kind) {
			continue;
    }

		RtpCodecParameters codec = RtpCodecParameters(
			mimeType     : extendedCodec.mimeType,
			clockRate    : extendedCodec.clockRate,
			payloadType  : extendedCodec.localPayloadType,
			channels     : extendedCodec.channels,
			rtcpFeedback : extendedCodec.rtcpFeedback,
			parameters   : extendedCodec.remoteParameters
		);
		rtpParameters.codecs.add(codec);

		// Add RTX codec.
		if (extendedCodec.localRtxPayloadType != null)
		{
			RtpCodecParameters rtxCodec = RtpCodecParameters(
				mimeType     : '${extendedCodec.kind}/rtx',
				clockRate    : extendedCodec.clockRate,
				payloadType  : extendedCodec.localRtxPayloadType,
				rtcpFeedback : [],
				parameters   : {
					'apt' : extendedCodec.localPayloadType
				}
			);
			rtpParameters.codecs.add(rtxCodec);
		}

		// NOTE: We assume a single media codec plus an optional RTX codec.
		break;
	}

	for (RtpHeaderExtension extendedExtension in extendedRtpCapabilities.headerExtensions)
	{
		// Ignore RTP extensions of a different kind and those not valid for sending.
		if (
			(extendedExtension.kind != kind) ||
			(
				extendedExtension.direction != RtpHeaderExtensionDirection.sendrecv &&
				extendedExtension.direction != RtpHeaderExtensionDirection.sendonly
			)
		)
		{
			continue;
		}

		RtpHeaderExtensionParameters ext = RtpHeaderExtensionParameters(
			uri : extendedExtension.uri,
			id  : extendedExtension.sendId
		);

		rtpParameters.headerExtensions.add(ext);
	}

	// Reduce codecs' RTCP feedback. Use Transport-CC if available, REMB otherwise.
	if (
		rtpParameters.headerExtensions.any((ext) => (
			ext.uri == 'http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01'
		))
	)
	{
		for (RtpCodecParameters codec in rtpParameters.codecs)
		{
      if(codec.rtcpFeedback != null) {
        codec.rtcpFeedback = codec.rtcpFeedback
          .where((fb) => fb.type != 'goog-remb').toList();
      }
		}
	}
	else if (
		rtpParameters.headerExtensions.any((ext) => (
			ext.uri == 'http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time'
		))
	)
	{
		for (RtpCodecParameters codec in rtpParameters.codecs)
		{
      if(codec.rtcpFeedback != null) {
        codec.rtcpFeedback = codec.rtcpFeedback
          .where((fb) => fb.type != 'transport-cc');
      }
		}
	}
	else
	{
		for (RtpCodecParameters codec in rtpParameters.codecs)
		{
      if(codec.rtcpFeedback != null) {
        codec.rtcpFeedback = codec.rtcpFeedback
          .where((fb) => (
            fb.type != 'transport-cc' &&
            fb.type != 'goog-remb'
				  ));
      }
		}
	}

	return rtpParameters;
}


/*
 * Whether media can be sent based on the given RTP capabilities.
 */
bool canSend(MediaKind kind, RtpCapabilities extendedRtpCapabilities) {
	return extendedRtpCapabilities.codecs.any((RtpCodecCapability codec) => codec.kind == kind);
}

bool _matchHeaderExtensions(RtpHeaderExtension aExt, RtpHeaderExtension bExt) {
	if (aExt.kind != null && bExt.kind != null && aExt.kind != bExt.kind)
		return false;

	if (aExt.uri != bExt.uri)
		return false;

	return true;
}

dynamic _reduceRtcpFeedback(RtpCodecCapability codecA, RtpCodecCapability codecB)
{
	var reducedRtcpFeedback = [];

  if(codecA.rtcpFeedback != null && codecB.rtcpFeedback != null) {
    codecA.rtcpFeedback.forEach((aFb) {
      var matchingFeedbacks = codecB.rtcpFeedback
        .where((bFb) => (
          bFb.type == aFb.type &&
          (bFb.parameter == aFb.parameter || (bFb.parameter == null && aFb.parameter == null))
        ));

      if (matchingFeedbacks.isNotEmpty) {
        reducedRtcpFeedback.add(matchingFeedbacks.first);
      }
    });
	}

	return reducedRtcpFeedback;
}
