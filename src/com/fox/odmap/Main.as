import com.Utils.Archive;
import com.fox.odmap.Mod
/*
* ...
* @author fox
*/
class com.fox.odmap.Main

{
	private static var s_app:Mod;
	public static function main(swfRoot:MovieClip):Void
	{
		s_app = new Mod(swfRoot);
		swfRoot.onLoad = OnLoad;
		swfRoot.onUnload = OnUnload;
		swfRoot.OnModuleActivated = OnActivated;
		swfRoot.OnModuleDeactivated = OnDeactivated;
	}

	public function Main() { }

	public static function OnLoad()
	{
		s_app.Load();
	}

	public static function OnUnload()
	{
		s_app.Unload();
	}

	public static function OnActivated(config: Archive):Void
	{
		s_app.Activate(config);
	}

	public static function OnDeactivated():Archive
	{
		return s_app.Deactivate();
	}
}