package suqing.refrigeration.nativebackend;

import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.j2se.KahluaTableImpl;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.InventoryContainer;

/** Read-only qualification of the main mod's already-paid container record. */
public final class NativeColdEligibility {
    public static final String RECORD_KEY = "SuQingRefrigeration";
    private static final int MAX_ANCESTORS = 64;
    private static volatile String lastRejectionReason = "none";

    private NativeColdEligibility() { }

    /** No Lua invocation, callback, type mutation, or new ModData is performed. */
    public static boolean isEligibleBag(InventoryItem item) {
        if (!(item instanceof InventoryContainer bag) || bag.getInventory() == null) return false;
        Object slot = bag.canBeEquipped();
        if (slot == null) return false;
        String name = slot.toString();
        if (name.isEmpty() || "null".equals(name) || !bag.hasModData()) return false;
        KahluaTable data = bag.getModData();
        if (!plainTable(data)) {
            lastRejectionReason = "moddata_metatable_or_table_class";
            return false;
        }
        Object record = data.rawget(RECORD_KEY);
        if (record == null) return false;
        String reason = record instanceof KahluaTable table ? recordRejectionReason(table) : "record_type";
        if (reason != null) lastRejectionReason = reason;
        return reason == null;
    }

    /**
     * Native mode accepts serialized plain records. Unknown metatable-backed
     * behavior and malformed battery holes fail closed rather than invoke Lua.
     */
    public static boolean isPaidCoolingRecord(KahluaTable record) {
        return recordRejectionReason(record) == null;
    }

    public static String lastRejectionReason() { return lastRejectionReason; }

    /** null means eligible; all rejection diagnostics are fixed strings. */
    public static String recordRejectionReason(KahluaTable record) {
        if (record == null) return "missing_record";
        if (!plainTable(record)) return "record_metatable_or_table_class";
        if (!luaNumberEquals(record.rawget("schema"), 1.0)) return "record_schema";
        if (!Boolean.TRUE.equals(record.rawget("on"))) return "record_off_or_invalid_on";
        if (!Boolean.TRUE.equals(record.rawget("paid"))) return "record_unpaid";
        Object token = record.rawget("token");
        if (!(token instanceof String text) || text.length() > 160) return "record_token";
        Object value = record.rawget("batteries");
        if (!(value instanceof KahluaTable batteries)) return "battery_table";
        if (!plainTable(batteries)) return "battery_metatable_or_table_class";
        if (batteries.len() != 6) return "battery_count";
        for (int i = 1; i <= 6; i++) {
            Object battery = batteries.rawget((double) i);
            if (!(battery instanceof Double number) || !Double.isFinite(number)
                    || number < 0.0 || number > 100000.0) return "battery_value";
        }
        return null;
    }

    private static boolean luaNumberEquals(Object value, double expected) {
        return value instanceof Double number && number == expected;
    }

    static boolean plainTable(KahluaTable table) {
        return table != null && table.getClass() == KahluaTableImpl.class && table.getMetatable() == null;
    }

    /** Nearest eligible ancestor, without retaining the chain or allocating a seen set. */
    static ItemContainer nearestColdContainer(ItemContainer direct) {
        ItemContainer current = direct;
        for (int depth = 0; current != null && depth < MAX_ANCESTORS; depth++) {
            InventoryItem owner = current.getContainingItem();
            if (owner == null) return null;
            if (owner instanceof InventoryContainer bag && bag.getInventory() == current
                    && isEligibleBag(bag)) return current;
            ItemContainer next = owner.getContainer();
            if (next == current) return null;
            current = next;
        }
        return null;
    }

    /** Preserve a genuinely powered native fridge/freezer before portable entitlement. */
    static boolean hasEffectiveNativeCold(ItemContainer original) {
        return original != null && (original.isFridge() || original.isFreezer()) && original.isPowered();
    }
}
