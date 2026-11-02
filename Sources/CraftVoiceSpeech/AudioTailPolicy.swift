/// Never discard quiet speech or a short remainder. Only mathematically zero
/// trailing PCM samples carry no signal and need no separate decoder window.
public enum AudioTailPolicy {
    public static func retainedSampleCount(_ samples: [Float]) -> Int {
        var end = samples.count
        while end > 0 && samples[end - 1] == 0 { end -= 1 }
        return end
    }
    /// WhisperKit 1.1.1 intentionally skips a <=1s remainder. Rebalance only that
    /// boundary case into two >=15s clips, without overlap, gaps or text deduplication.
    public static func balancedClipTimestamps(sampleCount: Int) -> [Float] {
        let rate = 16_000
        let window = 30 * rate
        let remainder = sampleCount % window
        guard sampleCount > window, remainder > 0, remainder <= rate else { return [] }
        let start = (sampleCount / window - 1) * window
        let middle = start + (sampleCount - start) / 2
        var result: [Float] = []
        if start > 0 { result += [0, Float(start) / Float(rate)] }
        result += [Float(start) / Float(rate), Float(middle) / Float(rate), Float(middle) / Float(rate)]
        // Odd final start lets WhisperKit use the exact final input sample as end.
        return result
    }

}
