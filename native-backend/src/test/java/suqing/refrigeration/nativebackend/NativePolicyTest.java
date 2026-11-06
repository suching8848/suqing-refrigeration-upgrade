package suqing.refrigeration.nativebackend;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.KahluaTable;

/** Real Kahlua data-only policy tests; no game/world initialization. */
public final class NativePolicyTest {
    private static final J2SEPlatform PLATFORM = new J2SEPlatform();
    private static int checks;

    private static KahluaTable record() {
        KahluaTable table = PLATFORM.newTable();
        table.rawset("schema", 1.0);
        table.rawset("on", true);
        table.rawset("paid", true);
        table.rawset("token", "paid-fixture");
        KahluaTable cells = PLATFORM.newTable();
        for (int i = 1; i <= 6; i++) cells.rawset((double) i, (double) i);
        table.rawset("batteries", cells);
        return table;
    }

    private static void check(boolean value, String name) {
        checks++;
        if (!value) throw new AssertionError(name);
    }

    private static void blocked(String field, Object value) {
        KahluaTable table = record();
        table.rawset(field, value);
        check(!NativeColdEligibility.isPaidCoolingRecord(table), field + " rejects " + value);
    }

    public static void main(String[] arguments) {
        check(!NativeColdEligibility.isPaidCoolingRecord(null), "missing record");
        check(NativeColdEligibility.isPaidCoolingRecord(record()), "legitimate paid on record");
        blocked("schema", 2.0);
        blocked("schema", Integer.valueOf(1)); // Lua number is a Double in this runtime.
        blocked("schema", null);
        blocked("on", false);
        blocked("on", "true");
        blocked("paid", false);
        blocked("paid", 1.0);
        blocked("token", null);
        blocked("token", 17.0);
        blocked("token", "x".repeat(161));
        KahluaTable table = record();
        table.rawset("token", "x".repeat(160));
        check(NativeColdEligibility.isPaidCoolingRecord(table), "160-character token is retained");
        table.rawset("token", "");
        check(NativeColdEligibility.isPaidCoolingRecord(table), "empty token matches existing Core acceptance");
        table.rawset("foreign", "preserve");
        check(NativeColdEligibility.isPaidCoolingRecord(table), "unknown fields do not invalidate or mutate record");
        check("preserve".equals(table.rawget("foreign")), "policy is read-only");
        blocked("batteries", null);
        blocked("batteries", "six");
        for (Object invalid : new Object[] {-1.0, 100001.0, Double.NaN,
                Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY, "1", Integer.valueOf(1), false}) {
            table = record();
            ((KahluaTable) table.rawget("batteries")).rawset(3.0, invalid);
            check(!NativeColdEligibility.isPaidCoolingRecord(table), "invalid battery " + invalid);
        }
        table = record();
        KahluaTable batteries = (KahluaTable) table.rawget("batteries");
        batteries.rawset(1.0, -0.0);
        batteries.rawset(6.0, 100000.0);
        check(NativeColdEligibility.isPaidCoolingRecord(table), "closed numeric endpoints including negative zero");
        batteries.rawset(3.0, null);
        check(!NativeColdEligibility.isPaidCoolingRecord(table), "battery hole fails closed even if Lua length is six");
        table = record();
        ((KahluaTable) table.rawget("batteries")).rawset(7.0, 1.0);
        check(!NativeColdEligibility.isPaidCoolingRecord(table), "seventh indexed cell");
        table = record();
        table.setMetatable(PLATFORM.newTable());
        check(!NativeColdEligibility.isPaidCoolingRecord(table), "record metatable rejected without Lua callbacks");
        table = record();
        ((KahluaTable) table.rawget("batteries")).setMetatable(PLATFORM.newTable());
        check(!NativeColdEligibility.isPaidCoolingRecord(table), "battery metatable rejected without Lua callbacks");
        System.out.println("NATIVE_POLICY checks=" + checks + " PASS");
    }
}
