#ifndef GLOBAL_HOTKEY_SERVICE_HPP
#define GLOBAL_HOTKEY_SERVICE_HPP

#include <X11/Xlib.h>
#include <functional>
#include <atomic>
#include <thread>

class GlobalHotkeyService {
public:
    GlobalHotkeyService(std::function<void()> onKeyDown, std::function<void()> onKeyUp);
    ~GlobalHotkeyService();

    void start();
    void stop();

private:
    void listenLoop();

    std::function<void()> onKeyDown;
    std::function<void()> onKeyUp;
    std::atomic<bool> running;
    std::thread listenerThread;
    Display* display;
    
    bool isKeyPressed;
};

#endif
