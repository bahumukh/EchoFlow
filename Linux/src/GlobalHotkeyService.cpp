#include "GlobalHotkeyService.hpp"
#include <X11/keysym.h>
#include <iostream>
#include <cstring>

GlobalHotkeyService::GlobalHotkeyService(std::function<void()> onKeyDown, std::function<void()> onKeyUp)
    : onKeyDown(onKeyDown), onKeyUp(onKeyUp), running(false), isKeyPressed(false) {
    display = XOpenDisplay(NULL);
    if (!display) {
        std::cerr << "Error: Could not open X display for hotkeys." << std::endl;
    }
}

GlobalHotkeyService::~GlobalHotkeyService() {
    stop();
    if (display) {
        XCloseDisplay(display);
    }
}

void GlobalHotkeyService::start() {
    if (!display) return;
    running = true;
    listenerThread = std::thread(&GlobalHotkeyService::listenLoop, this);
}

void GlobalHotkeyService::stop() {
    running = false;
    if (listenerThread.joinable()) {
        // Dummy event to wake up XNextEvent
        XEvent ev;
        memset(&ev, 0, sizeof(ev));
        ev.type = ClientMessage;
        ev.xclient.window = DefaultRootWindow(display);
        ev.xclient.format = 32;
        XSendEvent(display, DefaultRootWindow(display), False, NoEventMask, &ev);
        XFlush(display);

        listenerThread.join();
    }
}

void GlobalHotkeyService::listenLoop() {
    Window root = DefaultRootWindow(display);
    
    // We will bind to F12 (XK_F12) for Linux dictation
    KeyCode keycode = XKeysymToKeycode(display, XK_F12);
    
    // Grab the key globally (ignoring modifiers for simplicity, or grab specific ones)
    XGrabKey(display, keycode, AnyModifier, root, True, GrabModeAsync, GrabModeAsync);
    
    XEvent ev;
    while (running) {
        XNextEvent(display, &ev);
        
        if (ev.type == KeyPress && ev.xkey.keycode == keycode) {
            if (!isKeyPressed) {
                isKeyPressed = true;
                onKeyDown();
            }
        } else if (ev.type == KeyRelease && ev.xkey.keycode == keycode) {
            // X11 auto-repeat simulates Release+Press rapidly.
            // We'll ignore auto-repeat if there's a pending press immediately after.
            if (XEventsQueued(display, QueuedAfterReading)) {
                XEvent nev;
                XPeekEvent(display, &nev);
                if (nev.type == KeyPress && nev.xkey.time == ev.xkey.time && nev.xkey.keycode == keycode) {
                    continue; // It's an auto-repeat, ignore release
                }
            }
            
            if (isKeyPressed) {
                isKeyPressed = false;
                onKeyUp();
            }
        }
    }
    
    XUngrabKey(display, keycode, AnyModifier, root);
}
