package suqing.refrigeration.nativebackend;

import java.lang.instrument.ClassFileTransformer;
import java.security.MessageDigest;
import java.security.ProtectionDomain;
import java.util.*;
import java.util.function.Consumer;
import net.bytebuddy.jar.asm.*;

/** A narrow, instruction-verified adapter. It never replaces Food's age algorithm. */
public final class FoodTransformer implements ClassFileTransformer {
    public static final String FOOD = "zombie/inventory/types/Food";
    public static final String HOOKS = "suqing/refrigeration/nativebackend/NativeHooks";
    public static final String EXPECTED_FOOD_SHA256 = "14a5b02878a5608e3a28d3e91110961b3576694badf127dc7fe2749b8393d8b1";
    public static final int EXPECTED_MAJOR = 69;
    private static final String CONTAINER = "zombie/inventory/ItemContainer";
    private static final String ITEM = "zombie/inventory/InventoryItem";
    private static final String SQUARE = "zombie/iso/IsoGridSquare";
    private static final Set<String> TARGETS = Set.of(
        "update()V", "shouldPlayCookingSound()Z", "updateTemperature()V",
        "updateAge(Z)V", "setAutoAge()V", "updateFreezing(L"+CONTAINER+";F)V",
        "finishupdate()Z", "isFreezing()Z", "isThawing()Z", "isInFridge(L"+CONTAINER+";)Z",
        "save(Ljava/nio/ByteBuffer;Z)V");

    // Captured from the current 42.21.0 method instructions. Constant-pool order,
    // debug information and StackMap encoding are deliberately not hashed.
    private static final Map<String,String> EXPECTED = Map.ofEntries(
        Map.entry("update()V", "e8e1c921e082495059e3d4dae3379b52d1e89e4bda54fc4948abda66e5314357"),
        Map.entry("shouldPlayCookingSound()Z", "fe0c1b7185ebfdb173eef4bd8c503055161109d43be09f0f88bf5e2e2e94a695"),
        Map.entry("updateTemperature()V", "6a9dacef1ef6e5862fa6808c88ad2a1a0378da5b1dadd36c7bb7249e964981d8"),
        Map.entry("updateAge(Z)V", "ff63f419a801cd76313c458337aea450224eacc42dad7c61c443171d9c33899d"),
        Map.entry("setAutoAge()V", "474360bbbef083493aa24db7f039e82c118602dad18236c01e31221195c9f309"),
        Map.entry("updateFreezing(L"+CONTAINER+";F)V", "06832b89f4d202826375038332a10870111ff4205cde8a62af1ffcb52de7436b"),
        Map.entry("finishupdate()Z", "507c5a4448b16b37a92015eb0fab4afe1c8af3e1ef32249fe6199086cf268756"),
        Map.entry("isFreezing()Z", "1a0b58a0be4abe9539a7da3a8f07c1a3bbddb6b5148bf8dbf458c333f0f24e44"),
        Map.entry("isThawing()Z", "7f1aa03b41b6aa0456e6f025222f6dd3ab8f4198265e02ee22cc579848547eb2"),
        Map.entry("isInFridge(L"+CONTAINER+";)Z", "aea22e27c8b0af969306f6d188d2146bfcc4451d99b83e3bac0bc2fb2e505636"),
        Map.entry("save(Ljava/nio/ByteBuffer;Z)V", "c808a478ec3e4581f96085e719d09035dab6e99ad8f2b7d1e9db3f88bd098047"));

    private final Consumer<String> failure;
    private volatile String lastFailure;
    private volatile Map<String,Integer> lastCounts = Map.of();
    private volatile long applications;

    public FoodTransformer(Consumer<String> failure) { this.failure = Objects.requireNonNull(failure); }
    public String lastFailure() { return lastFailure; }
    public long applications() { return applications; }
    public Map<String,Integer> lastCounts() { return lastCounts; }

