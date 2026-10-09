SwarmRegistryTestPlayback {
	var <cancelCount = 0, <releaseCount = 0, <disposeCount = 0;

	cancelRamp { cancelCount = cancelCount + 1; ^this }
	release { releaseCount = releaseCount + 1; ^this }
	dispose { disposeCount = disposeCount + 1; ^this }
}
