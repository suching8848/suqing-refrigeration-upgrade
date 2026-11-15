package suqing.refrigeration.nativebackend;

import java.io.InputStream;
import java.io.OutputStream;
import java.lang.instrument.Instrumentation;
import java.lang.reflect.*;
import java.nio.file.*;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.util.*;

/** Canonical system-loader installation state; deliberately inactive until Lua handoff. */
public final class Bootstrap {
    public static final int API_VERSION=1;
    public static final String MOD_ID="SuQingRefrigerationNative_4221";
    public static final String VERSION="0.1.0-rc.2";
    private record ReviewedBuild(String version, String foodSha256, String stockJarSha256) { }
    private static final Map<String,ReviewedBuild> REVIEWED_BUILDS=Map.of(
            "42.21.0",new ReviewedBuild("42.21",
                    "14a5b02878a5608e3a28d3e91110961b3576694badf127dc7fe2749b8393d8b1",null),
            "42.22.2",new ReviewedBuild("42.22",
                    "72c432d1730ffc84bb96711b12da6864f845ea898a761acd70caa5a61f0f96c0",
                    "3c4a7c5f149d784758c6fb5f8fa85f3a21d572e38bc081400e89035f8120d287"));
    private static volatile String state="uninstalled",failure;
    private static String candidatePath,candidateHash,zbPath,gameBuild;
    private static FoodTransformer transformer;
    private static Instrumentation instrumentation;
    private static Class<?> runtime;
    private Bootstrap() { }

    public static synchronized boolean install(Instrumentation inst,String jarPath,String jarHash) {
        if(Bootstrap.class.getClassLoader()!=ClassLoader.getSystemClassLoader()) {
            failure="Bootstrap must be called through the canonical system loader";
            return false;
        }
        try {
            Path jar=Path.of(jarPath).toRealPath();
            if(!jar.equals(AgentSupport.codeSourceJar(Bootstrap.class))) throw new IllegalStateException("Bootstrap candidate source differs");
            if(!jarHash.equals(AgentSupport.sha256(Files.readAllBytes(jar)))) throw new IllegalStateException("Candidate JAR changed");
            if(state.equals("installed")) {
                if(!jar.toString().equals(candidatePath)||!jarHash.equals(candidateHash)||inst!=instrumentation)
                    throw new IllegalStateException("A different candidate or instrumentation is already installed");
                // Returning to the menu clears Runtime state but does not undo
                // the class rewrite. A new world needs fresh inactive runtime
                // initialization; this is never an ownership activation.
                if(runtime==null) throw new IllegalStateException("Installed runtime is missing");
                verifyCanonical(runtime,jar);
                return Boolean.TRUE.equals(runtime.getMethod("initialize").invoke(null));
            }
            if(!state.equals("uninstalled")) throw new IllegalStateException("Installation requires a fresh JVM after "+state);
            state="installing";
            candidatePath=jar.toString();candidateHash=jarHash;
            AgentSupport.ZombieBuddyAccess zb=AgentSupport.verifiedZombieBuddy();
            if(zb.instrumentation()!=inst) throw new IllegalStateException("Instrumentation is not the reviewed ZombieBuddy handle");
            zbPath=zb.jar().toString();instrumentation=inst;
            ClassLoader system=ClassLoader.getSystemClassLoader();
            verifyCanonical(FoodTransformer.class,jar);
            verifyCanonical(AgentSupport.class,jar);
            ReviewedBuild reviewedBuild=verifyGameBuild(system);
            verifyHooks(system,jar);
            runtime=Class.forName("suqing.refrigeration.nativebackend.NativeRuntime",true,system);
            verifyCanonical(runtime,jar);
            if(runtime.getField("API_VERSION").getInt(null)!=API_VERSION
                    ||!MOD_ID.equals(runtime.getField("MOD_ID").get(null)))
                throw new IllegalStateException("Unsupported canonical NativeRuntime ABI");
            requireMethod(runtime,"initialize",boolean.class);
            requireMethod(runtime,"isReady",boolean.class);
            requireMethod(runtime,"activate",boolean.class,boolean.class);
            requireMethod(runtime,"emergencyDisable",void.class,String.class);
            requireMethod(runtime,"invalidate",void.class);
            requireMethod(runtime,"shutdown",void.class);
            requireMethod(runtime,"status",String.class);
            if(!Boolean.TRUE.equals(runtime.getMethod("initialize").invoke(null))) throw new IllegalStateException("NativeRuntime rejected initialization");
            runtime.getMethod("activate",boolean.class).invoke(null,false);
            String resource=FoodTransformer.FOOD+".class";
            byte[] reviewed;
            try(InputStream input=system.getResourceAsStream(resource)) {
                if(input==null) throw new IllegalStateException("Food class resource unavailable");
                reviewed=input.readAllBytes();
            }
            String foodHash=FoodTransformer.sha256(reviewed);
            if(!reviewedBuild.foodSha256().equals(foodHash))
                throw new IllegalStateException("Unsupported Food resource build="+gameBuild+" sha256="+foodHash);
            // Validate the entire rewrite before registering any transformer.
            FoodTransformer.rewrite(reviewed);
            transformer=new FoodTransformer(Bootstrap::transformFailed);
            inst.addTransformer(transformer,true);
            Class<?> food=null;
            for(Class<?> loaded:inst.getAllLoadedClasses()) {
                if(loaded.getName().equals("zombie.inventory.types.Food")) {
                    if(loaded.getClassLoader()!=system) throw new IllegalStateException("A second Food class loader exists");
                    food=loaded;
                }
            }
            if(food==null) food=Class.forName("zombie.inventory.types.Food",false,system);
            else {
                if(!inst.isModifiableClass(food)) throw new IllegalStateException("Loaded Food class is not modifiable");
                inst.retransformClasses(food);
            }
            if(transformer.applications()!=1 || transformer.lastFailure()!=null || !state.equals("installing"))
                throw new IllegalStateException("Food rewrite did not complete exactly once: "+transformer.lastFailure());
            if(!jarHash.equals(AgentSupport.sha256(Files.readAllBytes(jar)))) throw new IllegalStateException("Candidate changed during installation");
            state="installed";failure=null;
            System.out.println("[SuQingRefrigerationNative] installed inactive; api="+API_VERSION+" game="+gameBuild+" ZB="+AgentSupport.ZB_VERSION+" privateABI=g_instrumentation candidate="+candidateHash+" hooks="+transformer.lastCounts());
            return true;
        } catch(Throwable error) {
            transformFailed(describe(error));
            if(transformer!=null && inst!=null) inst.removeTransformer(transformer);
            return false;
        }
    }

