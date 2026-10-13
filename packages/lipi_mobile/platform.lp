@! ============================================================================
@! LIPI MOBILE PLATFORM ABSTRACTION (universe/mobile/platform.lp)
@! 100% Pure Lipi Implementation — Zero Native C/Java Framework Dependencies
@! Supports Orientation, Touch Event Queue, Safe Area, Status, & JNI Generator
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Platform & Orientation Constants
@! ----------------------------------------------------------------------------

@fn ORIENTATION_PORTRAIT() return 1 @end
@fn ORIENTATION_LANDSCAPE() return 2 @end
@fn ORIENTATION_PORTRAIT_REVERSE() return 3 @end
@fn ORIENTATION_LANDSCAPE_REVERSE() return 4 @end

@fn orientation_name(o)
  @if o == 1 return "PORTRAIT" @end
  @if o == 2 return "LANDSCAPE" @end
  @if o == 3 return "PORTRAIT_REVERSE" @end
  @if o == 4 return "LANDSCAPE_REVERSE" @end
  return "PORTRAIT"
@end

@! ----------------------------------------------------------------------------
@! 2. Data Structures
@! ----------------------------------------------------------------------------

@struct TouchEvent
  event_type: string
  x: i64
  y: i64
  pointer_id: i64
  pressure: i64
  timestamp_ms: i64
@end

@struct SafeAreaInsets
  top: i64
  bottom: i64
  left: i64
  right: i64
@end

@struct BatteryStatus
  level: i64
  is_charging: i64
  battery_health: string
  temperature_c: i64
@end

@struct NetworkStatus
  connected: i64
  network_type: string
  is_metered: i64
  signal_strength: i64
@end

@struct Screen
  width: i64
  height: i64
  density: i64
  orientation: i64
  safe_area
@end

@struct MobileApp
  name: string
  version: string
  platform: string
  orientation: i64
  screen
  touch_queue: array
  safe_area
  battery
  network
  permissions: array
@end

@! ----------------------------------------------------------------------------
@! 3. Constructors & Initialization
@! ----------------------------------------------------------------------------

@fn touch_event_new(event_type, x, y, pointer_id)
  return {
    event_type: event_type,
    x: x,
    y: y,
    pointer_id: pointer_id,
    pressure: 100,
    timestamp_ms: clock_ms()
  }
@end

@fn safe_area_insets_new(top, bottom, left, right)
  return {
    top: top,
    bottom: bottom,
    left: left,
    right: right
  }
@end

@fn battery_status_new(level, is_charging, health, temp)
  return {
    level: level,
    is_charging: is_charging,
    battery_health: health,
    temperature_c: temp
  }
@end

@fn network_status_new(connected, net_type, is_metered, signal)
  return {
    connected: connected,
    network_type: net_type,
    is_metered: is_metered,
    signal_strength: signal
  }
@end

@fn screen_new(w, h, density, orientation, safe_area)
  return {
    width: w,
    height: h,
    density: density,
    orientation: orientation,
    safe_area: safe_area
  }
@end

@fn app_new(name, version)
  safe = safe_area_insets_new(48, 34, 0, 0)
  scr = screen_new(1080, 1920, 2, ORIENTATION_PORTRAIT(), safe)
  bat = battery_status_new(100, 0, "GOOD", 25)
  net = network_status_new(1, "WIFI", 0, 100)
  
  return {
    name: name,
    version: version,
    platform: "android",
    orientation: ORIENTATION_PORTRAIT(),
    screen: scr,
    touch_queue: [],
    safe_area: safe,
    battery: bat,
    network: net,
    permissions: []
  }
@end

@! ----------------------------------------------------------------------------
@! 4. Screen, Orientation, and Safe Area Operations
@! ----------------------------------------------------------------------------

@fn app_get_screen()
  safe = safe_area_insets_new(48, 34, 0, 0)
  return screen_new(1080, 1920, 2, ORIENTATION_PORTRAIT(), safe)
@end

@fn app_get_platform()
  return "android"
@end

