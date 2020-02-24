
/*
 * Based on https://github.com/clux/sdp-transform
 */

import 'package:mediasoup_client/rtp_parameters.dart';
import 'package:mediasoup_client/sctp_parameters.dart';
import 'package:mediasoup_client/transport.dart';

typedef _SdpTransformFormat = String Function(dynamic);

_toIntIfInt(String v) {
  var i = int.tryParse(v);
  return i == null ? v : i;
}

class PlainRtpParameters {
	final String ip;
	final int ipVersion; // - 4 or 6.
	final int port;

  PlainRtpParameters({this.ip, this.ipVersion, this.port});
}

class RemoteSdp {
	// Remote ICE parameters.
  final IceParameters iceParameters;
  
	// Remote ICE candidates.
  final List<IceCandidate> iceCandidates;
  
	// Remote DTLS parameters.
  final DtlsParameters dtlsParameters;
  
	// Remote SCTP parameters.
  final List<SctpParameters> sctpParameters;
  
	// Parameters for plain RTP (no SRTP nor DTLS no BUNDLE). Fields:
	// @type {Object}
	//
	// Fields:
	// @param {String} ip
	// @param {Number} ipVersion - 4 or 6.
	// @param {Number} port
	final PlainRtpParameters plainRtpParameters;

	// Whether this is Plan-B SDP.
	final bool planB;

	// MediaSection instances indexed by MID.
	Map<String, AnswerMediaSection> _mediaSections = Map<String, AnswerMediaSection>();

	// First MID.
	String _firstMid;

	// SDP object.
	dynamic _sdpObject;

  
  RemoteSdp({
    this.iceParameters, 
    this.iceCandidates, 
    this.dtlsParameters, 
    this.sctpParameters,
    this.plainRtpParameters,
    this.planB = false
  }) {
		_sdpObject =
		{
			'version' : 0,
			'origin'  : {
				'address'        : '0.0.0.0',
				'ipVer'          : 4,
				'netType'        : 'IN',
				'sessionId'      : 10000,
				'sessionVersion' : 0,
				'username'       : 'mediasoup-client'
			},
			'name'   : '-',
			'timing' : { 'start': 0, 'stop': 0 },
			'media'  : []
		};

		// If ICE parameters are given, add ICE-Lite indicator.
		if (iceParameters != null && iceParameters.iceLite)
		{
			_sdpObject['icelite'] = 'ice-lite';
		}

		// If DTLS parameters are given assume WebRTC and BUNDLE.
		if (dtlsParameters != null)
		{
			_sdpObject['msidSemantic'] = { 'semantic': 'WMS', 'token': '*' };

			// NOTE: We take the latest fingerprint.
			var numFingerprints = dtlsParameters.fingerprints.length;

			_sdpObject['fingerprint'] = {
				'type' : dtlsParameters.fingerprints[numFingerprints - 1].algorithm,
				'hash' : dtlsParameters.fingerprints[numFingerprints - 1].value
			};

			_sdpObject['groups'] = [ { 'type': 'BUNDLE', 'mids': '' } ];
		}

		// If there are plain parameters override SDP origin.
		if (plainRtpParameters != null)
		{
			_sdpObject['origin']['address'] = plainRtpParameters.ip;
			_sdpObject['origin']['ipVer'] = plainRtpParameters.ipVersion;
		}
  }

	dynamic getNextMediaSectionIdx() {
		var idx = -1;

		// If a closed media section is found, return its index.
		for(AnswerMediaSection mediaSection in _mediaSections.values) {
			idx++;

			if (mediaSection.closed) {
				return { 
          'idx': idx, 
          'reuseMid': mediaSection.mid 
        };
      }
		}

		// If no closed media section is found, return next one.
		return { 
      'idx': _mediaSections.length, 
      'reuseMid': null 
    };
	}
  
	void updateDtlsRole(DtlsRole role) {
		dtlsParameters.role = role;

		for (AnswerMediaSection mediaSection in _mediaSections.values)
		{
			mediaSection.setDtlsRole(role);
		}
	}
  
    
  send({
      dynamic offerMediaObject,
      bool reuseMid,
      RtpParameters offerRtpParameters,
      RtpParameters answerRtpParameters,
      dynamic codecOptions,
      bool extmapAllowMixed
    }) {
    var mediaSection = AnswerMediaSection(
      iceParameters       : iceParameters,
      iceCandidates       : iceCandidates,
      dtlsParameters      : dtlsParameters,
      plainRtpParameters  : plainRtpParameters,
      planB               : planB,
      offerMediaObject    : offerMediaObject,
      // offerRtpParameters  : offerRtpParameters,
      // answerRtpParameters : answerRtpParameters,
      // codecOptions        : codecOptions,
      // extmapAllowMixed    : extmapAllowMixed
    );

    // Unified-Plan with closed media section replacement.
    if (reuseMid)
    {
      _replaceMediaSection(mediaSection, reuseMid);
    }
    // Unified-Plan or Plan-B with different media kind.
    else if (!_mediaSections.containsKey(mediaSection.mid))
    {
      _addMediaSection(mediaSection);
    }
    // Plan-B with same media kind.
    else
    {
      _replaceMediaSection(mediaSection);
    }
  }
  
	void _addMediaSection(AnswerMediaSection newMediaSection) {
		if (_firstMid == null) {
			_firstMid = newMediaSection.mid;
    }

		// Store it in the map.
		_mediaSections[newMediaSection.mid] = newMediaSection;

		// Update SDP object.
		_sdpObject['media'].add(newMediaSection.getObject());

		// Regenerate BUNDLE mids.
		_regenerateBundleMids();
	}

	void _replaceMediaSection(AnswerMediaSection newMediaSection, [bool reuseMid = false]) {
		// Store it in the map.
		if (reuseMid) {
			var newMediaSections = Map<String, AnswerMediaSection>();

			for (AnswerMediaSection mediaSection in _mediaSections.values)
			{
				if (mediaSection.mid == newMediaSection.mid)
					newMediaSections[mediaSection.mid] = newMediaSection;
				else
					newMediaSections[mediaSection.mid] = mediaSection;
			}

			// Regenerate media sections.
			_mediaSections = newMediaSections;

			// Regenerate BUNDLE mids.
			_regenerateBundleMids();
		}
		else
		{
			_mediaSections[newMediaSection.mid] = newMediaSection;
		}

		// Update SDP object.
		_sdpObject['media'] = _mediaSections.values
			.map((mediaSection) => mediaSection.getObject());
	}


