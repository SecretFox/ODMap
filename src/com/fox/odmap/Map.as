import com.fox.Utils.Common;
import flash.geom.Point;
/*
* ...
* @author fox
*/
class com.fox.odmap.Map
{

	public var Image:MovieClip;

	public function Map(target:MovieClip, pos:Point, size:Number, cb:Function)
	{
		Image = target.attachMovie("src.assets.map.png", "Image", target.getNextHighestDepth());
		Image._width = Image._height = size;
		Image._x = pos.x;
		Image._y = pos.y;
		var pos2 = Common.getOnScreen(Image);
		Image._x = pos2.x;
		Image._y = pos2.y;
		cb();
	}

	public function setSize(size)
	{
		Image._width = Image._height = size;
	}

	public function setPos(pos:Point)
	{
		Image._x = pos.x;
		Image._y = pos.y;
	}
}