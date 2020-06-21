import com.GameInterface.Chat;
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
	public var cb:Function;
	public var XMLFile:XML;
	public var target:MovieClip;
	public var pos:Point;
	public var size:Number;
	public var loadListener:Object;

	public function Map(_target:MovieClip, _pos:Point, _size:Number, _cb:Function)
	{
		cb = _cb;
		target = _target;
		pos = _pos;
		size = _size;
		XMLFile = new XML();
		XMLFile.ignoreWhite = true;
		XMLFile.onLoad = Delegate.create(this, ProcessXML);
		XMLFile.load("ODMap/config.xml");
	}
	
	private function ProcessXML(success)
	{
		if (success){
			var rootXML:XMLNode = XMLFile.firstChild;
			var mapLocation = rootXML.attributes.iimg;
			if (mapLocation)
			{
				Image = target.attachMovie(mapLocation, "Image", target.getNextHighestDepth());
				if (!Image){
					ImageFailed();
					return;
				}
				Image._width = Image._height = size;
				Image._x = pos.x;
				Image._y = pos.y;
				var pos2 = Common.getOnScreen(Image);
				Image._x = pos2.x;
				Image._y = pos2.y;
				cb();
			}
			else{
				mapLocation = rootXML.attributes.eimg;
				if (mapLocation)
				{
					loadListener = new Object();
					loadListener.onLoadComplete = Delegate.create(this,ImageLoaded);
					loadListener.onLoadError = Delegate.create(this, ImageFailed);
					Image = target.createEmptyMovieClip("Image", target.getNextHighestDepth());
					var imgLoader:MovieClipLoader = new MovieClipLoader();
					imgLoader.addListener(loadListener);
					imgLoader.loadClip(mapLocation, Image);
				}
				else
				{
					ImageFailed();
				}
			}
		}
		else
		{
			ImageFailed();
		}
		XMLFile = undefined;
	}
	
	private function ImageLoaded(){
		loadListener = undefined;
		Image._width = Image._height = size;
		Image._x = pos.x;
		Image._y = pos.y;
		var pos2 = Common.getOnScreen(Image);
		Image._x = pos2.x;
		Image._y = pos2.y;
		cb();
	}
	
	private function ImageFailed(){
		loadListener = undefined;
		Chat.SignalShowFIFOMessage.Emit("ODMap: Failed to load map image", 0);
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