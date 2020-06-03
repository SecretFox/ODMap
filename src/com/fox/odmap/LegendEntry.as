import com.Utils.ID32;
import com.fox.odmap.MarkerConfigLegend;
/**
 * ...
 * @author fox
 */
class com.fox.odmap.LegendEntry
{
	static var RightText:String = "Right";
	static var LeftText:String = "Left";

	public var ID:ID32;
	public var TextRoot:MovieClip;
	public var Time:Number;
	public var ExpireTime:Boolean;
	public var Config:MarkerConfigLegend;
}