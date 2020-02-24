
/*
 * Based on https://github.com/ibc/h264-profile-level-id
 */


const ProfileConstrainedBaseline = 1;
const ProfileBaseline = 2;
const ProfileMain = 3;
const ProfileConstrainedHigh = 4;
const ProfileHigh = 5;

// All values are equal to ten times the level number, except level 1b which is
// special.
const Level1_b = 0;
const Level1 = 10;
const Level1_1 = 11;
const Level1_2 = 12;
const Level1_3 = 13;
const Level2 = 20;
const Level2_1 = 21;
const Level2_2 = 22;
const Level3 = 30;
const Level3_1 = 31;
const Level3_2 = 32;
const Level4 = 40;
const Level4_1 = 41;
const Level4_2 = 42;
const Level5 = 50;
const Level5_1 = 51;
const Level5_2 = 52;

class ProfileLevelId {
  final int profile;
  final int level;

  // Default ProfileLevelId.
  //
  // TODO: The default should really be profile Baseline and level 1 according to
  // the spec: https://tools.ietf.org/html/rfc6184#section-8.1. In order to not
  // break backwards compatibility with older versions of WebRTC where external
  // codecs don't have any parameters, use profile ConstrainedBaseline level 3_1
  // instead. This workaround will only be done in an interim period to allow
  // external clients to update their code.
  //
  // http://crbug/webrtc/6337.
  static final ProfileLevelId defaultProfileLevelId = ProfileLevelId(
    profile: ProfileConstrainedBaseline, 
    level: Level3_1
  );

  ProfileLevelId({this.profile, this.level});
}


// For level_idc=11 and profile_idc=0x42, 0x4D, or 0x58, the constraint set3
// flag specifies if level 1b or level 1.1 is used.
const ConstraintSet3Flag = 0x10;

// Class for matching bit patterns such as "x1xx0000" where 'x' is allowed to be
// either 0 or 1.
class BitPattern {
  int _mask;
  int _maskedValue;

	BitPattern(String str) {
		_mask = ~_byteMaskString('x', str);
		_maskedValue = _byteMaskString('1', str);
	}

	isMatch(value)
	{
		return _maskedValue == (value & _mask);
	}
}

// Class for converting between profile_idc/profile_iop to Profile.
class ProfilePattern
{
  final int profileIdc;
  final BitPattern profileIop;
  final int profile;

  // This is from https://tools.ietf.org/html/rfc6184#section-8.1.
  static final List<ProfilePattern> patterns = [
    ProfilePattern(0x42, BitPattern('x1xx0000'), ProfileConstrainedBaseline),
    ProfilePattern(0x4D, BitPattern('1xxx0000'), ProfileConstrainedBaseline),
    ProfilePattern(0x58, BitPattern('11xx0000'), ProfileConstrainedBaseline),
    ProfilePattern(0x42, BitPattern('x0xx0000'), ProfileBaseline),
    ProfilePattern(0x58, BitPattern('10xx0000'), ProfileBaseline),
    ProfilePattern(0x4D, BitPattern('0x0x0000'), ProfileMain),
    ProfilePattern(0x64, BitPattern('00000000'), ProfileHigh),
    ProfilePattern(0x64, BitPattern('00001100'), ProfileConstrainedHigh)
  ];

  ProfilePattern(this.profileIdc, this.profileIop, this.profile);
}

/*
 * Parse profile level id that is represented as a string of 3 hex bytes.
 * Nothing will be returned if the string is not a recognized H264 profile
 * level id.
 *
 * @param {String} str - profile-level-id value as a string of 3 hex bytes.
 *
 * @returns {ProfileLevelId}
 */
