package suqing.refrigeration.nativebackend;

import java.util.IdentityHashMap;
import java.util.concurrent.atomic.AtomicLong;
import se.krka.kahlua.vm.KahluaTable;
import zombie.GameTime;
import zombie.SandboxOptions;
import zombie.Lua.LuaManager;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.inventory.types.InventoryContainer;

/** Canonical system-loader state. Initialization deliberately starts inactive. */
public final class NativeRuntime {
    public static final int API_VERSION = 1;
    public static final String MOD_ID = "SuQingRefrigerationNative_4221";
    public static final String FOOD_RECORD_KEY = "SuQingRefrigerationFood";
    private static final ColdContainerCache CACHE = new ColdContainerCache();
    private static final ThreadLocal<IdentityHashMap<Food, Boolean>> SETTLING = ThreadLocal.withInitial(IdentityHashMap::new);
    private static final ThreadLocal<IdentityHashMap<Food, Boolean>> SAVING = ThreadLocal.withInitial(IdentityHashMap::new);
    private static volatile boolean ready;
    private static volatile boolean active;
    private static volatile boolean masterEnabled = true;
    private static volatile String lastFailure = "none";
    private static volatile long failures;
    private static final AtomicLong SETTLES = new AtomicLong(), FLUSHES = new AtomicLong();
    private static final AtomicLong CHECKPOINTS = new AtomicLong(), WARM_CLEARS = new AtomicLong();
    private static final AtomicLong UNKNOWN_CHECKPOINTS = new AtomicLong(), INVALID_CHECKPOINTS = new AtomicLong();

    private NativeRuntime() { }

    public static synchronized boolean initialize() {
        if (!ready) {
            active = false;
            masterEnabled = true;
            CACHE.invalidate();
            CACHE.clearKnown();
            lastFailure = "none";
            ready = true;
        }
        return true;
    }

    public static boolean isReady() { return ready; }
    public static boolean isActive() { return ready && active; }
    public static boolean isCoolingEnabled() { return isActive() && masterEnabled; }

    public static float fridgeFactor() {
        return switch (SandboxOptions.instance.fridgeFactor.getValue()) {
            case 1 -> 0.4f; case 2 -> 0.3f; case 4 -> 0.1f;
            case 5 -> 0.03f; case 6 -> 0.0f; default -> 0.2f;
        };
    }

    public static float foodRotSpeed() {
        return switch (SandboxOptions.instance.foodRotSpeed.getValue()) {
            case 1 -> 1.7f; case 2 -> 1.4f; case 4 -> 0.7f;
            case 5 -> 0.4f; default -> 1.0f;
        };
    }

    /** Caller must separately verify successful Bootstrap installation. */
    public static synchronized boolean activate(boolean enabled) {
        if (enabled && !ready) return false;
        if (active != enabled) {
            if (isActive()) flushKnown();
            active = enabled;
            CACHE.invalidate();
        }
        return isActive();
    }

    public static synchronized void setCoolingEnabled(boolean enabled) {
        if (masterEnabled != enabled) {
            if (isActive()) flushKnown();
            masterEnabled = enabled;
            CACHE.invalidate();
        }
    }

    public static void invalidate() { CACHE.invalidate(); }

    public static synchronized void shutdown() {
        active = false;
        ready = false;
        CACHE.invalidate();
        CACHE.clearKnown();
    }

    /** May run on a transformer thread: never traverses or mutates any Food. */
    public static synchronized void emergencyDisable(String reason) {
        active = false;
        ready = false;
        String message = reason == null ? "emergency_disable" : reason;
        if (message.length() > 160) message = message.substring(0, 160);
        lastFailure = message.replaceAll("[^A-Za-z0-9_.:-]", "_");
        CACHE.invalidate();
        CACHE.clearKnown();
    }

    static ItemContainer coldContainer(ItemContainer direct) {
        if (!isCoolingEnabled() || direct == null) return null;
        try {
            GameTime clock = GameTime.getInstance();
            double now = clock == null ? Double.NaN : clock.getWorldAgeHours();
            ItemContainer result = CACHE.resolve(direct, now);
            return isCoolingEnabled() ? result : null;
        } catch (RuntimeException error) {
            // Qualification failure grants no portable entitlement. Vanilla
            // operations outside qualification retain their original failures.
            recordFailure(error);
            return null;
        }
    }

    /** Explicit state/transfer/save boundary; there is no tracked-food tick. */
    public static void settle(Food food) {
        settleInternal(food, true);
    }

    private static void settleInternal(Food food, boolean checkpoint) {
        if (!isActive() || food == null) return;
        IdentityHashMap<Food, Boolean> pending = SETTLING.get();
        if (pending.containsKey(food)) return;
        pending.put(food, Boolean.TRUE);
        try {
            food.updateAge(false);
            SETTLES.incrementAndGet();
            if (checkpoint) checkpointCurrent(food);
        } finally { pending.remove(food); }
    }

