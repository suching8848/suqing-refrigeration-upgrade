package suqing.refrigeration.nativebackend;

import java.lang.ref.WeakReference;
import java.util.WeakHashMap;
import java.util.ArrayList;
import java.util.List;
import zombie.inventory.ItemContainer;

/** Container-grouped, bounded-lifetime qualification, never a tracked-food loop. */
public final class ColdContainerCache {
    public static final double TTL_GAME_HOURS = 1.0 / 60.0;
    private WeakHashMap<ItemContainer, Entry> entries = new WeakHashMap<>();
    private WeakHashMap<ItemContainer, Boolean> knownCold = new WeakHashMap<>();
    private long generation;
    private double lastTime = Double.NaN;
    private long hits, misses, invalidations, rewinds, validations;

    private static final class Entry {
        final double time, expires;
        final long generation;
        final boolean managed;
        final WeakReference<ItemContainer> target;

        Entry(double time, long generation, ItemContainer cold) {
            this.time = time;
            this.expires = time + TTL_GAME_HOURS;
            this.generation = generation;
            this.managed = cold != null;
            // Even when cold == key, no strong back-reference retains the key.
            this.target = cold == null ? null : new WeakReference<>(cold);
        }
    }

    public record Stats(long generation, long hits, long misses, long invalidations,
                        long rewinds, long validations, int containers, int knownColdContainers) { }

    public synchronized ItemContainer resolve(ItemContainer direct, double time) {
        if (direct == null) return null;
        boolean validTime = Double.isFinite(time) && time >= 0.0;
        if (validTime && Double.isFinite(lastTime) && time < lastTime) {
            invalidateInternal();
            rewinds++;
        }
        if (validTime) lastTime = time;
        Entry entry = validTime ? entries.get(direct) : null;
        if (entry != null && entry.generation == generation
                && time >= entry.time && time < entry.expires) {
            ItemContainer cold = entry.managed ? entry.target.get() : null;
            if (!entry.managed || cold != null) {
                hits++;
                return cold;
            }
        }
        misses++;
        validations++;
        ItemContainer cold = NativeColdEligibility.nearestColdContainer(direct);
        if (cold != null) knownCold.put(cold, Boolean.TRUE);
        if (validTime) entries.put(direct, new Entry(time, generation, cold));
        return cold;
    }

    public synchronized void invalidate() { invalidateInternal(); }

    /** A boundary-only strong snapshot, never retained by an entry or scanned per tick. */
    public synchronized List<ItemContainer> knownColdSnapshot() {
        return new ArrayList<>(knownCold.keySet());
    }

    public synchronized void clearKnown() { knownCold = new WeakHashMap<>(); }

    private void invalidateInternal() {
        generation++;
        // O(1) invalidation: do not walk containers, foods, or stored entries.
        entries = new WeakHashMap<>();
        lastTime = Double.NaN;
        invalidations++;
    }

    public synchronized Stats stats() {
        return new Stats(generation, hits, misses, invalidations, rewinds, validations, entries.size(), knownCold.size());
    }
}