ProfileLevelId parseProfileLevelId(String str) {
	// The string should consist of 3 bytes in hexadecimal format.
	if (str.length != 6) {
		return null;
  }

	var profileLevelIdNumeric = int.parse(str, radix: 16);

	if (profileLevelIdNumeric == 0)
		return null;

	// Separate into three bytes.
	var levelIdc = profileLevelIdNumeric & 0xFF;
	var profileIop = (profileLevelIdNumeric >> 8) & 0xFF;
	var profileIdc = (profileLevelIdNumeric >> 16) & 0xFF;

	// Parse level based on level_idc and constraint set 3 flag.
	int level;

	switch (levelIdc)
	{
		case Level1_1:
		{
			level = (profileIop & ConstraintSet3Flag) != 0 ? Level1_b : Level1_1;
			break;
		}
		case Level1:
		case Level1_2:
		case Level1_3:
		case Level2:
		case Level2_1:
		case Level2_2:
		case Level3:
		case Level3_1:
		case Level3_2:
		case Level4:
		case Level4_1:
		case Level4_2:
		case Level5:
		case Level5_1:
		case Level5_2:
			level = levelIdc;
			break;

		// Unrecognized level_idc.
		default:
			return null;
	}

	// Parse profile_idc/profile_iop into a Profile enum.
  var pattern = ProfilePattern.patterns.firstWhere((pattern) => (
			profileIdc == pattern.profileIdc &&
			pattern.profileIop.isMatch(profileIop)
		)
  );

  if(pattern != null) {
    return new ProfileLevelId(profile: pattern.profile, level: level);
  }

	return null;
}

/*
 * Returns canonical string representation as three hex bytes of the profile
 * level id, or returns nothing for invalid profile level ids.
 *
 * @param {ProfileLevelId} profile_level_id
 *
 * @returns {String}
 */
String profileLevelIdToString(profileLevelId)
{
	// Handle special case level == 1b.
	if (profileLevelId.level == Level1_b)
	{
		switch (profileLevelId.profile)
		{
			case ProfileConstrainedBaseline:
				return '42f00b';

			case ProfileBaseline:      
				return '42100b';
        
			case ProfileMain:
				return '4d100b';
        
			// Level 1_b is not allowed for other profiles.
			default:
				return null;
		}
	}

	var profileIdcIopString;

	switch (profileLevelId.profile)
	{
		case ProfileConstrainedBaseline:
			profileIdcIopString = '42e0';
			break;

		case ProfileBaseline:
			profileIdcIopString = '4200';
			break;
      
		case ProfileMain:
			profileIdcIopString = '4d00';
			break;
      
		case ProfileConstrainedHigh:
			profileIdcIopString = '640c';
			break;
      
		case ProfileHigh:
			profileIdcIopString = '6400';
			break;
      
		default:
			return null;
	}

	var levelStr = (profileLevelId.level).toString(16);

	if (levelStr.length == 1)
		levelStr = '0$levelStr';

	return '$profileIdcIopString$levelStr';
}

/*
 * Parse profile level id that is represented as a string of 3 hex bytes
 * contained in an SDP key-value map. A default profile level id will be
 * returned if the profile-level-id key is missing. Nothing will be returned if
 * the key is present but the string is invalid.
 *
 * @param {Object} [params={}] - Codec parameters object.
 *
 * @returns {ProfileLevelId}
 */
ProfileLevelId parseSdpProfileLevelId([dynamic params])
{
  if(params == null) {
    params = {};
  }
	var profileLevelId = params['profile-level-id'];

	return profileLevelId == null ? ProfileLevelId.defaultProfileLevelId : parseProfileLevelId(profileLevelId);
}

/*
 * Returns true if the parameters have the same H264 profile, i.e. the same
 * H264 profile (Baseline, High, etc).
 *
 * @param {Object} [params1={}] - Codec parameters object.
 * @param {Object} [params2={}] - Codec parameters object.
 *
 * @returns {Boolean}
 */
bool isSameProfile([dynamic params1, dynamic params2]) {
  if(params1 == null) {
    params1 = {};
  }
  if(params2 == null) {
    params2 = {};
  }
	var profilelevelId1 = parseSdpProfileLevelId(params1);
	var profileLevelId2 = parseSdpProfileLevelId(params2);

	// Compare H264 profiles, but not levels.
	return (
		profilelevelId1 != null &&
		profileLevelId2 != null &&
		profilelevelId1.profile == profileLevelId2.profile
	);
}