	void _regenerateBundleMids() {
		if (dtlsParameters == null) {
			return;
    }

		_sdpObject['groups'][0]['mids'] = _mediaSections.values
			.where((mediaSection) => !mediaSection.closed)
			.map((mediaSection) => mediaSection.mid)
			.join(' ');
	}
  
	String getSdp() {
		// Increase SDP version.
		_sdpObject['origin']['sessionVersion']++;

		return SdpTransform.write(_sdpObject);
	}
}


class _SdpTransformType {
  final String name;
  final String push;
  final List<String> names;
  final String format;
  final _SdpTransformFormat formater;
  RegExp reg;

  _SdpTransformType({this.name, this.push, this.reg, this.names, this.format = '%s', this.formater}) {
    if (reg == null) {
      reg = RegExp(r'(.*)');
    }
  }
  
  _attachProperties(Iterable<RegExpMatch> matches, location, names, rawName) {
    var match = matches.first;
    if (rawName != null && names == null) {
      location[rawName] = _toIntIfInt(match[1]);
    }
    else {
      for (var i = 0; i < names.length; i += 1) {
        if (match.groupCount > i+1) {
          location[names[i]] = _toIntIfInt(match[i+1]);
        }
      }
    }
  }

  parse(dynamic location, String content) {
    var needsBlank = name != null && names != null;
    if (push != null && location[push] == null) {
      location[push] = [];
    }
    else if (needsBlank && location[name] == null) {
      location[name] = {};
    }
    var keyLocation = push != null ?
      {} :  // blank object that will be pushed
      needsBlank ? location[name] : location; // otherwise, named location or root

    _attachProperties(reg.allMatches(content), keyLocation, names, name);

    if (push != null) {
      location[push].Add(keyLocation);
    }
  }
}

