import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import me.zed_0xff.zombie_buddy.Exposer;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import sun.misc.Unsafe;
import suqing.refrigeration.nativebackend.SuQingNativeColdApi;
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

/** TEST ONLY: real ZB exposure/API and Lua handshake, no game/World/Cell/player/UI. */
public final class NativeLuaIntegrationTest {
    private static void set(Object o,Class<?> owner,String name,Object value)throws Exception {
        Field f=owner.getDeclaredField(name);f.setAccessible(true);f.set(o,value);
    }
    public static void main(String[] args)throws Exception {
        Field field=Unsafe.class.getDeclaredField("theUnsafe");field.setAccessible(true);
        Unsafe unsafe=(Unsafe)field.get(null);
        ZomboidFileSystem.instance.init();RandStandard.INSTANCE.init();RandLua.INSTANCE.init();LuaManager.init();
        GameTime time=new GameTime();GameTime.setInstance(time);time.setTimeOfDay(12);
        SandboxOptions.instance.elecShutModifier.setValue(99999);
        SandboxOptions.instance.fridgeFactor.setValue(3);SandboxOptions.instance.foodRotSpeed.setValue(3);
        // Complete real native ownership objects; no player or loaded world.
        ItemContainer root=new ItemContainer();root.setType("inventory");
        InventoryContainer bag=(InventoryContainer)unsafe.allocateInstance(InventoryContainer.class);
        ItemContainer inner=new ItemContainer();inner.setType("bag");inner.containingItem=bag;
        bag.setItemContainer(inner);bag.setCanBeEquipped(ItemBodyLocation.BACK);bag.setContainer(root);root.items.add(bag);
        KahluaTable md=LuaManager.platform.newTable(),record=LuaManager.platform.newTable(),batteries=LuaManager.platform.newTable();
        record.rawset("schema",1.0);record.rawset("paid",true);record.rawset("on",true);record.rawset("token","native-lua-host");
        for(int n=1;n<=6;n++)batteries.rawset((double)n,75.0);
        record.rawset("batteries",batteries);md.rawset("SuQingRefrigeration",record);set(bag,InventoryItem.class,"table",md);
        Food food=(Food)unsafe.allocateInstance(Food.class);food.setContainer(inner);inner.items.add(food);
        food.setAge(1);food.setOffAge(1000);food.setOffAgeMax(2000);food.setHeat(1);food.setLastAged((float)time.getWorldAgeHours());
        set(food,Food.class,"lastFrozenUpdate",(float)time.getWorldAgeHours());
        LuaManager.env.rawset("ProbeFood",food);LuaManager.env.rawset("ProbeTime",time);
        LuaManager.env.rawset("ProbeAdvance",(JavaFunction)(frame,count)->{
            time.setTimeOfDay(time.getTimeOfDay()+((Number)frame.get(0)).floatValue());return 0;
        });
        if(SuQingNativeColdApi.isActive()||SuQingNativeColdApi.isReady())throw new AssertionError("API loaded active before handover");
        // Actual installed ZB2.3.4 annotation exposure, not a fabricated table.
        Exposer.exposeClass(SuQingNativeColdApi.class);
        if(LuaManager.env.rawget("SuQingNativeColdApi")==null)
            throw new AssertionError("EXPOSER_API_MISSING: real ZB did not retain the API global");
        for(String file:args){
            String source=Files.readString(Path.of(file),StandardCharsets.UTF_8);
            Object closure=LuaCompiler.loadstring(source,file,LuaManager.env);
            Object[] result=LuaManager.thread.pcall(closure,new Object[0]);
            System.out.println(file+": "+Arrays.toString(result));
            if(!Boolean.TRUE.equals(result[0]))throw new AssertionError("Native Lua integration failed: "+Arrays.toString(result));
        }
        if(SuQingNativeColdApi.isActive())throw new AssertionError("Lua menu shutdown left native active");
    }
}
