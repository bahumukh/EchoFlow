#ifndef WHISPER_SERVICE_HPP
#define WHISPER_SERVICE_HPP

#include <string>

class WhisperService {
public:
    WhisperService();
    std::string transcribe(const std::string& audioPath);

private:
    std::string whisperExePath;
    std::string modelPath;
};

#endif
