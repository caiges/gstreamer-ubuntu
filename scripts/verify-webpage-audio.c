/* Exercise WebKit media capabilities through actual wpesrc output buffers. */
#include <gst/gst.h>
#include <math.h>
#include <string.h>

typedef struct {
    GstElement *pipeline;
    GstBus *bus;
    gint video_buffers;
    gint changed_video_buffers;
    guint32 previous_frame_hash;
    gint audio_buffers;
    GMutex audio_lock;
    guint64 samples;
    guint64 crossings;
    gint rate;
    float previous_sample;
    guint frequency;
} Capture;

static void video_buffer(GstElement *sink, GstBuffer *buffer, GstPad *pad, gpointer data)
{
    (void)sink; (void)buffer; (void)pad;
    Capture *capture = data;
    GstMapInfo map;
    if (gst_buffer_map(buffer, &map, GST_MAP_READ)) {
        guint32 hash = 2166136261u;
        for (gsize i = 0; i < map.size; i++) hash = (hash ^ map.data[i]) * 16777619u;
        if (g_atomic_int_get(&capture->video_buffers) && hash != capture->previous_frame_hash)
            g_atomic_int_inc(&capture->changed_video_buffers);
        capture->previous_frame_hash = hash;
        gst_buffer_unmap(buffer, &map);
    }
    g_atomic_int_inc(&capture->video_buffers);
}

static void audio_buffer(GstElement *sink, GstBuffer *buffer, GstPad *pad, gpointer data)
{
    (void)sink;
    Capture *capture = data;
    GstMapInfo map;
    if (!gst_buffer_map(buffer, &map, GST_MAP_READ)) return;
    GstCaps *caps = gst_pad_get_current_caps(pad);
    gint rate = 0;
    if (caps) {
        gst_structure_get_int(gst_caps_get_structure(caps, 0), "rate", &rate);
        gst_caps_unref(caps);
    }
    gboolean nonzero = FALSE;
    g_mutex_lock(&capture->audio_lock);
    capture->rate = rate;
    for (gsize i = 0; i + sizeof(float) <= map.size; i += sizeof(float)) {
        float sample;
        memcpy(&sample, map.data + i, sizeof(sample));
        if (fabsf(sample) > 0.01f) nonzero = TRUE;
        if (sample > 0 && capture->previous_sample <= 0) capture->crossings++;
        capture->previous_sample = sample;
        capture->samples++;
    }
    g_mutex_unlock(&capture->audio_lock);
    if (nonzero) g_atomic_int_inc(&capture->audio_buffers);
    gst_buffer_unmap(buffer, &map);
}

static void audio_pad(GstElement *source, GstPad *pad, gpointer data)
{
    (void)source;
    if (!g_str_has_prefix(GST_PAD_NAME(pad), "audio_")) return;
    Capture *capture = data;
    GstElement *pipeline = capture->pipeline;
    GstElement *convert = gst_element_factory_make("audioconvert", NULL);
    GstElement *filter = gst_element_factory_make("capsfilter", NULL);
    GstElement *sink = gst_element_factory_make("fakesink", NULL);
    g_assert(convert && filter && sink);
    GstCaps *caps = gst_caps_from_string("audio/x-raw,format=F32LE,layout=interleaved,channels=1");
    g_object_set(filter, "caps", caps, NULL);
    gst_caps_unref(caps);
    g_object_set(sink, "sync", FALSE, "async", FALSE, "signal-handoffs", TRUE, NULL);
    g_signal_connect(sink, "handoff", G_CALLBACK(audio_buffer), capture);
    gst_bin_add_many(GST_BIN(pipeline), convert, filter, sink, NULL);
    g_assert(gst_element_link_many(convert, filter, sink, NULL));
    GstPad *input = gst_element_get_static_pad(convert, "sink");
    g_assert(gst_pad_link(pad, input) == GST_PAD_LINK_OK);
    gst_object_unref(input);
    gst_element_sync_state_with_parent(sink);
    gst_element_sync_state_with_parent(filter);
    gst_element_sync_state_with_parent(convert);
}

static void configure_view(GstElement *source, GObject *view, gpointer data)
{
    (void)source; (void)data;
    GParamSpec *property = g_object_class_find_property(G_OBJECT_GET_CLASS(view), "settings");
    GObject *settings = g_object_new(G_PARAM_SPEC_VALUE_TYPE(property),
        "media-playback-requires-user-gesture", FALSE, "enable-webaudio", TRUE, NULL);
    g_object_set(view, "settings", settings, NULL);
    g_object_unref(settings);
}

