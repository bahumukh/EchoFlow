#include "TextInserterService.hpp"
#include <X11/Xlib.h>
#include <X11/extensions/XTest.h>
#include <X11/keysym.h>
#include <gtk/gtk.h>
#include <unistd.h>
#include <iostream>

TextInserterService::TextInserterService() {}

void TextInserterService::insertText(const std::string& text) {
    if (text.empty()) return;

    // Set GTK Clipboard
    GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    gtk_clipboard_set_text(clipboard, text.c_str(), -1);
    gtk_clipboard_store(clipboard);

    // Give GTK a moment to sync clipboard with X server
    usleep(50000); // 50ms

    // Simulate Ctrl+V via XTest
    Display* display = XOpenDisplay(NULL);
    if (!display) {
        std::cerr << "Failed to open display for XTest" << std::endl;
        return;
    }

    KeyCode ctrl = XKeysymToKeycode(display, XK_Control_L);
    KeyCode v = XKeysymToKeycode(display, XK_v);

    XTestFakeKeyEvent(display, ctrl, True, CurrentTime);
    XTestFakeKeyEvent(display, v, True, CurrentTime);
    XTestFakeKeyEvent(display, v, False, CurrentTime);
    XTestFakeKeyEvent(display, ctrl, False, CurrentTime);

    XFlush(display);
    XCloseDisplay(display);
}
