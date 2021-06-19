import com.GameInterface.Game.Character;
import com.Utils.SignalGroup;
import com.Utils.Slot;
import com.fox.odmap.MarkerConfig;
/*
* ...
* @author fox
*/
class com.fox.odmap.MarkerObject
{
	public var containerClip:MovieClip;
	public var imgClip:MovieClip;
	public var client:Boolean;
	public var m_Signals:SignalGroup;
	public var currentCast:String;
	public var config:MarkerConfig;
	public var char:Character;
	public var colorFunc:Slot;
}