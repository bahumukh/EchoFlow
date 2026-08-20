#include "AudioRecorderService.hpp"
#include <iostream>
#include <fstream>
#include <vector>
#include <cstring>
#include <unistd.h>

AudioRecorderService::AudioRecorderService() : isRecording(false), pcm_handle(nullptr) {
}

AudioRecorderService::~AudioRecorderService() {
    if (isRecording) {
        stopRecording();
    }
}

void AudioRecorderService::startRecording() {
    char tempPath[] = "/tmp/echoflow_XXXXXX.wav";
    int fd = mkstemps(tempPath, 4);
    if (fd != -1) close(fd);
    currentTempFile = tempPath;

    // Open PCM device for recording (capture)
    if (snd_pcm_open(&pcm_handle, "default", SND_PCM_STREAM_CAPTURE, 0) < 0) {
        std::cerr << "Error: Can't open ALSA audio device." << std::endl;
        return;
    }

    // Set hardware parameters for 16kHz, mono, 16-bit little endian
    snd_pcm_hw_params_t *params;
    snd_pcm_hw_params_alloca(&params);
    snd_pcm_hw_params_any(pcm_handle, params);
    snd_pcm_hw_params_set_access(pcm_handle, params, SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(pcm_handle, params, SND_PCM_FORMAT_S16_LE);
    snd_pcm_hw_params_set_channels(pcm_handle, params, 1);
    
    unsigned int rate = 16000;
    snd_pcm_hw_params_set_rate_near(pcm_handle, params, &rate, 0);

    if (snd_pcm_hw_params(pcm_handle, params) < 0) {
        std::cerr << "Error: Can't set ALSA hardware parameters." << std::endl;
        snd_pcm_close(pcm_handle);
        return;
    }

    isRecording = true;
    recordThread = std::thread(&AudioRecorderService::recordLoop, this);
}

std::string AudioRecorderService::stopRecording() {
    isRecording = false;
    if (recordThread.joinable()) {
        recordThread.join();
    }
    
    if (pcm_handle) {
        snd_pcm_drain(pcm_handle);
        snd_pcm_close(pcm_handle);
        pcm_handle = nullptr;
    }

    return currentTempFile;
}

void AudioRecorderService::recordLoop() {
    FILE* file = fopen(currentTempFile.c_str(), "wb");
    if (!file) return;

    // Reserve space for WAV header (44 bytes)
    fseek(file, 44, SEEK_SET);

    snd_pcm_uframes_t frames = 1024;
    int dir;
    snd_pcm_hw_params_t *params;
    snd_pcm_hw_params_alloca(&params);
    snd_pcm_hw_params_current(pcm_handle, params);
    snd_pcm_hw_params_get_period_size(params, &frames, &dir);
    
    int size = frames * 2; // 1 channel * 2 bytes (16-bit)
    char* buffer = new char[size];

    uint32_t totalDataSize = 0;

    while (isRecording) {
        int rc = snd_pcm_readi(pcm_handle, buffer, frames);
        if (rc == -EPIPE) {
            snd_pcm_prepare(pcm_handle); // Overrun
        } else if (rc < 0) {
            std::cerr << "Error: ALSA read failed." << std::endl;
        } else if (rc != (int)frames) {
            // Short read
        }

        if (rc > 0) {
            fwrite(buffer, 1, rc * 2, file);
            totalDataSize += rc * 2;
        }
    }

    // Write header
    writeWavHeader(file, totalDataSize);

    delete[] buffer;
    fclose(file);
}

void AudioRecorderService::writeWavHeader(FILE* file, uint32_t dataSize) {
    fseek(file, 0, SEEK_SET);
    
    uint32_t sampleRate = 16000;
    uint16_t channels = 1;
    uint16_t bitsPerSample = 16;
    uint32_t byteRate = sampleRate * channels * (bitsPerSample / 8);
    uint16_t blockAlign = channels * (bitsPerSample / 8);
    uint32_t chunkSize = 36 + dataSize;

    fwrite("RIFF", 1, 4, file);
    fwrite(&chunkSize, 4, 1, file);
    fwrite("WAVE", 1, 4, file);
    fwrite("fmt ", 1, 4, file);
    
    uint32_t subchunk1Size = 16;
    fwrite(&subchunk1Size, 4, 1, file);
    
    uint16_t audioFormat = 1;
    fwrite(&audioFormat, 2, 1, file);
    fwrite(&channels, 2, 1, file);
    fwrite(&sampleRate, 4, 1, file);
    fwrite(&byteRate, 4, 1, file);
    fwrite(&blockAlign, 2, 1, file);
    fwrite(&bitsPerSample, 2, 1, file);
    
    fwrite("data", 1, 4, file);
    fwrite(&dataSize, 4, 1, file);
}