    @Override public byte[] transform(Module module, ClassLoader loader, String name,
            Class<?> redefined, ProtectionDomain domain, byte[] input) {
        if (!FOOD.equals(name)) return null;
        try {
            if (loader != ClassLoader.getSystemClassLoader())
                throw new IllegalStateException("Food is not owned by the system loader");
            Rewrite result = rewrite(input);
            lastCounts = result.counts();
            applications++;
            return result.bytes();
        } catch (Throwable error) {
            lastFailure = error.getClass().getSimpleName()+": "+String.valueOf(error.getMessage());
            failure.accept(lastFailure);
            return null;
        }
    }

    public record Rewrite(byte[] bytes, Map<String,Integer> counts,
                          Map<String,String> originalMethodHashes) { }

    /** Pure class-file operation for offline audits; does not load a game class. */
    public static Rewrite rewrite(byte[] input) {
        Scan scan = scan(input);
        for (String key : TARGETS) {
            MethodCode code = scan.methods.get(key);
            if (code == null) throw new IllegalArgumentException("Missing reviewed Food method: "+key);
            int expectedAccess=key.startsWith("shouldPlayCookingSound(")||key.startsWith("updateTemperature(")
                    ||key.startsWith("updateFreezing(")||key.startsWith("isInFridge(") ? Opcodes.ACC_PRIVATE : Opcodes.ACC_PUBLIC;
            if(code.access!=expectedAccess) throw new IllegalArgumentException("Unreviewed Food method access: "+key+" flags="+code.access);
            String expected = EXPECTED.get(key);
            if (!Objects.equals(expected, code.hash()))
                throw new IllegalArgumentException("Unreviewed Food method: "+key+" sha256="+code.hash());
        }
        Map<String,Plan> plans = new HashMap<>();
        Map<String,Integer> counts = new TreeMap<>();
        for (String key : TARGETS) plans.put(key, plan(key, scan.methods.get(key), counts));
        Map<String,Integer> required = Map.of("resolveOutermost",7,"temperature",11,
                "isPowered",3,"isFridge",1,"poweredForAge",1,"beforeSave",1);
        if (!counts.equals(required)) throw new IllegalArgumentException("Unexpected reviewed call counts: "+counts);
        ClassReader reader = new ClassReader(input);
        // All replacements have the same stack types/widths. The shortened
        // power condition removes an edge but introduces no new frame/local.
        // Retaining the original frames avoids resolving/loading game classes.
        ClassWriter writer = new ClassWriter(reader,0);
        reader.accept(new ClassVisitor(Opcodes.ASM9,writer) {
            @Override public MethodVisitor visitMethod(int access,String name,String desc,String signature,String[] exceptions) {
                MethodVisitor delegate = super.visitMethod(access,name,desc,signature,exceptions);
                Plan p = plans.get(name+desc);
                return p == null ? delegate : new Rewriter(delegate,p);
            }
        },0);
        byte[] output = writer.toByteArray();
        Scan checked = scan(output);
        for (String key : TARGETS) {
            MethodCode before = scan.methods.get(key), after = checked.methods.get(key);
            if (!after.hash().equals(expectedTransformed(before,plans.get(key))))
                throw new IllegalStateException("Post-transform instruction audit failed: "+key);
        }
        // Other methods' executable instructions must be bytecode-equivalent.
        for (var entry : scan.methods.entrySet()) {
            if (!TARGETS.contains(entry.getKey()) && !entry.getValue().hash().equals(checked.methods.get(entry.getKey()).hash()))
                throw new IllegalStateException("Unrelated method changed: "+entry.getKey());
        }
        return new Rewrite(output,Map.copyOf(counts),fingerprints(input));
    }

    /** Diagnostic only. A returned hash does not authorize an unknown method. */
    public static Map<String,String> fingerprints(byte[] input) {
        Scan scan = scan(input);
        Map<String,String> result = new TreeMap<>();
        for (String key : TARGETS) {
            MethodCode code = scan.methods.get(key);
            if (code != null) result.put(key,code.hash());
        }
        return Collections.unmodifiableMap(result);
    }

