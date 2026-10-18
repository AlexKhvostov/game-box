// Shell UID test utility. Injects real Android MotionEvents into the isolated
// UI probe only. Coordinates must be observed from its actual field screenshot.
import android.os.SystemClock;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.MotionEvent;
import java.lang.reflect.Method;

public final class InputSequence {
  private static Object inputManager;
  private static Method inject;
  private static long down;

  private static void send(int action, int count, float x, float y) throws Exception {
    MotionEvent.PointerProperties[] properties = new MotionEvent.PointerProperties[count];
    MotionEvent.PointerCoords[] coords = new MotionEvent.PointerCoords[count];
    for (int i = 0; i < count; i++) {
      properties[i] = new MotionEvent.PointerProperties();
      properties[i].id = i;
      properties[i].toolType = MotionEvent.TOOL_TYPE_FINGER;
      coords[i] = new MotionEvent.PointerCoords();
      coords[i].x = x + i * 60;
      coords[i].y = y;
      coords[i].pressure = 1;
      coords[i].size = 1;
    }
    MotionEvent event = MotionEvent.obtain(down, SystemClock.uptimeMillis(), action,
        count, properties, coords, 0, 0, 1, 1, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0);
    try {
      if (!((Boolean) inject.invoke(inputManager, event, 2))) {
        throw new IllegalStateException("Android rejected the input event");
      }
    } finally { event.recycle(); }
  }
  public static void main(String[] args) throws Exception {
    if (args.length != 3 || !"ISOLATED_ENERGY_PROBE".equals(args[0])) {
      throw new IllegalArgumentException("Explicit isolated probe guard required");
    }
    float x = Float.parseFloat(args[1]);
    float y = Float.parseFloat(args[2]);
    Class<?> type = Class.forName("android.hardware.input.InputManager");
    inputManager = type.getMethod("getInstance").invoke(null);
    inject = type.getMethod("injectInputEvent", InputEvent.class, int.class);
    down = SystemClock.uptimeMillis();
    send(MotionEvent.ACTION_DOWN, 1, x, y);
    try {
      SystemClock.sleep(850);
      send(MotionEvent.ACTION_POINTER_DOWN | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, x, y);
      SystemClock.sleep(70);
      send(MotionEvent.ACTION_POINTER_UP | (1 << MotionEvent.ACTION_POINTER_INDEX_SHIFT), 2, x, y);
    } finally {
      send(MotionEvent.ACTION_UP, 1, x, y);
    }
    System.out.println("ANDROID_MULTITOUCH_SENT");
  }
}
