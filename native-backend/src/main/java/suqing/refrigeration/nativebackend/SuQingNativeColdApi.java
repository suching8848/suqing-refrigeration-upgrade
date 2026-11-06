package suqing.refrigeration.nativebackend;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import me.zed_0xff.zombie_buddy.Exposer.LuaClass;
import zombie.inventory.types.Food;

/** Sparse boundary API. Food hot paths call NativeHooks directly, never Lua. */
// ZB 2.3.4's explicit same-name alias branch clears its own global table.
// Default exposure publishes this simple class name without aliasing it.
@LuaClass
public final class SuQingNativeColdApi {
    public static final String BASE_VERSION = "1.0.0-rc.2-perf.8";
    private static volatile Map<String, Method> methods;
    private static volatile Class<?> canonicalBootstrap;
    private static volatile String failure;
    private SuQingNativeColdApi() { }

    public static int apiVersion() { return 1; }

    public static synchronized boolean bootstrap(String baseVersion) {
        if (!BASE_VERSION.equals(baseVersion)) {
            failure="unsupported base version: "+String.valueOf(baseVersion);
            return false;
        }
        if (!ZBIntegrationBootstrap.start()) {
            failure=ZBIntegrationBootstrap.lastFailure();
            return false;
        }
        try {
            ClassLoader system=ClassLoader.getSystemClassLoader();
            Path own=AgentSupport.codeSourceJar(SuQingNativeColdApi.class);
            Class<?> boot=Class.forName("suqing.refrigeration.nativebackend.Bootstrap",true,system);
            Class<?> runtime=Class.forName("suqing.refrigeration.nativebackend.NativeRuntime",true,system);
            if (boot.getClassLoader()!=system || runtime.getClassLoader()!=system
                    || !own.equals(AgentSupport.codeSourceJar(boot))
                    || !own.equals(AgentSupport.codeSourceJar(runtime)))
                throw new IllegalStateException("mixed candidate API/runtime loaders or sources");
            Map<String,Method> captured=new LinkedHashMap<>();
            capture(captured,runtime,"isReady",boolean.class);
            capture(captured,runtime,"isActive",boolean.class);
            capture(captured,runtime,"activate",boolean.class,boolean.class);
            capture(captured,runtime,"setCoolingEnabled",void.class,boolean.class);
            capture(captured,runtime,"invalidate",void.class);
            capture(captured,runtime,"settle",void.class,Food.class);
            capture(captured,runtime,"flushKnown",void.class);
            capture(captured,runtime,"fridgeFactor",float.class);
            capture(captured,runtime,"foodRotSpeed",float.class);
            capture(captured,runtime,"status",String.class);
            capture(captured,runtime,"shutdown",void.class);
            canonicalBootstrap=boot;
            methods=Map.copyOf(captured);
            failure=null;
            return isReady();
        } catch (Exception error) {
            failure=error.getClass().getName()+": "+String.valueOf(error.getMessage());
            return false;
        }
    }
    private static void capture(Map<String,Method> into,Class<?> owner,String name,Class<?> result,Class<?>...args)
            throws ReflectiveOperationException {
        Method method=owner.getMethod(name,args);
        if (!Modifier.isStatic(method.getModifiers()) || method.getReturnType()!=result)
            throw new IllegalStateException("unsupported runtime ABI: "+name);
        into.put(name,method);
    }
    private static Object call(String name,Object...args) {
        Map<String,Method> current=methods;
        if (current==null) throw new IllegalStateException("Native backend not bootstrapped");
        try { return current.get(name).invoke(null,args); }
        catch (InvocationTargetException error) {
            Throwable cause=error.getCause();
            if (cause instanceof RuntimeException runtime) throw runtime;
            if (cause instanceof Error fatal) throw fatal;
            throw new IllegalStateException("Native boundary failed: "+name,cause);
        } catch (ReflectiveOperationException error) {
            throw new IllegalStateException("Native ABI unavailable: "+name,error);
        }
    }
    public static boolean isReady() {
        if (methods==null || canonicalBootstrap==null) return false;
        try { return Boolean.TRUE.equals(canonicalBootstrap.getMethod("isInstalled").invoke(null))
                && Boolean.TRUE.equals(call("isReady")); }
        catch (ReflectiveOperationException error) { return false; }
    }
    public static boolean isActive() { return methods!=null && Boolean.TRUE.equals(call("isActive")); }
    public static boolean activate(boolean enabled) {
        if (methods==null) return false;
        if (enabled && !isReady()) return false;
        return Boolean.TRUE.equals(call("activate",enabled));
    }
    public static void setCoolingEnabled(boolean enabled) { call("setCoolingEnabled",enabled); }
    public static void invalidate() { call("invalidate"); }
    public static void settle(Food food) { call("settle",food); }
    public static void flushKnown() { call("flushKnown"); }
    public static float fridgeFactor() { return ((Number)call("fridgeFactor")).floatValue(); }
    public static float foodRotSpeed() { return ((Number)call("foodRotSpeed")).floatValue(); }
    public static void shutdown() { if (methods!=null) call("shutdown"); }
    public static String status() {
        String boot="null",runtime="null";
        if (canonicalBootstrap!=null) try { boot=String.valueOf(canonicalBootstrap.getMethod("status").invoke(null)); }
        catch (ReflectiveOperationException error) { boot=AgentSupport.json(error.toString()); }
        if (methods!=null) runtime=String.valueOf(call("status"));
        return "{\"api\":1,\"baseVersion\":"+AgentSupport.json(BASE_VERSION)
            +",\"failure\":"+AgentSupport.json(failure)+",\"bootstrap\":"+boot+",\"runtime\":"+runtime+"}";
    }
}
