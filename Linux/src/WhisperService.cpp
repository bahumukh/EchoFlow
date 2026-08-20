#include "WhisperService.hpp"
#include <iostream>
#include <memory>
#include <stdexcept>
#include <array>
#include <unistd.h>
#include <limits.h>
#include <cstdio>

#include <sys/stat.h>

WhisperService::WhisperService() {
    char result[PATH_MAX];
    ssize_t count = readlink("/proc/self/exe", result, PATH_MAX);
    std::string exePath = std::string(result, (count > 0) ? count : 0);
    std::string baseDir = exePath.substr(0, exePath.find_last_of("\\/"));
    
    struct stat sb;
    std::string prodRuntime = baseDir + "/Runtime";
    
    if (stat(prodRuntime.c_str(), &sb) == 0 && S_ISDIR(sb.st_mode)) {
        // Production ZIP deployment
        whisperExePath = prodRuntime + "/whisper-cli";
        modelPath = prodRuntime + "/models/ggml-small.en.bin";
    } else {
        // Local development fallback
        whisperExePath = baseDir + "/../../Runtime/whisper-cli";
        modelPath = baseDir + "/../../Runtime/models/ggml-small.en.bin";
    }
}

std::string WhisperService::transcribe(const std::string& audioPath) {
    std::string cmd = whisperExePath + " -m " + modelPath + " -f " + audioPath + " -nt 2>/dev/null";
    
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    
    // Remove temp audio file
    unlink(audioPath.c_str());
    
    // Trim trailing newline
    if (!result.empty() && result[result.length()-1] == '\n') {
        result.erase(result.length()-1);
    }
    
    return result;
}
