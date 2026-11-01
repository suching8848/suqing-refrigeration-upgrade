import java.lang.reflect.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
public class NativeCraftingAudit {
 static int checks;
 static void check(boolean v,String label){checks++;if(!v)throw new AssertionError(label);}
 static Field field(Class<?> c,String n)throws Exception{while(c!=null){try{Field f=c.getDeclaredField(n);f.setAccessible(true);return f;}catch(NoSuchFieldException e){c=c.getSuperclass();}}throw new NoSuchFieldException(n);}
 public static void main(String[] args)throws Exception{
  Class<?> parser=Class.forName("zombie.scripting.ScriptParser");
  Object root=parser.getMethod("parse",String.class).invoke(null,new String(Files.readAllBytes(Paths.get(args[0])),StandardCharsets.UTF_8));
  Class<?> block=root.getClass();Class<?> recipeClass=Class.forName("zombie.scripting.entity.components.crafting.CraftRecipe");
  Class<?> moduleClass=Class.forName("zombie.scripting.objects.ScriptModule");Class<?> inputClass=Class.forName("zombie.scripting.entity.components.crafting.InputScript");
  int count=0;
  for(Object mb:(List<?>)block.getField("children").get(root)){
   check("SuQingRefrigeration".equals(block.getField("id").get(mb)),"own module");
   for(Object rb:(List<?>)block.getField("children").get(mb)){
    if(!"craftRecipe".equals(block.getField("type").get(rb)))continue;
    count++;String name=(String)block.getField("id").get(rb);
    Object recipe=recipeClass.getConstructor().newInstance();Object module=moduleClass.getConstructor().newInstance();
    moduleClass.getField("name").set(module,"SuQingRefrigeration");recipeClass.getMethod("setModule",moduleClass).invoke(recipe,module);
    field(recipeClass,"scriptObjectName").set(recipe,name);recipeClass.getMethod("Load",String.class,block).invoke(recipe,name,rb);
    check("SuQingRefrigeration".equals(recipeClass.getMethod("getCategory").invoke(recipe)),"dedicated native category");
    boolean install=name.equals("InstallCooling");check(install||name.equals("RemoveCooling"),"only install and remove");
    List<?> inputs=(List<?>)recipeClass.getMethod("getInputs").invoke(recipe);check(inputs.size()==(install?5:1),"native input row count");
    float[] amounts={1,6,4,4,2};String[] ids={"Base.Bag_Schoolbag","Base.Battery","Base.ElectricWire","Base.ElectronicsScrap","Base.SmallSheetMetal"};
    for(int i=0;i<inputs.size();i++){
     Object input=inputs.get(i);
     check(((Float)inputClass.getMethod("getAmount").invoke(input))==amounts[i],"amount "+i);
     check((Boolean)inputClass.getMethod("isItemCount").invoke(input),"object counts including batteries "+i);
     check(((List<?>)inputClass.getMethod("getItems").invoke(input)).contains(ids[i]),"exact source item "+i);
     check((Boolean)inputClass.getMethod(i==0?"isKeep":"isDestroy").invoke(input),"keep target and consume materials "+i);
    }
    Object target=inputs.get(0);
    List raw=(List)inputClass.getMethod("getItems").invoke(target);
    List cache=(List)inputClass.getMethod("getPossibleInputItems").invoke(target);
    check(cache!=null,"resolved script cache available");
    raw.clear();raw.add("OtherMod.NewWearable");cache.clear();cache.add(Class.forName("zombie.scripting.objects.Item").getConstructor().newInstance());
    check(raw.size()==1&&cache.size()==1,"native ID and resolved caches accept dynamic candidates");
   }
  }
  check(count==2,"exactly two native recipes");
  System.out.println("NATIVE_CRAFTING assertions="+checks+" failures=0");
 }
}
