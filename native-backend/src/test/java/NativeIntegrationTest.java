import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.KahluaTable;
import sun.misc.Unsafe;
import suqing.refrigeration.nativebackend.*;
import zombie.GameTime;
import zombie.SandboxOptions;
import zombie.ZomboidFileSystem;
import zombie.Lua.LuaManager;
import zombie.core.Color;
import zombie.core.random.RandLua;
import zombie.core.random.RandStandard;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Food;
import zombie.inventory.types.InventoryContainer;
import zombie.scripting.objects.Item;
import zombie.scripting.objects.ItemBodyLocation;
import zombie.iso.IsoObject;
import zombie.iso.IsoWorld;

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
    private static Food serializableFood(ItemContainer container) throws Exception {
        Food f=food(container,.2f);
        Class<?> owner=InventoryItem.class;
        set(f,owner,"module","Base");
        set(f,owner,"type","Apple");
        set(f,owner,"fullType","Base.Apple");
        set(f,owner,"name","Native regression food");
        set(f,owner,"originalName","Native regression food");
        set(f,owner,"actualWeight",1f);
        set(f,owner,"scriptItem",new Item());
        set(f,owner,"condition",10);
        set(f,owner,"conditionMax",10);
        set(f,owner,"col",Color.white);
        set(f,owner,"colorRed",1f);
        set(f,owner,"colorGreen",1f);
        set(f,owner,"colorBlue",1f);
        set(f,owner,"itemCapacity",-1f);
        set(f,owner,"wetCooldown",-1f);
        set(f,owner,"keyId",-1);
        set(f,owner,"remoteControlId",-1);
        return f;
    }
    private static void readCheckpoint(ByteBuffer bytes,int worldVersion) throws Exception {
        Food restored=serializableFood(null);
        bytes.position(3); // InventoryItem writes the registry ID and save type first.
        restored.load(bytes,worldVersion);
        check(!bytes.hasRemaining(),"complete native Food binary consumed for world version "+worldVersion);
        Object raw=restored.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY);
        check(raw instanceof KahluaTable,"native Food binary contains compatible checkpoint");
        KahluaTable checkpoint=(KahluaTable)raw;
        check(Double.valueOf(1).equals(checkpoint.rawget("schema")),"preserved checkpoint schema");
        near(restored.getAge(),1.2f,"native Food age readback");
        near(((Number)checkpoint.rawget("age")).floatValue(),restored.getAge(),"checkpoint age");
        near(((Number)checkpoint.rawget("time")).floatValue(),restored.getLastAged(),"checkpoint time");
        near(((Number)checkpoint.rawget("heat")).floatValue(),restored.getHeat(),"checkpoint heat");
        check("unchanged".equals(restored.getModData().rawget("ColdFixtureForeign")),"foreign modData retained");
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
        String build=zombie.core.Core.getInstance().getGameAndBuildVersion();
        check(Bootstrap.status().contains("\"gameBuild\":\""+build+"\""),"exact reviewed build reported");
        check(SuQingNativeColdApi.activate(true),"explicit ownership handover");
        Food portable=food(nested.inside,.2f),warm=food(player,1);
        ItemContainer fridge=new ItemContainer();fridge.setType("fridge");fridge.setCustomTemperature(.2f);
        fridge.parent=(PoweredObject)unsafe.allocateInstance(PoweredObject.class);
        Food vanilla=food(fridge,.2f);advance(24);
        Bag inPoweredFridge=bag(fridge,true);
        check(NativeHooks.resolveOutermost(food(inPoweredFridge.inside,.2f))==fridge,
                "native powered fridge takes precedence over portable cooling");
        if(build.equals("42.22.2")){
            Bag cycleA=bag(null,false),cycleB=bag(cycleA.inside,false);
            cycleA.item.setContainer(cycleB.inside);
            Food cyclic=food(cycleA.inside,1);
            check(cyclic.getOutermostContainer()==cycleB.inside,"stock lookup stops on return to initial container");
            check(NativeHooks.resolveOutermost(cyclic)==cycleB.inside,"hook retains the stock cycle result");
            ItemContainer[] chain=new ItemContainer[20];
            chain[19]=player;
            for(int i=18;i>=0;i--)chain[i]=bag(chain[i+1],false).inside;
            Food deeplyNested=food(chain[0],1);
            check(deeplyNested.getOutermostContainer()==chain[16],"stock lookup caps deep nesting at 16 steps");
            check(NativeHooks.resolveOutermost(deeplyNested)==chain[16],"hook retains stock depth result for ordinary bags");
        }
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
        Food saved=serializableFood(cold.inside);advance(24);
        saved.getModData().rawset("ColdFixtureForeign","unchanged");
        ByteBuffer full=ByteBuffer.allocate(65536);
        saved.save(full,false);
        near(saved.getAge(),1.2f,"save entry settles before original serializer");
        check(saved.getModData().rawget(NativeRuntime.FOOD_RECORD_KEY)instanceof KahluaTable,"save entry records compatible state before parent serialization");
        int worldVersion=IsoWorld.class.getField("WorldVersion").getInt(null);
        full.flip();
        if(args.length>0) Files.write(Path.of(args[0]),java.util.Arrays.copyOf(full.array(),full.limit()),java.nio.file.StandardOpenOption.CREATE_NEW);
        readCheckpoint(full,worldVersion);
        if(args.length>1) readCheckpoint(ByteBuffer.wrap(Files.readAllBytes(Path.of(args[1]))),249);
        System.out.println("FOOD_BINARY worldVersion="+worldVersion+" historicalRead="+(args.length>1?"249":"none"));
        // Retransformation must tolerate the JVM's constant-pool normalization.
        AgentSupport.verifiedZombieBuddy().instrumentation().retransformClasses(Food.class);
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
