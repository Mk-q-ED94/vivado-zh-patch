import java.awt.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.List;
import java.util.jar.*;
import javax.swing.*;
import javax.swing.border.*;
import javax.swing.text.JTextComponent;
import javax.swing.tree.TreeCellRenderer;
import java.lang.instrument.Instrumentation;

/** Local, opt-in translation of display text only; original application files remain untouched. */
public final class VivadoChineseAgentV2 {
    private static final Map<String,String> translations = new HashMap<>();
    private static Path base;
    private static final Object LOCK = new Object();
    private static long total = 0;
    private static final Map<Component,Boolean> inspected = new WeakHashMap<>();
    private static final Set<String> inspectedNodes = new HashSet<>();
    private static final Map<JTree,Boolean> flowTreeFailures = new WeakHashMap<>();
    private static volatile boolean flow20252;
    static final String MARKER = "vivado.zh.patch.v2.active";
    static final String BUILD_MARKER = "vivado.zh.patch.build";
    static final String BUILD_VERSION = "2.1.0";

    public static void premain(String options, Instrumentation instrumentation) {
        try {
            initialize(options, false);
        } catch (Throwable t) { log("agent initialization failed: " + t); }
    }
    public static void agentmain(String options, Instrumentation instrumentation) throws Exception {
        initialize(options, true);
    }
    private static synchronized void initialize(String options, boolean attach) throws Exception {
        if ("true".equals(System.getProperty(MARKER))) {
            if (BUILD_VERSION.equals(System.getProperty(BUILD_MARKER))) return;
            throw new IllegalStateException("UPDATE_REQUIRES_RESTART: a different patch build is already active");
        }
        base = Paths.get(VivadoChineseAgentV2.class.getProtectionDomain().getCodeSource().getLocation().toURI()).getParent();
        try {
            Class.forName("VivadoChineseAgent", false, ClassLoader.getSystemClassLoader());
            throw new IllegalStateException("Legacy Vivado Chinese agent is already active; restart Vivado before upgrading.");
        } catch (ClassNotFoundException expected) { }
        String main = System.getProperty("sun.java.command", "");
        if (!main.isEmpty() && !main.startsWith("TranslationSelfTest")) {
            log("skip non-embedded Java command");
            if (attach) throw new IllegalStateException("Target is not an embedded Vivado JVM.");
            return;
        }
        translations.clear();
        loadDictionary(base.resolve("translations.tsv"));
        String version = options != null && options.startsWith("version=") ? options.substring(8) : System.getProperty("vivado.zh.version", "unknown");
        flow20252 = "2025.2".equals(version);
        log("agent v2 loaded; dictionary=" + translations.size() + "; java=" + System.getProperty("java.version") + "; Vivado=" + version + "; flow20252=" + flow20252);
        if (main.startsWith("TranslationSelfTest")) return;
        System.setProperty(BUILD_MARKER, BUILD_VERSION);
        System.setProperty(MARKER, "true");
        EventQueue.invokeLater(() -> {
            javax.swing.Timer timer = new javax.swing.Timer(1200, e -> {
                try { for (Window window : Window.getWindows()) if (window.isDisplayable()) translateTree(window); }
                catch (Throwable t) { log("scan error: " + t); }
            });
            timer.setCoalesce(true); timer.start();
        });
    }

