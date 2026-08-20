#ifndef AUDIO_RECORDER_SERVICE_HPP
#define AUDIO_RECORDER_SERVICE_HPP

#include <string>
#include <atomic>
#include <thread>
#include <alsa/asoundlib.h>

class AudioRecorderService {
public:
    AudioRecorderService();
    ~AudioRecorderService();

    void startRecording();
    std::string stopRecording();

private:
    void recordLoop();
    void writeWavHeader(FILE* file, uint32_t dataSize);

    std::atomic<bool> isRecording;
    std::thread recordThread;
    std::string currentTempFile;
    
    snd_pcm_t* pcm_handle;
};

#endif
