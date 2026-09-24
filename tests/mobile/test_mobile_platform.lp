import "universe/mobile/platform"

@fn main()
  println("--- Mobile Platform Test ---")

  app = app_new("LipiApp", "1.0.0")
  @if app.name != "LipiApp"
    println("FAIL: app_new")
    return 1
  @end
  println("PASS: app_new")

  // Test Notification
  notif_res = app_show_notification(app, "Sovereign Alert", "Execution verified")
  @if notif_res != 1
    println("FAIL: app_show_notification")
    return 1
  @end
  println("PASS: app_show_notification")

  // Test Vibration
  vibe_res = app_vibrate(app, 150)
  @if vibe_res != 1
    println("FAIL: app_vibrate")
    return 1
  @end
  println("PASS: app_vibrate")

  // Test URL opening (valid and invalid)
  url_ok = app_open_url(app, "https://lipi-lang.org/docs")
  @if url_ok != 1
    println("FAIL: app_open_url valid")
    return 1
  @end
  println("PASS: app_open_url valid")

  url_fail = app_open_url(app, "invalid-scheme://test")
  @if url_fail != 0
    println("FAIL: app_open_url invalid")
    return 1
  @end
  println("PASS: app_open_url invalid rejection")

  println("=== ALL MOBILE PLATFORM TESTS PASSED ===")
  return 0
@end