class SdpTransform {
  static Map<String, List<_SdpTransformType>> _grammar = {
    'v': [_SdpTransformType(
      name: 'version',
      reg: RegExp(r'^(\d*)\$')
    )],
    'o': [_SdpTransformType(
      // o=- 20518 0 IN IP4 203.0.113.1
      // NB: sessionId will be a String in most cases because it is huge
      name: 'origin',
      reg: RegExp(r'^(\S*) (\d*) (\d*) (\S*) IP(\d) (\S*)'),
      names: ['username', 'sessionId', 'sessionVersion', 'netType', 'ipVer', 'address'],
      format: '%s %s %d %s IP%d %s'
    )],
    // default parsing of these only (though some of these feel outdated)
    's': [_SdpTransformType(name: 'name' )],
    'i': [_SdpTransformType(name: 'description' )],
    'u': [_SdpTransformType(name: 'uri' )],
    'e': [_SdpTransformType(name: 'email' )],
    'p': [_SdpTransformType(name: 'phone' )],
    'z': [_SdpTransformType(name: 'timezones' )], // TODO: this one can actually be parsed properly...
    'r': [_SdpTransformType(name: 'repeats' )],   // TODO: this one can also be parsed properly
    // k: [{}], // outdated thing ignored
    't': [_SdpTransformType(
      // t=0 0
      name: 'timing',
      reg: RegExp(r'^(\d*) (\d*)'),
      names: ['start', 'stop'],
      format: '%d %d'
    )],
    'c': [_SdpTransformType(
      // c=IN IP4 10.47.197.26
      name: 'connection',
      reg: RegExp(r'^IN IP(\d) (\S*)'),
      names: ['version', 'ip'],
      format: 'IN IP%d %s'
    )],
    'b': [_SdpTransformType(
      // b=AS:4000
      push: 'bandwidth',
      reg: RegExp(r'^(TIAS|AS|CT|RR|RS):(\d*)'),
      names: ['type', 'limit'],
      format: '%s:%s'
    )],
    'm': [_SdpTransformType(
      // m=video 51744 RTP/AVP 126 97 98 34 31
      // NB: special - pushes to session
      // TODO: rtp/fmtp should be filtered by the payloads found here?
      reg: RegExp(r'^(\w*) (\d*) ([\w/]*)(?: (.*))?'),
      names: ['type', 'port', 'protocol', 'payloads'],
      format: '%s %d %s %s'
    )],
    'a': [
      _SdpTransformType(
        // a=rtpmap:110 opus/48000/2
        push: 'rtp',
        reg: RegExp(r'^rtpmap:(\d*) ([\w\-.]*)(?:\s*\/(\d*)(?:\s*\/(\S*))?)?'),
        names: ['payload', 'codec', 'rate', 'encoding'],
        formater: (dynamic o) => (o['encoding']) ? 'rtpmap:%d %s/%s/%s' : (o['rate'] ? 'rtpmap:%d %s/%s' : 'rtpmap:%d %s')
      ),
      _SdpTransformType(
        // a=fmtp:108 profile-level-id=24;object=23;bitrate=64000
        // a=fmtp:111 minptime=10; useinbandfec=1
        push: 'fmtp',
        reg: RegExp(r'^fmtp:(\d*) ([\S| ]*)'),
        names: ['payload', 'config'],
        format: 'fmtp:%d %s'
      ),
      _SdpTransformType(
        // a=control:streamid=0
        name: 'control',
        reg: RegExp(r'^control:(.*)'),
        format: 'control:%s'
      ),
      _SdpTransformType(
        // a=rtcp:65179 IN IP4 193.84.77.194
        name: 'rtcp',
        reg: RegExp(r'^rtcp:(\d*)(?: (\S*) IP(\d) (\S*))?'),
        names: ['port', 'netType', 'ipVer', 'address'],
        formater: (dynamic o) => (o['address'] != null) ? 'rtcp:%d %s IP%d %s' : 'rtcp:%d'
      ),
      _SdpTransformType(
        // a=rtcp-fb:98 trr-int 100
        push: 'rtcpFbTrrInt',
        reg: RegExp(r'^rtcp-fb:([*]|\d*) trr-int (\d*)'),
        names: ['payload', 'value'],
        format: 'rtcp-fb:%d trr-int %d'
      ),
      _SdpTransformType(
        // a=rtcp-fb:98 nack rpsi
        push: 'rtcpFb',
        reg: RegExp(r'^rtcp-fb:(\*|\d*) ([\w-_]*)(?: ([\w-_]*))?'),
        names: ['payload', 'type', 'subtype'],
        formater: (o) => (o.subtype != null) ? 'rtcp-fb:%s %s %s' : 'rtcp-fb:%s %s'
      ),
      _SdpTransformType(
        // a=extmap:2 urn:ietf:params:rtp-hdrext:toffset
        // a=extmap:1/recvonly URI-gps-string
        // a=extmap:3 urn:ietf:params:rtp-hdrext:encrypt urn:ietf:params:rtp-hdrext:smpte-tc 25@600/24
        push: 'ext',
        reg: RegExp(r'^extmap:(\d+)(?:\/(\w+))?(?: (urn:ietf:params:rtp-hdrext:encrypt))? (\S*)(?: (\S*))?'),
        names: ['value', 'direction', 'encrypt-uri', 'uri', 'config'],
        formater: (o) => 'extmap:%d' + (o.direction ? '/%s' : '%v') + (o['encrypt-uri'] ? ' %s' : '%v') + ' %s' + (o.config ? ' %s' : '')
      ),
      _SdpTransformType(
        // a=extmap-allow-mixed
        name: 'extmapAllowMixed',
        reg: RegExp(r'^(extmap-allow-mixed)')
      ),
      _SdpTransformType(
        // a=crypto:1 AES_CM_128_HMAC_SHA1_80 inline:PS1uQCVeeCFCanVmcjkpPywjNWhcYD0mXXtxaVBR|2^20|1:32
        push: 'crypto',
        reg: RegExp(r'^crypto:(\d*) ([\w_]*) (\S*)(?: (\S*))?'),
        names: ['id', 'suite', 'config', 'sessionConfig'],
        formater: (o) => (o.sessionConfig != null) ? 'crypto:%d %s %s %s' : 'crypto:%d %s %s'
      ),
      _SdpTransformType(
        // a=setup:actpass
        name: 'setup',
        reg: RegExp(r'^setup:(\w*)'),
        format: 'setup:%s'
      ),
      _SdpTransformType(
        // a=connection:new
        name: 'connectionType',
        reg: RegExp(r'^connection:(new|existing)'),
        format: 'connection:%s'
      ),
      _SdpTransformType(
        // a=mid:1
        name: 'mid',
        reg: RegExp(r'^mid:([^\s]*)'),
        format: 'mid:%s'
      ),
      _SdpTransformType(
        // a=msid:0c8b064d-d807-43b4-b434-f92a889d8587 98178685-d409-46e0-8e16-7ef0db0db64a
        name: 'msid',
        reg: RegExp(r'^msid:(.*)'),
        format: 'msid:%s'
      ),
      _SdpTransformType(
        // a=ptime:20
        name: 'ptime',
        reg: RegExp(r'^ptime:(\d*(?:\.\d*)*)'),
        format: 'ptime:%d'
      ),
      _SdpTransformType(
        // a=maxptime:60
        name: 'maxptime',
        reg: RegExp(r'^maxptime:(\d*(?:\.\d*)*)'),
        format: 'maxptime:%d'
      ),
      _SdpTransformType(
        // a=sendrecv
        name: 'direction',
        reg: RegExp(r'^(sendrecv|recvonly|sendonly|inactive)')
      ),
      _SdpTransformType(
        // a=ice-lite
        name: 'icelite',
        reg: RegExp(r'^(ice-lite)')
      ),
      _SdpTransformType(
        // a=ice-ufrag:F7gI
        name: 'iceUfrag',
        reg: RegExp(r'^ice-ufrag:(\S*)'),
        format: 'ice-ufrag:%s'
      ),
      _SdpTransformType(
        // a=ice-pwd:x9cml/YzichV2+XlhiMu8g
        name: 'icePwd',
        reg: RegExp(r'^ice-pwd:(\S*)'),
        format: 'ice-pwd:%s'
      ),
      _SdpTransformType(
        // a=fingerprint:SHA-1 00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33
        name: 'fingerprint',
        reg: RegExp(r'^fingerprint:(\S*) (\S*)'),
        names: ['type', 'hash'],
        format: 'fingerprint:%s %s'
      ),
      _SdpTransformType(
        // a=candidate:0 1 UDP 2113667327 203.0.113.1 54400 typ host
        // a=candidate:1162875081 1 udp 2113937151 192.168.34.75 60017 typ host generation 0 network-id 3 network-cost 10
        // a=candidate:3289912957 2 udp 1845501695 193.84.77.194 60017 typ srflx raddr 192.168.34.75 rport 60017 generation 0 network-id 3 network-cost 10
        // a=candidate:229815620 1 tcp 1518280447 192.168.150.19 60017 typ host tcptype active generation 0 network-id 3 network-cost 10
        // a=candidate:3289912957 2 tcp 1845501695 193.84.77.194 60017 typ srflx raddr 192.168.34.75 rport 60017 tcptype passive generation 0 network-id 3 network-cost 10
        push:'candidates',
        reg: RegExp(r'^candidate:(\S*) (\d*) (\S*) (\d*) (\S*) (\d*) typ (\S*)(?: raddr (\S*) rport (\d*))?(?: tcptype (\S*))?(?: generation (\d*))?(?: network-id (\d*))?(?: network-cost (\d*))?'),
        names: ['foundation', 'component', 'transport', 'priority', 'ip', 'port', 'type', 'raddr', 'rport', 'tcptype', 'generation', 'network-id', 'network-cost'],
        formater: (o) {
          var str = 'candidate:%s %d %s %d %s %d typ %s';

          str += (o.raddr != null) ? ' raddr %s rport %d' : '%v%v';

          // NB: candidate has three optional chunks, so %void middles one if it's missing
          str += (o.tcptype != null) ? ' tcptype %s' : '%v';

          if (o.generation != null) {
            str += ' generation %d';
          }

          str += (o['network-id'] != null) ? ' network-id %d' : '%v';
          str += (o['network-cost'] != null) ? ' network-cost %d' : '%v';
          return str;
        }
      ),
      _SdpTransformType(
        // a=end-of-candidates (keep after the candidates line for readability)
        name: 'endOfCandidates',
        reg: RegExp(r'^(end-of-candidates)')
      ),
      _SdpTransformType(
        // a=remote-candidates:1 203.0.113.1 54400 2 203.0.113.1 54401 ...
        name: 'remoteCandidates',
        reg: RegExp(r'^remote-candidates:(.*)'),
        format: 'remote-candidates:%s'
      ),
      _SdpTransformType(
        // a=ice-options:google-ice
        name: 'iceOptions',
        reg: RegExp(r'^ice-options:(\S*)'),
        format: 'ice-options:%s'
      ),
      _SdpTransformType(
        // a=ssrc:2566107569 cname:t9YU8M1UxTF8Y1A1
        push: 'ssrcs',
        reg: RegExp(r'^ssrc:(\d*) ([\w_-]*)(?::(.*))?'),
        names: ['id', 'attribute', 'value'],
        formater: (o) {
          var str = 'ssrc:%d';
          if (o.attribute != null) {
            str += ' %s';
            if (o.value != null) {
              str += ':%s';
            }
          }
          return str;
        }
      ),
      _SdpTransformType(
        // a=ssrc-group:FEC 1 2
        // a=ssrc-group:FEC-FR 3004364195 1080772241
        push: 'ssrcGroups',
        // token-char = %x21 / %x23-27 / %x2A-2B / %x2D-2E / %x30-39 / %x41-5A / %x5E-7E
        reg: RegExp(r'^ssrc-group:([\x21\x23\x24\x25\x26\x27\x2A\x2B\x2D\x2E\w]*) (.*)'),
        names: ['semantics', 'ssrcs'],
        format: 'ssrc-group:%s %s'
      ),
      _SdpTransformType(
        // a=msid-semantic: WMS Jvlam5X3SX1OP6pn20zWogvaKJz5Hjf9OnlV
        name: 'msidSemantic',
        reg: RegExp(r'^msid-semantic:\s?(\w*) (\S*)'),
        names: ['semantic', 'token'],
        format: 'msid-semantic: %s %s' // space after ':' is not accidental
      ),
      _SdpTransformType(
        // a=group:BUNDLE audio video
        push: 'groups',
        reg: RegExp(r'^group:(\w*) (.*)'),
        names: ['type', 'mids'],
        format: 'group:%s %s'
      ),
      _SdpTransformType(
        // a=rtcp-mux
        name: 'rtcpMux',
        reg: RegExp(r'^(rtcp-mux)')
      ),
      _SdpTransformType(
        // a=rtcp-rsize
        name: 'rtcpRsize',
        reg: RegExp(r'^(rtcp-rsize)')
      ),
      _SdpTransformType(
        // a=sctpmap:5000 webrtc-datachannel 1024
        name: 'sctpmap',
        reg: RegExp(r'^sctpmap:([\w_/]*) (\S*)(?: (\S*))?'),
        names: ['sctpmapNumber', 'app', 'maxMessageSize'],
        formater: (o) => (o.maxMessageSize != null) ? 'sctpmap:%s %s %s' : 'sctpmap:%s %s'
      ),
      _SdpTransformType(
        // a=x-google-flag:conference
        name: 'xGoogleFlag',
        reg: RegExp(r'^x-google-flag:([^\s]*)'),
        format: 'x-google-flag:%s'
      ),
      _SdpTransformType(
        // a=rid:1 send max-width=1280;max-height=720;max-fps=30;depend=0
        push: 'rids',
        reg: RegExp(r'^rid:([\d\w]+) (\w+)(?: ([\S| ]*))?'),
        names: ['id', 'direction', 'params'],
        formater: (o) => (o.params) ? 'rid:%s %s %s' : 'rid:%s %s'
      ),
      _SdpTransformType(
        // a=imageattr:97 send [x=800,y=640,sar=1.1,q=0.6] [x=480,y=320] recv [x=330,y=250]
        // a=imageattr:* send [x=800,y=640] recv *
        // a=imageattr:100 recv [x=320,y=240]
        push: 'imageattrs',
        reg: new RegExp(
          // a=imageattr:97
          '^imageattr:(\\d+|\\*)' +
          // send [x=800,y=640,sar=1.1,q=0.6] [x=480,y=320]
          '[\\s\\t]+(send|recv)[\\s\\t]+(\\*|\\[\\S+\\](?:[\\s\\t]+\\[\\S+\\])*)' +
          // recv [x=330,y=250]
          '(?:[\\s\\t]+(recv|send)[\\s\\t]+(\\*|\\[\\S+\\](?:[\\s\\t]+\\[\\S+\\])*))?'
        ),
        names: ['pt', 'dir1', 'attrs1', 'dir2', 'attrs2'],
        formater: (o) => 'imageattr:%s %s %s' + (o.dir2 ? ' %s %s' : '')
      ),
      _SdpTransformType(
        // a=simulcast:send 1,2,3;~4,~5 recv 6;~7,~8
        // a=simulcast:recv 1;4,5 send 6;7
        name: 'simulcast',
        reg: new RegExp(
          // a=simulcast:
          '^simulcast:' +
          // send 1,2,3;~4,~5
          '(send|recv) ([a-zA-Z0-9\\-_~;,]+)' +
          // space + recv 6;~7,~8
          '(?:\\s?(send|recv) ([a-zA-Z0-9\\-_~;,]+))?' +
          // end
          '\$'
        ),
        names: ['dir1', 'list1', 'dir2', 'list2'],
        formater: (o) => 'simulcast:%s %s' + (o.dir2 ? ' %s %s' : '')
      ),
      _SdpTransformType(
        // old simulcast draft 03 (implemented by Firefox)
        //   https://tools.ietf.org/html/draft-ietf-mmusic-sdp-simulcast-03
        // a=simulcast: recv pt=97;98 send pt=97
        // a=simulcast: send rid=5;6;7 paused=6,7
        name: 'simulcast_03',
        reg: RegExp(r'^simulcast:[\s\t]+([\S+\s\t]+)\$'),
        names: ['value'],
        format: 'simulcast: %s'
      ),
      _SdpTransformType(
        // a=framerate:25
        // a=framerate:29.97
        name: 'framerate',
        reg: RegExp(r'^framerate:(\d+(?:\$|\.\d+))'),
        format: 'framerate:%s'
      ),
      _SdpTransformType(
        // RFC4570
        // a=source-filter: incl IN IP4 239.5.2.31 10.1.15.5
        name: 'sourceFilter',
        reg: RegExp(r'^source-filter: *(excl|incl) (\S*) (IP4|IP6|\*) (\S*) (.*)'),
        names: ['filterMode', 'netType', 'addressTypes', 'destAddress', 'srcList'],
        format: 'source-filter: %s %s %s %s %s'
      ),
      _SdpTransformType(
        // a=bundle-only
        name: 'bundleOnly',
        reg: RegExp(r'^(bundle-only)')
      ),
      _SdpTransformType(
        // a=label:1
        name: 'label',
        reg: RegExp(r'^label:(.+)'),
        format: 'label:%s'
      ),
      _SdpTransformType(
        // RFC version 26 for SCTP over DTLS
        // https://tools.ietf.org/html/draft-ietf-mmusic-sctp-sdp-26#section-5
        name: 'sctpPort',
        reg: RegExp(r'^sctp-port:(\d+)\$'),
        format: 'sctp-port:%s'
      ),
      _SdpTransformType(
        // RFC version 26 for SCTP over DTLS
        // https://tools.ietf.org/html/draft-ietf-mmusic-sctp-sdp-26#section-6
        name: 'maxMessageSize',
        reg: RegExp(r'^max-message-size:(\d+)\$'),
        format: 'max-message-size:%s'
      ),
      _SdpTransformType(
        // RFC7273
        // a=ts-refclk:ptp=IEEE1588-2008:39-A7-94-FF-FE-07-CB-D0:37
        push:'tsRefClocks',
        reg: RegExp(r'^ts-refclk:([^\s=]*)(?:=(\S*))?'),
        names: ['clksrc', 'clksrcExt'],
        formater: (o) => 'ts-refclk:%s' + (o.clksrcExt != null ? '=%s' : '')
      ),
      _SdpTransformType(
        // RFC7273
        // a=mediaclk:direct=963214424
        name:'mediaClk',
        reg: RegExp(r'^mediaclk:(?:id=(\S*))? *([^\s=]*)(?:=(\S*))?(?: *rate=(\d+)\/(\d+))?'),
        names: ['id', 'mediaClockName', 'mediaClockValue', 'rateNumerator', 'rateDenominator'],
        formater: (o) {
          var str = 'mediaclk:';
          str += (o['id'] != null ? 'id=%s %s' : '%v%s');
          str += (o['mediaClockValue'] != null ? '=%s' : '');
          str += (o['rateNumerator'] != null ? ' rate=%s' : '');
          str += (o['rateDenominator'] != null ? '/%s' : '');
          return str;
        }
      ),
      _SdpTransformType(
        // a=keywds:keywords
        name: 'keywords',
        reg: RegExp(r'^keywds:(.+)\$'),
        format: 'keywds:%s'
      ),
      _SdpTransformType(
        // a=content:main
        name: 'content',
        reg: RegExp(r'^content:(.+)'),
        format: 'content:%s'
      ),
      // BFCP https://tools.ietf.org/html/rfc4583
      _SdpTransformType(
        // a=floorctrl:c-s
        name: 'bfcpFloorCtrl',
        reg: RegExp(r'^floorctrl:(c-only|s-only|c-s)'),
        format: 'floorctrl:%s'
      ),
      _SdpTransformType(
        // a=confid:1
        name: 'bfcpConfId',
        reg: RegExp(r'^confid:(\d+)'),
        format: 'confid:%s'
      ),
      _SdpTransformType(
        // a=userid:1
        name: 'bfcpUserId',
        reg: RegExp(r'^userid:(\d+)'),
        format: 'userid:%s'
      ),
      _SdpTransformType(
        // a=floorid:1
        name: 'bfcpFloorId',
        reg: RegExp(r'^floorid:(.+) (?:m-stream|mstrm):(.+)'),
        names: ['id', 'mStream'],
        format: 'floorid:%s mstrm:%s'
      ),
      _SdpTransformType(
        // any a= that we don't understand is kept verbatim on media.invalid
        push: 'invalid',
        names: ['value']
      )
    ]
  };