    public static void flushKnown() {
        if (!isActive()) return;
        FLUSHES.incrementAndGet();
        IdentityHashMap<ItemContainer, Boolean> seen = new IdentityHashMap<>();
        RuntimeException first = null;
        for (ItemContainer container : CACHE.knownColdSnapshot()) {
            try { flushContainer(container, seen, 0); }
            catch (RuntimeException failure) { if (first == null) first = failure; }
        }
        if (first != null) throw new IllegalStateException("Native cold boundary flush failed", first);
    }

    private static void flushContainer(ItemContainer container,
            IdentityHashMap<ItemContainer, Boolean> seen, int depth) {
        if (container == null || depth > 64 || seen.put(container, Boolean.TRUE) != null) return;
        InventoryItem[] items = container.getItems().toArray(new InventoryItem[0]);
        RuntimeException first = null;
        for (InventoryItem item : items) {
            try {
                if (item instanceof Food food) settle(food);
                if (item instanceof InventoryContainer bag) flushContainer(bag.getInventory(), seen, depth + 1);
            } catch (RuntimeException failure) { if (first == null) first = failure; }
        }
        if (first != null) throw first;
    }

    static void beforeSave(Food food) {
        if (!isActive() || food == null) return;
        IdentityHashMap<Food, Boolean> pending = SAVING.get();
        if (pending.containsKey(food)) {
            // A native freshness callback runs after age/lastAged assignment.
            // Snapshot those values without recursively aging the same Food.
            checkpointCurrent(food);
            return;
        }
        pending.put(food, Boolean.TRUE);
        try {
            if (coldContainer(food.getContainer()) != null) settleInternal(food, false);
            checkpointCurrent(food);
        } finally { pending.remove(food); }
    }

    private static void checkpointCurrent(Food food) {
        boolean managed = coldContainer(food.getContainer()) != null;
        if (!managed && !food.hasModData()) return;
        KahluaTable data = food.getModData();
        if (!NativeColdEligibility.plainTable(data)) {
            UNKNOWN_CHECKPOINTS.incrementAndGet();
            return;
        }
        Object previous = data.rawget(FOOD_RECORD_KEY);
        if (previous != null && !ownedCheckpoint(previous)) {
            UNKNOWN_CHECKPOINTS.incrementAndGet();
            return;
        }
        if (!managed) {
            if (previous != null) { data.rawset(FOOD_RECORD_KEY, null); WARM_CLEARS.incrementAndGet(); }
            return;
        }
        float time = food.getLastAged(), age = food.getAge(), heat = food.getHeat();
        if (!Float.isFinite(time) || time < 0 || !Float.isFinite(age) || age < 0 || !Float.isFinite(heat)) {
            INVALID_CHECKPOINTS.incrementAndGet();
            return;
        }
        KahluaTable checkpoint = LuaManager.platform.newTable();
        checkpoint.rawset("schema", 1.0);
        checkpoint.rawset("time", (double) time);
        checkpoint.rawset("age", (double) age);
        checkpoint.rawset("heat", (double) heat);
        data.rawset(FOOD_RECORD_KEY, checkpoint);
        CHECKPOINTS.incrementAndGet();
    }

    private static boolean ownedCheckpoint(Object value) {
        if (!(value instanceof KahluaTable table) || !NativeColdEligibility.plainTable(table)) return false;
        Object schema = table.rawget("schema");
        return schema instanceof Double number && number == 1.0;
    }

    private static synchronized void recordFailure(RuntimeException error) {
        failures++;
        lastFailure = error.getClass().getName();
    }

    public static String status() {
        ColdContainerCache.Stats s = CACHE.stats();
        return "{\"api\":" + API_VERSION + ",\"modId\":\"" + MOD_ID
                + "\",\"ready\":" + ready + ",\"active\":" + isActive()
                + ",\"coolingEnabled\":" + masterEnabled + ",\"effectiveCooling\":" + isCoolingEnabled()
                + ",\"generation\":" + s.generation() + ",\"cacheHits\":" + s.hits()
                + ",\"cacheMisses\":" + s.misses() + ",\"invalidations\":" + s.invalidations()
                + ",\"rewinds\":" + s.rewinds() + ",\"validations\":" + s.validations()
                + ",\"containers\":" + s.containers() + ",\"settles\":" + SETTLES.get()
                + ",\"knownColdContainers\":" + s.knownColdContainers()
                + ",\"flushes\":" + FLUSHES.get() + ",\"checkpoints\":" + CHECKPOINTS.get()
                + ",\"warmClears\":" + WARM_CLEARS.get() + ",\"unknownCheckpoints\":" + UNKNOWN_CHECKPOINTS.get()
                + ",\"invalidCheckpoints\":" + INVALID_CHECKPOINTS.get() + ",\"failures\":" + failures
                + ",\"lastRejectionReason\":\"" + NativeColdEligibility.lastRejectionReason() + "\""
                + ",\"lastFailure\":\"" + lastFailure + "\"}";
    }
}
