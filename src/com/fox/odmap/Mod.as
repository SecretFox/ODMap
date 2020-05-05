import com.GameInterface.Chat;
import com.GameInterface.DistributedValue;
import com.GameInterface.DistributedValueBase;
import com.GameInterface.GUIModuleIF;
import com.GameInterface.Game.Character;
import com.Utils.Archive;
import com.Utils.GlobalSignal;
import com.fox.Utils.Common;
import com.fox.odmap.Map;
import com.fox.odmap.Tracker;
import flash.geom.Point;
import mx.utils.Delegate;
/*
* ...
* @author fox
*/
class com.fox.odmap.Mod
{
	private var m_swfRoot:MovieClip;
	private var Container:MovieClip;
	private var m_Map:Map;
	private var m_Tracker:Tracker;
	private var config:Archive;
	private var mouseListener:Object;
	private var nametagsEnabled:DistributedValue;

	public function Mod(root)
	{
		m_swfRoot = root;
		mouseListener = new Object();
		mouseListener.onMouseWheel = Delegate.create(this, onMouseWheel);
		nametagsEnabled = DistributedValue.Create("ShowVicinityNPCNametags");
	}

	static function IsODZone()
	{
		return Character.GetClientCharacter().GetPlayfieldID() == 7670;
	}

	public function Activate(conf:Archive)
	{
		config = conf;
		if (IsODZone())
		{
			SavePreferences();
			if (!Container) DrawMap();
		}
		else
		{
			if (config.FindEntry("NametagsEnabled"))
			{
				nametagsEnabled.SetValue(false);
				config.DeleteEntry("NametagsEnabled");
			}
			if (Container)
			{
				removeMap();
			}
		}
	}

	public function removeMap()
	{
		m_Tracker.Disconnect();
		m_Tracker.ClearMarkers();
		m_Tracker = undefined;
		Container.removeMovieClip();
		Container = undefined;
		m_Map = undefined;
	}

	public function SavePreferences()
	{
		if (!nametagsEnabled.GetValue())
		{
			config.ReplaceEntry("NametagsEnabled", true);
			nametagsEnabled.SetValue(true);
			Chat.SignalShowFIFOMessage.Emit("ODMap: Force enabling nametags");
			var mod:GUIModuleIF = GUIModuleIF.FindModuleIF("ODMap");
			mod.StoreConfig(config);
		}
	}

	private function DrawMap()
	{
		if (!_root.mainmenuwindow)
		{
			setTimeout(Delegate.create(this, DrawMap), 100);
			return
		}
		Container = m_swfRoot.createEmptyMovieClip("MapContainer", m_swfRoot.getNextHighestDepth());
		AttachMap();
	}

	public function Deactivate():Archive
	{
		return config
	}

	private function getMapPos()
	{
		var pos:Point = config.FindEntry("Pos");
		if (!pos)
		{
			pos = new Point(Stage.width-200,DistributedValueBase.GetDValue("MinimapTopOffset"));
			config.ReplaceEntry("Pos", pos)
		}
		return pos;
	}

	private function getMapSize()
	{
		var size = config.FindEntry("Size");
		if (!size)
		{
			size = 2 * DistributedValueBase.GetDValue("MinimapScale");
			config.ReplaceEntry("Size", size)
		}
		return size;
	}

	private function onMouseWheel(delta)
	{
		var oldSize = config.FindEntry("Size");
		if (delta > 0)
		{
			var newSize = oldSize + 5;
			if (newSize > 400) newSize = 400;
			if (newSize != oldSize) ChangeSize(newSize);
		}
		else
		{
			var newSize = oldSize - 5;
			if (newSize < 100) newSize = 100;
			if (newSize != oldSize) ChangeSize(newSize);
		}
	}

	private function ChangeSize(size)
	{
		config.ReplaceEntry("Size", size);
		m_Map.setSize(size);
		ChangePos();
		m_Tracker.ChangeScale();
	}

	private function ChangePos()
	{
		var pos:Point = Common.getOnScreen(m_Map.Image);
		config.ReplaceEntry("Pos", pos);
		m_Map.setPos(pos);
		m_Tracker.CalculatePosToPixel();
		m_Tracker.MoveMarkers();
	}

	private function AttachMap()
	{
		var callback = Delegate.create(this, AttachTracker);
		m_Map = new Map(Container,getMapPos(),getMapSize(),callback);
		GlobalSignal.SignalSetGUIEditMode.Connect(GuiEdit, this);
		GuiEdit(false);
	}

	private function StartDrag()
	{
		m_Map.Image.startDrag();
		m_Tracker.Hide();
	}

	private function StopDrag()
	{
		m_Map.Image.stopDrag();
		m_Tracker.Show();
		ChangePos();
	}

	private function GuiEdit(state)
	{
		if (state)
		{
			m_Map.Image.onPress = Delegate.create(this, StartDrag);
			m_Map.Image.onRelease = m_Map.Image.onReleaseOutside = Delegate.create(this, StopDrag);
			Mouse.addListener(mouseListener);
		}
		else
		{
			m_Map.Image.onPress = m_Map.Image.onRelease = m_Map.Image.onReleaseOutside = undefined;
			Mouse.removeListener(mouseListener);
		}
	}

	private function AttachTracker()
	{
		m_Tracker = new Tracker(Container);
		m_Tracker.SignalLoadFailed.Connect(removeMap, this);
		m_Tracker.Start();
	}
}