  static final _validLineRegex = RegExp(r'^([a-z])=(.*)');
  static bool _validLine(String line) {
    return _validLineRegex.hasMatch(line);
  }

  static dynamic parse(String sdp) {
    var session = {}
      , media = []
      , location = session; // points at where properties go under (one of the above)

    // parse lines we understand
    sdp.split(RegExp(r'(\r\n|\r|\n)')).where(_validLine).forEach((l) {
      var type = l[0];
      var content = l.substring(2);
      if (type == 'm') {
        media.add({'rtp': [], 'fmtp': []});
        location = media[media.length-1]; // point at latest media line
      }

      List<_SdpTransformType> types = _grammar.containsKey(type) ? _grammar[type] : [];
      for (var j = 0; j < types.length; j += 1) {
        var obj = types[j];
        if (obj.reg.hasMatch(content)) {
          return obj.parse(location, content);
        }
      }
    });

    session['media'] = media; // link it up
    return session;
  }

  
  static final _defaultOuterOrder = [
    'v', 'o', 's', 'i',
    'u', 'e', 'p', 'c',
    'b', 't', 'r', 'z', 'a'
  ];
  static final _defaultInnerOrder = ['i', 'c', 'b', 'a'];

  static final _formatRegExp = RegExp(r'%[sdv%]');
  static String format(List arguments) {
    var i = 1;
    var formatStr = arguments[0];
    var args = arguments;
    var len = args.length;
    return formatStr.replace(_formatRegExp, (x) {
      if (i >= len) {
        return x; // missing argument
      }
      var arg = args[i];
      i += 1;
      switch (x) {
        case '%%':
          return '%';
        case '%s':
        case '%d':
          return arg.toString();
        case '%v':
          return '';
      }
    });
    // NB: we discard excess arguments - they are typically undefined from makeLine
  }