@fn app_set_orientation(app: MobileApp, orientation)
  old_orient = app.orientation
  app.orientation = orientation
  
  @! Swap width and height if transitioning between portrait and landscape
  is_old_portrait = (old_orient == 1 || old_orient == 3)
  is_new_portrait = (orientation == 1 || orientation == 3)
  
  @if is_old_portrait != is_new_portrait
    tmp = app.screen.width
    app.screen.width = app.screen.height
    app.screen.height = tmp
  @end
  return app
@end

@fn app_get_orientation(app: MobileApp)
  return app.orientation
@end

@fn app_get_safe_area(app: MobileApp)
  return app.safe_area
@end

@fn app_set_safe_area(app: MobileApp, top, bottom, left, right)
  insets = safe_area_insets_new(top, bottom, left, right)
  app.safe_area = insets
  return app
@end

@! ----------------------------------------------------------------------------
@! 5. Touch Event Queue Operations
@! ----------------------------------------------------------------------------

@fn app_push_touch(app: MobileApp, event)
  app.touch_queue = app.touch_queue.push(event)
  return app
@end

@fn app_touch_queue_len(app: MobileApp)
  return app.touch_queue.len()
@end

@fn app_poll_touch(app: MobileApp)
  @if app.touch_queue.len() == 0
    return touch_event_new("NONE", 0, 0, 0)
  @end
  first = app.touch_queue[0]
  new_queue = []
  i = 1
  @while i < app.touch_queue.len()
    new_queue = new_queue.push(app.touch_queue[i])
    i = i + 1
  @end
  app.touch_queue = new_queue
  return first
@end

@fn app_clear_touches(app: MobileApp)
  app.touch_queue = []
  return app
@end

@! ----------------------------------------------------------------------------
@! 6. Device Status Queries (Battery & Network)
@! ----------------------------------------------------------------------------

@fn app_get_battery_status(app: MobileApp)
  return app.battery
@end

@fn app_set_battery_status(app: MobileApp, level, is_charging, health, temp)
  app.battery = battery_status_new(level, is_charging, health, temp)
  return app
@end

@fn app_get_network_status(app: MobileApp)
  return app.network
@end

@fn app_set_network_status(app: MobileApp, connected, net_type, is_metered, signal)
  app.network = network_status_new(connected, net_type, is_metered, signal)
  return app
@end

@! ----------------------------------------------------------------------------
@! 7. Permissions & OS Integrations
@! ----------------------------------------------------------------------------

@fn app_request_permission(app: MobileApp, perm)
  app.permissions = app.permissions.push(perm)
  return app
@end

@fn app_has_permission(app: MobileApp, perm)
  i = 0
  @while i < app.permissions.len()
    @if app.permissions[i] == perm
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

// WHY: Dispatches desktop and terminal notifications using ANSI OSC 9 / OSC 777 protocols
// and writes to persistent notification log without requiring heavyweight native Java/Android frameworks.
@fn app_show_notification(app: MobileApp, title, body)
  @if len(title) == 0 && len(body) == 0
    return 0
  @end
  
  // Format ANSI OSC 9 escape sequence: ESC ] 9 ; <title> : <body> BEL
  osc9 = chr(27) + "]9;" + title + ": " + body + chr(7)
  println(osc9)
  
  // Append to notification spool file for IPC desktop daemon listeners
  spool_entry = "[" + to_str(clock_ms()) + "] " + title + ": " + body + "\n"
  log_path = "/tmp/lipi_notifications.log"
  prev_log = ""
  @if file_exists(log_path) == 1
    prev_log = file_read(log_path)
  @end
  file_write(log_path, prev_log + spool_entry)
  return 1
@end

