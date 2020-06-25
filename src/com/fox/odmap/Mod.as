import com.GameInterface.Chat;
import com.GameInterface.DistributedValue;
import com.GameInterface.DistributedValueBase;
import com.GameInterface.GUIModuleIF;
import com.GameInterface.Game.Character;
import com.GameInterface.WaypointInterface;
import com.Utils.Archive;
import com.Utils.GlobalSignal;
import com.Utils.ID32;
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
	static var config:Archive;
	private var m_swfRoot:MovieClip;
	private var Container:MovieClip;
	private var m_Map:Map;
	private var m_Tracker:Tracker;
	private var DvalHideMinimap:DistributedValue;
	private var DvalReloadConfig:DistributedValue;
	private var mouseListener:Object;
	private var nametagsEnabled:DistributedValue;
	private var loaded:Boolean;
	static var inStoneHenge:Boolean;

	public function Mod(root)
	{
		m_swfRoot = root;
		mouseListener = new Object();
		mouseListener.onMouseWheel = Delegate.create(this, onMouseWheel);
		nametagsEnabled = DistributedValue.Create("ShowVicinityNPCNametags");
		DvalHideMinimap = DistributedValue.Create("ODMap_HideMinimap");
		DvalReloadConfig = DistributedValue.Create("ODMap_ReloadConfig");
	}

	static function IsStoneHenge(zone)
	{
		inStoneHenge = zone == 7670;
		return inStoneHenge;
	}

	public function Load()
	{
		DvalHideMinimap.SignalChanged.Connect(SettingsChanged, this);
		WaypointInterface.SignalPlayfieldChanged.Connect(PlayfieldChanged, this);
		GlobalSignal.SignalSetGUIEditMode.Connect(GuiEdit, this);
		DvalReloadConfig.SignalChanged.Connect(ReloadConfig, this);
	}

	public function Unload()
	{
		DvalHideMinimap.SignalChanged.Disconnect(SettingsChanged, this);
		WaypointInterface.SignalPlayfieldChanged.Disconnect(PlayfieldChanged, this);
		GlobalSignal.SignalSetGUIEditMode.Disconnect(GuiEdit, this);
		DvalReloadConfig.SignalChanged.Disconnect(ReloadConfig, this);
	}

	public function Activate(conf:Archive)
	{
		config = conf;
		if (!loaded)
		{
			loaded = true;
			PlayfieldChanged(Character.GetClientCharacter().GetPlayfieldID());
		}
	}

	public function Deactivate():Archive
	{
		return config;
	}
	
	private function ReloadConfig(dv:DistributedValue)
	{
		if (dv.GetValue())
		{
			if (Container)
			{
				removeMap(true);
				AttachMap();
			}
			dv.SetValue(false);
		}
	}

	static function GetCachedLegend(id:ID32)
	{
		var entries:Array = config.FindEntryArray("legend");
		for (var i:Number = 0; i < entries.length; i++){
			var data:Array = entries[i].split(",");
			if (data[0] == id.toString()) return data[1];
		}
	}
	
	static function GetCachedLegends()
	{
		return config.FindEntryArray("legend");
	}
	
	static function CacheLegend(id:ID32, time:Number)
	{
		var entries:Array = config.FindEntryArray("legend");
		if (!entries) entries = [];
		var found;
		for (var i:Number = 0; i < entries.length; i++){
			var data:Array = entries[i].split(",");
			if (data[0] == id.toString()) found = i;
		}
		if (found == undefined) entries.push([id, time].join(","));
		else entries[found] = [id, time].join(",")
		Mod.config.DeleteEntry("legend");
		for (var i:Number = 0; i < entries.length; i++){
			config.AddEntry("legend", entries[i]);
		}
	}

	static function ClearCachedLegend(id:ID32)
	{
		var entries:Array = config.FindEntryArray("legend");
		for (var i:Number = 0; i < entries.length; i++){
			var data:Array = entries[i].split(",");
			if (data[0] == id.toString())
			{
				entries.splice(i,1);
				config.DeleteEntry("legend");
				for (var y:Number = 0; y < entries.length; y++)
				{
					config.AddEntry("legend", entries[y]);
				}
				break
			}
		}
	}

	static function ClearAllCachedLegends()
	{
		config.DeleteEntry("legend");
		var mod:GUIModuleIF = GUIModuleIF.FindModuleIF("ODMap");
		mod.StoreConfig(config);
	}

	public function SettingsChanged(dv:DistributedValue)
	{
		config.ReplaceEntry("hide", dv.GetValue());
		if (dv.GetValue() && inStoneHenge) DistributedValueBase.SetDValue("hud_map_window", false);
		else DistributedValueBase.SetDValue("hud_map_window", true);
	}

	public function PlayfieldChanged(zone)
	{
		if (IsStoneHenge(zone))
		{
			if (config.FindEntry("hide"))
			{
				DistributedValueBase.SetDValue("hud_map_window", false);
			}
			SavePreferences();
			if (!Container) AttachMap();
		}
		else
		{
			if (config.FindEntry("hide"))
			{
				DistributedValueBase.SetDValue("hud_map_window", true);
			}
			if (config.FindEntry("NametagsEnabled"))
			{
				nametagsEnabled.SetValue(false);
				config.DeleteEntry("NametagsEnabled");
			}
			if (Container)
			{
				removeMap();
				ClearAllCachedLegends();
			}
		}
	}

	public function removeMap(keepLegend)
	{
		m_Tracker.Disconnect(keepLegend);
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

	private function getMapPos()
	{
		var pos:Point = config.FindEntry("Pos");
		if (!pos)
		{
			pos = new Point(Stage.width - 200, DistributedValueBase.GetDValue("MinimapTopOffset"));
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
		if (Mouse.getTopMostEntity() != Container.Image)
		{
			return
		}
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
		m_Tracker.CalculateLocToPixel();
		m_Tracker.MoveMarkers();
		m_Tracker.m_Legend.UpdatePosSize();
	}

	private function AttachMap(temp)
	{
		Container = m_swfRoot.createEmptyMovieClip("MapContainer", m_swfRoot.getNextHighestDepth());
		var callback;
		if (inStoneHenge) callback = Delegate.create(this, MapLoaded);
		m_Map = new Map(Container, getMapPos(), getMapSize(), callback);
		if (inStoneHenge) GuiEdit(false);
	}

	private function MapLoaded()
	{
		AttachTracker();
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
			if (!inStoneHenge)
			{
				if (!Container) AttachMap(true);
			}
			Container.Image.onPress = Delegate.create(this, StartDrag);
			Container.Image.onRelease = Container.Image.onReleaseOutside = Delegate.create(this, StopDrag);
			Mouse.addListener(mouseListener);
		}
		else
		{
			Container.Image.onPress = Container.Image.onRelease = Container.Image.onReleaseOutside = undefined;
			if (!inStoneHenge)
			{
				removeMap();
			}
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