  static String makeLine(type, _SdpTransformType obj, location) {
    var str = obj.formater != null ?
      (obj.formater(obj.push != null ? location : location[obj.name])) :
      obj.format;

    var args = [type + '=' + str];
    if (obj.names != null) {
      for (var i = 0; i < obj.names.length; i += 1) {
        var n = obj.names[i];
        if (obj.name != null) {
          args.add(location[obj.name][n]);
        }
        else { // for mLine and push attributes
          args.add(location[obj.names[i]]);
        }
      }
    }
    else {
      args.add(location[obj.name]);
    }
    return format(args);
  }

  static String write(dynamic session, [dynamic opts]) {
    if(opts == null) {
      opts = {};
    }
    // ensure certain properties exist
    if (session['version'] == null) {
      session['version'] = 0; // 'v=0' must be there (only defined version atm)
    }
    if (session['name'] == null) {
      session['name'] = ' '; // 's= ' must be there if no meaningful name set
    }
    session['media'].forEach((mLine) {
      if (mLine['payloads'] == null) {
        mLine['payloads'] = '';
      }
    });

    var outerOrder = opts['outerOrder'] != null ? opts['outerOrder'] : _defaultOuterOrder;
    var innerOrder = opts['innerOrder'] != null ? opts['innerOrder'] : _defaultInnerOrder;
    var sdp = [];

    // loop through outerOrder for matching properties on session
    outerOrder.forEach((type) {
      _grammar[type].forEach((obj) {
        if (obj.name != null && session[obj.name] != null) {
          sdp.add(makeLine(type, obj, session));
        }
        else if (obj.push != null && session[obj.push] != null) {
          session[obj.push].forEach((el) {
            sdp.add(makeLine(type, obj, el));
          });
        }
      });
    });

    // then for each media line, follow the innerOrder
    session.media.forEach((mLine) {
      sdp.add(makeLine('m', _grammar['m'][0], mLine));

      innerOrder.forEach((type) {
        _grammar[type].forEach((obj) {
          if (obj.name != null && mLine[obj.name] != null) {
            sdp.add(makeLine(type, obj, mLine));
          }
          else if (obj.push != null && mLine[obj.push] != null) {
            mLine[obj.push].forEach((el) {
              sdp.add(makeLine(type, obj, el));
            });
          }
        });
      });
    });

    return sdp.join('\r\n') + '\r\n';
  }

