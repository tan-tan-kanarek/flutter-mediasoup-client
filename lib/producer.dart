

import 'dart:core';

import 'package:flutter_webrtc/webrtc.dart';
import 'package:mediasoup_client/events.dart';
import 'package:mediasoup_client/rtp_parameters.dart';
import 'package:mediasoup_client/transport.dart';

class Producer extends EventEmitter {
	// Id.
	final String id;

	// Local id.
	final String localId;

	// Closed flag.
	bool closed = false;

	// Associated RTCRtpSender.
	final RTCRtpSender rtpSender;

	// Local track.
	final MediaStreamTrack track;

	// RTP parameters.
	final RtpParameters rtpParameters;

	// Paused flag.
	bool paused;

	// Video max spatial layer.
	int maxSpatialLayer;

	// App custom data.
	final dynamic appData;

	Producer({this.id, this.localId, this.rtpSender, this.track, this.rtpParameters, this.appData})	{		
		// TODO? this._onTrackEnded = this._onTrackEnded.bind(this);

		// this._handleTrack();
	}

	// /*
	//  * Closes the Producer.
	//  */
	// void close() {
	// 	if (closed)
	// 		return;

	// 	closed = true;

	// 	this._destroyTrack();

	// 	emit('@close');
	// }

	// /*
	//  * Transport was closed.
	//  */
	// transportClosed(): void
	// {
	// 	if (closed)
	// 		return;

	// 	closed = true;

	// 	this._destroyTrack();

	// 	emit('transportclose');
	// }

	// /*
  //  * TODO
	//  * Get associated RTCRtpSender stats.
	//  */
	// async getStats(): Promise<any>
	// {
	// 	if (this._closed)
	// 		throw new InvalidStateError('closed');

	// 	return this.safeEmitAsPromise('@getstats');
	// }

	// /*
	//  * Pauses sending media.
	//  */
	// void pause() {
	// 	if (closed)
	// 	{
	// 		return;
	// 	}

	// 	paused = true;
	// 	track.enabled = false;
	// }

	// /*
	//  * Resumes sending media.
	//  */
	// void resume() {
	// 	if (closed)
	// 	{
	// 		return;
	// 	}

	// 	paused = false;
	// 	track.enabled = true;
	// }

	// /*
	//  * Replaces the current track with a new one.
	//  */
	// void replaceTrack(MediaStreamTrack newTrack)
	// {
	// 	if (closed)
	// 	{
	// 		// This must be done here. Otherwise there is no chance to stop the given
	// 		// track.
	// 		try { newTrack.stop(); }
	// 		catch (error) {}

	// 		throw new InvalidStateError('closed');
	// 	}
	// 	else if (track.readyState == 'ended')
	// 	{
	// 		throw new InvalidStateError('track ended');
	// 	}

	// 	// Do nothing if this is the same track as the current handled one.
	// 	if (track == newTrack)
	// 	{
	// 		return;
	// 	}

	// 	emit('@replacetrack', newTrack);

	// 	// Destroy the previous track.
	// 	_destroyTrack();

	// 	// Set the new track.
	// 	track = newTrack;

	// 	// If this Producer was paused/resumed and the state of the new
	// 	// track does not match, fix it.
	// 	if (!paused)
	// 		track.enabled = true;
	// 	else
	// 		track.enabled = false;

	// 	// Handle the effective track.
	// 	_handleTrack();
	// }

	// /*
	//  * Sets the video max spatial layer to be sent.
	//  */
	// setMaxSpatialLayer(int spatialLayer) {
	// 	if (closed)
	// 		throw new InvalidStateError('closed');
	// 	else if (track.kind != 'video')
	// 		throw new UnsupportedError('not a video Producer');

	// 	if (spatialLayer == maxSpatialLayer)
	// 		return;

	// 	await this.safeEmitAsPromise('@setmaxspatiallayer', spatialLayer);

	// 	maxSpatialLayer = spatialLayer;
	// }

	// /*
	//  * Sets the DSCP value.
	//  */
	// async setRtpEncodingParameters(params: any): Promise<void>
	// {
	// 	if (this._closed)
	// 		throw new InvalidStateError('closed');
	// 	else if (typeof params !== 'object')
	// 		throw new TypeError('invalid params');

	// 	await this.safeEmitAsPromise('@setrtpencodingparameters', params);
	// }

	// private _onTrackEnded(): void
	// {
	// 	logger.debug('track "ended" event');

	// 	this.safeEmit('trackended');
	// }

	// private _handleTrack(): void
	// {
	// 	this._track.addEventListener('ended', this._onTrackEnded);
	// }

	// private _destroyTrack(): void
	// {
	// 	try
	// 	{
	// 		this._track.removeEventListener('ended', this._onTrackEnded);
	// 		this._track.stop();
	// 	}
	// 	catch (error)
	// 	{}
	// }
}

