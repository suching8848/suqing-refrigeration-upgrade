package suqing.refrigeration.nativebackend;

import java.lang.reflect.InvocationTargetException;
import java.nio.file.*;

/** Child-loader-safe bridge. Main must not invoke start before the Lua handshake. */
public final class ZBIntegrationBootstrap {
    private static volatile String failure;
    private ZBIntegrationBootstrap() { }

    public static synchronized boolean start() {
        try {
            AgentSupport.ZombieBuddyAccess access=AgentSupport.verifiedZombieBuddy();
            Path candidate=AgentSupport.codeSourceJar(ZBIntegrationBootstrap.class);
            String hash=AgentSupport.sha256(Files.readAllBytes(candidate));
            // ZB2.3.4's normal loader already appends approved JARs to system.
            // Only a genuine child-loader bridge needs an additional append.
            if(ZBIntegrationBootstrap.class.getClassLoader()!=ClassLoader.getSystemClassLoader())
                AgentSupport.appendCandidate(access.instrumentation(),candidate,hash);
            Class<?> bootstrap=Class.forName("suqing.refrigeration.nativebackend.Bootstrap",true,ClassLoader.getSystemClassLoader());
            if(bootstrap.getClassLoader()!=ClassLoader.getSystemClassLoader()
                    || !candidate.equals(AgentSupport.codeSourceJar(bootstrap)))
                throw new IllegalStateException("Canonical Bootstrap is loaded from another candidate");
            Object result=bootstrap.getMethod("install",java.lang.instrument.Instrumentation.class,String.class,String.class)
                    .invoke(null,access.instrumentation(),candidate.toString(),hash);
            if(!Boolean.TRUE.equals(result)) {
                failure=String.valueOf(bootstrap.getMethod("status").invoke(null));
                return false;
            }
            failure=null;
            return true;
        } catch(Throwable error) {
            Throwable cause=error instanceof InvocationTargetException ite && ite.getCause()!=null ? ite.getCause() : error;
            failure=cause.getClass().getName()+": "+String.valueOf(cause.getMessage());
            System.out.println("[SuQingRefrigerationNative] bootstrap rejected: "+failure);
            return false;
        }
    }
    public static String lastFailure() { return failure; }
    public static String status() { return "{\"bridgeFailure\":"+AgentSupport.json(failure)+"}"; }
}
