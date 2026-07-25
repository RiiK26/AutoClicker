#include <atomic>
#include <dirent.h>
#include <fcntl.h>
#include <fstream>
#include <gtk/gtk.h>
#include <linux/input.h>
#include <string>
#include <sys/epoll.h>
#include <sys/ioctl.h>
#include <thread>
#include <unistd.h>
#include <vector>

// Set path to RKKDR module parameters
const std::string SYSFS_BASE    = "/sys/module/RKKDR/parameters/";
const std::string ENABLE_FILE   = SYSFS_BASE + "enable";
const std::string INTERVAL_FILE = SYSFS_BASE + "interval_ms";

std::atomic<bool> is_enabled(false);
GtkWidget*        toggle_btn;
GtkWidget*        scale;

void write_sysfs(const std::string& path, const std::string& val)
{
    std::ofstream f(path);
    if (f.is_open())
    {
        f << val;
    }
}

std::string read_sysfs(const std::string& path)
{
    std::ifstream f(path);
    std::string   val;
    if (f.is_open())
    {
        f >> val;
    }
    return val;
}

void on_toggle(GtkWidget* widget, gpointer data)
{
    bool active = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(widget));
    is_enabled  = active;
    if (active)
    {
        gtk_button_set_label(GTK_BUTTON(widget), "AutoClicker is ON");
        write_sysfs(ENABLE_FILE, "Y");
    }
    else
    {
        gtk_button_set_label(GTK_BUTTON(widget), "AutoClicker is OFF");
        write_sysfs(ENABLE_FILE, "N");
    }
}

void on_interval_change(GtkAdjustment* adj, gpointer data)
{
    int val = (int) gtk_adjustment_get_value(adj);
    write_sysfs(INTERVAL_FILE, std::to_string(val));
}

gboolean update_ui(gpointer data)
{
    bool active = is_enabled.load();
    gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(toggle_btn), active);
    return G_SOURCE_REMOVE;
}

// Background thread to listen to /dev/input
void hotkey_thread()
{
    int epfd = epoll_create1(0);
    if (epfd < 0)
        return;

    std::vector<int> fds;
    DIR*             dir = opendir("/dev/input");
    if (dir)
    {
        struct dirent* ent;
        while ((ent = readdir(dir)) != NULL)
        {
            std::string name = ent->d_name;
            if (name.find("event") == 0)
            {
                std::string path = "/dev/input/" + name;
                int         fd   = open(path.c_str(), O_RDONLY | O_NONBLOCK);
                if (fd >= 0)
                {
                    unsigned long evbit[1 + EV_MAX / 8 / sizeof(long)] = {0};
                    ioctl(fd, EVIOCGBIT(0, sizeof(evbit)), evbit);
                    if (evbit[0] & (1UL << EV_KEY))
                    {
                        fds.push_back(fd);
                        struct epoll_event ev;
                        ev.events  = EPOLLIN;
                        ev.data.fd = fd;
                        epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &ev);
                    }
                    else
                    {
                        close(fd);
                    }
                }
            }
        }
        closedir(dir);
    }

    struct epoll_event events[10];
    while (true)
    {
        int n = epoll_wait(epfd, events, 10, -1);
        for (int i = 0; i < n; i++)
        {
            struct input_event ev;
            while (read(events[i].data.fd, &ev, sizeof(ev)) > 0)
            {
                // KEY_GRAVE is 41 (the ` key)
                if (ev.type == EV_KEY && ev.code == 41 && ev.value == 1)
                {
                    bool current = is_enabled.load();
                    is_enabled   = !current;
                    if (is_enabled)
                        write_sysfs(ENABLE_FILE, "Y");
                    else
                        write_sysfs(ENABLE_FILE, "N");
                    g_idle_add(update_ui, NULL);
                }
            }
        }
    }
}

