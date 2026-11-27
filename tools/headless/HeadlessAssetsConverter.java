import com.jme3.asset.plugins.FileLocator;
import com.jme3.system.JmeSystem;
import java.io.File;
import toniarts.openkeeper.tools.convert.AssetsConverter;

/**
 * Headless front-end for OpenKeeper's real asset converter.
 * No Swing UI: suitable for Windows command line and CI.
 */
public class HeadlessAssetsConverter extends AssetsConverter {

    public HeadlessAssetsConverter(String dungeonKeeperFolder) {
        // ConvertModels needs a real AssetManager for KMF material loading.
        // Create the same headless DesktopAssetManager Main.java uses.
        super(dungeonKeeperFolder, createAssetManager());
    }

    private static com.jme3.asset.AssetManager createAssetManager() {
        com.jme3.asset.AssetManager manager = JmeSystem.newAssetManager(
                Thread.currentThread().getContextClassLoader()
                        .getResource("com/jme3/asset/Desktop.cfg"));
        manager.registerLocator(AssetsConverter.getAssetsFolder(), FileLocator.class);
        return manager;
    }

    @Override
    public void onUpdateStatus(Integer current, Integer total, ConvertProcess process) {
        System.out.println("[convert] " + process + " " + current + "/" + total);
    }

    @Override
    public void onComplete(ConvertProcess process) {
        System.out.println("[convert] DONE " + process);
    }

    @Override
    public void onError(Exception ex, ConvertProcess process) {
        System.err.println("[convert] ERROR in " + process + ": " + ex);
        ex.printStackTrace();
    }

    public static void main(String[] args) {
        String folder = args.length > 0 ? args[0]
                : "C:\\Program Files (x86)\\Dungeon Keeper 2";
        // OpenKeeper concatenates DKII_DATA_FOLDER directly ("Data"), so the
        // root must end with a separator or paths become "...Keeper 2Data".
        if (!folder.endsWith(File.separator) && !folder.endsWith("/")) {
            folder += File.separator;
        }
        System.out.println("DK2 folder: " + folder);
        boolean ok = new HeadlessAssetsConverter(folder).convertAssets();
        System.out.println("CONVERSION_RESULT=" + ok);
        if (!ok) {
            System.exit(1);
        }
    }
}