    private static Plan plan(String key,MethodCode code,Map<String,Integer> counts) {
        Plan p = new Plan();
        for (int i=0;i<code.ops.size();i++) {
            Op op = code.ops.get(i);
            if (op.kind != Kind.METHOD || op.opcode != Opcodes.INVOKEVIRTUAL) continue;
            String hook=null,desc=null;
            if ((op.owner.equals(FOOD)||op.owner.equals(ITEM)) && op.name.equals("getOutermostContainer") && op.desc.equals("()L"+CONTAINER+";")) {
                hook="resolveOutermost"; desc="(L"+ITEM+";)L"+CONTAINER+";";
            } else if (op.owner.equals(CONTAINER) && op.name.equals("getTemperature") && op.desc.equals("()F")) {
                hook="temperature";desc="(L"+CONTAINER+";)F";
            } else if (op.owner.equals(CONTAINER) && op.name.equals("isFridge") && op.desc.equals("()Z")) {
                hook="isFridge";desc="(L"+CONTAINER+";)Z";
            } else if (op.owner.equals(CONTAINER) && op.name.equals("isPowered") && op.desc.equals("()Z")) {
                hook="isPowered";desc="(L"+CONTAINER+";)Z";
            }
            if (hook!=null) { p.calls.put(i,new Hook(hook,desc)); counts.merge(hook,1,Integer::sum); }
        }
        if (key.equals("updateAge(Z)V")) {
            int found=0;
            for (int i=0;i+6<code.ops.size();i++) {
                Op a=code.ops.get(i),b=code.ops.get(i+1),c=code.ops.get(i+2),d=code.ops.get(i+3),
                   e=code.ops.get(i+4),f=code.ops.get(i+5),g=code.ops.get(i+6);
                if (a.isVar(Opcodes.ALOAD,3) && b.isCall(CONTAINER,"getSourceGrid","()L"+SQUARE+";")
                        && c.kind==Kind.JUMP && c.opcode==Opcodes.IFNULL && d.isVar(Opcodes.ALOAD,3)
                        && e.isCall(CONTAINER,"getSourceGrid","()L"+SQUARE+";")
                        && f.isCall(SQUARE,"haveElectricity","()Z") && g.kind==Kind.JUMP
                        && g.opcode==Opcodes.IFEQ && c.label==g.label) {
                    int target=code.position(c.label);
                    if (target<=i+6) throw new IllegalArgumentException("Power fallback target is not after condition");
                    for (int label : code.branchTargets())
                        if (label>i && label<=i+6) throw new IllegalArgumentException("Branch enters removed power condition");
                    for (int pos : code.framePositions)
                        if (pos>i && pos<=i+6) throw new IllegalArgumentException("Frame inside removed power condition");
                    if (!code.catches.isEmpty()) throw new IllegalArgumentException("Unexpected updateAge exception handlers");
                    p.calls.put(i+1,new Hook("poweredForAge","(L"+CONTAINER+";)Z"));
                    p.jumpChanges.put(i+2,Opcodes.IFEQ);
                    for (int skip=i+3;skip<=i+6;skip++) p.skips.add(skip);
                    counts.merge("poweredForAge",1,Integer::sum);
                    found++;
                }
            }
            if (found!=1) throw new IllegalArgumentException("Expected exactly one complete native age power condition; found "+found);
        }
        if (key.equals("save(Ljava/nio/ByteBuffer;Z)V")) {
            if(code.ops.size()<4 || !code.ops.get(0).isVar(Opcodes.ALOAD,0)
                    || !code.ops.get(1).isVar(Opcodes.ALOAD,1) || !code.ops.get(2).isVar(Opcodes.ILOAD,2))
                throw new IllegalArgumentException("Unexpected save entry operands");
            Op call=code.ops.get(3);
            if(call.kind!=Kind.METHOD || call.opcode!=Opcodes.INVOKESPECIAL || !call.owner.equals(ITEM)
                    || !call.name.equals("save") || !call.desc.equals("(Ljava/nio/ByteBuffer;Z)V"))
                throw new IllegalArgumentException("Food.save no longer begins with InventoryItem.save");
            p.beforeSave=true;counts.merge("beforeSave",1,Integer::sum);
        }
        return p;
    }

