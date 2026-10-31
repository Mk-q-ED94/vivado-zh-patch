import javax.swing.*;
import java.awt.event.*;
public class TranslationSelfTest {
    public static void main(String[] args) throws Exception {
        final String[] action = {null};
        SwingUtilities.invokeAndWait(() -> {
            JPanel root = new JPanel();
            JButton button = new JButton("Open Project");
            button.addActionListener(e -> action[0]=e.getActionCommand());
            JLabel label = new JLabel("Project Summary");
            JTextField field = new JTextField("Open Project");
            JTabbedPane tabs = new JTabbedPane(); tabs.addTab("Sources",new JPanel());
            root.add(button); root.add(label); root.add(field); root.add(tabs);
            VivadoChineseAgentV2.translateTree(root);
            if (!button.getText().contains("打开")) throw new AssertionError("button not translated");
            if (!label.getText().contains("项目")) throw new AssertionError("label not translated");
            if (!tabs.getTitleAt(0).contains("源")) throw new AssertionError("tab not translated");
            if (!field.getText().equals("Open Project")) throw new AssertionError("editable field changed");
            button.doClick();
            if (!"Open Project".equals(action[0])) throw new AssertionError("action command changed: "+action[0]);
            System.out.println("PASS: controls translated; text field and action command preserved");
        });
    }
}
