#include <gtk/gtk.h>
#include <iostream>
#include <thread>
#include "GlobalHotkeyService.hpp"
#include "AudioRecorderService.hpp"
#include "WhisperService.hpp"
#include "TextInserterService.hpp"
#include "HUDWindow.hpp"

// Global pointers for GTK dispatch
HUDWindow* hudWindow = nullptr;
AudioRecorderService* audioService = nullptr;
WhisperService* whisperService = nullptr;
TextInserterService* textInserter = nullptr;

// GTK runs on the main thread, so we must schedule UI updates from the hotkey thread
gboolean show_hud_callback(gpointer data) {
    if (hudWindow) hudWindow->show();
    return G_SOURCE_REMOVE;
}

gboolean hide_hud_callback(gpointer data) {
    if (hudWindow) hudWindow->hide();
    return G_SOURCE_REMOVE;
}

void onHotkeyDown() {
    g_idle_add(show_hud_callback, nullptr);
    if (audioService) {
        audioService->startRecording();
    }
}

void onHotkeyUp() {
    g_idle_add(hide_hud_callback, nullptr);
    
    if (audioService && whisperService && textInserter) {
        std::string audioPath = audioService->stopRecording();
        if (!audioPath.empty()) {
            std::string text = whisperService->transcribe(audioPath);
            if (!text.empty()) {
                textInserter->insertText(text);
            }
        }
    }
}

int main(int argc, char *argv[]) {
    gtk_init(&argc, &argv);

    hudWindow = new HUDWindow();
    audioService = new AudioRecorderService();
    whisperService = new WhisperService();
    textInserter = new TextInserterService();

    GlobalHotkeyService hotkeyService(onHotkeyDown, onHotkeyUp);
    hotkeyService.start();

    // Run GTK main loop
    gtk_main();

    hotkeyService.stop();

    delete textInserter;
    delete whisperService;
    delete audioService;
    delete hudWindow;

    return 0;
}
