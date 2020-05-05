import com.fox.Utils.Common;
import flash.geom.Point;
import mx.utils.Delegate;
/*
* ...
* @author fox
*/
class com.fox.odmap.Map
{

	public var Image:MovieClip;
	private var listener:Object;
	private var callBack:Function;

	public function Map(target:MovieClip, pos:Point, size:Number, cb:Function)
	{
		callBack = cb;
		listener = new Object();
		listener.size = size;
		listener.onLoadComplete = Delegate.create(this, LoadComplete);
		Image = target.createEmptyMovieClip("Image", target.getNextHighestDepth());
		Image._x = pos.x;
		Image._y = pos.y;
		var loader:MovieClipLoader = new MovieClipLoader();
		loader.addListener(listener);
		loader.loadClip("ODMap/assets/map.png",Image);
	}

	private function LoadComplete()
	{
		Image._width = Image._height = listener.size;
		var pos = Common.getOnScreen(Image);
		Image._x = pos.x;
		Image._y = pos.y;
		callBack();
		callBack = undefined;
		listener = undefined;
	}

	public function setSize(size)
	{
		Image._width = Image._height = Image.size = size;
	}

	public function setPos(pos:Point)
	{
		Image._x = pos.x;
		Image._y = pos.y;
	}
}