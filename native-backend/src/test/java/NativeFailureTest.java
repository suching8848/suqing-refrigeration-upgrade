import java.lang.instrument.ClassFileTransformer;
import java.security.ProtectionDomain;
import net.bytebuddy.jar.asm.ClassReader;
import net.bytebuddy.jar.asm.ClassWriter;
import net.bytebuddy.jar.asm.ClassVisitor;
import net.bytebuddy.jar.asm.MethodVisitor;
import net.bytebuddy.jar.asm.Opcodes;
import suqing.refrigeration.nativebackend.*;
import zombie.inventory.types.Food;

/** Real retransform failure paths, separate JVM from the positive test. */
public final class NativeFailureTest {
    private static int assertions;
    private static void check(boolean value,String name){assertions++;if(!value)throw new AssertionError(name);}
    private static final class ForeignFood implements ClassFileTransformer {
        boolean enabled;int changes;
        public byte[] transform(ClassLoader loader,String name,Class<?> type,ProtectionDomain domain,byte[] data){
            if(!enabled||!"zombie/inventory/types/Food".equals(name))return null;
            ClassReader reader=new ClassReader(data);ClassWriter writer=new ClassWriter(reader,0);
            reader.accept(new ClassVisitor(Opcodes.ASM9,writer){
                public MethodVisitor visitMethod(int access,String method,String desc,String signature,String[] exceptions){
                    MethodVisitor next=super.visitMethod(access,method,desc,signature,exceptions);
                    if(!"updateAge".equals(method)||!"(Z)V".equals(desc))return next;
                    return new MethodVisitor(Opcodes.ASM9,next){
                        public void visitLdcInsn(Object value){
                            if(value instanceof Double d&&d==24.0){value=25.0;changes++;}
                            super.visitLdcInsn(value);
                        }
                    };
                }
            },0);return writer.toByteArray();
        }
    }
    public static void main(String[]args)throws Exception {
        String mode=args[0];
        if(mode.equals("missing-handle")){
            check(!SuQingNativeColdApi.bootstrap(SuQingNativeColdApi.BASE_VERSION),"missing ZB instrumentation refuses takeover");
            check(!SuQingNativeColdApi.isReady()&&!SuQingNativeColdApi.isActive(),"missing handle remains inactive");
            check(SuQingNativeColdApi.status().contains("instrumentation is unavailable"),"reason is inspectable");
        } else {
            ForeignFood foreign=new ForeignFood();foreign.enabled=mode.equals("initial-conflict");
            OfflineInstrumentation.instrumentation.addTransformer(foreign,true);
            boolean installed=SuQingNativeColdApi.bootstrap(SuQingNativeColdApi.BASE_VERSION);
            if(mode.equals("initial-conflict")){
                check(!installed,"modified target rejects initial installation");
            } else {
                check(installed&&SuQingNativeColdApi.activate(true),"clean reviewed target initially active");
                foreign.enabled=true;OfflineInstrumentation.instrumentation.retransformClasses(Food.class);
            }
            check(foreign.changes>0,"foreign target method really changed in JVM");
            check(!Bootstrap.isInstalled()&&!SuQingNativeColdApi.isReady()&&!SuQingNativeColdApi.isActive(),"unknown target fails closed in canonical state");
            check(Bootstrap.status().contains("failed"),"canonical failure retained");
            check(!SuQingNativeColdApi.bootstrap(SuQingNativeColdApi.BASE_VERSION),"failed installation cannot retry in same JVM");
        }
        System.out.println("NATIVE_FAILURE mode="+mode+" assertions="+assertions+" PASS");
    }
}
