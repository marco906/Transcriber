//
//  DiarizationService.swift
//  Transcriber
//
//  Created by Marco Wenzel on 09.06.2025.
//

import Foundation

struct DiarizationServiceConfig {
    // Model names
    let segmentationModel: String = "pyannote_segmentation"
    let embeddingExtractorModel: String = "nemo_en_titanet_small"
    
    // Diarization parameters
    let numSpeakers: Int = 2
    let threshold: Float = 0.7
    let minDurationOn: Float = 0.1
    let minDurationOff: Float = 0.55
    let numThreads: Int = 4
}

class DiarizationService {
    static let shared = DiarizationService()
    
    var config = DiarizationServiceConfig()
    
    func rundDiarization(samples: [Float]) -> [SherpaOnnxOfflineSpeakerDiarizationSegmentWrapper] {
        let segmentationStartTime = Date.now.timeIntervalSince1970
        
        var config = createSherpaOnnxConfig()
        let sd = SherpaOnnxOfflineSpeakerDiarizationWrapper(config: &config)
        let segments = sd.process(samples: samples)
        
        let segmentationEndTime = Date.now.timeIntervalSince1970
        let segmentationTime = segmentationEndTime - segmentationStartTime
        print("Segmentation time: \(String(format: "%.2f", segmentationTime)) seconds")
        return segments
    }
    
    private func createSherpaOnnxConfig() -> SherpaOnnxOfflineSpeakerDiarizationConfig {
        let segmentationModelPath = getResource(config.segmentationModel, "onnx")
        let embeddingExtractorModelPath = getResource(config.embeddingExtractorModel, "onnx")
        
        return sherpaOnnxOfflineSpeakerDiarizationConfig(
            segmentation: sherpaOnnxOfflineSpeakerSegmentationModelConfig(
                pyannote: sherpaOnnxOfflineSpeakerSegmentationPyannoteModelConfig(model: segmentationModelPath),
                numThreads: config.numThreads
            ),
            embedding: sherpaOnnxSpeakerEmbeddingExtractorConfig(
                model: embeddingExtractorModelPath,
                numThreads: config.numThreads
            ),
            clustering: sherpaOnnxFastClusteringConfig(numClusters: config.numSpeakers, threshold: config.threshold),
            minDurationOn: config.minDurationOn,
            minDurationOff: config.minDurationOff
        )
    }
    
    private func sherpaOnnxOfflineSpeakerSegmentationPyannoteModelConfig(model: String) -> SherpaOnnxOfflineSpeakerSegmentationPyannoteModelConfig {
        return SherpaOnnxOfflineSpeakerSegmentationPyannoteModelConfig(model: toCPointer(model))
    }
    
    private func sherpaOnnxOfflineSpeakerSegmentationModelConfig(
        pyannote: SherpaOnnxOfflineSpeakerSegmentationPyannoteModelConfig,
        numThreads: Int = 1,
        debug: Int = 0,
        provider: String = "cpu"
    ) -> SherpaOnnxOfflineSpeakerSegmentationModelConfig {
        return SherpaOnnxOfflineSpeakerSegmentationModelConfig(
            pyannote: pyannote,
            num_threads: Int32(numThreads),
            debug: Int32(debug),
            provider: toCPointer(provider)
        )
    }
    
    private func sherpaOnnxFastClusteringConfig(numClusters: Int = -1, threshold: Float = 0.5) -> SherpaOnnxFastClusteringConfig {
        return SherpaOnnxFastClusteringConfig(num_clusters: Int32(numClusters), threshold: threshold)
    }
    
    private func sherpaOnnxSpeakerEmbeddingExtractorConfig(
        model: String,
        numThreads: Int = 1,
        debug: Int = 0,
        provider: String = "cpu"
    ) -> SherpaOnnxSpeakerEmbeddingExtractorConfig {
        return SherpaOnnxSpeakerEmbeddingExtractorConfig(
            model: toCPointer(model),
            num_threads: Int32(numThreads),
            debug: Int32(debug),
            provider: toCPointer(provider)
        )
    }
    
    private func sherpaOnnxOfflineSpeakerDiarizationConfig(
        segmentation: SherpaOnnxOfflineSpeakerSegmentationModelConfig,
        embedding: SherpaOnnxSpeakerEmbeddingExtractorConfig,
        clustering: SherpaOnnxFastClusteringConfig,
        minDurationOn: Float = 0.3,
        minDurationOff: Float = 0.5
    ) -> SherpaOnnxOfflineSpeakerDiarizationConfig {
        return SherpaOnnxOfflineSpeakerDiarizationConfig(
            segmentation: segmentation,
            embedding: embedding,
            clustering: clustering,
            min_duration_on: minDurationOn,
            min_duration_off: minDurationOff
        )
    }
    
    private func toCPointer(_ s: String) -> UnsafePointer<Int8>! {
        let cs = (s as NSString).utf8String
        return UnsafePointer<Int8>(cs)
    }
    
    private func getResource(_ forResource: String, _ ofType: String) -> String {
        let path = Bundle.main.path(forResource: forResource, ofType: ofType)
        return path!
    }
}

struct SherpaOnnxOfflineSpeakerDiarizationSegmentWrapper {
    var start: Float = 0
    var end: Float = 0
    var speaker: Int = 0
}

class SherpaOnnxOfflineSpeakerDiarizationWrapper {
    /// A pointer to the underlying counterpart in C
    let impl: OpaquePointer!
    
    init(
        config: UnsafePointer<SherpaOnnxOfflineSpeakerDiarizationConfig>!
    ) {
        impl = SherpaOnnxCreateOfflineSpeakerDiarization(config)
    }
    
    deinit {
        if let impl {
            SherpaOnnxDestroyOfflineSpeakerDiarization(impl)
        }
    }
    
    var sampleRate: Int {
        return Int(SherpaOnnxOfflineSpeakerDiarizationGetSampleRate(impl))
    }
    
    // only config.clustering is used. All other fields are ignored
    func setConfig(config: UnsafePointer<SherpaOnnxOfflineSpeakerDiarizationConfig>!) {
        SherpaOnnxOfflineSpeakerDiarizationSetConfig(impl, config)
    }
    
    func process(samples: [Float]) -> [SherpaOnnxOfflineSpeakerDiarizationSegmentWrapper] {
        let result = SherpaOnnxOfflineSpeakerDiarizationProcess(
            impl, samples, Int32(samples.count))
        
        if result == nil {
            return []
        }
        
        let numSegments = Int(SherpaOnnxOfflineSpeakerDiarizationResultGetNumSegments(result))
        
        let p: UnsafePointer<SherpaOnnxOfflineSpeakerDiarizationSegment>? =
        SherpaOnnxOfflineSpeakerDiarizationResultSortByStartTime(result)
        
        if p == nil {
            return []
        }
        
        var ans: [SherpaOnnxOfflineSpeakerDiarizationSegmentWrapper] = []
        for i in 0..<numSegments {
            ans.append(
                SherpaOnnxOfflineSpeakerDiarizationSegmentWrapper(
                    start: p![i].start, end: p![i].end, speaker: Int(p![i].speaker)))
        }
        
        SherpaOnnxOfflineSpeakerDiarizationDestroySegment(p)
        SherpaOnnxOfflineSpeakerDiarizationDestroyResult(result)
        
        return ans
    }
}
