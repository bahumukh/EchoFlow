#include "HUDWindow.hpp"

static void draw_hud(GtkWidget *widget, cairo_t *cr, gpointer data) {
    // Draw a semi-transparent dark background
    cairo_set_source_rgba(cr, 0.1, 0.1, 0.1, 0.7);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_paint(cr);

    // Draw a red pulsing circle (simple static for now)
    cairo_set_source_rgba(cr, 1.0, 0.2, 0.2, 0.9);
    cairo_arc(cr, 20, 20, 8, 0, 2 * 3.14159);
    cairo_fill(cr);

    // Draw text "Listening..."
    cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 1.0);
    cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 16);
    cairo_move_to(cr, 40, 26);
    cairo_show_text(cr, "Listening...");
}

HUDWindow::HUDWindow() {
    window = gtk_window_new(GTK_WINDOW_POPUP);
    gtk_window_set_default_size(GTK_WINDOW(window), 200, 40);
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
    gtk_window_set_keep_above(GTK_WINDOW(window), TRUE);

    // Set transparency
    GdkScreen *screen = gtk_widget_get_screen(window);
    GdkVisual *visual = gdk_screen_get_rgba_visual(screen);
    if (visual != NULL && gdk_screen_is_composited(screen)) {
        gtk_widget_set_visual(window, visual);
    }

    gtk_widget_set_app_paintable(window, TRUE);
    g_signal_connect(G_OBJECT(window), "draw", G_CALLBACK(draw_hud), NULL);
}

HUDWindow::~HUDWindow() {
    gtk_widget_destroy(window);
}

void HUDWindow::show() {
    gtk_widget_show_all(window);
}

void HUDWindow::hide() {
    gtk_widget_hide(window);
}