/*
 * Generate codec parameters that will be used as answer in an SDP negotiation
 * based on local supported parameters and remote offered parameters. Both
 * local_supported_params and remote_offered_params represent sendrecv media
 * descriptions, i.e they are a mix of both encode and decode capabilities. In
 * theory, when the profile in local_supported_params represent a strict superset
 * of the profile in remote_offered_params, we could limit the profile in the
 * answer to the profile in remote_offered_params.
 *
 * However, to simplify the code, each supported H264 profile should be listed
 * explicitly in the list of local supported codecs, even if they are redundant.
 * Then each local codec in the list should be tested one at a time against the
 * remote codec, and only when the profiles are equal should this function be
 * called. Therefore, this function does not need to handle profile intersection,
 * and the profile of local_supported_params and remote_offered_params must be
 * equal before calling this function. The parameters that are used when
 * negotiating are the level part of profile-level-id and level-asymmetry-allowed.
 *
 * @param {Object} [local_supported_params={}]
 * @param {Object} [remote_offered_params={}]
 *
 * @returns {String} Canonical string representation as three hex bytes of the
 *   profile level id, or null if no one of the params have profile-level-id.
 *
 * @throws {TypeError} If Profile mismatch or invalid params.
 */
String generateProfileLevelIdForAnswer([dynamic localSupportedParams, dynamic remoteOfferedParams]) {
  if(localSupportedParams == null) {
    localSupportedParams = {};
  }
	if(remoteOfferedParams == null) {
    remoteOfferedParams = {};
  }
	// If both local and remote params do not contain profile-level-id, they are
	// both using the default profile. In this case, don't return anything.
	if (
		localSupportedParams['profile-level-id'] == null &&
		remoteOfferedParams['profile-level-id'] == null
	)
	{
		return null;
	}

	// Parse profile-level-ids.
	var localProfileLevelId = parseSdpProfileLevelId(localSupportedParams);
	var remoteProfileLevelId = parseSdpProfileLevelId(remoteOfferedParams);

	// The local and remote codec must have valid and equal H264 Profiles.
	if (localProfileLevelId == null)
		throw new TypeError();

	if (remoteProfileLevelId == null)
		throw new TypeError();

	if (localProfileLevelId.profile != remoteProfileLevelId.profile)
		throw new TypeError();

	// Parse level information.
	var levelAsymmetryAllowed = (
		_isLevelAsymmetryAllowed(localSupportedParams) &&
		_isLevelAsymmetryAllowed(remoteOfferedParams)
	);

	var localLevel = localProfileLevelId.level;
	var remoteLevel = remoteProfileLevelId.level;
	var minLevel = _minLevel(localLevel, remoteLevel);

	// Determine answer level. When level asymmetry is not allowed, level upgrade
	// is not allowed, i.e., the level in the answer must be equal to or lower
	// than the level in the offer.
	var answerLevel = levelAsymmetryAllowed ? localLevel : minLevel;

	// Return the resulting profile-level-id for the answer parameters.
	return profileLevelIdToString(ProfileLevelId(profile: localProfileLevelId.profile, level: answerLevel));
}

// Convert a string of 8 characters into a byte where the positions containing
// character c will have their bit set. For example, c = 'x', str = "x1xx0000"
// will return 0b10110000.
int _byteMaskString(String c, String str) {
  int ret = 0;
  for(var i = 0; i < 8 && i < str.length; i++) {
    if(str[i] == c) {
      ret |= 1 << (7 - i);
    }
  }
	return ret;
}

// Compare H264 levels and handle the level 1b case.
bool _isLessLevel(int a, int b) {
	if (a == Level1_b)
		return b != Level1 && b != Level1_b;

	if (b == Level1_b)
		return a != Level1;

	return a < b;
}

int _minLevel(int a, int b) {
	return _isLessLevel(a, b) ? a : b;
}

bool _isLevelAsymmetryAllowed([params]) {
  if(params == null) {
    params = {};
  }
	var levelAsymmetryAllowed = params['level-asymmetry-allowed'];

	return (
		levelAsymmetryAllowed == 1 ||
		levelAsymmetryAllowed == '1'
	);
}