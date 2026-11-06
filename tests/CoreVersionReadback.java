import java.lang.reflect.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;

/** Reads Core version accessors only. Does not initialize or run a game world. */
public final class CoreVersionReadback {
    public static void main(String[] args) throws Exception {
        Class<?> owner=Class.forName("zombie.core.Core");
        Object core=owner.getMethod("getInstance").invoke(null);
        Method numberMethod=owner.getMethod("getVersionNumber");
        Method buildMethod=owner.getMethod("getGameAndBuildVersion");
        if(!Modifier.isPublic(numberMethod.getModifiers())||Modifier.isStatic(numberMethod.getModifiers())
            ||!Modifier.isPublic(buildMethod.getModifiers())||Modifier.isStatic(buildMethod.getModifiers()))
            throw new IllegalStateException("Expected exposed public instance methods");
        String number=(String)numberMethod.invoke(core);
        String build=(String)buildMethod.invoke(core);
        System.out.println("getVersionNumber publicInstance=true");
        System.out.println("getGameAndBuildVersion publicInstance=true");
        System.out.println("Core codeSource="+owner.getProtectionDomain().getCodeSource().getLocation());
        System.out.println("getVersionNumber="+number);
        System.out.println("getGameAndBuildVersion="+build);
        String lua="DISPLAY_NATIVE_CORE_VERSION="+quote(number)+"\nDISPLAY_NATIVE_CORE_BUILD_VERSION="+quote(build)+"\n";
        Files.write(Paths.get(args[0]),lua.getBytes(StandardCharsets.UTF_8));
        System.out.println("PASS: native Core version accessors read; no world/save methods invoked.");
    }
    private static String quote(String s) {
        return "\""+s.replace("\\","\\\\").replace("\"","\\\"")+"\"";
    }
}