    private static void loadDictionary(Path file) throws IOException {
        for (String line : Files.readAllLines(file, StandardCharsets.UTF_8)) {
            if (line.trim().isEmpty() || line.startsWith("#")) continue;
            int i = line.indexOf('\t');
            if (i > 0 && i < line.length()-1) translations.put(line.substring(0,i), line.substring(i+1));
        }
    }
    private static String translated(String s) { return s == null ? null : translations.get(s); }
    private static void ensureChineseFont(Component c, String value) {
        Font f = c.getFont();
        if (f == null || value == null) return;
        boolean hasChinese = value.codePoints().anyMatch(cp -> Character.UnicodeScript.of(cp) == Character.UnicodeScript.HAN);
        if (hasChinese) c.setFont(new Font("Microsoft YaHei UI", f.getStyle(), Math.max(1, f.getSize())).deriveFont(f.getSize2D()));
    }
    private static void count(String from, String to) {
        total++;
        if (total <= 400) log("translated " + from + " => " + to);
    }
    private static void log(String message) {
        try {
            if (base == null) return;
            synchronized (LOCK) {
                Files.write(base.resolve("patch.log"), (java.time.LocalDateTime.now()+" "+message+System.lineSeparator()).getBytes(StandardCharsets.UTF_8),
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND);
            }
        } catch (Exception ignored) { }
    }
    public static void translateTree(Component c) {
        // Cell renderers and editors can contain user data that happens to match a
        // dictionary entry. Never recurse through their component hierarchies.
        if (c instanceof JTextComponent || c instanceof JTable || c instanceof JList ||
            c instanceof JComboBox || c instanceof CellRendererPane) return;
        if (Boolean.getBoolean("vivado.zh.debug") && c instanceof JTree && !inspected.containsKey(c)) {
            inspected.put(c,Boolean.TRUE);
            JTree tree=(JTree)c;
            log("TREE class="+c.getClass().getName()+" model="+tree.getModel().getClass().getName()+" root="+tree.getModel().getRoot()+" renderer="+tree.getCellRenderer().getClass().getName());
            dumpTree(tree.getModel(),tree.getModel().getRoot(),0);
        }
        // Vivado 2025.2 Flow Navigator uses a custom tree. Wrap only its renderer;
        // leave the model, node values and action handling entirely unchanged.
        if (flow20252 && c instanceof JTree && c.getClass().getName().equals("ui.views.S.b.g")) {
            JTree tree=(JTree)c;
            try {
                TreeCellRenderer original=(TreeCellRenderer)tree.getClass().getMethod("getWrappedCellRenderer").invoke(tree);
                if (original != null && !(original instanceof FlowRenderer)) {
                    tree.setCellRenderer(new FlowRenderer(original));
                    flowTreeFailures.remove(tree); tree.revalidate(); tree.repaint();
                    log("flow navigator display renderer enabled");
                }
            } catch (Throwable t) {
                if (!flowTreeFailures.containsKey(tree)) { flowTreeFailures.put(tree,Boolean.TRUE); log("flow renderer unavailable: "+t); }
            }
        }
        // The explicitly wrapped Flow Navigator renderer above is display-only;
        // all other tree content and every tree model remain untouched.
        if (c instanceof JTree) return;
        if (c instanceof AbstractButton) {
            AbstractButton b=(AbstractButton)c;
            String original=b.getText(), replacement=translated(original);
            if (replacement != null && !replacement.equals(original)) {
                String command=b.getActionCommand();
                b.setActionCommand(command); // default Swing command otherwise follows displayed text
                ensureChineseFont(b,replacement); b.setText(replacement); count(original,replacement);
            }
        } else if (c instanceof JLabel) {
            JLabel label=(JLabel)c; String original=label.getText(), replacement=translated(original);
            if (replacement != null && !replacement.equals(original)) { ensureChineseFont(label,replacement); label.setText(replacement); count(original,replacement); }
        }
        if (c instanceof JTabbedPane) {
            JTabbedPane tab=(JTabbedPane)c;
            for(int i=0;i<tab.getTabCount();i++) {
                String original=tab.getTitleAt(i), replacement=translated(original);
                if (replacement != null && !replacement.equals(original)) { ensureChineseFont(tab,replacement); tab.setTitleAt(i,replacement); count(original,replacement); }
            }
        }
        if (c instanceof JComponent) {
            Border border=((JComponent)c).getBorder();
            if (border instanceof TitledBorder) {
                TitledBorder tb=(TitledBorder)border; String original=tb.getTitle(), replacement=translated(original);
                if (replacement != null && !replacement.equals(original)) { tb.setTitle(replacement); ((JComponent)c).repaint(); count(original,replacement); }
            }
        }
        if (c instanceof JMenu) {
            for(Component child:((JMenu)c).getMenuComponents()) translateTree(child);
        } else if (c instanceof Container) {
            for(Component child:((Container)c).getComponents()) translateTree(child);
        }
    }
    private static void dumpTree(javax.swing.tree.TreeModel m,Object node,int depth) {
        if(depth>2) return;
        int count=Math.min(m.getChildCount(node),25);
        for(int i=0;i<count;i++) {Object child=m.getChild(node,i); log("TREE node depth="+depth+" class="+child.getClass().getName()+" value="+child); dumpTree(m,child,depth+1);}
    }
    private static final class FlowRenderer implements TreeCellRenderer {
        private final TreeCellRenderer delegate;
        FlowRenderer(TreeCellRenderer d) { delegate=d; }
        public Component getTreeCellRendererComponent(JTree tree,Object value,boolean selected,boolean expanded,boolean leaf,int row,boolean focus) {
            Component rendered=delegate.getTreeCellRendererComponent(tree,value,selected,expanded,leaf,row,focus);
            String original=String.valueOf(value), replacement=translated(original);
            if (Boolean.getBoolean("vivado.zh.debug") && inspectedNodes.add(original)) log("RENDER value="+original+" component="+describeComponent(rendered));
            if (replacement!=null) replaceRendererLabel(rendered,original,replacement);
            return rendered;
        }
    }
    private static String describeComponent(Component c) {
        String out=c.getClass().getName()+ (c instanceof JLabel ? " label="+((JLabel)c).getText() : "");
        if(c instanceof Container) for(Component child:((Container)c).getComponents()) out+=" ["+describeComponent(child)+"]";
        return out;
    }
    private static void replaceRendererLabel(Component c,String original,String replacement) {
        if (c instanceof JLabel) {
            JLabel label=(JLabel)c; String text=label.getText();
            if (text!=null) {
                String changed=java.util.regex.Pattern.compile(java.util.regex.Pattern.quote(original),java.util.regex.Pattern.CASE_INSENSITIVE)
                    .matcher(text).replaceFirst(java.util.regex.Matcher.quoteReplacement(replacement));
                if (!changed.equals(text)) { ensureChineseFont(label,replacement); label.setText(changed); }
            }
        }
        if (c instanceof Container) for(Component child:((Container)c).getComponents()) replaceRendererLabel(child,original,replacement);
    }
}
