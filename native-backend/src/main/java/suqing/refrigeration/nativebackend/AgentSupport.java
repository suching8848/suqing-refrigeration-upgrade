package suqing.refrigeration.nativebackend;

import java.io.IOException;
import java.lang.instrument.Instrumentation;
import java.lang.reflect.*;
import java.net.URI;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.jar.JarFile;

/** Deliberately version-bound access to ZombieBuddy's private instrumentation handle. */
public final class AgentSupport {
    public static final String ZB_VERSION = "2.3.4";
    public static final String ZB_SHA256 = "eb79b9876332010733a8e0d7ce4fe0377846059a9e28859029e2a0fb449f6cf2";
    private static final String LOADER = "me.zed_0xff.zombie_buddy.Loader";
    private static final String ZOMBIE_BUDDY = "me.zed_0xff.zombie_buddy.ZombieBuddy";
    // The JVM can continue using these archives after appendToSystemClassLoaderSearch.
    private static final List<JarFile> APPENDED_ARCHIVES = new ArrayList<>();
    private AgentSupport() { }

    public record ZombieBuddyAccess(Instrumentation instrumentation,Path jar,String sha256,String version) { }

    public static ZombieBuddyAccess verifiedZombieBuddy() throws Exception {
        ClassLoader system = ClassLoader.getSystemClassLoader();
        Class<?> loader = Class.forName(LOADER,false,system);
        Class<?> api = Class.forName(ZOMBIE_BUDDY,false,system);
        if(loader.getClassLoader()!=system || api.getClassLoader()!=system)
            throw new IllegalStateException("ZombieBuddy must be owned by the system loader");
        Path jar = codeSourceJar(loader);
        if(!jar.equals(codeSourceJar(api))) throw new IllegalStateException("Mixed ZombieBuddy code sources");
        String before = sha256(Files.readAllBytes(jar));
        if(!ZB_SHA256.equals(before)) throw new IllegalStateException("Unsupported ZombieBuddy JAR sha256="+before);
        String manifestVersion;
        try(JarFile archive=new JarFile(jar.toFile())) {
            manifestVersion=archive.getManifest().getMainAttributes().getValue("Implementation-Version");
        }
        String liveVersion=String.valueOf(api.getMethod("getVersion").invoke(null));
        if(!ZB_VERSION.equals(manifestVersion)||!ZB_VERSION.equals(liveVersion))
            throw new IllegalStateException("Unsupported ZombieBuddy version manifest="+manifestVersion+" live="+liveVersion);
        Field field=loader.getDeclaredField("g_instrumentation");
        if(field.getType()!=Instrumentation.class || !Modifier.isStatic(field.getModifiers())
                || Modifier.isPublic(field.getModifiers()) || Modifier.isProtected(field.getModifiers())
                || Modifier.isPrivate(field.getModifiers()))
            throw new IllegalStateException("ZombieBuddy private ABI changed");
        if(!field.trySetAccessible()) throw new IllegalStateException("Cannot access reviewed ZombieBuddy instrumentation field");
        Object handle=field.get(null);
        if(!(handle instanceof Instrumentation inst)) throw new IllegalStateException("ZombieBuddy instrumentation is unavailable");
        if(!inst.isRetransformClassesSupported()) throw new IllegalStateException("JVM does not support class retransformation");
        if(!before.equals(sha256(Files.readAllBytes(jar)))) throw new IllegalStateException("ZombieBuddy JAR changed during validation");
        return new ZombieBuddyAccess(inst,jar,before,liveVersion);
    }

    public static Path codeSourceJar(Class<?> owner) throws Exception {
        if(owner.getProtectionDomain()==null || owner.getProtectionDomain().getCodeSource()==null)
            throw new IllegalStateException("Missing JAR code source: "+owner.getName());
        URI uri=owner.getProtectionDomain().getCodeSource().getLocation().toURI();
        if(!"file".equalsIgnoreCase(uri.getScheme())) throw new IllegalStateException("Non-file code source: "+uri);
        Path path=Path.of(uri).toRealPath();
        if(!Files.isRegularFile(path)||!path.getFileName().toString().toLowerCase(Locale.ROOT).endsWith(".jar"))
            throw new IllegalStateException("Candidate must run from a JAR: "+path);
        return path;
    }

    public static synchronized void appendCandidate(Instrumentation inst,Path candidate,String expectedHash) throws Exception {
        Path real=candidate.toRealPath();
        if(!expectedHash.equals(sha256(Files.readAllBytes(real)))) throw new IllegalStateException("Candidate changed before append");
        for(JarFile archive:APPENDED_ARCHIVES) if(Path.of(archive.getName()).toRealPath().equals(real)) return;
        JarFile archive=new JarFile(real.toFile());
        try {
            // This only exposes this approved candidate's helpers. No self-attach,
            // additional agent, game class replacement or policy change occurs.
            inst.appendToSystemClassLoaderSearch(archive);
            APPENDED_ARCHIVES.add(archive);
            if(!expectedHash.equals(sha256(Files.readAllBytes(real)))) throw new IllegalStateException("Candidate changed during append");
        } catch(Throwable error) {
            if(!APPENDED_ARCHIVES.contains(archive)) archive.close();
            throw error;
        }
    }

    public static String sha256(byte[] bytes) {
        try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));}
        catch(java.security.NoSuchAlgorithmException impossible){throw new AssertionError(impossible);}
    }
    public static String json(String value) {
        if(value==null)return "null";
        StringBuilder out=new StringBuilder("\"");
        for(int i=0;i<value.length();i++) {
            char c=value.charAt(i);
            switch(c) {
                case '\\'->out.append("\\\\");case '"'->out.append("\\\"");
                case '\n'->out.append("\\n");case '\r'->out.append("\\r");case '\t'->out.append("\\t");
                default->{if(c<32)out.append(String.format(Locale.ROOT,"\\u%04x",(int)c));else out.append(c);}
            }
        }
        return out.append('"').toString();
    }
}
