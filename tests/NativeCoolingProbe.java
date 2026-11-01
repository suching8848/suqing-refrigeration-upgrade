import java.lang.reflect.*;
import sun.misc.Unsafe;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
public class NativeCoolingProbe {
 static Field field(Class<?> c,String n)throws Exception {while(c!=null){try{Field f=c.getDeclaredField(n);f.setAccessible(true);return f;}catch(NoSuchFieldException e){c=c.getSuperclass();}}throw new NoSuchFieldException(n);}
 static void set(Object o,String n,Object v)throws Exception {field(o.getClass(),n).set(o,v);}
 public static void main(String[] args)throws Exception {
  Field uf=Unsafe.class.getDeclaredField("theUnsafe");uf.setAccessible(true);Unsafe u=(Unsafe)uf.get(null);
  Class<?> fs=Class.forName("zombie.ZomboidFileSystem");fs.getMethod("init").invoke(fs.getField("instance").get(null));
  for(String n:new String[]{"RandStandard","RandLua"}) {Class<?> rc=Class.forName("zombie.core.random."+n);Object rr=rc.getField("INSTANCE").get(null);rc.getMethod("init").invoke(rr);}
  Class.forName("zombie.Lua.LuaManager").getMethod("init").invoke(null);
  Class<?> gt=Class.forName("zombie.GameTime");Object time=gt.getConstructor().newInstance();gt.getMethod("setInstance",gt).invoke(null,time);
  Class<?> fc=Class.forName("zombie.inventory.types.Food");Object food=u.allocateInstance(fc);
  set(food,"offAge",5);set(food,"offAgeMax",10);set(food,"age",1f);set(food,"lastAged",0f);set(food,"heat",1f);
  set(time,"timeOfDay",12f);
  double now=(Double)gt.getMethod("getWorldAgeHours").invoke(time);
  fc.getMethod("updateAge",boolean.class).invoke(food,false);
  System.out.println("NATIVE_PROBE now="+now+" age="+fc.getMethod("getAge").invoke(food)+" last="+fc.getMethod("getLastAged").invoke(food));
  if(args.length>0){
   Class<?> lm=Class.forName("zombie.Lua.LuaManager");Object env=lm.getField("env").get(null);Object thread=lm.getField("thread").get(null);
   Class<?> table=Class.forName("se.krka.kahlua.vm.KahluaTable");Method put=table.getMethod("rawset",Object.class,Object.class);
   put.invoke(env,"ProbeFood",food);put.invoke(env,"ProbeTime",time);
   Class<?> ic=Class.forName("zombie.inventory.ItemContainer");Object fridge=ic.getConstructor().newInstance();set(fridge,"type","fridge");put.invoke(env,"ProbeFridge",fridge);
   Class<?> so=Class.forName("zombie.SandboxOptions");Object options=so.getField("instance").get(null);
   Object shut=field(so,"elecShutModifier").get(options);shut.getClass().getMethod("setValue",int.class).invoke(shut,99999);
   Class<?> comp=Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler");
   Method compile=comp.getMethod("loadstring",String.class,String.class,table);
   Method pcall=thread.getClass().getMethod("pcall",Object.class,Object[].class);
   for(String file:args){String source=new String(Files.readAllBytes(Paths.get(file)),StandardCharsets.UTF_8);Object closure=compile.invoke(null,source,file,env);Object[] r=(Object[])pcall.invoke(thread,closure,new Object[0]);System.out.println(file+": "+java.util.Arrays.toString(r));if(!Boolean.TRUE.equals(r[0]))throw new AssertionError("Lua native probe failed");}
  }
 }
}