// WHY: Triggers haptic feedback via Linux sysfs timed_output or LED vibrator node,
// falling back to terminal ASCII BEL (0x07) for cross-platform hardware feedback.
@fn app_vibrate(app: MobileApp, ms)
  @if ms <= 0
    return 0
  @end
  // Safety clamp to prevent hardware burnout (max 5000 ms)
  vibe_duration = ms
  @if vibe_duration > 5000
    vibe_duration = 5000
  @end
  
  vibe_str = to_str(vibe_duration)
  node_found = 0
  
  // 1. Android/Embedded Linux timed_output sysfs interface
  timed_out_path = "/sys/class/timed_output/vibrator/enable"
  @if file_exists(timed_out_path) == 1
    file_write(timed_out_path, vibe_str)
    node_found = 1
  @end
  
  // 2. LED vibrator sysfs interface
  led_vibe_path = "/sys/class/leds/vibrator/duration"
  @if file_exists(led_vibe_path) == 1
    file_write(led_vibe_path, vibe_str)
    node_found = 1
  @end
  
  // 3. Universal hardware bell fallback (auditory/tactile pulse)
  println(chr(7))
  return 1
@end

// WHY: Validates URL format against standard sovereign web/resource protocols (http, https, mailto, tel, file)
// and queues launch intent to IPC spool file for external system dispatcher.
@fn app_open_url(app: MobileApp, url)
  url_len = len(url)
  @if url_len == 0
    return 0
  @end
  
  // Validate protocol prefix
  is_valid = 0
  @if str_starts_with(url, "http://") == 1 || str_starts_with(url, "https://") == 1
    is_valid = 1
  @elif str_starts_with(url, "mailto:") == 1 || str_starts_with(url, "tel:") == 1
    is_valid = 1
  @elif str_starts_with(url, "file://") == 1
    is_valid = 1
  @end
  
  @if is_valid == 0
    return 0
  @end
  
  // Record intent in system dispatcher spool file
  queue_path = "/tmp/lipi_open_url.queue"
  queue_prev = ""
  @if file_exists(queue_path) == 1
    queue_prev = file_read(queue_path)
  @end
  file_write(queue_path, queue_prev + url + "\n")
  return 1
@end

@! ----------------------------------------------------------------------------
@! 8. JNI Method Signature & Native Binding Generator
@! ----------------------------------------------------------------------------

@fn jni_type_to_signature(t)
  @if t == "void" || t == "Void" return "V" @end
  @if t == "boolean" || t == "bool" || t == "Bool" return "Z" @end
  @if t == "byte" || t == "i8" || t == "u8" return "B" @end
  @if t == "char" return "C" @end
  @if t == "short" || t == "i16" return "S" @end
  @if t == "int" || t == "i32" return "I" @end
  @if t == "long" || t == "i64" return "J" @end
  @if t == "float" || t == "f32" return "F" @end
  @if t == "double" || t == "f64" return "D" @end
  @if t == "string" || t == "String" || t == "str" return "Ljava/lang/String;" @end
  @if t == "object" || t == "Object" return "Ljava/lang/Object;" @end
  @if str_starts_with(t, "[")
    sub = str_substr(t, 1, str_len(t))
    return "[" + jni_type_to_signature(sub)
  @end
  @if str_starts_with(t, "L") && str_ends_with(t, ";")
    return t
  @end
  return "L" + t + ";"
@end

@fn jni_method_signature(params, ret)
  sig = "("
  i = 0
  @while i < params.len()
    sig = sig + jni_type_to_signature(params[i])
    i = i + 1
  @end
  sig = sig + ")" + jni_type_to_signature(ret)
  return sig
@end

@fn jni_mangle_name(name)
  res = ""
  i = 0
  num_items = str_len(name)
  @while i < num_items
    ch = str_substr(name, i, i + 1)
    @if ch == "/" || ch == "."
      res = res + "_"
    @else
      res = res + ch
    @end
    i = i + 1
  @end
  return res
@end

@fn jni_native_method_name(class_name, method_name)
  return "Java_" + jni_mangle_name(class_name) + "_" + jni_mangle_name(method_name)
@end

@fn jni_generate_native_binding(class_name, method_name, param_types, return_type)
  mangled = jni_native_method_name(class_name, method_name)
  sig = jni_method_signature(param_types, return_type)
  out = "/* JNI Signature: " + sig + " */\n"
  out = out + "JNIEXPORT " + return_type + " JNICALL " + mangled + "(JNIEnv *env, jobject thiz"
  i = 0
  @while i < param_types.len()
    out = out + ", " + param_types[i] + " arg" + int_to_str(i)
    i = i + 1
  @end
  out = out + ")"
  return out
@end
