import java.lang.reflect.*;
import java.util.Properties;

/** Attach only to a selected Vivado process, and verify the marker after injection. */
public final class VivadoAttach {
    public static void main(String[] args) {
        if (args.length != 3 || !args[0].matches("[0-9]+")) {
            System.err.println("Usage: VivadoAttach PID AGENT_JAR VERSION"); System.exit(2);
        }
        Object vm = null;
        Class<?> type = null;
        boolean failed = false;
        try {
            type = Class.forName("com.sun.tools.attach.VirtualMachine");
            vm = type.getMethod("attach",String.class).invoke(null,args[0]);
            Method propsMethod=type.getMethod("getSystemProperties");
            Properties props=(Properties)propsMethod.invoke(vm);
            if ("true".equals(props.getProperty("vivado.zh.patch.v2.active"))) {
                System.out.println("ALREADY_ACTIVE PID="+args[0]); return;
            }
            type.getMethod("loadAgent",String.class,String.class).invoke(vm,args[1],"version="+args[2]);
            props=(Properties)propsMethod.invoke(vm);
            if (!"true".equals(props.getProperty("vivado.zh.patch.v2.active")))
                throw new IllegalStateException("Agent returned without the active marker.");
            System.out.println("INJECTION_OK PID="+args[0]+" JAVA="+props.getProperty("java.version"));
        } catch (Throwable t) {
            Throwable cause=t;
            while (cause instanceof InvocationTargetException && ((InvocationTargetException)cause).getCause()!=null) cause=((InvocationTargetException)cause).getCause();
            System.err.println("ATTACH_FAILED "+cause.getClass().getSimpleName()+": "+cause.getMessage());
            failed = true;
        } finally {
            if (vm!=null && type!=null) try { type.getMethod("detach").invoke(vm); } catch (Throwable ignored) { }
        }
        if (failed) System.exit(1);
    }
}