    private static String expectedTransformed(MethodCode original,Plan plan) {
        MethodCode expected = new MethodCode();
        if(plan.beforeSave) {
            Op receiver=new Op(Kind.VAR,Opcodes.ALOAD);receiver.var=0;expected.ops.add(receiver);
            expected.ops.add(Op.method(Opcodes.INVOKESTATIC,HOOKS,"beforeSave","(L"+FOOD+";)V",false));
        }
        int[] positions = new int[original.ops.size()+1];
        for (int i=0;i<original.ops.size();i++) {
            positions[i]=expected.ops.size();
            if (plan.skips.contains(i)) continue;
            Op op=original.ops.get(i);
            Hook hook=plan.calls.get(i);
            if (hook!=null) op=Op.method(Opcodes.INVOKESTATIC,HOOKS,hook.name,hook.desc,false);
            else if (plan.jumpChanges.containsKey(i)) op=Op.jump(plan.jumpChanges.get(i),op.label);
            expected.ops.add(op);
        }
        positions[original.ops.size()]=expected.ops.size();
        original.labels.forEach((label,pos)->expected.labels.put(label,positions[pos]));
        expected.catches.addAll(original.catches);
        return expected.hash();
    }

    private record Hook(String name,String desc) { }
    private static final class Plan {
        boolean beforeSave;
        final Map<Integer,Hook> calls=new HashMap<>();
        final Set<Integer> skips=new HashSet<>();
        final Map<Integer,Integer> jumpChanges=new HashMap<>();
    }
    private enum Kind { SIMPLE,INT,VAR,TYPE,FIELD,METHOD,DYNAMIC,JUMP,LDC,IINC,TABLE,LOOKUP,MULTI }
    private static final class Op {
        Kind kind;int opcode,var,value,min,max;String owner,name,desc,type;boolean itf;Object constant;
        Label label,defaultLabel;Label[] labels;int[] keys;Handle handle;Object[] arguments;
        Op(Kind kind,int opcode){this.kind=kind;this.opcode=opcode;}
        static Op method(int opcode,String owner,String name,String desc,boolean itf){Op o=new Op(Kind.METHOD,opcode);o.owner=owner;o.name=name;o.desc=desc;o.itf=itf;return o;}
        static Op jump(int opcode,Label label){Op o=new Op(Kind.JUMP,opcode);o.label=label;return o;}
        boolean isVar(int opcode,int var){return kind==Kind.VAR&&this.opcode==opcode&&this.var==var;}
        boolean isCall(String owner,String name,String desc){return kind==Kind.METHOD&&opcode==Opcodes.INVOKEVIRTUAL&&this.owner.equals(owner)&&this.name.equals(name)&&this.desc.equals(desc);}
        String canonical(MethodCode code) {
            String head=kind+":"+opcode+":";
            return head+switch(kind) {
                case SIMPLE->"";
                case INT->Integer.toString(value);
                case VAR->Integer.toString(var);
                case TYPE->type;
                case FIELD,METHOD->owner+"|"+name+"|"+desc+"|"+itf;
                case DYNAMIC->name+"|"+desc+"|"+constant(handle)+"|"+Arrays.stream(arguments).map(FoodTransformer::constant).toList();
                case JUMP->Integer.toString(code.position(label));
                case LDC->constant(constant);
                case IINC->var+"|"+value;
                case TABLE->min+"|"+max+"|"+code.position(defaultLabel)+"|"+Arrays.stream(labels).map(code::position).toList();
                case LOOKUP->Arrays.toString(keys)+"|"+code.position(defaultLabel)+"|"+Arrays.stream(labels).map(code::position).toList();
                case MULTI->desc+"|"+value;
            };
        }
    }
    private static String constant(Object v) {
        if (v instanceof Float f) return "Float:"+Integer.toHexString(Float.floatToRawIntBits(f));
        if (v instanceof Double d) return "Double:"+Long.toHexString(Double.doubleToRawLongBits(d));
        if (v instanceof String s) return "String:"+s.length()+":"+s;
        if (v instanceof Type t) return "Type:"+t.getDescriptor();
        if (v instanceof Handle h) return "Handle:"+h.getTag()+":"+h.getOwner()+":"+h.getName()+":"+h.getDesc()+":"+h.isInterface();
        if (v instanceof ConstantDynamic d) {
            StringBuilder s=new StringBuilder("Dynamic:").append(d.getName()).append(':').append(d.getDescriptor()).append(':').append(constant(d.getBootstrapMethod()));
            for(int i=0;i<d.getBootstrapMethodArgumentCount();i++) s.append(':').append(constant(d.getBootstrapMethodArgument(i)));
            return s.toString();
        }
        return v==null?"null":v.getClass().getName()+":"+v;
    }
    private record Catch(Label start,Label end,Label handler,String type) { }
    private static final class MethodCode extends MethodVisitor {
        int access;
        final List<Op> ops=new ArrayList<>();
        final IdentityHashMap<Label,Integer> labels=new IdentityHashMap<>();
        final List<Catch> catches=new ArrayList<>();final Set<Integer> framePositions=new HashSet<>();
        MethodCode(){super(Opcodes.ASM9);}
        int position(Label label){Integer p=labels.get(label);if(p==null)throw new IllegalArgumentException("Unresolved method label");return p;}
        Set<Integer> branchTargets(){Set<Integer>s=new HashSet<>();for(Op o:ops){if(o.label!=null)s.add(position(o.label));if(o.defaultLabel!=null)s.add(position(o.defaultLabel));if(o.labels!=null)for(Label l:o.labels)s.add(position(l));}return s;}
        String hash(){StringBuilder s=new StringBuilder();for(Op o:ops)s.append(o.canonical(this)).append('\n');for(Catch c:catches)s.append("catch:").append(position(c.start)).append(':').append(position(c.end)).append(':').append(position(c.handler)).append(':').append(c.type).append('\n');return sha256(s.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));}
        @Override public void visitLabel(Label label){labels.put(label,ops.size());}
        @Override public void visitFrame(int type,int nLocal,Object[] local,int nStack,Object[] stack){framePositions.add(ops.size());}
        @Override public void visitTryCatchBlock(Label s,Label e,Label h,String t){catches.add(new Catch(s,e,h,t));}
        @Override public void visitInsn(int opcode){ops.add(new Op(Kind.SIMPLE,opcode));}
        @Override public void visitIntInsn(int opcode,int operand){Op o=new Op(Kind.INT,opcode);o.value=operand;ops.add(o);}
        @Override public void visitVarInsn(int opcode,int var){Op o=new Op(Kind.VAR,opcode);o.var=var;ops.add(o);}
        @Override public void visitTypeInsn(int opcode,String type){Op o=new Op(Kind.TYPE,opcode);o.type=type;ops.add(o);}
        @Override public void visitFieldInsn(int opcode,String owner,String name,String desc){Op o=new Op(Kind.FIELD,opcode);o.owner=owner;o.name=name;o.desc=desc;ops.add(o);}
        @Override public void visitMethodInsn(int opcode,String owner,String name,String desc,boolean itf){ops.add(Op.method(opcode,owner,name,desc,itf));}
        @Override public void visitInvokeDynamicInsn(String name,String desc,Handle handle,Object...args){Op o=new Op(Kind.DYNAMIC,Opcodes.INVOKEDYNAMIC);o.name=name;o.desc=desc;o.handle=handle;o.arguments=args.clone();ops.add(o);}
        @Override public void visitJumpInsn(int opcode,Label label){ops.add(Op.jump(opcode,label));}
        @Override public void visitLdcInsn(Object c){Op o=new Op(Kind.LDC,Opcodes.LDC);o.constant=c;ops.add(o);}
        @Override public void visitIincInsn(int var,int increment){Op o=new Op(Kind.IINC,Opcodes.IINC);o.var=var;o.value=increment;ops.add(o);}
        @Override public void visitTableSwitchInsn(int min,int max,Label d,Label...labels){Op o=new Op(Kind.TABLE,Opcodes.TABLESWITCH);o.min=min;o.max=max;o.defaultLabel=d;o.labels=labels.clone();ops.add(o);}
        @Override public void visitLookupSwitchInsn(Label d,int[]keys,Label[]labels){Op o=new Op(Kind.LOOKUP,Opcodes.LOOKUPSWITCH);o.defaultLabel=d;o.keys=keys.clone();o.labels=labels.clone();ops.add(o);}
        @Override public void visitMultiANewArrayInsn(String desc,int dimensions){Op o=new Op(Kind.MULTI,Opcodes.MULTIANEWARRAY);o.desc=desc;o.value=dimensions;ops.add(o);}
    }
    private static final class Scan { final Map<String,MethodCode> methods=new TreeMap<>(); }
    private static Scan scan(byte[] bytes) {
        ClassReader r=new ClassReader(bytes);
        if(!FOOD.equals(r.getClassName()))throw new IllegalArgumentException("Not Food.class");
        if(!ITEM.equals(r.getSuperName()))throw new IllegalArgumentException("Unsupported Food superclass");
        if(r.readUnsignedShort(6)!=EXPECTED_MAJOR)throw new IllegalArgumentException("Unsupported Food class major: "+r.readUnsignedShort(6));
        Scan result=new Scan();
        r.accept(new ClassVisitor(Opcodes.ASM9){
            @Override public MethodVisitor visitMethod(int a,String n,String d,String s,String[]e){MethodCode c=new MethodCode();c.access=a;if(result.methods.put(n+d,c)!=null)throw new IllegalArgumentException("Duplicate method");return c;}
        },ClassReader.SKIP_DEBUG);
        return result;
    }
    private static final class Rewriter extends MethodVisitor {
        final Plan plan;int index;
        Rewriter(MethodVisitor delegate,Plan plan){super(Opcodes.ASM9,delegate);this.plan=plan;}
        @Override public void visitCode(){super.visitCode();if(plan.beforeSave){super.visitVarInsn(Opcodes.ALOAD,0);super.visitMethodInsn(Opcodes.INVOKESTATIC,HOOKS,"beforeSave","(L"+FOOD+";)V",false);}}
        boolean next(){return !plan.skips.contains(index++);}
        @Override public void visitInsn(int op){if(next())super.visitInsn(op);}
        @Override public void visitIntInsn(int op,int v){if(next())super.visitIntInsn(op,v);}
        @Override public void visitVarInsn(int op,int v){if(next())super.visitVarInsn(op,v);}
        @Override public void visitTypeInsn(int op,String t){if(next())super.visitTypeInsn(op,t);}
        @Override public void visitFieldInsn(int op,String owner,String name,String desc){if(next())super.visitFieldInsn(op,owner,name,desc);}
        @Override public void visitMethodInsn(int op,String owner,String name,String desc,boolean itf){int i=index;if(!next())return;Hook h=plan.calls.get(i);if(h==null)super.visitMethodInsn(op,owner,name,desc,itf);else super.visitMethodInsn(Opcodes.INVOKESTATIC,HOOKS,h.name,h.desc,false);}
        @Override public void visitInvokeDynamicInsn(String n,String d,Handle h,Object...a){if(next())super.visitInvokeDynamicInsn(n,d,h,a);}
        @Override public void visitJumpInsn(int op,Label l){int i=index;if(next())super.visitJumpInsn(plan.jumpChanges.getOrDefault(i,op),l);}
        @Override public void visitLdcInsn(Object v){if(next())super.visitLdcInsn(v);}
        @Override public void visitIincInsn(int v,int n){if(next())super.visitIincInsn(v,n);}
        @Override public void visitTableSwitchInsn(int a,int b,Label d,Label...l){if(next())super.visitTableSwitchInsn(a,b,d,l);}
        @Override public void visitLookupSwitchInsn(Label d,int[]k,Label[]l){if(next())super.visitLookupSwitchInsn(d,k,l);}
        @Override public void visitMultiANewArrayInsn(String d,int n){if(next())super.visitMultiANewArrayInsn(d,n);}
    }
    public static String sha256(byte[] bytes) {
        try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));}
        catch(java.security.NoSuchAlgorithmException impossible){throw new AssertionError(impossible);}
    }
}
