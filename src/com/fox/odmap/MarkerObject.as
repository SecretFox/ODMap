import com.GameInterface.Game.Character;
import com.Utils.Slot;
import com.fox.odmap.MarkerConfig;
/*
* ...
* @author fox
*/
class com.fox.odmap.MarkerObject extends MovieClip
{
	public var containerClip:MovieClip;
	public var imgClip:MovieClip;
	public var client:Boolean;
	public var config:MarkerConfig;
	public var char:Character;
	public var slot:Slot; // for disconnecting offensive target changed signal
}