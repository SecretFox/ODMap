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
		swfRoot.OnModuleActivated = OnActivated;
		swfRoot.OnModuleDeactivated = OnDeactivated;
	}

	public function Main() { }

	public static function OnActivated(config: Archive):Void
	{
		s_app.Activate(config);
	}

	public static function OnDeactivated():Archive
	{
		return s_app.Deactivate();
	}
}