static void configure_child(const GValue *value, gpointer data)
{
    (void)data;
    GstElement *child = g_value_get_object(value);
    if (g_signal_lookup("configure-web-view", G_OBJECT_TYPE(child))) {
        g_object_set(child, "enable-autoplay", TRUE, NULL);
        g_signal_connect(child, "configure-web-view", G_CALLBACK(configure_view), NULL);
    }
}

static gchar *media_page(guint frequency)
{
    const guint rate = 22050, size = rate * 2;
    guint8 *wav = g_malloc0(44 + size);
    memcpy(wav, "RIFF", 4);
    GST_WRITE_UINT32_LE(wav + 4, 36 + size);
    memcpy(wav + 8, "WAVEfmt ", 8);
    GST_WRITE_UINT32_LE(wav + 16, 16);
    GST_WRITE_UINT16_LE(wav + 20, 1);
    GST_WRITE_UINT16_LE(wav + 22, 1);
    GST_WRITE_UINT32_LE(wav + 24, rate);
    GST_WRITE_UINT32_LE(wav + 28, rate * 2);
    GST_WRITE_UINT16_LE(wav + 32, 2);
    GST_WRITE_UINT16_LE(wav + 34, 16);
    memcpy(wav + 36, "data", 4);
    GST_WRITE_UINT32_LE(wav + 40, size);
    for (guint i = 0; i < rate; i++)
        GST_WRITE_UINT16_LE(wav + 44 + i * 2, (gint16)(8000 * sin(2 * G_PI * frequency * i / rate)));
    gchar *base64 = g_base64_encode(wav, 44 + size);
    gchar *page = g_strdup_printf("<body style='background:green'><script>"
        "const audio=new Audio('data:audio/wav;base64,%s');audio.loop=true;audio.play();"
        "</script>", base64);
    g_free(base64);
    g_free(wav);
    return page;
}

static gchar *video_page(guint frequency)
{
    const gchar *directory = g_getenv("WPE_VIDEO_FIXTURE_DIR");
    g_assert(directory);
    gchar *path = g_strdup_printf("%s/webpage-video-%u.mp4", directory, frequency);
    gchar *contents = NULL;
    gsize size = 0;
    g_assert(g_file_get_contents(path, &contents, &size, NULL));
    gchar *base64 = g_base64_encode((const guchar *)contents, size);
    gchar *page = g_strdup_printf("<body><video width=64 height=64 loop autoplay "
        "src='data:video/mp4;base64,%s'></video>", base64);
    g_free(path);
    g_free(contents);
    g_free(base64);
    return page;
}

static void start_capture(Capture *capture, const gchar *mode)
{
    gchar *page = !strcmp(mode, "media") ? media_page(capture->frequency) :
        !strcmp(mode, "video") ? video_page(capture->frequency) : g_strdup_printf(
        "<body style='background:green'><script>const context=new AudioContext();"
        "const oscillator=context.createOscillator();oscillator.connect(context.destination);"
        "oscillator.frequency.value=%u;oscillator.start();context.resume();</script>", capture->frequency);
    gchar *escaped = g_uri_escape_string(page, NULL, FALSE);
    gchar *uri = g_strconcat("data:text/html,", escaped, NULL);
    g_free(escaped);
    g_free(page);
    GstElement *pipeline = gst_pipeline_new(NULL);
    capture->pipeline = pipeline;
    GstElement *source = gst_element_factory_make("wpesrc", NULL);
    GstElement *filter = gst_element_factory_make("capsfilter", NULL);
    GstElement *sink = gst_element_factory_make("fakesink", NULL);
    g_assert(source && filter && sink);
    g_object_set(source, "location", uri, NULL);
    g_free(uri);
    GstIterator *children = gst_bin_iterate_elements(GST_BIN(source));
    gst_iterator_foreach(children, configure_child, NULL);
    gst_iterator_free(children);
    GstCaps *caps = gst_caps_from_string("video/x-raw,format=BGRA,width=64,height=64,framerate=10/1");
    g_object_set(filter, "caps", caps, NULL);
    gst_caps_unref(caps);
    g_object_set(sink, "sync", FALSE, "async", FALSE, "signal-handoffs", TRUE, NULL);
    g_signal_connect(sink, "handoff", G_CALLBACK(video_buffer), capture);
    g_signal_connect(source, "pad-added", G_CALLBACK(audio_pad), capture);
    gst_bin_add_many(GST_BIN(pipeline), source, filter, sink, NULL);
    g_assert(gst_element_link_pads(source, "video", filter, "sink"));
    g_assert(gst_element_link(filter, sink));
    capture->bus = gst_element_get_bus(pipeline);
    gst_element_set_state(pipeline, GST_STATE_PLAYING);
}

