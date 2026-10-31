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
        int exitCode = 0;
        try {
            type = Class.forName("com.sun.tools.attach.VirtualMachine");
            vm = type.getMethod("attach",String.class).invoke(null,args[0]);
            Method propsMethod=type.getMethod("getSystemProperties");
            Properties props=(Properties)propsMethod.invoke(vm);
            int current = activeStatus(props);
            if (current == 1) {
                System.out.println("ALREADY_ACTIVE PID="+args[0]+" BUILD="+VivadoChineseAgentV2.BUILD_VERSION);
            } else if (current == 3) {
                System.out.println("UPDATE_REQUIRES_RESTART PID="+args[0]+" ACTIVE_BUILD="+
                    props.getProperty(VivadoChineseAgentV2.BUILD_MARKER,"unknown")+" EXPECTED_BUILD="+VivadoChineseAgentV2.BUILD_VERSION);
                exitCode = 3;
            } else {
                type.getMethod("loadAgent",String.class,String.class).invoke(vm,args[1],"version="+args[2]);
                props=(Properties)propsMethod.invoke(vm);
                if (activeStatus(props) != 1)
                    throw new IllegalStateException("Agent returned without the matching active build marker.");
                System.out.println("INJECTION_OK PID="+args[0]+" JAVA="+props.getProperty("java.version")+" BUILD="+VivadoChineseAgentV2.BUILD_VERSION);
            }
        } catch (Throwable t) {
            Throwable cause=t;
            while (cause instanceof InvocationTargetException && ((InvocationTargetException)cause).getCause()!=null) cause=((InvocationTargetException)cause).getCause();
            System.err.println("ATTACH_FAILED "+cause.getClass().getSimpleName()+": "+cause.getMessage());
            exitCode = 1;
        } finally {
            if (vm!=null && type!=null) try { type.getMethod("detach").invoke(vm); } catch (Throwable ignored) { }
        }
        if (exitCode != 0) System.exit(exitCode);
    }

    // 0 = not loaded; 1 = this exact build; 3 = old/different build.
    static int activeStatus(Properties properties) {
        if (!"true".equals(properties.getProperty(VivadoChineseAgentV2.MARKER))) return 0;
        return VivadoChineseAgentV2.BUILD_VERSION.equals(properties.getProperty(VivadoChineseAgentV2.BUILD_MARKER)) ? 1 : 3;
    }
}