  static RtpCapabilities extractRtpCapabilities(dynamic sdpObject) {
    // Map of RtpCodecParameters indexed by payload type.
    Map<int, RtpCodecCapability> codecsMap = Map<int, RtpCodecCapability>();
    // Array of RtpHeaderExtensions.
    List<RtpHeaderExtension> headerExtensions = [];
    // Whether a m=audio/video section has been already found.
    var gotAudio = false;
    var gotVideo = false;

    sdpObject['media'].forEach((dynamic m) {
      var kind = m['type'];

      switch (kind)
      {
        case 'audio':
          if (gotAudio)
            return;

          gotAudio = true;
          break;

        case 'video':
          if (gotVideo)
            return;

          gotVideo = true;
          break;
          
        default:
          return;
      }

      // Get codecs.
      m['rtp'].forEach((dynamic rtp) {

        RtpCodecCapability codec = RtpCodecCapability(
          mimeType             : '$kind/${rtp['codec']}',
          kind                 : kind,
          clockRate            : rtp['rate'],
          preferredPayloadType : rtp['payload'],
          channels             : rtp['encoding'],
          rtcpFeedback         : [],
          parameters           : {}
        );

        if (codec.kind != MediaKind.audio) {
          codec.channels = null;
        }
        else if (codec.channels == null) { 
          codec.channels = 1;
        }

        codecsMap[codec.preferredPayloadType] = codec;
      });

      // Get codec parameters.
      if(m['fmtp'] != null) {
        m['fmtp'].forEach((dynamic fmtp) {
          var parameters = SdpTransform.parseParams(fmtp.config);
          RtpCodecCapability codec = codecsMap[fmtp.payload];

          if (codec == null) {
            return;
          }

          // Specials case to convert parameter value to string.
          if (parameters && parameters['profile-level-id']) {
            parameters['profile-level-id'] = '${parameters['profile-level-id']}';
          }

          codec.parameters = parameters;
        });
      }

      // Get RTCP feedback for each codec.
      if(m['rtcpFb'] != null) {
        m['rtcpFb'].forEach((dynamic fb) {
          var codec = codecsMap[fb.payload];

          if (codec == null) {
            return;
          }

          var feedback = RtcpFeedback(
            type      : fb.type,
            parameter : fb.subtype
          );

          codec.rtcpFeedback.add(feedback);
        });
      }

      // Get RTP header extensions.
      if(m['ext'] != null) {
        m['ext'].forEach((dynamic ext) {
          var headerExtension = RtpHeaderExtension(
            kind        : kind,
            uri         : ext.uri,
            preferredId : ext.value
          );

          headerExtensions.add(headerExtension);
        });
      }
    });

    RtpCapabilities rtpCapabilities = RtpCapabilities(
      codecs           : codecsMap.values.toList(),
      headerExtensions : headerExtensions,
      fecMechanisms    : []
    );

    return rtpCapabilities;
  }

  /*
   * Get RTCP CNAME.
   *
   * @param {Object} offerMediaObject - Local SDP media Object generated by sdp-transform.
   */
  static String getCname(dynamic offerMediaObject) {
    if(offerMediaObject['ssrcs'] != null) {
      List ssrcCnameLines = offerMediaObject['ssrcs'].where((line) => line['attribute'] == 'cname').toList();
      if(ssrcCnameLines.isNotEmpty) {
        return ssrcCnameLines.first['value'];
      }
    }
    return '';
  }

  
  /*
   * Extract DTLS parameters.
   *
   * @param {Object} sdpObject - SDP Object generated by sdp-transform.
   *
   * @returns {RTCDtlsParameters}
   */
  static DtlsParameters extractDtlsParameters(dynamic sdpObject)
  {
    var mediaObject;

    if(sdpObject.media != null) {
      List mediaObjects = sdpObject.media.where((m) => m['iceUfrag'] != null && m['port'] != 0).toList();
      if(mediaObjects.isNotEmpty) {
        mediaObject = mediaObjects.first;
      }
    }

    if (mediaObject == null) {
      throw 'no active media section found';
    }

    var fingerprint = mediaObject['fingerprint'] != null ? mediaObject['fingerprint'] : sdpObject['fingerprint'];
    DtlsRole role;

    switch (mediaObject['setup'])
    {
      case 'active':
        role = DtlsRole.client;
        break;
      case 'passive':
        role = DtlsRole.server;
        break;
      case 'actpass':
        role = DtlsRole.auto;
        break;
    }

    var dtlsParameters = DtlsParameters(
      role: role,
      fingerprints : [
        DtlsFingerprint(
          algorithm : fingerprint['type'],
          value     : fingerprint['hash']
        )
      ]
    );

    return dtlsParameters;
  }

