import com.GameInterface.AccountManagement;
import com.GameInterface.Chat;
import com.GameInterface.DistributedValue;
import com.GameInterface.DistributedValueBase;
import com.GameInterface.GUIModuleIF;
import com.GameInterface.Game.Character;
import com.GameInterface.ScryWidgets;
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
	static var DvalReloadConfig:DistributedValue;
	static var nametagsEnabled:DistributedValue;
	static var loaded:Boolean;
	static var inStoneHenge:Boolean;
	private var m_swfRoot:MovieClip;
	private var Container:MovieClip;
	private var m_Map:Map;
	private var m_Tracker:Tracker;

	public function Mod(root)
	{
		m_swfRoot = root;
		nametagsEnabled = DistributedValue.Create("ShowVicinityNPCNametags");
		DvalReloadConfig = DistributedValue.Create("ODMap_ReloadConfig");
	}

	static function IsStoneHenge(zone)
	{
		inStoneHenge = zone == 7670;
		return inStoneHenge;
	}

	public function Load()
	{
		WaypointInterface.SignalPlayfieldChanged.Connect(PlayfieldChanged, this);
		GlobalSignal.SignalSetGUIEditMode.Connect(GuiEdit, this);
		DvalReloadConfig.SignalChanged.Connect(ReloadConfig, this);
	}

	public function Unload()
	{
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

	public function PlayfieldChanged(zone)
	{
		if (IsStoneHenge(zone))
		{
			if (DistributedValueBase.GetDValue("ODMap_HideMinimap"))
			{
				HideMiniMap();
			}
			SaveNametagPreferences();
			if (!Container) AttachMap();
		}
		else
		{
			if (DistributedValueBase.GetDValue("ODMap_HideMinimap"))
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
	
	static function HideMiniMap()
	{
		if (!AccountManagement.GetInstance().GetLoginState() == _global.Enums.LoginState.e_LoginStateInPlay)
		{
			setTimeout(HideMiniMap, 1000);
		}
		else
		{
			DistributedValueBase.SetDValue("hud_map_window", false);
		}
	}

	public function removeMap(keepLegend)
	{
		GlobalSignal.SignalScryTimerLoaded.Disconnect(TweakTimer, this);
		ScryWidgets.SignalScryMessage.Disconnect(TweakTimer, this);
		m_Tracker.Disconnect(keepLegend);
		m_Tracker = undefined;
		Container.removeMovieClip();
		Container = undefined;
		m_Map = undefined;
	}

	public function SaveNametagPreferences()
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
		var oldSize = config.FindEntry("Size");
		if (delta > 0)
		{
			var newSize = oldSize + 5;
			if (newSize > 500) newSize = 500;
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
		if ( DistributedValueBase.GetDValue("TopMenuAlignment") == 0)
		{
			var minY = _root.mainmenuwindow.m_BackgroundBar.getBounds().yMax * _root.mainmenuwindow.m_BackgroundBar._yscale / 100 || 20;
			pos.y = Math.max(minY, pos.y);
		}
		config.ReplaceEntry("Pos", pos);
		m_Map.setPos(pos);
		m_Tracker.CalculateLocToPixel();
		m_Tracker.MoveMarkers();
		m_Tracker.m_Legend.UpdatePosSize();
	}

	private function AttachMap()
	{
		Container = m_swfRoot.createEmptyMovieClip("MapContainer", m_swfRoot.getNextHighestDepth());
		var callback:Function = Delegate.create(this, MapLoaded);
		m_Map = new Map(Container, getMapPos(), getMapSize(), callback);
	}

	private function MapLoaded()
	{
		AttachTracker();
		GuiEdit(false);
		if (DistributedValueBase.GetDValue("ODMap_TweakTimer"))
		{
			GlobalSignal.SignalScryTimerLoaded.Connect(TweakTimer, this);
			ScryWidgets.SignalScryMessage.Connect(TweakTimer, this);
		}
	}
	
	private function TweakTimer()
	{
		_root.scrytimer.m_PanelBackground._alpha = 0;
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
		if ( !inStoneHenge ) return
		TweakTimer();
		if (state)
		{
			Container.Image.onPress = Delegate.create(this, StartDrag);
			Container.Image.onRelease = Container.Image.onReleaseOutside = Delegate.create(this, StopDrag);
			Container.Image.onMouseWheel = Delegate.create(this, onMouseWheel);
		}
		else
		{
			StopDrag();
			delete Container.Image.onPress;
			delete Container.Image.onRelease;
			delete Container.Image.onReleaseOutside;
			delete Container.Image.onMouseWheel;
		}
	}

	private function AttachTracker()
	{
		m_Tracker = new Tracker(Container);
		m_Tracker.SignalLoadFailed.Connect(removeMap, this);
		m_Tracker.Start();
	}
}