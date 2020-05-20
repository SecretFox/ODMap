import com.GameInterface.Game.Character;
import com.GameInterface.Tooltip.TooltipInterface;
import com.Utils.Slot;
import com.fox.odmap.MarkerConfig;
/*
* ...
* @author fox
*/
class com.fox.odmap.MarkerObject
{
	public var containerClip:MovieClip;
	public var m_ToolTip:TooltipInterface;
	public var deathinterval:Number;
	public var deathSlot:Slot;//for disconnecting invisible buff added signal
	public var imgClip:MovieClip;
	public var deathClip:TextField;
	public var client:Boolean;
	public var config:MarkerConfig;
	public var char:Character;
	public var slot:Slot; // for disconnecting offensive target changed signal
	public var deathTime:Number;
}