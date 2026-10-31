import javax.swing.*;
import javax.swing.tree.TreeCellRenderer;
import java.lang.reflect.Constructor;
import java.util.Properties;
public class TranslationSelfTest {
    public static void main(String[] args) throws Exception {
        final String[] action = {null};
        SwingUtilities.invokeAndWait(() -> {
            JPanel root = new JPanel();
            JButton button = new JButton("Open Project");
            button.addActionListener(e -> action[0]=e.getActionCommand());
            JButton explicitButton = new JButton("Open Project");
            explicitButton.setActionCommand("internal-open-command");
            JLabel label = new JLabel("Project Summary");
            JTextField field = new JTextField("Open Project");
            JTabbedPane tabs = new JTabbedPane(); tabs.addTab("Sources",new JPanel());
            CellRendererPane cellPane = new CellRendererPane();
            JLabel renderedValue = new JLabel("Open Project"); cellPane.add(renderedValue);
            JTree tree = new JTree(); JLabel treeValue = new JLabel("Open Project"); tree.add(treeValue);
            JTable table = new JTable(1,1); JLabel tableValue = new JLabel("Open Project"); table.add(tableValue);
            JList<String> list = new JList<String>(new String[]{"Open Project"});
            JLabel listValue = new JLabel("Open Project"); list.add(listValue);
            JComboBox<String> combo = new JComboBox<String>(new String[]{"Open Project"});
            root.add(button); root.add(explicitButton); root.add(label); root.add(field); root.add(tabs);
            root.add(cellPane); root.add(tree); root.add(table); root.add(list); root.add(combo);
            VivadoChineseAgentV2.translateTree(root);
            if (!button.getText().contains("打开")) throw new AssertionError("button not translated");
            if (!label.getText().contains("项目")) throw new AssertionError("label not translated");
            if (!tabs.getTitleAt(0).contains("源")) throw new AssertionError("tab not translated");
            if (!field.getText().equals("Open Project")) throw new AssertionError("editable field changed");
            if (!renderedValue.getText().equals("Open Project") || !treeValue.getText().equals("Open Project") ||
                !tableValue.getText().equals("Open Project") || !listValue.getText().equals("Open Project") ||
                !combo.getItemAt(0).equals("Open Project")) throw new AssertionError("data renderer changed");
            button.doClick();
            if (!"Open Project".equals(action[0])) throw new AssertionError("action command changed: "+action[0]);
            if (!"internal-open-command".equals(explicitButton.getActionCommand())) throw new AssertionError("explicit action command changed");
            Properties props = new Properties();
            if (VivadoAttach.activeStatus(props) != 0) throw new AssertionError("inactive build detection");
            props.setProperty(VivadoChineseAgentV2.MARKER,"true");
            if (VivadoAttach.activeStatus(props) != 3) throw new AssertionError("legacy build detection");
            props.setProperty(VivadoChineseAgentV2.BUILD_MARKER,"different");
            if (VivadoAttach.activeStatus(props) != 3) throw new AssertionError("different build detection");
            props.setProperty(VivadoChineseAgentV2.BUILD_MARKER,VivadoChineseAgentV2.BUILD_VERSION);
            if (VivadoAttach.activeStatus(props) != 1) throw new AssertionError("matching build detection");
            try {
                TreeCellRenderer original = (t,v,selected,expanded,leaf,row,focus) -> new JLabel("<html><span style='color:gray'>"+v+"</span></html>");
                Class<?> type = Class.forName("VivadoChineseAgentV2$FlowRenderer");
                Constructor<?> ctor=type.getDeclaredConstructor(TreeCellRenderer.class); ctor.setAccessible(true);
                TreeCellRenderer wrapped=(TreeCellRenderer)ctor.newInstance(original);
                JLabel rendered=(JLabel)wrapped.getTreeCellRendererComponent(tree,"Open Project",false,false,true,0,false);
                if (!rendered.getText().contains("打开项目") || !rendered.getText().contains("color:gray")) throw new AssertionError("flow renderer lost translation or HTML");
            } catch (ReflectiveOperationException e) { throw new AssertionError("flow renderer test",e); }
            System.out.println("PASS: labels translated; data and action commands preserved; flow HTML and build detection verified");
        });
    }
}