  static dynamic _paramReducer(dynamic acc, String expr) {
    var s = expr.split(RegExp(r'=(.+)')).take(2).toList();
    if (s.length == 2) {
      acc[s[0]] = _toIntIfInt(s[1]);
    } else if (s.length == 1 && expr.length > 1) {
      acc[s[0]] = null;
    }
    return acc;
  }

  static dynamic parseParams(String str) {
    return str.split(RegExp(r';\s?')).fold<dynamic>({}, _paramReducer);
  }
}


abstract class MediaSection {
	// SDP media object.
	dynamic _mediaObject;

	// Whether this is Plan-B SDP.
	bool planB = false;

	MediaSection({
    IceParameters iceParameters,
    List<IceCandidate> iceCandidates,
    DtlsParameters dtlsParameters,
    planB
		}) {
		_mediaObject = {};

		if (iceParameters != null) {
			setIceParameters(iceParameters);
		}

		if (iceCandidates != null) {
			_mediaObject['candidates'] = [];

			for (IceCandidate candidate in iceCandidates) {
				dynamic candidateObject = {
          // mediasoup does mandates rtcp-mux so candidates component is always
          // RTP (1).
          'component': 1,
          'foundation': candidate.foundation,
          'ip': candidate.ip,
          'port': candidate.port,
          'priority': candidate.priority,
          'transport': candidate.protocol,
          'type': candidate.type,
        };
        if (candidate.tcpType != null)
          candidateObject['tcptype'] = candidate.tcpType;

				_mediaObject['candidates'].add(candidateObject);
			}

			_mediaObject['endOfCandidates'] = 'end-of-candidates';
			_mediaObject['iceOptions'] = 'renomination';
		}

		if (dtlsParameters != null)
		{
			setDtlsRole(dtlsParameters.role);
		}
	}

	void setDtlsRole(DtlsRole role);

	String get mid => _mediaObject['mid'];

	bool get closed => _mediaObject['port'] == 0;

	dynamic getObject() {
		return _mediaObject;
	}

	/*
	 * @param {RTCIceParameters} iceParameters
	 */
	void setIceParameters(IceParameters iceParameters) {
		_mediaObject['iceUfrag'] = iceParameters.usernameFragment;
		_mediaObject['icePwd'] = iceParameters.password;
	}

	void disable() {
		_mediaObject['direction'] = 'inactive';

		_mediaObject.remove('ext');
		_mediaObject.remove('ssrcs');
		_mediaObject.remove('ssrcGroups');
		_mediaObject.remove('simulcast');
		_mediaObject.remove('simulcast_03');
		_mediaObject.remove('rids');
	}

	void close() {
		_mediaObject['direction'] = 'inactive';

		_mediaObject['port'] = 0;

		_mediaObject.remove('ext');
		_mediaObject.remove('ssrcs');
		_mediaObject.remove('ssrcGroups');
		_mediaObject.remove('simulcast');
		_mediaObject.remove('simulcast_03');
		_mediaObject.remove('rids');
		_mediaObject.remove('ext');
		_mediaObject.remove('extmapAllowMixed');
	}
}


