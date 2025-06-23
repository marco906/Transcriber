# Transcriber

Transcriber is an iOS/macOS app for audio transcription and speaker diarization. It leverages ONNX models for advanced speech processing, allowing users to record, import, and transcribe audio files, while automatically identifying and segmenting different speakers.

## Features
- **Audio Recording & Import**: Record audio directly or import existing audio files (WAV format recommended).
- **Speaker Diarization**: Automatically segments audio by speaker using ONNX-based models (e.g., pyannote, NeMo).
- **Transcription**: Converts speech to text using on-device speech recognition (Apple Speech framework).
- **Demo & Test Files**: Includes sample audio and segment files for demonstration and testing.
- **Modern SwiftUI Interface**: Clean, user-friendly interface for managing recordings and viewing results.

## ONNX Models
The app uses several ONNX models for diarization and speaker embedding, located in `Transcriber/Services/SherpaOnnx/OnnxModels/`:
- `pyannote_segmentation.onnx`
- `nemo_en_titanet_small.onnx`
- `nemo_en_speakernet.onnx`

## Getting Started

### Prerequisites
- Xcode 15 or later
- macOS 14 or later
- Swift 5.9+

### Setup
1. Clone the repository:
   ```sh
   git clone <repo-url>
   cd transcriber
   ```

2. Download large files:
   ```sh
   git lfs pull
   ```
3. Set your Apple Developer Team ID: Open `Config.xcconfig` and replace `YOUR_DEVELOPMENT_TEAM` with your Team ID:
   ```
   DEVELOPMENT_TEAM = <YOUR_TEAM_ID>
   ```
4. Open `Transcriber.xcodeproj` in Xcode.
5. Build and run the app on an iOS Simulator, device, or macOS (if supported).

### Usage
- **Record**: Click the "Record" button to start recording audio.
- **Import**: Use the "Import" button to select and transcribe an existing audio file.
- **Demo**: Try the "Demo" button to use included sample files.
- **Results**: View diarized and transcribed segments, with speaker labels.

### Testing
- Test files are available in `TranscriberTests/TestFiles/` for evaluation and development.
- Run unit tests via Xcode's test navigator or `Cmd+U`.

## Directory Structure
- `Transcriber/` - Main app source code
- `Transcriber/Services/` - Core services (audio, transcription, diarization)
- `Transcriber/Services/SherpaOnnx/OnnxModels/` - ONNX model files
- `Transcriber/Resources/` - App resources and sample audio
- `TranscriberTests/` - Unit tests and test data

## License
This project may use third-party models and libraries. Please review their respective licenses.

---

**Note:** This project is for research and educational purposes. For production use, ensure compliance with all model and data licenses. 