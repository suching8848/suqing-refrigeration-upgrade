package suqing.refrigeration.nativebackend;

import java.lang.ref.WeakReference;
import java.lang.reflect.Field;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.KahluaTable;
import sun.misc.Unsafe;
import zombie.GameTime;
import zombie.ZomboidFileSystem;
import zombie.Lua.LuaManager;
import zombie.core.random.RandLua;
import zombie.core.random.RandStandard;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.inventory.types.InventoryContainer;
import zombie.iso.IsoObject;
import zombie.scripting.objects.ItemBodyLocation;

/** Native ownership objects/policy, with no World, Cell, player or game launch. */
public final class NativeContainerPolicyTest {
    private static final J2SEPlatform PLATFORM = new J2SEPlatform();
    private static final Unsafe UNSAFE;
    private static int checks;
    static {
        try {
            Field f = Unsafe.class.getDeclaredField("theUnsafe");
            f.setAccessible(true); UNSAFE = (Unsafe) f.get(null);
        } catch (ReflectiveOperationException e) { throw new ExceptionInInitializerError(e); }
    }
    private static void check(boolean value, String name) {
        checks++; if (!value) throw new AssertionError(name);
    }
    private static void field(Object object, Class<?> owner, String name, Object value) throws Exception {
        Field field = owner.getDeclaredField(name); field.setAccessible(true); field.set(object, value);
    }
    private static KahluaTable paid() {
        KahluaTable r = PLATFORM.newTable(), cells = PLATFORM.newTable();
        r.rawset("schema", 1.0);r.rawset("paid", true);r.rawset("on", true);r.rawset("token", "native-fixture");
        for (int i=1;i<=6;i++) cells.rawset((double)i, (double)i);
        r.rawset("batteries", cells);return r;
    }
    private record Bag(InventoryContainer item, ItemContainer inside, KahluaTable record) { }
    private static Bag bag(ItemContainer parent, boolean cold) throws Exception {
        InventoryContainer item = (InventoryContainer) UNSAFE.allocateInstance(InventoryContainer.class);
        ItemContainer inside = new ItemContainer(); inside.setType("bag"); inside.containingItem = item;
        item.setItemContainer(inside);item.setCanBeEquipped(ItemBodyLocation.BACK);item.setContainer(parent);
        KahluaTable md = PLATFORM.newTable(), record = paid();
        if (cold) md.rawset(NativeColdEligibility.RECORD_KEY, record);
        field(item, InventoryItem.class, "table", md);
        if (parent != null) parent.items.add(item);
        return new Bag(item, inside, record);
    }
    public static class PoweredObject extends IsoObject {
        boolean powered;
        @Override public int getObjectIndex() { return 0; }
        @Override public boolean checkObjectPowered() { return powered; }
    }
    private static Food food(ItemContainer container) throws Exception {
        Food food=(Food)UNSAFE.allocateInstance(Food.class);
        food.setContainer(container);food.setAge(2.0f);food.setHeat(0.2f);food.setLastAged(5.0f);
        food.setOffAge(5);food.setOffAgeMax(10);
        if(container!=null)container.items.add(food);
        return food;
    }
    private static void move(InventoryItem item,ItemContainer target){
        if(item.getContainer()!=null)item.getContainer().items.remove(item);
        item.setContainer(target);if(target!=null)target.items.add(item);
    }
    private static WeakReference<ItemContainer> ghost(ColdContainerCache cache) throws Exception {
        Bag bag=bag(null,true);cache.resolve(bag.inside,200);return new WeakReference<>(bag.inside);
    }
    public static void main(String[] args) throws Exception {
        ZomboidFileSystem.instance.init();RandStandard.INSTANCE.init();RandLua.INSTANCE.init();LuaManager.init();
        LuaManager.platform=PLATFORM;
        GameTime time=new GameTime();GameTime.setInstance(time);time.setTimeOfDay(12.0f);
        ItemContainer root=new ItemContainer();root.setType("inventory");root.setCustomTemperature(0.2f);
        Bag cold=bag(root,true), nested=bag(cold.inside,false);
        check(NativeColdEligibility.isEligibleBag(cold.item),"real native paid wearable bag");
        ColdContainerCache cache=new ColdContainerCache();
        check(cache.resolve(nested.inside,100)==cold.inside,"nearest enclosing cold bag through nested container");
        check(cache.resolve(nested.inside,100.001)==cold.inside,"positive cache hit");
        check(cache.stats().validations()==1,"one qualification per container window");
        cold.record.rawset("on",false);
        check(cache.resolve(nested.inside,100.002)==cold.inside,"unknown bypass mutation bounded by TTL");
        check(cache.resolve(nested.inside,100+ColdContainerCache.TTL_GAME_HOURS)==null,"exact TTL revalidates off state");
        cold.record.rawset("on",true);
        check(cache.resolve(nested.inside,100.017)==null,"negative results cached too");
        cache.invalidate();check(cache.resolve(nested.inside,100.017)==cold.inside,"known mutation immediately invalidates");
        cold.record.rawset("on",false);check(cache.resolve(nested.inside,99)==null,"clock rewind revalidates");
        check(cache.stats().rewinds()==1,"rewind recorded");
        cold.record.rawset("on",true);long before=cache.stats().validations();
        check(cache.resolve(nested.inside,Double.NaN)==cold.inside,"invalid time strict qualification");
        check(cache.resolve(nested.inside,Double.NaN)==cold.inside && cache.stats().validations()==before+2,"invalid time is not memoized");
        cache.invalidate();check(cache.knownColdSnapshot().contains(cold.inside),"known cold roots survive classification invalidation");

        Food food=food(nested.inside);
        NativeRuntime.initialize();check(!NativeRuntime.isActive(),"initialize stays inactive");
        check(NativeHooks.resolveOutermost(food)==root,"inactive exact native outer");
        check(NativeRuntime.activate(true),"activate owns");
        check(NativeHooks.resolveOutermost(food)==cold.inside,"managed food resolves nearest cold bag");
        check(NativeHooks.temperature(nested.inside)==0.2f,"nested direct temperature is cold too");
        check(NativeHooks.isFridge(cold.inside)&&NativeHooks.isPowered(cold.inside)&&NativeHooks.poweredForAge(cold.inside),"portable native fridge and power adapters");
        InventoryItem ordinary=(InventoryItem)UNSAFE.allocateInstance(InventoryItem.class);ordinary.setContainer(nested.inside);
        check(NativeHooks.resolveOutermost(ordinary)==root,"non-Food returns original outer");
        NativeRuntime.invalidate();time.setTimeOfDay(time.getTimeOfDay()+1);NativeRuntime.flushKnown();
        check(food.getLastAged()==(float)time.getWorldAgeHours(),"boundary flush traverses known root after invalidation");
        NativeRuntime.setCoolingEnabled(false);
        check(NativeRuntime.isActive()&&!NativeRuntime.isCoolingEnabled(),"master off retains Java ownership");
        check(NativeHooks.resolveOutermost(food)==root&&NativeHooks.temperature(nested.inside)==1.0f,"master off helpers preserve vanilla");
        NativeRuntime.setCoolingEnabled(true);

        ItemContainer fridge=new ItemContainer();fridge.setType("fridge");
        PoweredObject power=(PoweredObject)UNSAFE.allocateInstance(PoweredObject.class);power.powered=true;fridge.parent=power;
        move(cold.item,fridge);NativeRuntime.invalidate();
        check(NativeHooks.resolveOutermost(food)==fridge,"effective native fridge has priority");
        fridge.setType("freezer");check(NativeHooks.resolveOutermost(food)==fridge,"effective native freezer has priority");
        power.powered=false;check(NativeHooks.resolveOutermost(food)==cold.inside,"unpowered native environment does not defeat paid cold bag");
        move(cold.item,root);NativeRuntime.invalidate();

        food.setAge(2.0f);NativeHooks.beforeSave(food);
        Object saved=food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY);
        check(saved instanceof KahluaTable,"cold save writes compatibility checkpoint");
        KahluaTable checkpoint=(KahluaTable)saved;
        check(Double.valueOf((double)food.getLastAged()).equals(checkpoint.rawget("time"))&&Double.valueOf(2.0).equals(checkpoint.rawget("age")),"checkpoint uses exact native lastAged and age");
        check(Double.valueOf((double)0.2f).equals(checkpoint.rawget("heat")),"checkpoint preserves physical float as double");
        NativeHooks.beforeSave(food);check(food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)!=saved,"save replaces owned table only at save");
        KahluaTable unknown=PLATFORM.newTable();unknown.rawset("schema",99.0);food.getModData().rawset(NativeRuntime.FOOD_RECORD_KEY,unknown);
        NativeHooks.beforeSave(food);check(food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)==unknown,"unknown schema preserved cold");
        move(food,root);NativeRuntime.invalidate();NativeHooks.beforeSave(food);
        check(food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)==unknown,"unknown schema preserved warm");
        unknown.rawset("schema",1.0);NativeHooks.beforeSave(food);check(food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)==null,"warm food clears only owned checkpoint");
        move(food,nested.inside);NativeRuntime.invalidate();
        Field savingField=NativeRuntime.class.getDeclaredField("SAVING");savingField.setAccessible(true);
        @SuppressWarnings("unchecked") ThreadLocal<java.util.IdentityHashMap<Food,Boolean>> saving=(ThreadLocal<java.util.IdentityHashMap<Food,Boolean>>)savingField.get(null);
        food.setLastAged((float)time.getWorldAgeHours()-0.5f);float priorTime=food.getLastAged();
        saving.get().put(food,true);NativeHooks.beforeSave(food);saving.get().remove(food);
        check(food.getLastAged()==priorTime,"reentrant-save branch snapshots without recursively aging");
        food.setLastAged((float)time.getWorldAgeHours());
        LuaManager.platform=null;boolean failed=false;try{NativeHooks.beforeSave(food);}catch(NullPointerException expected){failed=true;}
        finally{LuaManager.platform=PLATFORM;}
        check(failed,"save propagates checkpoint writing failure");NativeHooks.beforeSave(food);
        check(food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)instanceof KahluaTable,"save guard recovers after failure");
        check(NativeRuntime.initialize()&&NativeRuntime.isActive(),"repeated initialize does not drop owner");
        move(food,root);NativeRuntime.invalidate();NativeRuntime.settle(food);
        check(food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)==null,"warm boundary clears owned ledger without a save");
        move(food,nested.inside);NativeRuntime.invalidate();NativeRuntime.settle(food);
        check(food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)instanceof KahluaTable,"warm-to-cold boundary anchors current native state without a save");
        move(food,root);NativeRuntime.invalidate();float coldAge=food.getAge();time.setTimeOfDay(time.getTimeOfDay()+1);
        NativeRuntime.settle(food);float warmAge=food.getAge();
        check(warmAge>coldAge&&food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)==null,"cold-to-warm boundary preserves native warm growth and removes stale cap");
        NativeRuntime.emergencyDisable("unsaved_transition_fixture");
        check(food.getAge()==warmAge&&food.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)==null,"API failure before any save cannot reapply stale cold ledger");
        NativeRuntime.initialize();NativeRuntime.activate(true);move(food,nested.inside);NativeHooks.resolveOutermost(food);
        java.util.ArrayList<InventoryItem> retained=cold.inside.items;cold.inside.items=null;
        float beforeStop=food.getLastAged();time.setTimeOfDay(time.getTimeOfDay()+1);
        NativeRuntime.shutdown();cold.inside.items=retained;
        check(!NativeRuntime.isActive()&&!NativeRuntime.isReady()&&food.getLastAged()==beforeStop,"shutdown does not traverse stale containers or age food");
        NativeRuntime.initialize();NativeRuntime.activate(true);NativeHooks.resolveOutermost(food);
        cold.inside.items=null;NativeRuntime.emergencyDisable("transform_failed:fixture");cold.inside.items=retained;
        check(!NativeRuntime.isActive()&&!NativeRuntime.isReady()&&food.getLastAged()==beforeStop,"emergency disable is metadata-only and safe after teardown");
        check(NativeRuntime.status().contains("transform_failed:fixture"),"emergency reason exposed without callbacks");

        ColdContainerCache weak=new ColdContainerCache();WeakReference<ItemContainer> key=ghost(weak);
        for(int i=0;i<30&&key.get()!=null;i++){System.gc();Thread.sleep(10);}
        check(key.get()==null,"neither entry value nor known-root set retains its weak key");
        System.out.println("NATIVE_CONTAINER_POLICY checks="+checks+" PASS");
        System.out.println("NATIVE_RUNTIME_STATUS "+NativeRuntime.status());
    }
}
