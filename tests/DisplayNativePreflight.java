import java.io.*;import java.lang.reflect.*;import java.nio.file.*;import java.nio.charset.StandardCharsets;import java.util.*;import java.util.regex.*;
/** Native metadata/source gate only; no save/world load or renderer execution. */
public final class DisplayNativePreflight {
 static Class<?> table;static Object env,thread;static Method compile,pcall;
 static Object[] execute(String source,String filename)throws Exception{
  Class<?> state=Class.forName("org.luaj.kahluafork.compiler.FuncState");state.getField("currentFile").set(null,Paths.get(filename).getFileName().toString());state.getField("currentfullFile").set(null,filename.replace('\\','/'));
  Object closure=compile.invoke(null,new StringReader(source),Paths.get(filename).getFileName().toString(),env);Object[] r=(Object[])pcall.invoke(thread,closure,new Object[0]);if(!Boolean.TRUE.equals(r[0]))throw new IllegalStateException(filename+": "+Arrays.toString(r));return r;
 }
 static Object get(Object o,String key)throws Exception{return o.getClass().getMethod(key).invoke(o);}
 public static void main(String[] a)throws Exception{
  Class<?> fs=Class.forName("zombie.ZomboidFileSystem");Object files=fs.getField("instance").get(null);fs.getMethod("init").invoke(files);
  for(String n:new String[]{"RandStandard","RandLua"}){Class<?> c=Class.forName("zombie.core.random."+n);c.getMethod("init").invoke(c.getField("INSTANCE").get(null));}
  Class<?> manager=Class.forName("zombie.Lua.LuaManager");manager.getMethod("init").invoke(null);
  ArrayList<String> roots=new ArrayList<>();for(int i=6;i<a.length;i+=2)roots.add(a[i+1]);Field mf=fs.getDeclaredField("modFolders");mf.setAccessible(true);mf.set(files,roots);
  Class<?> choose=Class.forName("zombie.gameStates.ChooseGameInfo");for(int i=6;i<a.length;i+=2){fs.getMethod("setModIdToDir",String.class,String.class).invoke(files,a[i],a[i+1]);Object mod=choose.getMethod("readModInfo",String.class).invoke(null,a[i+1]);if(mod==null)throw new IllegalStateException("Native metadata missing: "+a[i]);System.out.println("NATIVE_METADATA\t"+get(mod,"getId")+"\t"+get(mod,"getModVersion")+"\t"+get(mod,"getVersionDir"));}
  List<String> ids=(List<String>)fs.getMethod("getModIDs").invoke(files);ids.clear();String saved=new String(Files.readAllBytes(Paths.get(a[3])),StandardCharsets.UTF_8);Matcher m=Pattern.compile("(?m)^\\s*mod\\s*=\\s*([^,\\r\\n]+)").matcher(saved);while(m.find())ids.add(m.group(1));System.out.println("NATIVE_ACTIVE_IDS\t"+ids.size()+"\tfrom saved mods.txt copied in memory only");
  env=manager.getField("env").get(null);thread=manager.getField("thread").get(null);table=Class.forName("se.krka.kahlua.vm.KahluaTable");Class<?> compiler=Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler");compile=compiler.getMethod("loadis",Reader.class,String.class,table);pcall=thread.getClass().getMethod("pcall",Object.class,Object[].class);
  Object renderer=execute(new String(Files.readAllBytes(Paths.get(a[1])),StandardCharsets.UTF_8),a[2])[1];table.getMethod("rawset",Object.class,Object.class).invoke(env,"ProbeRenderer",renderer);
  Class<?> closure=Class.forName("se.krka.kahlua.vm.LuaClosure"),globals=Class.forName("zombie.Lua.LuaManager$GlobalObject");Object filename=globals.getMethod("getFilenameOfClosure",closure).invoke(null,renderer);System.out.println("NATIVE_RENDER_FILENAME\t"+filename);if(!a[2].replace('\\','/').equals(filename))throw new IllegalStateException("Closure source mismatch");
  execute(new String(Files.readAllBytes(Paths.get(a[4])),StandardCharsets.UTF_8),a[4]);execute(new String(Files.readAllBytes(Paths.get(a[0])),StandardCharsets.UTF_8),a[0]);Object[] r=execute(new String(Files.readAllBytes(Paths.get(a[5])),StandardCharsets.UTF_8),a[5]);System.out.println("PREFLIGHT_RESULT\t"+r[1]);System.out.println("PASS native gate preflight only; renderer body compiled but never called. No world/save/gameplay API invoked.");
 }
}