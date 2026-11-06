package suqing.refrigeration.nativebackend;

import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;

/** Callsite-only Food adapters; calls to original classes cannot recurse here. */
public final class NativeHooks {
    private NativeHooks() { }

    public static ItemContainer resolveOutermost(InventoryItem item) {
        // Read the exact vanilla value first, even while inactive/non-Food.
        ItemContainer original = item.getOutermostContainer();
        if (!NativeRuntime.isCoolingEnabled() || !(item instanceof Food)
                || NativeColdEligibility.hasEffectiveNativeCold(original)) return original;
        ItemContainer cold = NativeRuntime.coldContainer(item.getContainer());
        return cold == null ? original : cold;
    }

    public static float temperature(ItemContainer container) {
        return NativeRuntime.coldContainer(container) == null ? container.getTemperature() : 0.2f;
    }

    public static boolean isFridge(ItemContainer container) {
        return container != null && (NativeRuntime.coldContainer(container) != null || container.isFridge());
    }

    public static boolean isPowered(ItemContainer container) {
        return container != null && (NativeRuntime.coldContainer(container) != null || container.isPowered());
    }

    public static boolean poweredForAge(ItemContainer container) {
        return container != null && (NativeRuntime.coldContainer(container) != null
                || (container.getSourceGrid() != null && container.getSourceGrid().haveElectricity()));
    }

    /** Injected only at Food.save entry, before the parent serializes ModData. */
    public static void beforeSave(Food food) { NativeRuntime.beforeSave(food); }
}
