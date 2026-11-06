import java.io.*;import java.lang.reflect.*;import java.nio.file.*;import java.nio.charset.StandardCharsets;import java.util.*;import java.util.regex.*;
/** Complete installed local registrars in native Lua; UI/event dependencies are controlled, no world/client. */
public final class DisplayFullChainNative {
 static Object env,thread;static Method compile,pcall;static Class<?> table;
 static Object[] execute(Path path)throws Exception{
  String filename=path.toAbsolutePath().toString().replace('\\','/');
  Class<?> state=Class.forName("org.luaj.kahluafork.compiler.FuncState");state.getField("currentFile").set(null,path.getFileName().toString());state.getField("currentfullFile").set(null,filename);
  Object closure=compile.invoke(null,new StringReader(new String(Files.readAllBytes(path),StandardCharsets.UTF_8)),path.getFileName().toString(),env);
  Object[] r=(Object[])pcall.invoke(thread,closure,new Object[0]);if(!Boolean.TRUE.equals(r[0]))throw new IllegalStateException(filename+": "+Arrays.toString(r));return r;
 }
 static Object field(Object obj,String name)throws Exception{return obj.getClass().getMethod("rawget",Object.class).invoke(obj,name);}
 static String source()throws Exception{
  Object pane=field(env,"ISInventoryPane"),fn=field(pane,"renderdetails");Class<?> globals=Class.forName("zombie.Lua.LuaManager$GlobalObject"),closure=Class.forName("se.krka.kahlua.vm.LuaClosure");
  return globals.getMethod("getFilenameOfClosure",closure).invoke(null,fn)+":"+globals.getMethod("getFirstLineOfClosure",closure).invoke(null,fn);
 }
 public static void main(String[] a)throws Exception{
  Class<?> fs=Class.forName("zombie.ZomboidFileSystem");Object files=fs.getField("instance").get(null);fs.getMethod("init").invoke(files);
  for(String n:new String[]{"RandStandard","RandLua"}){Class<?> c=Class.forName("zombie.core.random."+n);c.getMethod("init").invoke(c.getField("INSTANCE").get(null));}
  Class<?> manager=Class.forName("zombie.Lua.LuaManager");manager.getMethod("init").invoke(null);
  ArrayList<String[]> roots=new ArrayList<>();for(String line:Files.readAllLines(Paths.get(a[0]),StandardCharsets.UTF_8)){if(!line.trim().isEmpty())roots.add(line.split("\t",2));}
  ArrayList<String> folders=new ArrayList<>();for(String[] row:roots)folders.add(row[1]);Field mf=fs.getDeclaredField("modFolders");mf.setAccessible(true);mf.set(files,folders);
  Class<?> choose=Class.forName("zombie.gameStates.ChooseGameInfo");for(String[] row:roots){fs.getMethod("setModIdToDir",String.class,String.class).invoke(files,row[0],row[1]);Object mod=choose.getMethod("readModInfo",String.class).invoke(null,row[1]);if(mod==null)throw new IllegalStateException("Native metadata missing: "+row[0]);System.out.println("CHAIN_NATIVE_METADATA\t"+row[0]+"\t"+mod.getClass().getMethod("getModVersion").invoke(mod)+"\t"+mod.getClass().getMethod("getVersionDir").invoke(mod));}
  @SuppressWarnings("unchecked") List<String> ids=(List<String>)fs.getMethod("getModIDs").invoke(files);ids.clear();Matcher m=Pattern.compile("(?m)^\\s*mod\\s*=\\s*([^,\\r\\n]+)").matcher(new String(Files.readAllBytes(Paths.get(a[1])),StandardCharsets.UTF_8));while(m.find())ids.add(m.group(1));System.out.println("CHAIN_NATIVE_ACTIVE_IDS\t"+ids.size());
  env=manager.getField("env").get(null);thread=manager.getField("thread").get(null);table=Class.forName("se.krka.kahlua.vm.KahluaTable");compile=Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler").getMethod("loadis",Reader.class,String.class,table);pcall=thread.getClass().getMethod("pcall",Object.class,Object[].class);
  for(int index=12;index<a.length;index++){
   execute(Paths.get(a[index]));execute(Paths.get(a[2]));execute(Paths.get(a[3]));
   for(int dep=4;dep<=7;dep++)execute(Paths.get(a[dep]));
   Object options=field(env,"CHAIN_OPTIONS");boolean first=Boolean.TRUE.equals(field(options,"displayFirst")),searchFirst=Boolean.TRUE.equals(field(options,"searchFirst"));
   if(first)execute(Paths.get(a[10]));
   execute(Paths.get(a[searchFirst?9:8]));execute(Paths.get(a[searchFirst?8:9]));
   if(!first)execute(Paths.get(a[10]));
   System.out.println("CHAIN_BEFORE_GAMESTART\t"+source());
   Object[] result=execute(Paths.get(a[11]));System.out.println(result[1]);
  }
  Object world=Class.forName("zombie.iso.IsoWorld").getField("instance").get(null);
  if(world!=null){Field cell=world.getClass().getField("currentCell");if(cell.get(world)!=null)throw new IllegalStateException("Unexpected world cell");}
  System.out.println("CHAIN_NATIVE_PASS game_started=false world_loaded=false UI_base=controlled event_bus=controlled complete_registrars=true");
 }
}