class AnswerMediaSection extends MediaSection
{
	AnswerMediaSection({
    IceParameters iceParameters,
    List<IceCandidate> iceCandidates,
    DtlsParameters dtlsParameters,
    PlainRtpParameters plainRtpParameters,
    bool planB,
    dynamic offerMediaObject,
		}) : super(
      iceParameters: iceParameters,
      iceCandidates: iceCandidates,
      dtlsParameters: dtlsParameters,
      planB: planB
    )
	{
		// const {
		// 	sctpParameters,
		// 	offerMediaObject,
		// 	offerRtpParameters,
		// 	answerRtpParameters,
		// 	plainRtpParameters,
		// 	codecOptions,
		// 	extmapAllowMixed
		// } = data;

		_mediaObject.mid = offerMediaObject['mid'].toString();
		_mediaObject.type = offerMediaObject['type'];
		_mediaObject.protocol = offerMediaObject['protocol'];

		// if (!plainRtpParameters)
		// {
		// 	_mediaObject.connection = { ip: '127.0.0.1', version: 4 };
		// 	_mediaObject.port = 7;
		// }
		// else
		// {
		// 	_mediaObject.connection =
		// 	{
		// 		ip      : plainRtpParameters.ip,
		// 		version : plainRtpParameters.ipVersion
		// 	};
		// 	_mediaObject.port = plainRtpParameters.port;
		// }

		// switch (offerMediaObject.type)
		// {
		// 	case 'audio':
		// 	case 'video':
		// 	{
		// 		_mediaObject.direction = 'recvonly';
		// 		_mediaObject.rtp = [];
		// 		_mediaObject.rtcpFb = [];
		// 		_mediaObject.fmtp = [];

		// 		for (const codec of answerRtpParameters.codecs)
		// 		{
		// 			const rtp: any =
		// 			{
		// 				payload : codec.payloadType,
		// 				codec   : codec.mimeType.replace(/^.*\//, ''),
		// 				rate    : codec.clockRate
		// 			};

		// 			if (codec.channels > 1)
		// 				rtp.encoding = codec.channels;

		// 			_mediaObject.rtp.push(rtp);

		// 			const codecParameters = utils.clone(codec.parameters || {});

		// 			if (codecOptions)
		// 			{
		// 				const {
		// 					opusStereo,
		// 					opusFec,
		// 					opusDtx,
		// 					opusMaxPlaybackRate,
		// 					videoGoogleStartBitrate,
		// 					videoGoogleMaxBitrate,
		// 					videoGoogleMinBitrate
		// 				} = codecOptions;

		// 				const offerCodec = offerRtpParameters.codecs
		// 					.find((c: any) => c.payloadType === codec.payloadType);

		// 				switch (codec.mimeType.toLowerCase())
		// 				{
		// 					case 'audio/opus':
		// 					{
		// 						if (opusStereo !== undefined)
		// 						{
		// 							offerCodec.parameters['sprop-stereo'] = opusStereo ? 1 : 0;
		// 							codecParameters.stereo = opusStereo ? 1 : 0;
		// 						}

		// 						if (opusFec !== undefined)
		// 						{
		// 							offerCodec.parameters.useinbandfec = opusFec ? 1 : 0;
		// 							codecParameters.useinbandfec = opusFec ? 1 : 0;
		// 						}

		// 						if (opusDtx !== undefined)
		// 						{
		// 							offerCodec.parameters.usedtx = opusDtx ? 1 : 0;
		// 							codecParameters.usedtx = opusDtx ? 1 : 0;
		// 						}

		// 						if (opusMaxPlaybackRate !== undefined)
		// 							codecParameters.maxplaybackrate = opusMaxPlaybackRate;

		// 						break;
		// 					}

		// 					case 'video/vp8':
		// 					case 'video/vp9':
		// 					case 'video/h264':
		// 					case 'video/h265':
		// 					{
		// 						if (videoGoogleStartBitrate !== undefined)
		// 							codecParameters['x-google-start-bitrate'] = videoGoogleStartBitrate;

		// 						if (videoGoogleMaxBitrate !== undefined)
		// 							codecParameters['x-google-max-bitrate'] = videoGoogleMaxBitrate;

		// 						if (videoGoogleMinBitrate !== undefined)
		// 							codecParameters['x-google-min-bitrate'] = videoGoogleMinBitrate;

		// 						break;
		// 					}
		// 				}
		// 			}

		// 			const fmtp =
		// 			{
		// 				payload : codec.payloadType,
		// 				config  : ''
		// 			};

		// 			for (const key of Object.keys(codecParameters))
		// 			{
		// 				if (fmtp.config)
		// 					fmtp.config += ';';

		// 				fmtp.config += `${key}=${codecParameters[key]}`;
		// 			}

		// 			if (fmtp.config)
		// 				_mediaObject.fmtp.push(fmtp);

		// 			if (codec.rtcpFeedback)
		// 			{
		// 				for (const fb of codec.rtcpFeedback)
		// 				{
		// 					_mediaObject.rtcpFb.push(
		// 						{
		// 							payload : codec.payloadType,
		// 							type    : fb.type,
		// 							subtype : fb.parameter || ''
		// 						});
		// 				}
		// 			}
		// 		}

		// 		_mediaObject.payloads = answerRtpParameters.codecs
		// 			.map((codec: any) => codec.payloadType)
		// 			.join(' ');

		// 		_mediaObject.ext = [];

		// 		for (const ext of answerRtpParameters.headerExtensions)
		// 		{
		// 			// Don't add a header extension if not present in the offer.
		// 			const found = (offerMediaObject.ext || [])
		// 				.some((localExt: any) => localExt.uri === ext.uri);

		// 			if (!found)
		// 				continue;

		// 			_mediaObject.ext.push(
		// 				{
		// 					uri   : ext.uri,
		// 					value : ext.id
		// 				});
		// 		}

		// 		// Allow both 1 byte and 2 bytes length header extensions.
		// 		if (
		// 			extmapAllowMixed &&
		// 			offerMediaObject.extmapAllowMixed === 'extmap-allow-mixed'
		// 		)
		// 		{
		// 			_mediaObject.extmapAllowMixed = 'extmap-allow-mixed';
		// 		}

		// 		// Simulcast.
		// 		if (offerMediaObject.simulcast)
		// 		{
		// 			_mediaObject.simulcast =
		// 			{
		// 				dir1  : 'recv',
		// 				list1 : offerMediaObject.simulcast.list1
		// 			};

		// 			_mediaObject.rids = [];

		// 			for (const rid of offerMediaObject.rids || [])
		// 			{
		// 				if (rid.direction !== 'send')
		// 					continue;

		// 				_mediaObject.rids.push(
		// 					{
		// 						id        : rid.id,
		// 						direction : 'recv'
		// 					});
		// 			}
		// 		}
		// 		// Simulcast (draft version 03).
		// 		else if (offerMediaObject.simulcast_03)
		// 		{
		// 			// eslint-disable-next-line camelcase, @typescript-eslint/camelcase
		// 			_mediaObject.simulcast_03 =
		// 			{
		// 				value : offerMediaObject.simulcast_03.value.replace(/send/g, 'recv')
		// 			};

		// 			_mediaObject.rids = [];

		// 			for (const rid of offerMediaObject.rids || [])
		// 			{
		// 				if (rid.direction !== 'send')
		// 					continue;

		// 				_mediaObject.rids.push(
		// 					{
		// 						id        : rid.id,
		// 						direction : 'recv'
		// 					});
		// 			}
		// 		}

		// 		_mediaObject.rtcpMux = 'rtcp-mux';
		// 		_mediaObject.rtcpRsize = 'rtcp-rsize';

		// 		if (_planB && _mediaObject.type === 'video')
		// 			_mediaObject.xGoogleFlag = 'conference';

		// 		break;
		// 	}

		// 	case 'application':
		// 	{
		// 		// New spec.
		// 		if (typeof offerMediaObject.sctpPort === 'number')
		// 		{
		// 			_mediaObject.payloads = 'webrtc-datachannel';
		// 			_mediaObject.sctpPort = sctpParameters.port;
		// 			_mediaObject.maxMessageSize = sctpParameters.maxMessageSize;
		// 		}
		// 		// Old spec.
		// 		else if (offerMediaObject.sctpmap)
		// 		{
		// 			_mediaObject.payloads = sctpParameters.port;
		// 			_mediaObject.sctpmap =
		// 			{
		// 				app            : 'webrtc-datachannel',
		// 				sctpmapNumber  : sctpParameters.port,
		// 				maxMessageSize : sctpParameters.maxMessageSize
		// 			};
		// 		}

		// 		break;
		// 	}
		// }

	}

	/*
	 * @param {String} role
	 */
	void setDtlsRole(DtlsRole role) {
		switch (role)
		{
			case DtlsRole.client:
				_mediaObject['setup'] = 'active';
				break;
			case DtlsRole.server:
				_mediaObject['setup'] = 'passive';
				break;
			case DtlsRole.auto:
				_mediaObject['setup'] = 'actpass';
				break;
		}
	}
}