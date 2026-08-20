import Foundation

class EchoflowModelManager: NSObject, URLSessionDownloadDelegate {
    
    static let shared = EchoflowModelManager()
    
    enum ModelType: String {
        case base = "ggml-base.en.bin"
        case small = "ggml-small.en.bin"
        
        var downloadURL: URL {
            URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(self.rawValue)")!
        }
        
        var displayName: String {
            switch self {
            case .base: return "Base (Faster, Good Accuracy)"
            case .small: return "Small (Slower, High Accuracy)"
            }
        }
    }
    
    var onProgress: ((Double) -> Void)?
    var onCompletion: ((Result<URL, Error>) -> Void)?
    
    private var downloadTask: URLSessionDownloadTask?
    
    private var modelsDir: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Echoflow")
        let dir = appSupport.appendingPathComponent("Models")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    func getModelPath(_ type: ModelType) -> String? {
        // 1. Check downloaded models in App Support
        let path = modelsDir.appendingPathComponent(type.rawValue).path
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
        // 2. Check bundled models
        if let bundlePath = Bundle.main.resourcePath {
            let bundledPath = bundlePath + "/Runtime/models/" + type.rawValue
            if FileManager.default.fileExists(atPath: bundledPath) {
                return bundledPath
            }
        }
        // 3. Check CWD (for debug builds)
        let cwdPath = FileManager.default.currentDirectoryPath + "/Runtime/models/" + type.rawValue
        if FileManager.default.fileExists(atPath: cwdPath) {
            return cwdPath
        }
        
        return nil
    }
    
    func isDownloading() -> Bool {
        return downloadTask != nil
    }
    
    func downloadModel(_ type: ModelType, progress: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isDownloading() else { return }
        
        self.onProgress = progress
        self.onCompletion = completion
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        downloadTask = session.downloadTask(with: type.downloadURL)
        downloadTask?.taskDescription = type.rawValue
        downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        defer { self.downloadTask = nil }
        
        guard let filename = downloadTask.taskDescription else { return }
        let destURL = modelsDir.appendingPathComponent(filename)
        
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: location, to: destURL)
            onCompletion?(.success(destURL))
        } catch {
            onCompletion?(.failure(error))
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress?(progress)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.downloadTask = nil
            onCompletion?(.failure(error))
        }
    }
}
