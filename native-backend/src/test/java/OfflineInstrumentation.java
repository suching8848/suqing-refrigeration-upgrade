import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;

/** TEST ONLY: isolated JVM premain, never bundled with or installed as the patch. */
public final class OfflineInstrumentation {
    public static Instrumentation instrumentation;
    public static void premain(String options,Instrumentation inst) throws Exception {
        instrumentation=inst;
        if("no-handle".equals(options)) return;
        Class<?> loader=Class.forName("me.zed_0xff.zombie_buddy.Loader",false,ClassLoader.getSystemClassLoader());
        Field field=loader.getDeclaredField("g_instrumentation");field.setAccessible(true);field.set(null,inst);
    }
}
