#ifndef HUD_WINDOW_HPP
#define HUD_WINDOW_HPP

#include <gtk/gtk.h>

class HUDWindow {
public:
    HUDWindow();
    ~HUDWindow();

    void show();
    void hide();

private:
    GtkWidget* window;
};

#endif