static void activate(GtkApplication* app, gpointer user_data)
{
    GtkWidget* window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "AutoClicker");
    gtk_window_set_default_size(GTK_WINDOW(window), 300, 180);
    gtk_container_set_border_width(GTK_CONTAINER(window), 20);

    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 15);
    gtk_container_add(GTK_CONTAINER(window), vbox);

    // Set the window icon (shows in the title bar and taskbar)
    GError* error = NULL;
    
    // First try standard name for global install
    gtk_window_set_icon_name(GTK_WINDOW(window), "autoclicker");
    
    // Fallback to absolute path or local path if name fails
    if (!gtk_window_get_icon_name(GTK_WINDOW(window))) {
        gtk_window_set_icon_from_file(GTK_WINDOW(window), "/usr/share/pixmaps/autoclicker.png", &error);
        if (error != NULL)
        {
            g_error_free(error);
            error = NULL;
            gtk_window_set_icon_from_file(GTK_WINDOW(window), "image/AutoClick.png", &error);
            if (error != NULL)
            {
                g_warning("Could not load window icon: %s", error->message);
                g_error_free(error);
            }
        }
    }

    // Label
    GtkWidget* label = gtk_label_new("Toggle with hotkey: ` (Backtick)");
    gtk_box_pack_start(GTK_BOX(vbox), label, FALSE, FALSE, 0);

    // Toggle Button
    toggle_btn        = gtk_toggle_button_new_with_label("AutoClicker is OFF");
    std::string state = read_sysfs(ENABLE_FILE);
    if (state == "Y" || state == "1")
    {
        is_enabled = true;
        gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(toggle_btn), TRUE);
        gtk_button_set_label(GTK_BUTTON(toggle_btn), "AutoClicker is ON");
    }
    g_signal_connect(toggle_btn, "toggled", G_CALLBACK(on_toggle), NULL);
    gtk_box_pack_start(GTK_BOX(vbox), toggle_btn, FALSE, FALSE, 0);

    // Interval adjustment shared between Slider and Text Input
    // Range: 1ms to 10000ms
    GtkAdjustment* adj = gtk_adjustment_new(100.0, 1.0, 10000.0, 1.0, 10.0, 0.0);

    std::string interval = read_sysfs(INTERVAL_FILE);
    if (!interval.empty())
    {
        gtk_adjustment_set_value(adj, std::stod(interval));
    }

    // Connect signal to adjustment (triggers on both slider move and text edit)
    g_signal_connect(adj, "value-changed", G_CALLBACK(on_interval_change), NULL);

    // Horizontal Box for Slider and SpinButton
    GtkWidget* hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);

    // Slider (Scale)
    scale = gtk_scale_new(GTK_ORIENTATION_HORIZONTAL, adj);
    gtk_widget_set_hexpand(scale, TRUE);
    gtk_box_pack_start(GTK_BOX(hbox), scale, TRUE, TRUE, 0);

    // Text Input (Entry) instead of SpinButton (avoids SVG plus/minus icon crash
    // on root)
    GtkWidget* entry = gtk_entry_new();
    gtk_entry_set_width_chars(GTK_ENTRY(entry), 5);
    gtk_entry_set_text(GTK_ENTRY(entry), interval.empty() ? "100" : interval.c_str());

    // Sync Entry -> Adjustment
    g_signal_connect(
      entry, "changed", G_CALLBACK(+[](GtkEntry* e, gpointer data) {
          GtkAdjustment* adj  = GTK_ADJUSTMENT(data);
          std::string    text = gtk_entry_get_text(e);
          try
          {
              double val = std::stod(text);
              if (val >= 1.0 && val <= 10000.0)
              {
                  gtk_adjustment_set_value(adj, val);
              }
          } catch (...)
          {
          }
      }),
      adj
    );

    // Sync Adjustment -> Entry
    g_signal_connect(
      adj, "value-changed", G_CALLBACK(+[](GtkAdjustment* a, gpointer data) {
          GtkEntry* e   = GTK_ENTRY(data);
          int       val = (int) gtk_adjustment_get_value(a);
          gtk_entry_set_text(e, std::to_string(val).c_str());
      }),
      entry
    );

    gtk_box_pack_start(GTK_BOX(hbox), entry, FALSE, FALSE, 0);

    GtkWidget* ms_label = gtk_label_new("ms");
    gtk_box_pack_start(GTK_BOX(hbox), ms_label, FALSE, FALSE, 0);

    gtk_box_pack_start(GTK_BOX(vbox), hbox, FALSE, FALSE, 0);

    gtk_widget_show_all(window);
}

int main(int argc, char** argv)
{
    // Start background hotkey thread
    std::thread hk_thread(hotkey_thread);
    hk_thread.detach();

    GtkApplication* app = gtk_application_new("org.riik.autoclicker", G_APPLICATION_NON_UNIQUE);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);

    return status;
}