static gboolean finish_capture(Capture *capture)
{
    gboolean success = TRUE;
    if (gst_element_set_state(capture->pipeline, GST_STATE_NULL) == GST_STATE_CHANGE_FAILURE ||
        gst_element_get_state(capture->pipeline, NULL, NULL, 2 * GST_SECOND) != GST_STATE_CHANGE_SUCCESS) {
        g_printerr("Pipeline did not finish shutting down\n");
        success = FALSE;
    }
    gst_object_unref(capture->bus);
    gst_object_unref(capture->pipeline);
    return success;
}

int main(int argc, char **argv)
{
    gst_init(&argc, &argv);
    if (argc != 2 || (strcmp(argv[1], "media") && strcmp(argv[1], "webaudio") && strcmp(argv[1], "video"))) {
        g_printerr("Usage: %s {media|webaudio|video}\n", argv[0]);
        return 64;
    }
    for (guint cycle = 0; cycle < 2; cycle++) {
        Capture captures[2] = { 0 };
        for (guint i = 0; i < G_N_ELEMENTS(captures); i++) {
            captures[i].frequency = 440 + 220 * i;
            g_mutex_init(&captures[i].audio_lock);
            start_capture(&captures[i], argv[1]);
        }
        gint64 deadline = g_get_monotonic_time() + 15 * G_TIME_SPAN_SECOND;
        gboolean success = FALSE, failed = FALSE;
        while (g_get_monotonic_time() < deadline && !failed) {
            success = TRUE;
            for (guint i = 0; i < G_N_ELEMENTS(captures); i++) {
                Capture *capture = &captures[i];
                GstMessage *message = gst_bus_timed_pop_filtered(capture->bus, 50 * GST_MSECOND, GST_MESSAGE_ERROR);
                if (message) {
                    GError *error = NULL;
                    gst_message_parse_error(message, &error, NULL);
                    g_printerr("%s\n", error->message);
                    g_error_free(error);
                    gst_message_unref(message);
                    failed = TRUE;
                }
                g_mutex_lock(&capture->audio_lock);
                guint seconds = !strcmp(argv[1], "video") ? 3 : 1;
                gboolean enough_audio = capture->rate > 0 && capture->samples >= seconds * (guint)capture->rate;
                g_mutex_unlock(&capture->audio_lock);
                success &= enough_audio && g_atomic_int_get(&capture->video_buffers) >= 10 &&
                    g_atomic_int_get(&capture->audio_buffers) >= 10;
                if (!strcmp(argv[1], "video"))
                    success &= g_atomic_int_get(&capture->changed_video_buffers) >= 20;
            }
            if (success) break;
        }
        success &= !failed;
        for (guint i = 0; i < G_N_ELEMENTS(captures); i++) {
            Capture *capture = &captures[i];
            success &= finish_capture(capture);
            double frequency = capture->samples ? (double)capture->crossings * capture->rate / capture->samples : 0;
            success &= fabs(frequency - capture->frequency) < 20.0;
            g_print("%s cycle=%u view=%u video=%d nonzero_audio=%d expected_hz=%u observed_hz=%.2f\n", argv[1], cycle, i,
                g_atomic_int_get(&capture->video_buffers), g_atomic_int_get(&capture->audio_buffers), capture->frequency, frequency);
            if (!strcmp(argv[1], "video"))
                g_print("video cycle=%u view=%u changed_frames=%d\n", cycle, i,
                    g_atomic_int_get(&capture->changed_video_buffers));
            g_mutex_clear(&capture->audio_lock);
            if (i == 0 && success) {
                Capture *remaining = &captures[1];
                gint audio_before = g_atomic_int_get(&remaining->audio_buffers);
                gint video_before = g_atomic_int_get(&remaining->video_buffers);
                gint64 continuation_deadline = g_get_monotonic_time() + 3 * G_TIME_SPAN_SECOND;
                gboolean continued = FALSE;
                while (g_get_monotonic_time() < continuation_deadline) {
                    GstMessage *error = gst_bus_timed_pop_filtered(remaining->bus,
                        50 * GST_MSECOND, GST_MESSAGE_ERROR);
                    if (error) {
                        gst_message_unref(error);
                        break;
                    }
                    continued = g_atomic_int_get(&remaining->audio_buffers) >= audio_before + 10 &&
                        g_atomic_int_get(&remaining->video_buffers) >= video_before + 10;
                    if (continued) break;
                }
                g_print("%s cycle=%u second_view_after_first_removed=%s\n",
                    argv[1], cycle, continued ? "PASS" : "FAIL");
                success &= continued;
            }
        }
        if (!success) {
            g_printerr("%s: FAIL\n", argv[1]);
            return 1;
        }
    }
    g_print("%s: PASS\n", argv[1]);
    return 0;
}
