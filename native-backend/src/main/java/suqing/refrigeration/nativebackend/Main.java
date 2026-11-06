package suqing.refrigeration.nativebackend;

/** ZombieBuddy discovery entry point. Loading alone never installs or activates. */
public final class Main {
    private Main() { }
    public static void main(String[] args) {
        System.out.println("[SuQingRefrigerationNative] 0.1.0-rc.1 discovered; waiting for compatible Lua handover; no automatic activation");
    }
}
