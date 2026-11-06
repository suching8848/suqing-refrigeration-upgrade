import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.KahluaTable;
import sun.misc.Unsafe;
import suqing.refrigeration.nativebackend.*;
import zombie.GameTime;
import zombie.SandboxOptions;
import zombie.ZomboidFileSystem;
import zombie.Lua.LuaManager;
import zombie.core.random.RandLua;
import zombie.core.random.RandStandard;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.inventory.types.InventoryContainer;
import zombie.scripting.objects.ItemBodyLocation;
import zombie.iso.IsoObject;

/** Native Food execution + live retransformation, with no World/Cell/player/game. */
public final class NativeIntegrationTest {
    private static final J2SEPlatform PLATFORM=new J2SEPlatform();
    private static Unsafe unsafe;
    private static GameTime time;
    private static int assertions;
    private record Bag(InventoryContainer item,ItemContainer inside,KahluaTable record) { }
    public static final class PoweredObject extends IsoObject {
        @Override public int getObjectIndex(){return 0;}
        @Override public boolean checkObjectPowered(){return true;}
    }
    private static void check(boolean value,String name) {
        assertions++;if(!value)throw new AssertionError(name);
    }
    private static void near(float actual,float expected,String name) {
        check(Math.abs(actual-expected)<0.00002f,name+": actual="+actual+" expected="+expected);
    }
    private static void set(Object target,Class<?> owner,String name,Object value)throws Exception {
        Field f=owner.getDeclaredField(name);f.setAccessible(true);f.set(target,value);
    }
    private static float now(){return(float)time.getWorldAgeHours();}
    private static void advance(float hours){time.setTimeOfDay(time.getTimeOfDay()+hours);}
    private static ItemContainer root(){ItemContainer c=new ItemContainer();c.setType("inventory");return c;}
    private static Bag bag(ItemContainer parent,boolean cold)throws Exception {
        InventoryContainer item=(InventoryContainer)unsafe.allocateInstance(InventoryContainer.class);
        ItemContainer inside=new ItemContainer();inside.setType("bag");inside.containingItem=item;
        item.setItemContainer(inside);item.setCanBeEquipped(ItemBodyLocation.BACK);item.setContainer(parent);
        KahluaTable md=PLATFORM.newTable(),r=PLATFORM.newTable(),batteries=PLATFORM.newTable();
        r.rawset("schema",1.0);r.rawset("paid",true);r.rawset("on",true);r.rawset("token","offline-integration");
        for(int i=1;i<=6;i++)batteries.rawset((double)i,75.0);
        r.rawset("batteries",batteries);if(cold)md.rawset("SuQingRefrigeration",r);
        set(item,InventoryItem.class,"table",md);if(parent!=null)parent.items.add(item);
        return new Bag(item,inside,r);
    }
    private static Food food(ItemContainer container,float heat)throws Exception {
        Food f=(Food)unsafe.allocateInstance(Food.class);f.setContainer(container);
        f.setAge(1);f.setOffAge(1000);f.setOffAgeMax(2000);f.setHeat(heat);f.setLastAged(now());
        set(f,Food.class,"lastFrozenUpdate",now());
        if(container!=null)container.items.add(f);return f;
    }
    private static void move(InventoryItem item,ItemContainer destination){
        if(item.getContainer()!=null)item.getContainer().items.remove(item);
        item.setContainer(destination);if(destination!=null)destination.items.add(item);
    }
    public static void main(String[] args)throws Exception {
        Field u=Unsafe.class.getDeclaredField("theUnsafe");u.setAccessible(true);unsafe=(Unsafe)u.get(null);
        ZomboidFileSystem.instance.init();RandStandard.INSTANCE.init();RandLua.INSTANCE.init();LuaManager.init();
        LuaManager.platform=PLATFORM;time=new GameTime();GameTime.setInstance(time);time.setTimeOfDay(12);
        SandboxOptions.instance.elecShutModifier.setValue(99999);
        SandboxOptions.instance.fridgeFactor.setValue(3);SandboxOptions.instance.foodRotSpeed.setValue(3);
        ItemContainer player=root();Bag cold=bag(player,true),nested=bag(cold.inside,false);
        Food legacy=food(cold.inside,1);advance(24);legacy.updateAge(false);near(legacy.getAge(),2,"inactive is exact native warm aging");
        check(!SuQingNativeColdApi.isActive()&&!SuQingNativeColdApi.isReady(),"discovery cannot activate");
        check(!SuQingNativeColdApi.bootstrap("old"),"old Lua version refused before transformation");
        // Food was deliberately loaded and executed above. This therefore tests
        // actual retransformation, bytecode verification and canonical linkage.
        check(SuQingNativeColdApi.bootstrap(SuQingNativeColdApi.BASE_VERSION),"production bootstrap installs");
        check(SuQingNativeColdApi.isReady()&&!SuQingNativeColdApi.isActive(),"install remains inactive");
        check(Bootstrap.status().contains("\"transformApplications\":1"),"exactly one initial retransform");
        check(SuQingNativeColdApi.activate(true),"explicit ownership handover");
        Food portable=food(nested.inside,.2f),warm=food(player,1);
        ItemContainer fridge=new ItemContainer();fridge.setType("fridge");fridge.setCustomTemperature(.2f);
        fridge.parent=(PoweredObject)unsafe.allocateInstance(PoweredObject.class);
        Food vanilla=food(fridge,.2f);advance(24);
        portable.updateAge(false);vanilla.updateAge(false);warm.updateAge(false);
        near(portable.getAge(),vanilla.getAge(),"native bag equals actual vanilla fridge formula");
        near(portable.getAge(),1.2f,"native fridge factor applied once");near(warm.getAge(),2,"ordinary items retain native aging");
        check(!portable.hasModData(),"ordinary native age call allocates no Lua food ledger");
        Food coolingA=food(cold.inside,1),coolingB=food(fridge,1);
        var temperature=Food.class.getDeclaredMethod("updateTemperature");temperature.setAccessible(true);
        for(int i=0;i<100;i++){
            set(coolingA,Food.class,"temperatureTimeAccum",10.0f);set(coolingB,Food.class,"temperatureTimeAccum",10.0f);
            temperature.invoke(coolingA);temperature.invoke(coolingB);
            near(coolingA.getHeat(),coolingB.getHeat(),"native temperature transition parity "+i);
        }
        near(coolingA.getHeat(),.2f,"native temperature reaches refrigerator minimum");
        SandboxOptions.instance.daysForRottenFoodRemoval.setValue(-1);
        check(coolingA.finishupdate()==coolingB.finishupdate()&&coolingA.finishupdate(),"cold non-cookable can leave native per-frame processor like fridge food");
        set(coolingA,InventoryItem.class,"isCookable",true);
        check(!coolingA.finishupdate(),"native cookable scheduling remains intact");
        Food thawA=food(cold.inside,.2f),thawB=food(fridge,.2f);
        thawA.setCanBeFrozen(true);thawB.setCanBeFrozen(true);thawA.setFreezingTime(100);thawB.setFreezingTime(100);
        check(thawA.isThawing()&&thawB.isThawing()&&!thawA.isFreezing(),"cold bag is refrigerator, never a freezer");
        advance(.5f);thawA.updateAge(false);thawB.updateAge(false);
        near(thawA.getFreezingTime(),thawB.getFreezingTime(),"native powered-fridge thawing parity");
        for(int fridgeSetting=1;fridgeSetting<=6;fridgeSetting++)for(int rotSetting=1;rotSetting<=5;rotSetting++){
            SandboxOptions.instance.fridgeFactor.setValue(fridgeSetting);SandboxOptions.instance.foodRotSpeed.setValue(rotSetting);
            Food a=food(cold.inside,.2f),b=food(fridge,.2f);advance(24);a.updateAge(false);b.updateAge(false);
            near(a.getAge(),b.getAge(),"native sandbox parity "+fridgeSetting+"/"+rotSetting);
            near(a.getAge(),1+NativeRuntime.fridgeFactor()*NativeRuntime.foodRotSpeed(),"exact native factor "+fridgeSetting+"/"+rotSetting);
            check(!a.hasModData(),"no per-update compatibility table "+fridgeSetting+"/"+rotSetting);
        }
        SandboxOptions.instance.fridgeFactor.setValue(3);SandboxOptions.instance.foodRotSpeed.setValue(3);
        Food ground=food(cold.inside,.2f);move(cold.item,null);NativeRuntime.invalidate();advance(24);ground.updateAge(false);
        near(ground.getAge(),1.2f,"whole cold bag stays cold on ground");
        move(cold.item,player);NativeRuntime.invalidate();NativeRuntime.settle(ground);
        check(ground.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)instanceof KahluaTable,"explicit boundary writes fallback checkpoint");
        KahluaTable table=ground.getModData();ByteBuffer bytes=ByteBuffer.allocate(4096);table.save(bytes);bytes.flip();
        KahluaTable restored=PLATFORM.newTable();restored.load(bytes,222);
        check(restored.rawget(NativeRuntime.FOOD_RECORD_KEY)instanceof KahluaTable,"native table binary roundtrip preserves checkpoint");
        move(ground,player);NativeRuntime.invalidate();NativeRuntime.settle(ground);
        check(ground.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)==null,"transfer clears stale cold ledger before any save");
        advance(24);ground.updateAge(false);near(ground.getAge(),2.2f,"transferred food gets warm native rate");
        move(ground,cold.inside);NativeRuntime.invalidate();NativeRuntime.settle(ground);
        float age=ground.getAge();advance(24);NativeRuntime.setCoolingEnabled(false);
        near(ground.getAge(),age+.2f,"master change flushes prior cold interval");
        check(SuQingNativeColdApi.isActive(),"master off keeps exclusive native owner");
        advance(24);ground.updateAge(false);near(ground.getAge(),age+1.2f,"master off uses vanilla warm rate");
        NativeRuntime.setCoolingEnabled(true);NativeRuntime.invalidate();
        Food saved=food(cold.inside,.2f);advance(24);
        try{saved.save(null,false);}catch(NullPointerException expected){ }
        near(saved.getAge(),1.2f,"save entry settles before original serializer");
        check(saved.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)instanceof KahluaTable,"save entry records compatible state before parent serialization");
        // Retransformation must tolerate the JVM's constant-pool normalization.
        OfflineInstrumentation.instrumentation.retransformClasses(Food.class);
        check(Bootstrap.isInstalled(),"normalized repeat retransformation stays installed");
        Food after=food(cold.inside,.2f);advance(24);after.updateAge(false);near(after.getAge(),1.2f,"retransform has exactly one effective hook layer");
        check(!SuQingNativeColdApi.activate(false)&&!SuQingNativeColdApi.isActive(),"deactivation confirms single owner stopped");
        Food stopped=food(cold.inside,1);advance(24);stopped.updateAge(false);near(stopped.getAge(),2,"disabled transformed bytecode delegates vanilla");
        SuQingNativeColdApi.shutdown();check(!SuQingNativeColdApi.isReady(),"shutdown clears readiness without world operations");
        check(SuQingNativeColdApi.bootstrap(SuQingNativeColdApi.BASE_VERSION),"same JVM next session reinitializes installed inactive runtime");
        check(SuQingNativeColdApi.isReady()&&!SuQingNativeColdApi.isActive(),"next-session bootstrap does not activate ownership");
        check(SuQingNativeColdApi.activate(true),"next session accepts a fresh explicit ownership handover");
        SuQingNativeColdApi.shutdown();
        check(zombie.iso.IsoWorld.instance.getCell()==null,"test creates no World Cell");
        System.out.println("NATIVE_INTEGRATION assertions="+assertions+" PASS");
        System.out.println("NATIVE_INTEGRATION_STATUS "+SuQingNativeColdApi.status());
    }
}
