
class SctpCapabilities {
  final NumSctpStreams numStreams;

  SctpCapabilities({this.numStreams});
}

class NumSctpStreams {
	/*
	 * Initially requested number of outgoing SCTP streams.
	 */
	final int os;

	/*
	 * Maximum number of incoming SCTP streams.
	 */
	final int mis;

  NumSctpStreams({this.os, this.mis});
}

class SctpParameters {
	/*
	 * Must always equal 5000.
	 */
	final int port;

	/*
	 * Initially requested number of outgoing SCTP streams.
	 */
	final int os;

	/*
	 * Maximum number of incoming SCTP streams.
	 */
	final int mis;

	/*
	 * Maximum allowed size for SCTP messages.
	 */
	final int maxMessageSize;

  SctpParameters({this.port, this.os, this.mis, this.maxMessageSize});
  
  static SctpParameters fromDynamic(dynamic data) {
    return SctpParameters(
      port: data['port'],
      os: data['os'],
      mis: data['mis'],
      maxMessageSize: data['maxMessageSize'],
    );
  }
}