    private static ReviewedBuild verifyGameBuild(ClassLoader system) throws Exception {
        Class<?> core=Class.forName("zombie.core.Core",true,system);
        Object instance=core.getMethod("getInstance").invoke(null);
        String version=String.valueOf(core.getMethod("getVersionNumber").invoke(instance));
        String build=String.valueOf(core.getMethod("getGameAndBuildVersion").invoke(instance));
        ReviewedBuild reviewed=reviewedBuild(version,build);
        if(reviewed.stockJarSha256()!=null)
            verifyStockSources(system,core,reviewed.stockJarSha256());
        gameBuild=build;
        return reviewed;
    }

    private static ReviewedBuild reviewedBuild(String version,String build) {
        ReviewedBuild reviewed=REVIEWED_BUILDS.get(build);
        if(reviewed==null||!(version.equals(reviewed.version())||version.equals(build)))
            throw new IllegalStateException("Unsupported game version="+version+" build="+build);
        return reviewed;
    }

    private static void verifyStockSources(ClassLoader system,Class<?> core,String expectedHash) throws Exception {
        Path stock=AgentSupport.codeSourceJar(core);
        MessageDigest digest=MessageDigest.getInstance("SHA-256");
        try(DigestInputStream input=new DigestInputStream(Files.newInputStream(stock),digest)) {
            input.transferTo(OutputStream.nullOutputStream());
        }
        String hash=HexFormat.of().formatHex(digest.digest());
        if(!expectedHash.equals(hash))
            throw new IllegalStateException("Unsupported stock game JAR sha256="+hash);
        // A matching Food resource alone cannot establish that its dependencies
        // came from the reviewed stock JAR rather than a classpath overlay.
        for(String name:List.of("zombie.inventory.types.Food","zombie.inventory.InventoryItem",
                "zombie.inventory.ItemContainer","zombie.inventory.types.InventoryContainer",
                "zombie.iso.IsoGridSquare","zombie.GameTime","zombie.SandboxOptions",
                "zombie.SandboxOptions$EnumSandboxOption","zombie.config.EnumConfigOption",
                "zombie.Lua.LuaManager","zombie.scripting.objects.ItemBodyLocation",
                "se.krka.kahlua.vm.KahluaTable","se.krka.kahlua.j2se.J2SEPlatform",
                "se.krka.kahlua.j2se.KahluaTableImpl")) {
            Class<?> dependency=Class.forName(name,false,system);
            if(dependency.getClassLoader()!=system||!stock.equals(AgentSupport.codeSourceJar(dependency)))
                throw new IllegalStateException("Non-stock game dependency: "+name);
        }
    }
    private static void verifyCanonical(Class<?> type,Path candidate) throws Exception {
        if(type.getClassLoader()!=ClassLoader.getSystemClassLoader()
                ||!candidate.equals(AgentSupport.codeSourceJar(type)))
            throw new IllegalStateException("Noncanonical or mixed candidate class: "+type.getName());
    }
    private static void verifyHooks(ClassLoader system,Path candidate) throws Exception {
        Class<?> hooks=Class.forName("suqing.refrigeration.nativebackend.NativeHooks",false,system);
        verifyCanonical(hooks,candidate);
        Class<?> item=Class.forName("zombie.inventory.InventoryItem",false,system);
        Class<?> container=Class.forName("zombie.inventory.ItemContainer",false,system);
        Class<?> food=Class.forName("zombie.inventory.types.Food",false,system);
        requireHook(hooks,"resolveOutermost",container,item);
        requireHook(hooks,"temperature",float.class,container);
        requireHook(hooks,"isFridge",boolean.class,container);
        requireHook(hooks,"isPowered",boolean.class,container);
        requireHook(hooks,"poweredForAge",boolean.class,container);
        requireHook(hooks,"beforeSave",void.class,food);
    }
    private static void requireHook(Class<?> owner,String name,Class<?> result,Class<?>...args) throws Exception {
        requireMethod(owner,name,result,args);
    }
    private static void requireMethod(Class<?> owner,String name,Class<?> result,Class<?>...args) throws Exception {
        Method method=owner.getMethod(name,args);
        if(!Modifier.isStatic(method.getModifiers())||method.getReturnType()!=result)
            throw new IllegalStateException("Unsupported native ABI: "+owner.getSimpleName()+"."+name);
    }
    private static void transformFailed(String reason) {
        state="failed";failure=reason;
        // A JVMTI transformer callback is not necessarily the game thread.
        // Emergency disable may touch flags/cache only, never settle GameFood.
        if(runtime!=null)try{runtime.getMethod("emergencyDisable",String.class).invoke(null,reason);}catch(Throwable secondary){failure+="; emergencyDisable="+describe(secondary);}
        System.out.println("[SuQingRefrigerationNative] fail-closed: "+failure);
    }
    private static String describe(Throwable error) {
        Throwable cause=error instanceof InvocationTargetException ite && ite.getCause()!=null?ite.getCause():error;
        return cause.getClass().getName()+": "+String.valueOf(cause.getMessage());
    }
    public static boolean isInstalled(){return state.equals("installed") && transformer!=null && transformer.lastFailure()==null;}
    public static String lastFailure(){return failure;}
    public static String status(){
        return "{\"api\":"+API_VERSION+",\"modId\":"+AgentSupport.json(MOD_ID)+",\"version\":"+AgentSupport.json(VERSION)
            +",\"gameBuild\":"+AgentSupport.json(gameBuild)+",\"installed\":"+isInstalled()
            +",\"state\":"+AgentSupport.json(state)+",\"failure\":"+AgentSupport.json(failure)
            +",\"candidatePath\":"+AgentSupport.json(candidatePath)+",\"candidateSha256\":"+AgentSupport.json(candidateHash)
            +",\"zombieBuddyPath\":"+AgentSupport.json(zbPath)+",\"zombieBuddyVersion\":"+AgentSupport.json(AgentSupport.ZB_VERSION)
            +",\"zombieBuddySha256\":"+AgentSupport.json(AgentSupport.ZB_SHA256)+",\"privateAbi\":\"Loader.g_instrumentation\""
            +",\"transformApplications\":"+(transformer==null?0:transformer.applications())+"}";
    }
}
